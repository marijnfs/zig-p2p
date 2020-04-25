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

var event_queue: p2p.EventQueue;

pub fn init() !void {
    p2p.init();
    chat.init();
}

pub fn reader(context: void) !void {
    var pull_sock = try p2p.Socket.init(p2p.connection_management.context, p2p.c.ZMQ_PULL);
    var router_sock = try p2p.Socket.init(p2p.connection_management.context, p2p.c.ZMQ_ROUTER);

    try pull_sock.bind("ipc:///tmp/pull");
    try router_sock.bind("ipc:///tmp/router");

    while (true) {
        var poll_items: [2]c.zmq_pollitem_t = undefined;
        poll_items[0].socket = pull_sock.socket;
        poll_items[0].events = c.ZMQ_POLLIN;
        poll_items[0].revents = 0;
        poll_items[0].fd = 0;
        poll_items[1].socket = router_sock.socket;
        poll_items[1].events = c.ZMQ_POLLIN;
        poll_items[1].revents = 0;
        poll_items[1].fd = 0;

        var rc = c.zmq_poll(&poll_items, poll_items.len, -1);
        if (rc == -1) {
            warn("polling fail\n", .{});
            break;
        }

        if (poll_items[0].revents != 0) {
            warn("item 0\n", .{});
        }
        if (poll_items[1].revents != 0) {
            warn("item 1\n", .{});
        }
        std.time.sleep(100000000);
    }
}

pub fn writer(context: void) !void {
    var push_sock = try p2p.Socket.init(p2p.connection_management.context, p2p.c.ZMQ_PUSH);
    try push_sock.connect("ipc:///tmp/pull");

    while (true) {
        var msg = try p2p.Message.init();
        try push_sock.send(&msg);
        std.time.sleep(100000000);
    }
}

pub fn requester(context: void) !void {
    var req_sock = try p2p.Socket.init(p2p.connection_management.context, p2p.c.ZMQ_REQ);
    try req_sock.connect("ipc:///tmp/router");

    while (true) {
        warn("read socket\n", .{});
        var blanc = try Message.init();
        try req_sock.send(&blanc);
        var msg = try req_sock.recv();
        try req_sock.send(&msg);

        std.time.sleep(100000000);
    }
}

pub fn reader_void(context: void) void {
    reader(context) catch unreachable;
}

pub fn writer_void(context: void) void {
    writer(context) catch unreachable;
}

pub fn requester_void(context: void) void {
    requester(context) catch unreachable;
}

pub fn main() anyerror!void {
    warn("Chat\n", .{});
    try init();

    _ = try p2p.thread_pool.add_thread({}, reader_void);
    _ = try p2p.thread_pool.add_thread({}, writer_void);
    _ = try p2p.thread_pool.add_thread({}, requester_void);

    p2p.thread_pool.join();
}
