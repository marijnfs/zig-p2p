const std = @import("std");
const p2p = @import("p2p.zig");


var thread_pool: std.ArrayList(*std.Thread) = undefined;
var mutex: std.Mutex = undefined;

pub fn init() void {
    thread_pool = std.ArrayList(*std.Thread).init(p2p.default_allocator);
    mutex = std.Mutex.init();
}

pub const ThreadError = error {
    Exited,
    Fail,
};

pub fn add_thread(context: var, comptime startFn: var) !*std.Thread {
    const held = mutex.acquire();
    defer held.release();

    var t = try std.Thread.spawn(context, startFn);
    try thread_pool.append(t);
    return t;
}

pub fn join() void {
    for (thread_pool.items) |thread| {
        thread.wait();
    }
}
