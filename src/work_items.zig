const p2p = @import("p2p.zig");
const std = @import("std");

const Allocator = std.mem.Allocator;
const Socket = p2p.Socket;
const Message = p2p.Message;
const Chat = p2p.Chat;
const direct_allocator = std.heap.direct_allocator;
const WorkItem = p2p.work.WorkItem;
const cm = p2p.connection_management;


var PRNG = std.rand.DefaultPrng.init(0);

pub const SendWorkItem = struct {
    const Self = @This();
    work_item: WorkItem,
    chat: Chat,
    allocator: *Allocator,

    pub fn init(allocator: *Allocator, chat: Chat) !*SendWorkItem {
        var ptr = try allocator.create(Self);
        ptr.* = SendWorkItem{
            .work_item = WorkItem{
                .deinit_fn = deinit,
                .process_fn = process,
            },
            .chat = chat,
            .allocator = allocator,
        };
        return ptr;
    }

    pub fn deinit(work_item: *WorkItem) void {
        const self = @fieldParentPtr(SendWorkItem, "work_item", work_item);
        self.chat.deinit();
        self.allocator.destroy(self);
    }

    pub fn process(work_item: *WorkItem) void {
        const self = @fieldParentPtr(SendWorkItem, "work_item", work_item);
        var buffer = p2p.serialize(self.chat) catch unreachable;
        defer buffer.deinit();

        var i: usize = 0;
        while (i < cm.outgoing_connections.len) : (i += 1) {
            var msg = Message.init_slice(buffer.span()) catch unreachable;
            cm.outgoing_connections.ptrAt(i).queue_message(msg) catch unreachable;
        }
    }
};

pub const PresentWorkItem = struct {
    const Self = @This();
    work_item: WorkItem,
    chat: Chat,
    allocator: *Allocator,

    pub fn init(allocator: *Allocator, chat: Chat) !*PresentWorkItem {
        var ptr = try allocator.create(Self);

        ptr.* = PresentWorkItem{
            .work_item = WorkItem{
                .deinit_fn = deinit,
                .process_fn = process,
            },
            .chat = chat,
            .allocator = allocator,
        };
        return ptr;
    }

    pub fn deinit(work_item: *WorkItem) void {
        const self = @fieldParentPtr(PresentWorkItem, "work_item", work_item);
        self.chat.deinit();
        self.allocator.destroy(self);
    }

    pub fn process(work_item: *WorkItem) void {
        const self = @fieldParentPtr(PresentWorkItem, "work_item", work_item);
        std.debug.warn("{}: {}\n", .{ self.chat.user, self.chat.message });
    }
};

pub const RelayWorkItem = struct {
    const Self = @This();
    work_item: WorkItem,
    chat: Chat,
    allocator: *Allocator,

    pub fn init(allocator: *Allocator, chat: Chat) !*RelayWorkItem {
        var ptr = try allocator.create(Self);

        ptr.* = RelayWorkItem{
            .work_item = WorkItem{
                .deinit_fn = deinit,
                .process_fn = process,
            },
            .chat = chat,
            .allocator = allocator,
        };
        return ptr;
    }

    pub fn deinit(work_item: *WorkItem) void {
        const self = @fieldParentPtr(RelayWorkItem, "work_item", work_item);
        self.chat.deinit();
        self.allocator.destroy(self);
    }

    pub fn process(work_item: *WorkItem) void {
        const self = @fieldParentPtr(RelayWorkItem, "work_item", work_item);

        for (cm.outgoing_connections.span()) |*conn| {
            var msg = Message.init_slice(self.chat.message) catch unreachable;
            conn.queue_message(msg) catch unreachable;
        }
    }
};

pub const CheckConnectionWorkItem = struct {
    const Self = @This();
    work_item: WorkItem,
    allocator: *Allocator,

    pub fn init(allocator: *Allocator) !*Self {
        var ptr = try allocator.create(Self);

        ptr.* = CheckConnectionWorkItem{
            .work_item = WorkItem{
                .deinit_fn = deinit,
                .process_fn = process,
            },
            .allocator = allocator,
        };
        return ptr;
    }

    pub fn deinit(work_item: *WorkItem) void {
        const self = @fieldParentPtr(CheckConnectionWorkItem, "work_item", work_item);
        self.allocator.destroy(self);
    }

    pub fn process(work_item: *WorkItem) void {
        const self = @fieldParentPtr(CheckConnectionWorkItem, "work_item", work_item);

        var i: usize = 0;
        while (i < cm.outgoing_connections.len) {
            var current = cm.outgoing_connections.ptrAt(i);
            if (!current.active) {
                std.debug.warn("Removing connection: {}\n", .{current});

                current.deinit();
                _ = cm.outgoing_connections.swapRemove(i);
            } else {
                i += 1;
            }
        }

        const K: usize = 8;
        if (cm.known_addresses.len > cm.outgoing_connections.len) {
            var n: usize = 0;
            while (n < K and cm.outgoing_connections.len < K) {
                var selection = PRNG.random.uintLessThan(usize, cm.known_addresses.len);
                var selected_address = cm.known_addresses.at(selection);

                var found: bool = false;
                for (cm.outgoing_connections.span()) |*conn| {
                    if (std.mem.eql(u8, conn.connect_point.span(), selected_address)) {
                        found = true;
                        break;
                    }
                }
                if (found) continue;

                var outgoing_connection = cm.OutgoingConnection.init(selected_address) catch unreachable;
                cm.outgoing_connections.append(outgoing_connection) catch unreachable;
            }
        }
        // outgoing_connections
    }
};
