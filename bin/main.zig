const std = @import("std");
const p2p = @import("p2p");
const Socket = p2p.Socket;
const Message = p2p.Message;
const Serializer = p2p.Serializer;

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
    std.debug.warn("All your base are belong to us.\n", .{});

    var socket = Socket.init(context, c.ZMQ_REP);
    defer socket.deinit();

    const endpoint = "ipc:///tmp/test";
    var rc = socket.bind(endpoint);
    std.debug.warn("bind: {}\n", .{rc});

    var serializer = try Serializer.init();
    var bla = Bla{ .a = 2, .b = 4 };
    var bloe: i64 = 5;
    var err = try serializer.serialize(bloe);
    var buf = serializer.buffer();

    std.debug.warn("start while\n", .{});
    std.debug.warn("{x}\n", .{buf});

    var message = Message.init();

    while (true) {
        std.debug.warn("message: {}", .{message});
        rc = socket.recv(&message);
        std.debug.warn("recv rc: {}\n", .{rc});

        var data = message.get_data();
        std.debug.warn("Received {}", .{data});

        var send_message = Message.init_buffer(buf);
        defer send_message.deinit();
        rc = socket.send(&send_message);
        std.debug.warn("send rc: {}\n", .{rc});
    }

    std.debug.warn("All your base are belong to us.\n");
}
