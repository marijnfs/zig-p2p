const std = @import("std");
const p2p = @import("p2p.zig");

const mem = std.mem;
const Allocator = mem.Allocator;
const default_allocator = p2p.default_allocator;

// Default Event.
// Events should embed this and link the function pointers deinit_fn and process_fn to their deinit and process functions.
// Use make_event to create event structs.

pub const Event = struct {
    const Self = @This();

    pub fn deinit(event: *Event) void {
        event.deinit_fn(event);
    }

    pub fn process(event: *Event) anyerror!void {
        try event.process_fn(event);
    }

    pub fn free(event: *Event) void {
        event.free_fn(event);
    }

    deinit_fn: fn (event: *Event) void,
    process_fn: fn (event: *Event) anyerror!void,
    free_fn: fn (event: *Event, allocator: *Allocator) void
};

pub const EventQueue = struct {
    queue: p2p.AtomicQueue(*Event),
    thread: ?*std.Thread,

    pub fn init(allocator: *Allocator) EventQueue {
        return .{
            .queue = p2p.AtomicQueue(*Event).init(allocator),
            .thread = null,
        };
    }

    pub fn queue_event(self: *EventQueue, value: var) !void {
        try self.queue.push(&value.event);
    }

    //Main worker function, grabbing work items and processing them
    pub fn event_processor(event_queue: *EventQueue) void {
        std.debug.warn("start processor {}\n", .{@ptrToInt(event_queue)});

        while (true) {
            if (event_queue.queue.empty()) {
                std.time.sleep(100000000);
                // std.debug.warn("event {}\n", .{@ptrToInt(event_queue)});
                continue;
            }

            var event = event_queue.queue.pop() catch unreachable;
            defer event.deinit();

            event.process() catch unreachable;
        }
    }

    pub fn start_event_loop(self: *EventQueue) !void {
        std.debug.warn("start event loop {}\n", .{@ptrToInt(self)});

        self.thread = try p2p.thread_pool.add_thread(self, EventQueue.event_processor);
    }

    pub fn join(self: *EventQueue) void {
        std.debug.warn("join\n", .{});
        if (self.thread) |t| {
            t.wait();
        }
    }
};

pub fn make_event(comptime EventType: type, event_function: fn (data: *EventType) anyerror!void) type {
    return struct {
        const Self = @This();
        event_data: EventType,
        event: Event,

        pub fn create(event_data: EventType) !*Self {
            var event = try default_allocator.create(Self);
            event.event_data = event_data;
            event.event = .{
                .process_fn = process,
                .deinit_fn = deinit,
                .free_fn = free,
            };

            return event;
        }

        pub fn free(event: *Event, allocator: *Allocator) void {
            const self = @fieldParentPtr(Self, "event", event);
            allocator.destroy(self);
        }

        pub fn deinit(event: *Event) void {
            const self = @fieldParentPtr(Self, "event", event);
            if (comptime std.meta.trait.hasFn("deinit")(EventType))
                self.event_data.deinit();
        }

        pub fn process(event: *Event) anyerror!void {
            const self = @fieldParentPtr(Self, "event", event);
            try event_function(&self.event_data);
        }
    };
}
