const std = @import("std");
const p2p = @import("p2p");
const chat = @import("chat");

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
const Buffer = p2p.Buffer;

const functions = p2p.process_functions;

const warn = std.debug.warn;
const default_allocator = std.heap.page_allocator;

const c = p2p.c;

pub fn init() !void {
    p2p.init();
    chat.init();
}

var username: [:0]const u8 = undefined;

pub fn main() anyerror!void {
    warn("Chat\n", .{});
    try init();

    var argv = std.os.argv;
    if (argv.len < 3) {
        std.debug.panic("Not enough arguments: usage {} [username] [bind_point] [connection points] x N, e.g. bind_point = ipc:///tmp/dummy\n", .{argv[0]});
    }
    username = mem.spanZ(argv[1]);
    warn("Username: {}\n", .{username});

    const bind_point = mem.spanZ(argv[2]);
    chat.router = try p2p.Router.init(default_allocator, bind_point);

    try chat.router.?.add_route(0, void, chat.callbacks.greet);
    try chat.router.?.add_route(1, chat.ChatMessage, chat.callbacks.incoming_chat);

    var timer = p2p.timer.Timer.init();
    var f = struct {
        fn bla() void {
            warn("test\n", .{});
        }
    }.bla;
    try timer.add_timer(1000, f);
    try timer.start();
    // start router
    _ = try chat.router.?.start();

    //start line reader
    _ = try p2p.thread_pool.add_thread(username, chat.line_reader);

    // Add connections provided are arguments
    for (argv[3..]) |connect_point_arg| {
        var event = try chat.Events.AddConnection.init(default_allocator, Buffer.init(default_allocator, mem.spanZ(connect_point_arg)) catch unreachable);
        try chat.main_event_queue.queue_event(event);
    }

    //start main work queue
    try chat.main_event_queue.start_event_loop();

    // p2p.thread_pool.join();
    chat.main_event_queue.join();
}
