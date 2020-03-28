const std = @import("std");
const p2p = @import("p2p.zig");

const Message = @import("message.zig").Message;

const testing = std.testing;
const mem = std.mem;
const Allocator = mem.Allocator;

const direct_allocator = std.heap.direct_allocator;

const c = p2p.c;

pub const Socket = struct {
    socket_type: c_int,
    socket: ?*c_void,

    pub fn init(context: ?*c_void, socket_type_: c_int) Socket {
        return Socket{
            .socket_type = socket_type_,
            .socket = c.zmq_socket(context, socket_type_),
        };
    }

    pub fn deinit(self: *Socket) void {
        const rc = c.zmq_close(self.socket);
    }

    pub fn connect(self: *Socket, endpoint: [:0]const u8) !void {
        const rc = c.zmq_connect(self.socket, endpoint);
        if (rc == -1)
            return error.ConnectionFailed;
    }

    pub fn bind(self: *Socket, endpoint: [:0]const u8) !void {
        const rc = c.zmq_bind(self.socket, endpoint);
        if (rc == -1)
            return error.ConnectionFailed;
    }

    pub fn send(self: *Socket, message: *Message) c_int {
        return c.zmq_msg_send(@ptrCast([*c]c.struct_zmq_msg_t, &message.msg), self.socket, 0);
    }

    pub fn recv(self: *Socket, message: *Message) c_int {
        return c.zmq_msg_recv(@ptrCast([*c]c.struct_zmq_msg_t, &message.msg), self.socket, 0);
    }
};
