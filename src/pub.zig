const std = @import("std");

const c = @cImport({
    @cInclude("zmq.h");
    @cInclude("monocypher.h");
});



pub fn main() anyerror!void {
    var context = c.zmq_ctx_new();

    var socket = c.zmq_socket(context, c.ZMQ_REP);

    const endpoint = "ipc:///tmp/test";
    var responder = c.zmq_bind(socket, endpoint);

    std.debug.warn("start loop", .{});

    while (true) {
        var msg : c.zmq_msg_t = undefined;
        var rc = c.zmq_msg_init(&msg);
        rc = c.zmq_msg_recv(&msg, socket, 0);
        //std.debug.warn("recv rc: {}\n", rc);

        //std.debug.warn("Received"); 
        rc = c.zmq_msg_send(&msg, socket, 0);
        //std.debug.warn("send rc: {}\n", rc);

    }
}
