const std = @import("std");
const p2p = @import("p2p");
// const chat = @import("chat");
const warn = std.debug.warn;
// const default_allocator = std.heap.page_allocator;
const c = p2p.c;

pub fn init() !void {
    // p2p.init();
    // chat.init();
}

pub fn main() anyerror!void {
    warn("Tester\n", .{});
    try init();

    var argv = std.os.argv;
    if (argv.len < 2) {
        std.debug.panic("Not enough arguments: usage {} [username] [connect_point] [connection points] x N, e.g. connect_point = ipc:///tmp/dummy\n", .{argv[0]});
    }
    var connect_point = std.mem.spanZ(argv[1]);

    // var router = try p2p.Router.init(default_allocator, connect_point);
    // try router.start();
    // std.debug.warn("context: {}\n", .{p2p.connection_management.context});
    // var sock = try p2p.Socket.init(p2p.connection_management.context, p2p.c.ZMQ_ROUTER);
    // try sock.bind(connect_point);

    var context = c.zmq_ctx_new();
    //var socket: ?*c_void = undefined;
    warn("context: {}\n", .{context});
    var socket = c.zmq_socket(context, p2p.c.ZMQ_REQ);

    var rc = c.zmq_connect(socket, connect_point);
    if (rc == -1)
        return error.ZMQ_Error;

    var msg: c.zmq_msg_t = undefined;
    rc = c.zmq_msg_init(&msg);
    if (rc == -1)
        return error.ZMQ_Error;

    rc = c.zmq_msg_send(&msg, socket, 0);
    // rc = c.zmq_msg_recv(@ptrCast([*c]c.struct_zmq_msg_t, &msg), socket, 0);
    if (rc == -1)
        return error.ZMQ_Error;

    var rcv_msg: c.zmq_msg_t = undefined;
    rc = c.zmq_msg_init(&rcv_msg);
    if (rc == -1)
        return error.ZMQ_Error;

    rc = c.zmq_msg_recv(@ptrCast([*c]c.struct_zmq_msg_t, &rcv_msg), socket, 0);

    // var bla = sock.recv();

    //var bla = router.socket.recv();

    p2p.thread_pool.join();
}
