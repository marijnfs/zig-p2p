const std = @import("std");
const p2p = @import("p2p");
const Socket = p2p.Socket;
const Message = p2p.Message;

const Serializer = p2p.Serializer;
const Deserializer = p2p.Deserializer;

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

const Chat = struct {
    user: []u8,
    message: []u8,
    allocator: *Allocator,

    fn init(user: [:0] const u8, message: [:0] const u8, allocator: *Allocator) !Chat {
        const user_buf = try allocator.alloc(u8, user.len);
        std.mem.copy(u8, user_buf, user);

        const message_buf = try allocator.alloc(u8, message.len);
        std.mem.copy(u8, message_buf, message);

        return Chat {
            .user = user_buf,
            .message = message_buf,
            .allocator = allocator,
        };
    }

    fn deinit(self: *Chat) void {
        self.allocator.free(self.user);
        self.allocator.free(self.message);
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
        ptr.* = SendWorkItem {
            .work_item = WorkItem {
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
        // var serializer: Serializer = undefined;

        var msg = Message.init_slice(self.chat.message) catch unreachable;
        var some_hash = blake_hash_allocate(self.chat.message, direct_allocator) catch unreachable;
        warn("Some Hash: {x}\n", .{some_hash});

        var i: usize = 0;
        while (i < outgoing_connections.len) : (i += 1) {
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

        ptr.* = PresentWorkItem {
            .work_item = WorkItem {
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
        warn("{}: {}\n", .{self.chat.user, self.chat.message});
    }
};

var PRNG = DefaultPrng.init(0);

const CheckConnectionWorkItem = struct {
    const Self = @This();
    work_item: WorkItem,
    allocator: *Allocator,

    fn init(allocator: *Allocator) !*Self {
        var ptr = try allocator.create(Self);

        ptr.* = CheckConnectionWorkItem {
            .work_item = WorkItem {
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
        warn("discovery\n", .{});

        var i: usize = 0;
        while (i < outgoing_connections.len()) {
            var current = outgoing_connections.ptrAt(i);
            if (!current.active()) {
                current.deinit();
                outgoing_connections.orderedRemove(i);
            } else {
                i += 1;
            }

        }

        const K: usize = 8;
        if (known_addresses.len() > outgoing_connections.len()) {
            var n: usize = 0;
            while (n < k and outgoing_connections.len() < k) {
                var selected_address = PRNG.random.int(known_addresses.len());

                var found: bool = false;
                for (outgoing_connections) |*conn| {
                    if (std.mem.eql(u8, conn.connect_point.span(), selected_address)) {
                        found = true;
                        break;
                    }
                }
                if (found) continue;

                var outgoing_connection = try OutgoingConnection.init(connect_point);
                outgoing_connections.append(outgoing_connection);
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

        //setup work item and add to queue
        var chat = Chat.init("incoming", buffer.span(), direct_allocator) catch unreachable;
        var present_work_item = PresentWorkItem.init(direct_allocator, chat) catch unreachable;
        work_queue.push(&present_work_item.work_item) catch unreachable;

        //receive response
        var return_msg = Message.init();
        defer return_msg.deinit();

        var rc_send = socket.send(&return_msg);
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
        var chat = Chat.init("user", line[0..:0], direct_allocator) catch unreachable;

        // add work item to queue
        var send_work_item = SendWorkItem.init(direct_allocator, chat) catch unreachable;
        work_queue.push(&send_work_item.work_item) catch unreachable;
    }
}


var work_queue: p2p.AtomicQueue(*WorkItem) = undefined;
var known_addresses: std.ArrayList([:0]u8) = undefined;
var outgoing_connections: std.ArrayList(OutgoingConnection) = undefined;
var sent_map: std.AutoHashMap([]u8, []u8) = undefined;


const OutgoingConnection = struct {
    const Self = @This();

    fn init(connect_point: [:0] const u8) !OutgoingConnection {
        var connect_socket = Socket.init(context, c.ZMQ_REQ);
        try connect_socket.connect(connect_point);

        return OutgoingConnection{
            .send_queue = p2p.AtomicQueue(Message).init(direct_allocator),
            .socket = connect_socket,
            .connect_point = try std.Buffer.init(direct_allocator, connect_point)
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
    socket: Socket
};

fn connection_processor(outgoing_connection: *OutgoingConnection) void {
    while (true) {
        if (outgoing_connection.send_queue.empty()) {
            std.time.sleep(1000000);
            continue;
        }

        var message = outgoing_connection.send_queue.pop() catch unreachable;
        defer message.deinit();

        var rc = outgoing_connection.socket.send(&message);

        var reply = Message.init();
        rc = outgoing_connection.socket.recv(&reply);
    }   
}

fn discovery_reminder(discovery_period_sec: i64) void {
    while (true) {
        std.time.sleep(100000000 * discovery_period_sec);
    }
}



fn connection_manager(check_period_sec: i64) void {
    while (true) {
        std.time.sleep(100000000 * check_period_sec);
        var check_connection_item = CheckConnectionWorkItem.init() catch unreachable;

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
}

pub fn main() anyerror!void {
    warn("Chat\n", .{});
    try init();


    var argv = std.os.argv;
    if (argv.len < 3) {
        std.debug.panic("Not enough arguments: usage {} [bind_point] [connect_point], e.g. bind_point = ipc:///tmp/dummy\n", .{argv[0]});
    }
    const bind_point = mem.toSliceConst(u8, argv[1]);
    const connect_point = mem.toSliceConst(u8, argv[2]);


    bind_socket = Socket.init(context, c.ZMQ_REP);
    try bind_socket.bind(bind_point);

    var outgoing_connection = try OutgoingConnection.init(connect_point);
    try outgoing_connections.append(outgoing_connection);

    var receiver_thread = try std.Thread.spawn(&bind_socket, receiver);
    var line_reader_thread = try std.Thread.spawn({}, line_reader);
    var connection_thread = try std.Thread.spawn(outgoing_connections.ptrAt(0), connection_processor);

    

    // Main worker thread
    var worker_thread = try std.Thread.spawn({}, worker);

    receiver_thread.wait();
    line_reader_thread.wait();
    worker_thread.wait();

    warn("Binding to: {}, connecting to: {}", .{bind_point, connect_point});


}
