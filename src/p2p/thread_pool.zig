const std = @import("std");
const p2p = @import("p2p.zig");


var thread_pool: std.ArrayList(*std.Thread) = undefined;

pub fn init() void {
    thread_pool = std.ArrayList(*std.Thread).init(p2p.default_allocator);
}

pub const ThreadError = error {
    Exited,
    Fail,
};

pub fn add_thread(context: var, comptime startFn: var) !void {
    try thread_pool.append(try std.Thread.spawn(context, startFn));
}

pub fn join() void {
    for (thread_pool.items) |thread| {
        thread.wait();
    }
}