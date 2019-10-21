const std = @import("std");
const testing = std.testing;
const mem = std.mem;
const Allocator = mem.Allocator;

const c = @cImport({
    @cInclude("zmq.h");
    @cInclude("monocypher.h");
});


pub fn Socket(context: ?*c_void, socket_type_: c_int) type {
    return struct {
        socket_type: c_int,
        socket: ?*c_void,

        const Self = @This();

        pub fn init(allocator: *Allocator) Self {
            return Self {
                .socket_type = socket_type_,
                .socket = c.zmq_socket(context, socket_type_)
            };
        }

        pub fn send(data: []u8) void {
            
        }
    };
}

pub fn main() anyerror!void {
    std.debug.warn("All your base are belong to us.\n");
    var context = c.zmq_ctx_new();

    std.debug.warn("All your base are belong to us.\n");

    var socket = c.zmq_socket(context, c.ZMQ_REQ);

    const endpoint = c"ipc:///tmp/test";
    var responder = c.zmq_connect(socket, endpoint);

    std.debug.warn("start while");

    var counter : u64 = 0;
    var data = try std.heap.direct_allocator.alloc(u8, 1024);
    while (true) {
        if (counter % 10000 == 0)
            std.debug.warn("bla\n");

        const buf = "Some msg";
        var msg : c.zmq_msg_t = undefined;

        var rc = c.zmq_msg_init_data(&msg, @intToPtr(?*c_void, @ptrToInt(&data)), buf.len, null, null);
        defer _ = c.zmq_msg_close(&msg);
        rc = c.zmq_msg_send(&msg, socket, 0);
        //std.debug.warn("send rc: {}\n", rc);

        rc = c.zmq_msg_recv(&msg, socket, 0);
        //std.debug.warn("recv rc: {}\n", rc);

        var ptr = c.zmq_msg_data(&msg);
        var len = c.zmq_msg_size(&msg);
        std.debug.warn("{} {}", ptr, len);

        counter += 1;

    }

    std.debug.warn("All your base are belong to us.\n");
}
