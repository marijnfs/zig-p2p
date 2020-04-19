const std = @import("std");
const p2p = @import("p2p.zig");

const mem = std.mem;
const Allocator = mem.Allocator;

// Default Event.
// Events should embed this and link the function pointers deinit_fn and process_fn to their deinit and process functions.
// Use make_event to create event structs.

pub const Event = struct {
    const Self = @This();

    pub fn deinit(event: *Event) void {
        event.deinit_fn(event);
    }

    pub fn process(event: *Event) void {
        event.process_fn(event);
    }

    pub fn free(event: *Event) void {
        event.free_fn(event);
    }

    deinit_fn: fn (event: *Event) void,
    process_fn: fn (event: *Event) void,
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
    //     std.debug.warn("event processor: {}\n", .{@ptrToInt(event_queue)});
    //     std.debug.warn("--: {}\n", .{@ptrToInt(&event_queue.queue)});
    //     std.debug.warn("--: {}\n", .{event_queue});
        while (true) {
            if (event_queue.queue.empty()) {
                std.time.sleep(100000);
                continue;
            }

            var event = event_queue.queue.pop() catch unreachable;
            defer event.deinit();

            event.process();
        }
    }

    pub fn start_event_loop(self: *EventQueue) !void {
        // std.debug.warn("start event processor: {}\n", .{@ptrToInt(self)});
        // std.debug.warn("--: {}\n", .{@ptrToInt(&self.queue)});
        // std.debug.warn("--: {}\n", .{self});
        self.thread = try p2p.thread_pool.add_thread(self, EventQueue.event_processor);
    }

    pub fn join(self: *EventQueue) void {
        std.debug.warn("join\n", .{});
        if (self.thread) |t| {
            t.wait();
        }
    }
};

pub fn make_event(comptime EventType: type, event_function: fn (data: *EventType) void) type {
    return struct {
        const Self = @This();
        event_data: EventType,
        event: Event,

        pub fn init(allocator: *Allocator, event_data: EventType) !*Self {
            var event_type = try allocator.create(Self);
            event_type.event_data = event_data;
            event_type.event = .{
                .process_fn = process,
                .deinit_fn = deinit,
                .free_fn = free,
            };

            return event_type;
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

        pub fn process(event: *Event) void {
            const self = @fieldParentPtr(Self, "event", event);
            event_function(&self.event_data);
        }
    };
}
