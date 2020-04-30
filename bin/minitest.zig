const std = @import("std");

const warn = std.debug.warn;
const default_allocator = std.heap.page_allocator;

pub var zmq_context: *c_void = undefined; //zmq context

pub const c = @cImport({
    @cInclude("zmq.h");
    @cInclude("monocypher.h");
    @cInclude("sys/socket.h");
    @cInclude("sys/types.h");
    @cInclude("sys/ioctl.h");
    @cInclude("netinet/in.h");
    @cInclude("net/if.h");
    @cInclude("arpa/inet.h");
    @cInclude("ifaddrs.h");
});

pub fn init() !void {
    zmq_context = c.zmq_ctx_new();
}

pub fn reader() !void {
    var pull_sock = c.zmq_socket(zmq_context, c.ZMQ_PULL);
    var router_sock = c.zmq_socket(zmq_context, c.ZMQ_ROUTER);
 
    {
        var str = try std.mem.dupeZ(std.heap.c_allocator, u8, "ipc:///tmp/pull");
        _ = c.zmq_bind(pull_sock, str);
    }
    {
        var str = try std.mem.dupeZ(std.heap.c_allocator, u8, "ipc:///tmp/router");
        _ = c.zmq_bind(router_sock, str);
    }

    while (true) {
        var poll_items: [2]c.zmq_pollitem_t = undefined;
        poll_items[0].socket = pull_sock;
        poll_items[0].events = c.ZMQ_POLLIN;
        poll_items[0].revents = 0;
        poll_items[0].fd = 0;
        poll_items[1].socket = router_sock;
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

pub fn writer() !void {
    var push_sock = c.zmq_socket(zmq_context, c.ZMQ_PUSH);
    var str = try std.mem.dupeZ(std.heap.c_allocator, u8, "ipc:///tmp/pull");
    _ = c.zmq_connect(push_sock, str);

    while (true) {
        var msg: c.zmq_msg_t = undefined;
        _ = c.zmq_msg_init(&msg);
        _ = c.zmq_msg_send(&msg, push_sock, 0);
        std.time.sleep(100000000);
    }
}

pub fn requester() !void {
    var req_sock = c.zmq_socket(zmq_context, c.ZMQ_REQ);
    var str = try std.mem.dupeZ(std.heap.c_allocator, u8, "ipc:///tmp/router");
     _ = c.zmq_connect(req_sock, str);


    while (true) {
        warn("read socket\n", .{});
        var msg: c.zmq_msg_t = undefined;

        _ = c.zmq_msg_init(&msg);
        defer _ = c.zmq_msg_close(&msg);
        _ = c.zmq_msg_send(&msg, req_sock, 0);

        var msg_recv: c.zmq_msg_t = undefined;
        _ = c.zmq_msg_init(&msg_recv);
        defer _ = c.zmq_msg_close(&msg_recv);
        _ = c.zmq_msg_recv(&msg_recv, req_sock, 0);

        std.time.sleep(100000000);
    }
}

pub fn reader_void(v: void) void {
    reader() catch unreachable;
}

pub fn writer_void(v: void) void {
    writer() catch unreachable;
}

pub fn requester_void(v: void) void {
    requester() catch unreachable;
}

pub fn main() anyerror!void {
    warn("Chat\n", .{});
    try init();

    var t = try std.Thread.spawn({}, reader_void);
    var t2 = try std.Thread.spawn({}, writer_void);
    var t3 = try std.Thread.spawn({}, requester_void);

    t.wait();
    t2.wait();
    t3.wait();
}
