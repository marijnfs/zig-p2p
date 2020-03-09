const std = @import("std");
const p2p = @import("p2p");
const Socket = p2p.Socket;
const Message = p2p.Message;

const testing = std.testing;
const mem = std.mem;
const Allocator = mem.Allocator;

const direct_allocator = std.heap.direct_allocator;

const c = @cImport({
    @cInclude("zmq.h");
    @cInclude("monocypher.h");
});

pub fn main() anyerror!void {
    std.debug.warn("All your base are belong to us.\n", .{});
    var context = c.zmq_ctx_new();

    var test_socket = Socket.init(context, c.ZMQ_REQ);
    std.debug.warn("All your base are belong to us.\n", .{});
    var rc = test_socket.connect("ipc:///tmp/test");
    std.debug.warn("connect: {}", .{rc});

    std.debug.warn("start while", .{});

    var counter: u64 = 0;
    var data = try std.heap.direct_allocator.alloc(u8, 1024);
    while (true) {
        if (counter % 10000 == 0)
            std.debug.warn("bla\n", .{});

        var some_msg = "asfa";
        var msg = Message.init_buffer(some_msg);
        rc = test_socket.send(&msg);
        rc = test_socket.recv(&msg);
        var recv_data = msg.get_data();
        std.debug.warn("{}", .{recv_data});

        counter += 1;
    }

    std.debug.warn("All your base are belong to us.\n", .{});
}
