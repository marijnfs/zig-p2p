const chat = @import("chat.zig");
const p2p = chat.p2p;
const default_allocator = p2p.default_allocator;

pub var main_event_queue: p2p.event.EventQueue = undefined;

pub fn init() void {
    main_event_queue = p2p.event.EventQueue.init(default_allocator);
}