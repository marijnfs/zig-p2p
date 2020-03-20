const std = @import("std");
const p2p = @import("p2p");
const Socket = p2p.Socket;
const Message = p2p.Message;

const Serializer = p2p.Serializer;
const Deserializer = p2p.Deserializer;

const testing = std.testing;
const mem = std.mem;
const Allocator = mem.Allocator;

const warn = std.debug.warn;
const direct_allocator = std.heap.direct_allocator;

const c = @cImport({
    @cInclude("zmq.h");
    @cInclude("monocypher.h");
});

var work_queue: p2p.AtomicQueue(i64) = undefined;

fn reader(socket: *Socket) void {
    while (true) {
        var msg = Message.init();
        defer msg.deinit();
        var rc_recv = socket.recv(&msg);

        var buffer = msg.get_buffer() catch unreachable;
        defer buffer.deinit();

        warn("{}\n", .{buffer.span()});

        var return_msg = Message.init();
        defer return_msg.deinit();

        var rc_send = socket.send(&return_msg);
    }
}

fn sender(socket: *Socket) void {
    const stdin = std.io.getStdIn().inStream();

    
    while (true) {
        var line = stdin.readUntilDelimiterAlloc(direct_allocator, '\n', 10000) catch break;

        var msg = Message.init_buffer(line) catch unreachable;
        defer msg.deinit();
        var rc_send = socket.send(&msg);

        var return_msg = Message.init();
        defer return_msg.deinit();

        var rc_recv = socket.recv(&return_msg);
    }
}

const Chat = struct {
    user: string,
    message: string
};

pub fn main() anyerror!void {
    warn("Chat\n", .{});

    work_queue = p2p.AtomicQueue(i64).init(direct_allocator);
    try work_queue.push(1);
    try work_queue.push(2);
    try work_queue.push(3);
    try work_queue.push(4);
    _ = try work_queue.pop();
    try work_queue.push(5);    
    try work_queue.push(6);

    while (!work_queue.empty()) {
        warn("queue item: {}\n", .{work_queue.pop()});
    }

    var context = c.zmq_ctx_new();

    var argv = std.os.argv;
    if (argv.len < 3) {
        std.debug.panic("Not enough arguments: usage {} [bind_point] [connect_point], e.g. bind_point = ipc:///tmp/dummy\n", .{argv[0]});
    }
    const bind_point = mem.toSliceConst(u8, argv[1]);
    const connect_point = mem.toSliceConst(u8, argv[2]);





    var bind_socket = Socket.init(context, c.ZMQ_REP);
    var connect_socket = Socket.init(context, c.ZMQ_REQ);

    try bind_socket.bind(bind_point);
    try connect_socket.connect(connect_point);

    var read_thread = try std.Thread.spawn(&bind_socket, reader);
    var send_thread = try std.Thread.spawn(&connect_socket, sender);
    read_thread.wait();
    send_thread.wait();

    warn("Binding to: {}, connecting to: {}", .{bind_point, connect_point});


}
