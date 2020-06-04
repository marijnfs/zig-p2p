const std = @import("std");
const p2p = @import("p2p.zig");
const warn = std.debug.warn;

const Message = @import("message.zig").Message;

const testing = std.testing;
const mem = std.mem;
const Allocator = mem.Allocator;
const default_allocator = p2p.default_allocator;

const c = p2p.c;

var prng = std.rand.DefaultPrng.init(42);

pub const Socket = struct {
    socket_type: c_int,
    socket: ?*c_void,
    uuid: u64,

    pub fn init(context: ?*c_void, socket_type_: c_int) !*Socket {
        var sock = try default_allocator.create(Socket);
        sock.* = Socket{
            .socket_type = socket_type_,
            .socket = c.zmq_socket(context, socket_type_),
            .uuid = prng.random.int(u64),
        };
        return sock;
    }

    pub fn deinit(self: *Socket) void {
        const rc = c.zmq_close(self.socket);
        default_allocator.free(self);
    }

    pub fn connect(self: *Socket, endpoint: [:0]const u8) !void {
        warn("connecting to: {}\n", .{endpoint});

        const rc = c.zmq_connect(self.socket, endpoint);

        if (rc == -1)
            return error.ConnectionFailed;
    }

    pub fn bind(self: *Socket, endpoint: [:0]const u8) !void {
        warn("binding to: {}\n", .{endpoint});
        const rc = c.zmq_bind(self.socket, endpoint);
        if (rc == -1)
            return error.ConnectionFailed;
    }

    pub fn send(self: *Socket, message: *Message) !void {
        warn("sending over {x}\n", .{self.socket});
        const rc = c.zmq_msg_send(@ptrCast([*c]c.struct_zmq_msg_t, message.msg), self.socket.?, 0);
        if (rc == -1)
            return error.ConnectionFailed;
    }

    pub fn send_more(self: *Socket, message: *Message) !void {
        warn("send_more over {x}\n", .{self.socket});
        const rc = c.zmq_msg_send(@ptrCast([*c]c.struct_zmq_msg_t, message.msg), self.socket.?, c.ZMQ_SNDMORE);
        if (rc == -1)
            return error.ConnectionFailed;
    }

    pub fn recv(self: *Socket) !Message {
        warn("recv over {x}\n", .{self.socket});
        var message = try Message.init();
        var rc = c.zmq_msg_recv(@ptrCast([*c]c.struct_zmq_msg_t, message.msg), self.socket.?, 0);
        if (rc == -1)
            return error.ConnectionFailed;
        return message;
    }

    pub fn recv_noblock(self: *Socket) !Message {
        var message = try Message.init();
        errdefer message.deinit();
        var rc = c.zmq_msg_recv(@ptrCast([*c]c.struct_zmq_msg_t, message.msg), self.socket.?, c.ZMQ_DONTWAIT);
        if (rc == -1)
            return error.NoMessage;
        return message;
    }

    pub fn monitor(self: *Socket, bind_point: [:0]const u8) !void {
        var r = c.zmq_socket_monitor(self.socket, bind_point, c.ZMQ_EVENT_CONNECTED);
        if (r == -1) {
            warn("Failed to start monitor for sock: {}\n", .{self.socket});
            return error.MonitorFailed;
        }
    }
};
