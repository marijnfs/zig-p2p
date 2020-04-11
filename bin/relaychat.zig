const std = @import("std");
const p2p = @import("p2p");

const chat_functions = @import("chat_functions.zig");
const router_receiver = chat_functions.router_receiver;

const Socket = p2p.Socket;
const Message = p2p.Message;
const work = p2p.work;
const wi = p2p.work_items;

const Chat = p2p.Chat;
const cm = p2p.connection_management;

const mem = std.mem;
const Allocator = mem.Allocator;
const Buffer = std.ArrayListSentineled(u8, 0);

const functions = p2p.process_functions;

const warn = std.debug.warn;
const default_allocator = std.heap.page_allocator;

const c = p2p.c;

pub var bind_socket: Socket = undefined;

pub fn init() !void {
    p2p.init();
    chat_functions.init();
}

var username: [:0]const u8 = undefined;


const IdMessage = struct {
    id: [4]u8,
    buffer: Buffer,

    fn deinit(self: *IdMessage) void {
        self.buffer.deinit();
    }
};

pub fn send_to_bind_socket(id_message: *IdMessage) void {
    var id_msg = Message.init_slice(id_message.id[0..]) catch unreachable;
    defer id_msg.deinit();
    var rc = bind_socket.send(&id_msg);

    var delim_msg = Message.init() catch unreachable;
    defer delim_msg.deinit();
    rc = bind_socket.send(&delim_msg);


    var payload_msg = Message.init_slice(id_message.buffer.span()) catch unreachable;
    defer payload_msg.deinit();
    rc = bind_socket.send(&payload_msg);
}

pub const SendToBindSocketWorkItem = work.make_work_item(IdMessage, send_to_bind_socket);


pub fn main() anyerror!void {
    warn("Chat\n", .{});
    try init();

    var argv = std.os.argv;
    if (argv.len < 3) {
        std.debug.panic("Not enough arguments: usage {} [username] [bind_point] [connection points] x N, e.g. bind_point = ipc:///tmp/dummy\n", .{argv[0]});
    }
    username = mem.spanZ(argv[1]);

    const bind_point = mem.spanZ(argv[2]);
    for (argv[3..]) |connect_point_arg| {
        const connect_point = mem.spanZ(connect_point_arg);
        var work_item = try wi.AddConnectionWorkItem.init(default_allocator, Buffer.init(default_allocator, connect_point) catch unreachable);
        try work.queue_work_item(work_item);
    }

    warn("Username: {}\n", .{username});

    bind_socket = Socket.init(cm.context, c.ZMQ_ROUTER);
    try bind_socket.bind(bind_point);

    var receiver_thread = try std.Thread.spawn(&bind_socket, router_receiver);
    var line_reader_thread = try std.Thread.spawn(username, functions.line_reader);
    var manager_period: u64 = 4;
    var connection_manager_reminder_thread = try std.Thread.spawn(manager_period, functions.connection_manager_reminder);

    // Main worker thread
    var worker_thread = try std.Thread.spawn({}, work.worker);

    receiver_thread.wait();
    line_reader_thread.wait();
    worker_thread.wait();
    connection_manager_reminder_thread.wait();

    warn("Binding to: {}", .{bind_point});
}
