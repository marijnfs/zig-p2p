const chat = @import("chat.zig");
const p2p = chat.p2p;
const default_allocator = p2p.default_allocator;

pub var main_work_queue: p2p.work.WorkQueue = undefined;

pub fn init() void {
    main_work_queue = p2p.work.WorkQueue.init(default_allocator);
}