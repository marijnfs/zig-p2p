const std = @import("std");
const mem = std.mem;
const Allocator = mem.Allocator;
const direct_allocator = std.heap.direct_allocator;

const p2p = @import("p2p.zig");
const WorkQueue = @import("queue.zig").AtomicQueue(WorkItem);
const Chat = @import("chat.zig").Chat;

//Default work item.
//Work Items should embed this and link the function pointers deinit_fn and process_fn to their deinit and process functions.
pub const WorkItem = struct {
    const Self = @This();

    pub fn deinit(work_item: *WorkItem) void {
        work_item.deinit_fn(work_item);
    }

    pub fn process(work_item: *WorkItem) void {
        work_item.process_fn(work_item);
    }

    deinit_fn: fn (work_item: *WorkItem) void,
    process_fn: fn (work_item: *WorkItem) void
};

pub var work_queue: p2p.AtomicQueue(*WorkItem) = undefined;

pub fn init() void {
    work_queue = p2p.AtomicQueue(*WorkItem).init(direct_allocator);
}

//Main worker function, grabbing work items and processing them
pub fn worker(context: void) void {
    while (true) {
        if (work_queue.empty()) {
            std.time.sleep(100000);
            continue;
        }

        var work_item = work_queue.pop() catch unreachable;
        defer work_item.deinit();

        work_item.process();
    }
}

