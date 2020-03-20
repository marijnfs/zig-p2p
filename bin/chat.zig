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

const Chat = struct {
    user: std.Buffer,
    message: std.Buffer,

    fn deinit(self: *Chat) void {
        // self.user.deinit();
        // self.message.deinit();
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
    socket: Socket,
    allocator: *Allocator,

    fn init(allocator: *Allocator, socket: Socket, chat: Chat) !*SendWorkItem {
        var ptr = try allocator.create(Self);
        ptr.* = SendWorkItem {
            .work_item = WorkItem {
                .deinit_fn = deinit,
                .process_fn = process,
            },
            .chat = chat,
            .socket = socket,
            .allocator = allocator,
        };
        return ptr;
    }

    fn deinit(work_item: *WorkItem) void {
        const self = @fieldParentPtr(SendWorkItem, "work_item", work_item);
        self.chat.deinit();
        // self.allocator.destroy(self);
    }

    fn process(work_item: *WorkItem) void {
        const self = @fieldParentPtr(SendWorkItem, "work_item", work_item);

        var msg = Message.init_buffer(self.chat.message.span()) catch unreachable;
        defer msg.deinit();
        var rc_send = self.socket.send(&msg);

        var return_msg = Message.init();
        defer return_msg.deinit();

        var rc_recv = self.socket.recv(&return_msg);
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
        warn("Line: {}", .{self.chat.message});

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
        var chat = Chat{
            .user = Buffer.init(direct_allocator, "incoming") catch unreachable, 
            .message = Buffer.initFromBuffer(buffer) catch unreachable
        };

        var present_work_item = PresentWorkItem.init(direct_allocator, chat) catch unreachable;
        work_queue.push(present_work_item.work_item) catch unreachable;

        //receive response
        var return_msg = Message.init();
        defer return_msg.deinit();

        var rc_send = socket.send(&return_msg);
    }
}

fn line_reader(socket: *Socket) void {
    const stdin = std.io.getStdIn().inStream();
    
    while (true) {
        // read a line
        var line = stdin.readUntilDelimiterAlloc(direct_allocator, '\n', 10000) catch break;

        // set up a work item
        var chat = Chat{
            .user = Buffer.init(direct_allocator, "user") catch unreachable, 
            .message = Buffer.init(direct_allocator, line) catch unreachable
        };
        var send_work_item = SendWorkItem.init(direct_allocator, socket.*, chat) catch unreachable;
        work_queue.push(send_work_item.work_item) catch unreachable;
    }
}


var work_queue: p2p.AtomicQueue(WorkItem) = undefined;


fn worker(context: void) void {
    while (true) {
        if (work_queue.empty()) {
            std.time.sleep(1000000);
            continue;
        }

        var work_item = work_queue.pop() catch unreachable;
        defer work_item.deinit();

        work_item.process();
    }
}

var bind_socket: Socket = undefined;
var connect_socket: Socket = undefined;

pub fn main() anyerror!void {
    warn("Chat\n", .{});

    work_queue = p2p.AtomicQueue(WorkItem).init(direct_allocator);

    while (!work_queue.empty()) {
        warn("queue item: {}\n", .{work_queue.pop()});
    }

    var context = c.zmq_ctx_new();

    var argv = std.os.argv;
    if (argv.len < 3) {
        std.debug.panic("Not enough arguments: usage {} [bind_point] [connect_point], e.g. bind_point = ipc:///tmp/dummy\n", .{argv[0]});
    }
    const bind_point = mem.toSliceConst(u8, argv[1]);
    const connect_point = mem.toSliceConst(u8, argv[2]);


    bind_socket = Socket.init(context, c.ZMQ_REP);
    connect_socket = Socket.init(context, c.ZMQ_REQ);

    try bind_socket.bind(bind_point);
    try connect_socket.connect(connect_point);

    var receiver_thread = try std.Thread.spawn(&bind_socket, receiver);
    var line_reader_thread = try std.Thread.spawn(&connect_socket, line_reader);
    var worker_thread = try std.Thread.spawn({}, worker);

    receiver_thread.wait();
    line_reader_thread.wait();
    worker_thread.wait();

    warn("Binding to: {}, connecting to: {}", .{bind_point, connect_point});


}
