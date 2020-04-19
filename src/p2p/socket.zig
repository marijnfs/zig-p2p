const std = @import("std");
const p2p = @import("p2p.zig");

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
        std.debug.warn("connecting to: {}\n", .{endpoint});

        const rc = c.zmq_connect(self.socket, endpoint);

        if (rc == -1)
            return error.ConnectionFailed;
    }

    pub fn bind(self: *Socket, endpoint: [:0]const u8) !void {
        std.debug.warn("binding to: {}\n", .{endpoint});
        const rc = c.zmq_bind(self.socket, endpoint);
        if (rc == -1)
            return error.ConnectionFailed;
    }

    pub fn send(self: *Socket, message: *Message) !void {
        const rc = c.zmq_msg_send(@ptrCast([*c]c.struct_zmq_msg_t, message.msg), self.socket.?, 0);
        if (rc == -1)
            return error.ConnectionFailed;
    }

    pub fn send_more(self: *Socket, message: *Message) !void {
        const rc = c.zmq_msg_send(@ptrCast([*c]c.struct_zmq_msg_t, message.msg), self.socket.?, c.ZMQ_SNDMORE);
        if (rc == -1)
            return error.ConnectionFailed;
    }

    pub fn recv(self: *Socket) !Message {
        var message = try Message.init();
        var rc = c.zmq_msg_recv(@ptrCast([*c]c.struct_zmq_msg_t, message.msg), self.socket.?, 0);
        if (rc == -1)
            return error.ConnectionFailed;
        return message;
    }

};

pub fn start_proxy(frontend: *Socket, backend: *Socket) void {
    c.zmq_proxy(frontend.socket, backend.socket, 0);
}
