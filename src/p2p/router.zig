const p2p = @import("p2p.zig");
const std = @import("std");
const c = p2p.c;

const default_allocator = p2p.default_allocator;
const DeserializerTagged = p2p.serializer.DeserializerTagged;
const Buffer = p2p.Buffer;
const Message = p2p.Message;
const warn = std.debug.warn;

// Data Structs
pub const RouteId = [4]u8;

pub const RouterIdMessage = struct {
    id: RouteId,
    buffer: Buffer,

    fn deinit(self: *RouterIdMessage) void {
        self.buffer.deinit();
    }
};

pub const Router = struct {
    const CallbackType = fn (*DeserializerTagged, RouteId, *p2p.Message) void;

    //const dealer_bind_point = "ipc:///tmp/dealer";
    //const pull_bind_point = "ipc:///tmp/pull";

    socket: *p2p.Socket,
    // dealer_socket: *p2p.Socket,

    bind_point: Buffer,
    // dealer_bind_point: Buffer,
    pull_bind_point: Buffer,
    reply_queue: p2p.AtomicQueue(RouterIdMessage),

    callback_map: std.AutoHashMap(i64, CallbackType),
    allocator: *std.mem.Allocator,

    pub fn queue_message(self: *Router, message: RouterIdMessage) !void {
        try self.reply_queue.push(message);
    }

    pub fn init(allocator: *std.mem.Allocator, bind_point: [:0]u8) !*Router {
        var router = try allocator.create(Router);

        router.* = Router{
            .socket = undefined,
            // .dealer_socket = undefined,
            .bind_point = try Buffer.init(allocator, bind_point),
            // .dealer_bind_point = try Buffer.init(allocator, try std.fmt.allocPrint(allocator, "{}{}", .{ bind_point, "_dealer" })),
            .pull_bind_point = try Buffer.init(allocator, "ipc:///tmp/pull"),

            .reply_queue = p2p.AtomicQueue(RouterIdMessage).init(allocator),
            .callback_map = std.AutoHashMap(i64, CallbackType).init(allocator),
            .allocator = allocator,
        };

        return router;
    }

    pub fn deinit(self: *Router) void {
        self.socket.deinit();
        self.callback_map.deinit();
        self.allocator.free(self);
    }

    pub fn add_route(self: *Router, tag: i64, comptime T: type, comptime callback: fn (T, RouteId, *p2p.Message) anyerror!void) !void {
        const bla = struct {
            fn f(deserializer: *DeserializerTagged, id: RouteId, id_message: *p2p.Message) void {
                var value = deserializer.deserialize(T) catch unreachable;
                callback(value, id, id_message) catch unreachable;
            }
        }.f;
        _ = try self.callback_map.put(tag, bla);
    }

    pub fn router_processor_void(self: *Router) void {
        self.router_processor() catch unreachable;
    }

    pub fn router_processor(self: *Router) !void {
        warn("start router\n", .{});

        //create sockets
        warn("binding router to {}\n", .{self.bind_point.span()});
        self.socket = try p2p.Socket.init(p2p.c.ZMQ_ROUTER);
        try self.socket.bind(self.bind_point.span());

        //Setup internal passthrough socket from writer to here
        var read_socket = try p2p.Socket.init(p2p.c.ZMQ_PULL);
        try read_socket.bind(self.pull_bind_point.span());

        var poll_items: [2]c.zmq_pollitem_t = undefined;
        poll_items[0].socket = read_socket.socket;
        poll_items[0].events = c.ZMQ_POLLIN;
        poll_items[0].revents = 0;
        poll_items[0].fd = 0;
        poll_items[1].socket = self.socket.socket;
        poll_items[1].events = c.ZMQ_POLLIN;
        poll_items[1].revents = 0;
        poll_items[1].fd = 0;

        while (true) {
            std.debug.warn("polling\n", .{});
            var rc = c.zmq_poll(&poll_items, poll_items.len, 1000);
            if (rc == -1) {
                std.debug.warn("polling fail\n", .{});
                return error.PollFail;
            }

            if (poll_items[0].revents != 0) { // Pull socket, meaning a reply to the router
                std.debug.warn("got Pull socket\n", .{});
                var msg_id = try read_socket.recv();
                defer msg_id.deinit();
                try self.socket.send_more(&msg_id);

                var msg_payload = try read_socket.recv();
                defer msg_payload.deinit();
                try self.socket.send(&msg_payload);
            }

            if (poll_items[1].revents != 0) { // Router socket
                std.debug.warn("got Router socket\n", .{});
                var msg_id = try self.socket.recv();
                defer msg_id.deinit();
                var id_buffer = try msg_id.get_buffer();
                defer id_buffer.deinit();
                warn("msgid: {x}\n", .{id_buffer.span()});
                warn("bla {x}", .{msg_id.get_peer_ip4()});

                var id: RouteId = id_buffer.span()[0..4].*;

                std.debug.warn("router got msg from id: {x}\n", .{id});

                if (!msg_id.more()) {
                    return error.ValidationError;
                }

                warn("recving payload\n", .{});
                var msg_payload = try self.socket.recv(); //actual package
                defer msg_payload.deinit();

                // setup deserializer for package
                var buffer = try msg_payload.get_buffer();
                defer buffer.deinit();
                warn("router got payload from id: {x}\n", .{buffer.span()});

                //Deserialize the payload
                var deserializer = p2p.deserialize_tagged(buffer.span(), default_allocator);
                defer deserializer.deinit();

                var tag = try deserializer.tag();
                var callback_kv = self.callback_map.get(tag);
                if (callback_kv != null) {
                    callback_kv.?(&deserializer, id, &msg_id);
                } else {
                    std.debug.warn("False tag: {}\n", .{tag});
                    // reply that this tag is unknown

                    var reply_message = RouterIdMessage{
                        .id = id,
                        .buffer = try Buffer.initSize(self.allocator, 0),
                    };

                    try self.queue_message(reply_message);

                    continue;
                }
            }
            std.debug.warn("next poll\n", .{});
        }

        std.debug.warn("Router stopped\n", .{});
    }

    fn router_writer_void(self: *Router) void {
        self.router_writer() catch unreachable;
    }

    // this writer checks the write queue, and sends it properly over to the PULL socket
    fn router_writer(self: *Router) !void {
        std.debug.warn("start router writer\n", .{});

        var write_socket = try p2p.Socket.init(p2p.c.ZMQ_PUSH);
        try write_socket.connect(self.pull_bind_point.span());

        while (true) {
            if (self.reply_queue.empty()) {
                std.time.sleep(100000000);
                // std.debug.warn("write sleep\n", .{});
                continue;
            }

            var reply = try self.reply_queue.pop();
            defer reply.deinit();

            var id_message = try Message.init_slice(reply.id[0..]);
            defer id_message.deinit();
            try write_socket.send_more(&id_message);

            var payload_message = try Message.init_slice(reply.buffer.span());
            defer payload_message.deinit();
            try write_socket.send(&payload_message);
        }
    }

    pub fn start(self: *Router) !void {
        //start the reader and writer
        _ = try p2p.thread_pool.add_thread(self, Router.router_processor_void);
        _ = try p2p.thread_pool.add_thread(self, Router.router_writer_void);
    }
};
