const std = @import("std");
const Allocator = std.mem.Allocator;

const p2p = @import("p2p.zig");
const Socket = p2p.Socket;
const Message = p2p.Message;
const Chat = p2p.Chat;
const direct_allocator = std.heap.direct_allocator;
const WorkItem = p2p.work.WorkItem;

pub var context: ?*c_void = undefined; //zmq context
pub var outgoing_connections: std.ArrayList(OutgoingConnection) = undefined;
pub var known_addresses: std.ArrayList([:0]u8) = undefined;

var PRNG = std.rand.DefaultPrng.init(0);


const c = p2p.c;


pub fn init() void {
    outgoing_connections = std.ArrayList(OutgoingConnection).init(direct_allocator);
    context = c.zmq_ctx_new();
    known_addresses = std.ArrayList([:0]u8).init(direct_allocator);
}

pub const OutgoingConnection = struct {
    const Self = @This();

    pub fn init(connect_point: [:0]const u8) !OutgoingConnection {
        var connect_socket = Socket.init(context, c.ZMQ_REQ);
        try connect_socket.connect(connect_point);

        return OutgoingConnection{
            .send_queue = p2p.AtomicQueue(Message).init(direct_allocator),
            .socket = connect_socket,
            .connect_point = try std.Buffer.init(direct_allocator, connect_point),
            .active = true,
        };
    }

    pub fn deinit(self: *Self) void {
        self.connect_point.deinit();
    }

    pub fn queue_message(self: *Self, message: Message) !void {
        try self.send_queue.push(message);
    }

    connect_point: std.Buffer,
    send_queue: p2p.AtomicQueue(Message),
    socket: Socket,
    active: bool
};

// Work item to send a chat to all outgoing connections
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
        while (i < outgoing_connections.len) : (i += 1) {
            var msg = Message.init_slice(buffer.span()) catch unreachable;
            outgoing_connections.ptrAt(i).queue_message(msg) catch unreachable;
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

        for (outgoing_connections.span()) |*conn| {
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
        while (i < outgoing_connections.len) {
            var current = outgoing_connections.ptrAt(i);
            if (!current.active) {
                std.debug.warn("Removing connection: {}\n", .{current});

                current.deinit();
                _ = outgoing_connections.swapRemove(i);
            } else {
                i += 1;
            }
        }

        const K: usize = 8;
        if (known_addresses.len > outgoing_connections.len) {
            var n: usize = 0;
            while (n < K and outgoing_connections.len < K) {
                var selection = PRNG.random.uintLessThan(usize, known_addresses.len);
                var selected_address = known_addresses.at(selection);

                var found: bool = false;
                for (outgoing_connections.span()) |*conn| {
                    if (std.mem.eql(u8, conn.connect_point.span(), selected_address)) {
                        found = true;
                        break;
                    }
                }
                if (found) continue;

                var outgoing_connection = OutgoingConnection.init(selected_address) catch unreachable;
                outgoing_connections.append(outgoing_connection) catch unreachable;
            }
        }
        // outgoing_connections
    }
};
