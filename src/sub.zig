const std = @import("std");

const c = @cImport({
    @cInclude("zmq.h");
    @cInclude("monocypher.h");
});



pub fn main() anyerror!void {
    std.debug.warn("All your base are belong to us.\n");
    var context = c.zmq_ctx_new();

    std.debug.warn("All your base are belong to us.\n");

    var socket = c.zmq_socket(context, c.ZMQ_REQ);

    const endpoint = c"ipc:///tmp/test";
    var responder = c.zmq_connect(socket, endpoint);

    std.debug.warn("start while");

    while (true) {
        const buf = "Some msg";
        var msg : c.zmq_msg_t = undefined;

        var rc = c.zmq_msg_init_data(&msg, @intToPtr(?*c_void, @ptrToInt(&buf)), 8, null, null);
        defer _ = c.zmq_msg_close(&msg);
        rc = c.zmq_msg_send(&msg, socket, 0);
        std.debug.warn("send rc: {}\n", rc);

        rc = c.zmq_msg_recv(&msg, socket, 0);
        std.debug.warn("recv rc: {}\n", rc);

        var ptr = c.zmq_msg_data(&msg);
        var len = c.zmq_msg_size(&msg);
        std.debug.warn("{} {}", ptr, len);

    }

    std.debug.warn("All your base are belong to us.\n");
}
