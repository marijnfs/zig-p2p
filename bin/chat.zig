const std = @import("std");
const p2p = @import("p2p");
const Socket = p2p.Socket;
const Message = p2p.Message;


const testing = std.testing;
const mem = std.mem;
const Allocator = mem.Allocator;
const Buffer = std.Buffer;

const warn = std.debug.warn;
const direct_allocator = std.heap.direct_allocator;

const c = @cImport({
    @cInclude("zmq.h");
    @cInclude("monocypher.h");
});

fn blake_hash_allocate(data: []u8, allocator: *mem.Allocator) ![]u8 {
    const key_size = 32;
    var hash = try allocator.alloc(u8, key_size);

    c.crypto_blake2b_general(hash.ptr, hash.len, null, 0, data.ptr, data.len);
    return hash;
}

fn blake_hash(data: []u8) [32]u8 {
    var hash: [32]u8 = undefined;
    c.crypto_blake2b_general(&hash, hash.len, null, 0, data.ptr, data.len);
    return hash;
}

const Chat = struct {
    user: []u8,
    message: []u8,

    fn init(user: [:0]const u8, message: [:0]const u8) !Chat {
        const user_buf = try direct_allocator.alloc(u8, user.len);
        std.mem.copy(u8, user_buf, user);

        const message_buf = try direct_allocator.alloc(u8, message.len);
        std.mem.copy(u8, message_buf, message);

        return Chat{
            .user = user_buf,
            .message = message_buf,
        };
    }

    fn deinit(self: *Chat) void {
        direct_allocator.free(self.user);
        direct_allocator.free(self.message);
    }
};

const WorkItem = struct {
    const Self = @This();

    fn deinit(work_item: *WorkItem) void {
        work_item.deinit_fn(work_item);
    }

    fn process(work_item: *WorkItem) void {
        work_item.process_fn(work_item);
    }

    deinit_fn: fn (work_item: *WorkItem) void,
    process_fn: fn (work_item: *WorkItem) void
};

