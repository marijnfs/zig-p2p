const std = @import("std");
const p2p = @import("p2p");
const Socket = p2p.Socket;
const Message = p2p.Message;

const Serializer = p2p.Serializer;
const Deserializer = p2p.Deserializer;

const testing = std.testing;
const mem = std.mem;
const Allocator = mem.Allocator;

const direct_allocator = std.heap.direct_allocator;

const c = @cImport({
    @cInclude("zmq.h");
    @cInclude("monocypher.h");
});

const Bla = struct {
    a: i64,
    b: f64,
};

pub fn main() anyerror!void {
    var context = c.zmq_ctx_new();

    var test_socket = Socket.init(context, c.ZMQ_REQ);
    var rc = test_socket.connect("ipc:///tmp/test");

    var counter: u64 = 0;

    while (true) {
        {
            var bla = Bla{ .a = 2, .b = 4 };
            var serializer = try Serializer.init();
            var err = try serializer.serialize(bla);
            var buffer = serializer.buffer();
            var message = Message.init_buffer(buffer);
            defer message.deinit();
            rc = test_socket.send(&message);
        }

        {
            var message = Message.init();
            defer message.deinit();

            rc = test_socket.recv(&message);
            var recv_data = try message.get_buffer();
            defer recv_data.deinit();
            std.debug.warn("{x}", .{recv_data});
        }

        counter += 1;
    }

    std.debug.warn("All your base are belong to us.\n", .{});
}
