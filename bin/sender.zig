const std = @import("std");
const p2p = @import("p2p");
const Socket = p2p.Socket;
const Message = p2p.Message;


const testing = std.testing;
const mem = std.mem;
const Allocator = mem.Allocator;

const warn = std.debug.warn;
const direct_allocator = std.heap.direct_allocator;

const c = p2p.c;

const Bla = struct {
    a: i64,
    b: f64,
};

pub fn main() anyerror!void {
    var context = c.zmq_ctx_new();

    var test_socket = Socket.init(context, c.ZMQ_REQ);
    try test_socket.connect("ipc:///tmp/test");

    var counter: u64 = 0;

    while (true) {
        {
            var bla = Bla{ .a = 2, .b = 4 };
            var buffer = try p2p.serialize(bla);
            warn("{}\n", .{buffer});
            defer buffer.deinit();
            var message = try Message.init_slice(buffer.span());
            defer message.deinit();
            var rc = test_socket.send(&message);
            warn("first line\n", .{});
        }

        {
            warn("second line\n", .{});
            var message = Message.init();
            warn("{}\n", .{message});
            defer message.deinit();
            warn("second line\n", .{});
            var rc = test_socket.recv(&message);
            warn("second line\n", .{});
            var recv_data = try message.get_buffer();
            defer recv_data.deinit();
            warn("second line\n", .{});
        }

        counter += 1;
    }

    std.debug.warn("All your base are belong to us.\n", .{});
}
