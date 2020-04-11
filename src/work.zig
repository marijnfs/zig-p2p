const std = @import("std");
const p2p = @import("p2p.zig");

const mem = std.mem;
const Allocator = mem.Allocator;

const default_allocator = p2p.default_allocator;

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

    pub fn free(work_item: *WorkItem) void {
        work_item.free_fn(work_item);
    }

    deinit_fn: fn (work_item: *WorkItem) void,
    process_fn: fn (work_item: *WorkItem) void,
    free_fn: fn (work_item: *WorkItem, allocator: *Allocator) void
};

pub var work_queue: p2p.AtomicQueue(*WorkItem) = undefined;

pub fn init() void {
    work_queue = p2p.AtomicQueue(*WorkItem).init(default_allocator);
}

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
            if (comptime std.meta.trait.hasFn("deinit")(Self))
                self.work_data.deinit();
        }

        pub fn process(work_item: *WorkItem) void {
            const self = @fieldParentPtr(Self, "work_item", work_item);
            work_function(&self.work_data);
        }
    };
}

pub fn queue_work_item(value: var) !void {
    try work_queue.push(&value.work_item);
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