const SendWorkItem = struct {
    const Self = @This();
    work_item: WorkItem,
    chat: Chat,
    allocator: *Allocator,

    fn init(allocator: *Allocator, chat: Chat) !*SendWorkItem {
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

    fn deinit(work_item: *WorkItem) void {
        const self = @fieldParentPtr(SendWorkItem, "work_item", work_item);
        self.chat.deinit();
        self.allocator.destroy(self);
    }

    fn process(work_item: *WorkItem) void {
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

const PresentWorkItem = struct {
    const Self = @This();
    work_item: WorkItem,
    chat: Chat,
    allocator: *Allocator,

    fn init(allocator: *Allocator, chat: Chat) !*PresentWorkItem {
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

    fn deinit(work_item: *WorkItem) void {
        const self = @fieldParentPtr(PresentWorkItem, "work_item", work_item);
        self.chat.deinit();
        self.allocator.destroy(self);
    }

    fn process(work_item: *WorkItem) void {
        const self = @fieldParentPtr(PresentWorkItem, "work_item", work_item);
        warn("{}: {}\n", .{ self.chat.user, self.chat.message });
    }
};

const RelayWorkItem = struct {
    const Self = @This();
    work_item: WorkItem,
    chat: Chat,
    allocator: *Allocator,

    fn init(allocator: *Allocator, chat: Chat) !*RelayWorkItem {
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

    fn deinit(work_item: *WorkItem) void {
        const self = @fieldParentPtr(RelayWorkItem, "work_item", work_item);
        self.chat.deinit();
        self.allocator.destroy(self);
    }

    fn process(work_item: *WorkItem) void {
        const self = @fieldParentPtr(RelayWorkItem, "work_item", work_item);

        for (outgoing_connections.span()) |*conn| {
            var msg = Message.init_slice(self.chat.message) catch unreachable;
            conn.queue_message(msg) catch unreachable;
        }
    }
};
var PRNG = std.rand.DefaultPrng.init(0);

const CheckConnectionWorkItem = struct {
    const Self = @This();
    work_item: WorkItem,
    allocator: *Allocator,

    fn init(allocator: *Allocator) !*Self {
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

    fn deinit(work_item: *WorkItem) void {
        const self = @fieldParentPtr(CheckConnectionWorkItem, "work_item", work_item);
        self.allocator.destroy(self);
    }

    fn process(work_item: *WorkItem) void {
        const self = @fieldParentPtr(CheckConnectionWorkItem, "work_item", work_item);

        var i: usize = 0;
        while (i < outgoing_connections.len) {
            var current = outgoing_connections.ptrAt(i);
            if (!current.active) {
                warn("Removing connection: {}\n", .{current});

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

fn receiver(socket: *Socket) void {
    while (true) {
        //receive a message
        var msg = Message.init();
        defer msg.deinit();
        var rc_recv = socket.recv(&msg);

        var buffer = msg.get_buffer() catch unreachable;
        defer buffer.deinit();

        //send response immediately
        var return_msg = Message.init();
        defer return_msg.deinit();

        var rc_send = socket.send(&return_msg);

        //setup work item and add to queue
        var chat = p2p.deserialize(Chat, buffer.span(), direct_allocator) catch unreachable;

        //var chat = Chat.init("incoming", buffer.span(), direct_allocator) catch unreachable;

        const hash = blake_hash(chat.message);
        var optional_kv = sent_map.put(hash, true) catch unreachable;
        if (optional_kv) |kv| {
            continue;
        }

        var present_work_item = PresentWorkItem.init(direct_allocator, chat) catch unreachable;
        work_queue.push(&present_work_item.work_item) catch unreachable;

        var chat_copy = Chat.init("incoming", buffer.span()) catch unreachable;
        var relay_work_item = RelayWorkItem.init(direct_allocator, chat_copy) catch unreachable;
        work_queue.push(&relay_work_item.work_item) catch unreachable;
    }
}

fn line_reader(arg: void) void {
    const stdin = std.io.getStdIn().inStream();

    while (true) {
        // read a line
        var line = stdin.readUntilDelimiterAlloc(direct_allocator, '\n', 10000) catch break;
        if (line.len == 0)
            continue;
        // set up chat
        var chat = Chat.init(username, line[0..:0]) catch unreachable;

        // add work item to queue
        var send_work_item = SendWorkItem.init(direct_allocator, chat) catch unreachable;
        work_queue.push(&send_work_item.work_item) catch unreachable;
    }
}

var work_queue: p2p.AtomicQueue(*WorkItem) = undefined;
var known_addresses: std.ArrayList([:0]u8) = undefined;
var outgoing_connections: std.ArrayList(OutgoingConnection) = undefined;
var sent_map: std.AutoHashMap([32]u8, bool) = undefined;

const OutgoingConnection = struct {
    const Self = @This();

    fn init(connect_point: [:0]const u8) !OutgoingConnection {
        var connect_socket = Socket.init(context, c.ZMQ_REQ);
        try connect_socket.connect(connect_point);

        return OutgoingConnection{
            .send_queue = p2p.AtomicQueue(Message).init(direct_allocator),
            .socket = connect_socket,
            .connect_point = try std.Buffer.init(direct_allocator, connect_point),
            .active = true,
        };
    }

    fn deinit(self: *Self) void {
        self.connect_point.deinit();
    }

    fn queue_message(self: *Self, message: Message) !void {
        try self.send_queue.push(message);
    }

    connect_point: std.Buffer,
    send_queue: p2p.AtomicQueue(Message),
    socket: Socket,
    active: bool
};

fn connection_processor(outgoing_connection: *OutgoingConnection) void {
    while (true) {
        if (outgoing_connection.send_queue.empty()) {
            std.time.sleep(1000000);
            continue;
        }

        var message = outgoing_connection.send_queue.pop() catch break;
        defer message.deinit();

        var rc = outgoing_connection.socket.send(&message);
        if (rc == -1)
            break;
        var reply = Message.init();
        rc = outgoing_connection.socket.recv(&reply);
        if (rc == -1)
            break;
    }

    //when we get here the connection must be inactive
    outgoing_connection.active = false;
}

fn discovery_reminder(discovery_period_sec: i64) void {
    while (true) {
        std.time.sleep(100000000 * discovery_period_sec);
    }
}

fn connection_manager(check_period_sec: u64) void {
    while (true) {
        std.time.sleep(100000000 * check_period_sec);
        var check_connection_item = CheckConnectionWorkItem.init(direct_allocator) catch unreachable;
        work_queue.push(&check_connection_item.work_item) catch unreachable;
    }
}

fn worker(arg: void) void {
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

var bind_socket: Socket = undefined;
var context: ?*c_void = undefined;

pub fn init() !void {
    context = c.zmq_ctx_new();

    known_addresses = std.ArrayList([:0]u8).init(direct_allocator);
    outgoing_connections = std.ArrayList(OutgoingConnection).init(direct_allocator);
    work_queue = p2p.AtomicQueue(*WorkItem).init(direct_allocator);

    sent_map = std.AutoHashMap([32]u8, bool).init(direct_allocator);
}

var username: [:0] const u8 = undefined;

pub fn main() anyerror!void {
    warn("Chat\n", .{});
    try init();

    var argv = std.os.argv;
    if (argv.len < 4) {
        std.debug.panic("Not enough arguments: usage {} [bind_point] [connect_point] [username], e.g. bind_point = ipc:///tmp/dummy\n", .{argv[0]});
    }
    const bind_point = mem.toSliceConst(u8, argv[1]);
    const connect_point = mem.toSliceConst(u8, argv[2]);
    username = mem.spanZ(argv[3]);

    warn("Username: {}\n", .{username});

    bind_socket = Socket.init(context, c.ZMQ_REP);
    try bind_socket.bind(bind_point);

    var outgoing_connection = try OutgoingConnection.init(connect_point);
    try outgoing_connections.append(outgoing_connection);

    var receiver_thread = try std.Thread.spawn(&bind_socket, receiver);
    var line_reader_thread = try std.Thread.spawn({}, line_reader);
    var manager_period: u64 = 4;
    var connection_manager_thread = try std.Thread.spawn(manager_period, connection_manager);

    var connection_thread = try std.Thread.spawn(outgoing_connections.ptrAt(0), connection_processor);

    // Main worker thread
    var worker_thread = try std.Thread.spawn({}, worker);

    receiver_thread.wait();
    line_reader_thread.wait();
    worker_thread.wait();
    connection_manager_thread.wait();

    warn("Binding to: {}, connecting to: {}", .{ bind_point, connect_point });
}