const std = @import("std");
const p2p = @import("p2p.zig");

const mem = std.mem;
const Allocator = mem.Allocator;

// Default work item.
// Work Items should embed this and link the function pointers deinit_fn and process_fn to their deinit and process functions.
// Use make_work_item to create such work items.

pub const WorkItem = struct {
    const Self = @This();

    pub fn deinit(work_item: *WorkItem) void {
        work_item.deinit_fn(work_item);
    }

    pub fn process(work_item: *WorkItem) void {
        work_item.process_fn(work_item);
    }

    pub fn free(work_item: *WorkItem) void {
        work_item.free_fn(work_item);
    }

    deinit_fn: fn (work_item: *WorkItem) void,
    process_fn: fn (work_item: *WorkItem) void,
    free_fn: fn (work_item: *WorkItem, allocator: *Allocator) void
};

pub const WorkQueue = struct {
    queue: p2p.AtomicQueue(*WorkItem),

    pub fn init(allocator: *Allocator) WorkQueue {
        return .{
            .queue = p2p.AtomicQueue(*WorkItem).init(allocator),
        };
    }

    pub fn queue_work_item(self: *WorkQueue, value: var) !void {
        try self.work_queue.push(&value.work_item);
    }

    //Main worker function, grabbing work items and processing them
    pub fn work_process(work_queue: *WorkQueue) void {
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

    pub fn start_work_process(self: *WorkQueue) !void {
        try p2p.thread_pool.add_thread(self, WorkQueue.work_process);
    }
};


pub const DummyWorkData = struct {
    fn deinit(self: *DummyWorkData) void {}
};

pub fn make_work_item(comptime WorkType: type, work_function: fn (data: *WorkType) void) type {
    return struct {
        const Self = @This();
        work_data: WorkType,
        work_item: WorkItem,

        pub fn init(allocator: *Allocator, work_data: WorkType) !*Self {
            var work_type = try allocator.create(Self);
            work_type.work_data = work_data;
            work_type.work_item = .{
                .process_fn = process,
                .deinit_fn = deinit,
                .free_fn = free,
            };

            return work_type;
        }

        pub fn free(work_item: *WorkItem, allocator: *Allocator) void {
            const self = @fieldParentPtr(Self, "work_item", work_item);
            allocator.destroy(self);
        }

        pub fn deinit(work_item: *WorkItem) void {
            const self = @fieldParentPtr(Self, "work_item", work_item);
            if (comptime std.meta.trait.hasFn("deinit")(WorkType))
                self.work_data.deinit();
        }

        pub fn process(work_item: *WorkItem) void {
            const self = @fieldParentPtr(Self, "work_item", work_item);
            work_function(&self.work_data);
        }
    };
}
