const chat = @import("chat.zig");
const p2p = chat.p2p;
const std = @import("std");
const default_allocator = p2p.default_allocator;

pub var main_event_queue: p2p.event.EventQueue = undefined;

pub fn init() void {
    std.debug.warn("Inited main event queue\n", .{});
    main_event_queue = p2p.event.EventQueue.init(default_allocator);
}