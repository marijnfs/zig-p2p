const std = @import("std");
const p2p = @import("p2p");
const Socket = p2p.Socket;
const Message = p2p.Message;
const work = p2p.work;
const wi = p2p.work_items;

const Chat = p2p.Chat;
const cm = p2p.connection_management;

const mem = std.mem;
const Allocator = mem.Allocator;
const Buffer = std.Buffer;
const functions = p2p.process_functions;

const warn = std.debug.warn;
const direct_allocator = std.heap.direct_allocator;

const c = p2p.c;


var bind_socket: Socket = undefined;

pub fn init() !void {
    p2p.init();
}

var username: [:0] const u8 = undefined;

pub fn main() anyerror!void {
    warn("Chat\n", .{});
    try init();

    var argv = std.os.argv;
    if (argv.len < 3) {
        std.debug.panic("Not enough arguments: usage {} [username] [bind_point] [connection points] x N, e.g. bind_point = ipc:///tmp/dummy\n", .{argv[0]});
    }
    username = mem.spanZ(argv[1]);

    const bind_point = mem.toSliceConst(u8, argv[2]);
    for (argv[3..]) |connect_point_arg| {
        const connect_point = mem.toSliceConst(u8, connect_point_arg);
        var work_item = try wi.AddConnectionWorkItem.init(direct_allocator, std.Buffer.init(direct_allocator, connect_point) catch unreachable);
        try work.queue_work_item(work_item);
    }

    warn("Username: {}\n", .{username});

    bind_socket = Socket.init(cm.context, c.ZMQ_REP);
    try bind_socket.bind(bind_point);

    var receiver_thread = try std.Thread.spawn(&bind_socket, functions.receiver);
    var line_reader_thread = try std.Thread.spawn(username, functions.line_reader);
    var manager_period: u64 = 4;
    var connection_manager_reminder_thread = try std.Thread.spawn(manager_period, functions.connection_manager_reminder);

    // Main worker thread
    var worker_thread = try std.Thread.spawn({}, work.worker);

    receiver_thread.wait();
    line_reader_thread.wait();
    worker_thread.wait();
    connection_manager_reminder_thread.wait();

    warn("Binding to: {}", .{ bind_point });
}
