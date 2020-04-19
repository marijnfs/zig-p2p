const p2p = @import("p2p.zig");
const std = @import("std");


const default_allocator = p2p.default_allocator;
const DeserializerTagged = p2p.serializer.DeserializerTagged;

pub const RouteId = [4]u8;

pub const Router = struct {
    const CallbackType = fn (*DeserializerTagged, RouteId, *p2p.Message) void;

    socket: *p2p.Socket,
    callback_map: std.AutoHashMap(i64, CallbackType),
    allocator: *std.mem.Allocator,

    pub fn init(allocator: *std.mem.Allocator, bind_point: [:0]u8) !*Router {
        var router = try allocator.create(Router);

        var router_socket = try p2p.Socket.init(p2p.connection_management.context, p2p.c.ZMQ_ROUTER);
        router.* = Router{
            .socket = router_socket,
            .callback_map = std.AutoHashMap(i64, CallbackType).init(allocator),
            .allocator = allocator,
        };
        try router.socket.bind(bind_point);

        return router;
    }

    pub fn deinit(self: *Router) void {
        self.socket.deinit();
        self.callback_map.deinit();
        self.allocator.free(self);
    }

    pub fn add_route(self: *Router, tag: i64, comptime T: type, comptime callback: fn (T, RouteId, *p2p.Message) void) !void {
        const bla = struct {
            fn f(deserializer: *DeserializerTagged, id: RouteId, id_message: *p2p.Message) void {
                var value = deserializer.deserialize(T) catch unreachable;
                callback(value, id, id_message);
            }
        }.f;
        _ = try self.callback_map.put(tag, bla);
    }

    pub fn router_processor(self: *Router) void {
        std.debug.warn("start router\n", .{});
        //receive a message
        while (true) {
            std.debug.warn("router recv: sock{}\n", .{self.socket});

            var msg_id = self.socket.recv() catch break;
            defer msg_id.deinit();

            std.debug.warn("router got msg\n", .{});

            var id_buffer = msg_id.get_buffer() catch break;
            defer id_buffer.deinit();

            var id: RouteId = id_buffer.span()[0..4].*;

            if (!msg_id.more()) {
                break;
            }

            //delimiter
            var msg_delim = self.socket.recv() catch break;
            if (!msg_delim.more()) {
                break;
            }

            var msg_payload = self.socket.recv() catch break; //actual package


            // setup deserializer for package
            var buffer = msg_payload.get_buffer() catch break;
            defer buffer.deinit();

            var deserializer = p2p.deserialize_tagged(buffer.span(), default_allocator);
            defer deserializer.deinit();

            var tag = deserializer.tag() catch break;
            var callback_kv = self.callback_map.get(tag);
            if (callback_kv == null) {
                std.debug.warn("False tag: {}\n", .{tag});
                continue;
            }
            callback_kv.?.value(&deserializer, id, &msg_id);
        }
    }

    fn start(self: *Router) !void {
        _ = try p2p.thread_pool.add_thread(self, Router.router_processor);
    } 
};
