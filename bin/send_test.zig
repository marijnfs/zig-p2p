const std = @import("std");
const p2p = @import("p2p");
const chat = @import("chat");
const warn = std.debug.warn;
const default_allocator = std.heap.page_allocator;


pub var bind_socket: Socket = undefined;

pub fn init() !void {
    p2p.init();
    chat.init();
}

pub fn main() anyerror!void {
    warn("Tester\n", .{});
    try init();

    var argv = std.os.argv;
    if (argv.len < 2) {
        std.debug.panic("Not enough arguments: usage {} [username] [bind_point] [connection points] x N, e.g. bind_point = ipc:///tmp/dummy\n", .{argv[0]});
    }
    var connect_point = std.mem.spanZ(argv[1]);


    var outgoing = try p2p.OutgoingConnection.init(connect_point);
    // outgoing.start_event_loop();

    var hello_msg = try chat.messages.Hello();
    warn("hello buf: {x}\n", .{hello_msg.span()});

    var some_message = try p2p.Message.init_slice(hello_msg.span());
    try outgoing.socket.send(&some_message);

    // var reply_message = outgoing.socket.recv(); 

    // var chat_event = try chat.Events.SayHello.init(default_allocator, .{.socket = &outgoing.socket, .buffer = hello_msg});
    // try outgoing.queue_event(chat_event);

    p2p.thread_pool.join();
}

