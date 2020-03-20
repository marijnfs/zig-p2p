const std = @import("std");
const p2p = @import("p2p");
const Socket = p2p.Socket;
const Message = p2p.Message;
const Serializer = p2p.Serializer;
const Deserializer = p2p.Deserializer;

const warn = std.debug.warn;
const c = @cImport({
    @cInclude("zmq.h");
    @cInclude("monocypher.h");
});

const Bla = struct {
    a: i64,
    b: f64,
};

const endpoint = "ipc:///tmp/test";

pub fn main() anyerror!void {
    var context = c.zmq_ctx_new();

    var socket = Socket.init(context, c.ZMQ_REP);
    defer socket.deinit();

    try socket.bind(endpoint);

    while (true) {
        {
            var message = Message.init();
            defer message.deinit();
            var rc = socket.recv(&message);

            warn("recv rc: {}\n", .{rc});

            var deserializer = Deserializer.init();
            defer deserializer.deinit();
            var buffer = try message.get_buffer();
            var item = try deserializer.deserialize(Bla, buffer.span());
            warn("{}\n", .{item});
        }

        var send_message = try Message.init_buffer("hello");
        defer send_message.deinit();
        var rc = socket.send(&send_message);
        warn("send rc: {}\n", .{rc});
    }

    warn("All your base are belong to us.\n");
}
