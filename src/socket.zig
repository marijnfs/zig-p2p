const std = @import("std");
const Message = @import("message.zig").Message;

const testing = std.testing;
const mem = std.mem;
const Allocator = mem.Allocator;

const direct_allocator = std.heap.direct_allocator;

const c = @cImport({
    @cInclude("zmq.h");
});

pub const Socket = struct {
    socket_type: c_int,
    socket: ?*c_void,

    pub fn init(context: ?*c_void, socket_type_: c_int) Socket {
        return Socket{
            .socket_type = socket_type_,
            .socket = c.zmq_socket(context, socket_type_),
        };
    }

    pub fn deinit(self: *Socket) void {}

    pub fn connect(self: *Socket, endpoint: []const u8) void {
        var c_endpoint = direct_allocator.alloc(u8, endpoint.len + 1) catch unreachable;
        @memcpy(c_endpoint.ptr, endpoint.ptr, endpoint.len);
        c_endpoint[endpoint.len] = 0;

        _ = c.zmq_connect(self.socket, c_endpoint.ptr);
    }

    pub fn bind(self: *Socket, endpoint: []const u8) void {
        var c_endpoint = direct_allocator.alloc(u8, endpoint.len + 1) catch unreachable;
        @memcpy(c_endpoint.ptr, endpoint.ptr, endpoint.len);
        c_endpoint[endpoint.len] = 0;

        _ = c.zmq_bind(self.socket, c_endpoint.ptr);
    }

    pub fn send(self: *Socket, message: *Message) c_int {
        return c.zmq_msg_send(@ptrCast([*c]c.struct_zmq_msg_t, &message.msg), self.socket, 0);
    }

    pub fn recv(self: *Socket, message: *Message) c_int {
        return c.zmq_msg_recv(@ptrCast([*c]c.struct_zmq_msg_t, &message.msg), self.socket, 0);
    }
};
