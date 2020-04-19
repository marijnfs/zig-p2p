const std = @import("std");
const fmt = std.fmt;

const Allocator = std.mem.Allocator;

const p2p = @import("p2p.zig");
const Socket = p2p.Socket;
const Message = p2p.Message;
const Chat = p2p.Chat;
var default_allocator = p2p.default_allocator;

const Buffer = std.ArrayListSentineled(u8, 0);

pub var context: ?*c_void = undefined; //zmq context
pub var outgoing_connections: std.ArrayList(*OutgoingConnection) = undefined;
pub var known_addresses: std.ArrayList(Buffer) = undefined;
pub var mutex: std.Mutex = undefined;

const c = p2p.c;

pub fn init() void {
    context = c.zmq_ctx_new();

    outgoing_connections = std.ArrayList(*OutgoingConnection).init(default_allocator);
    known_addresses = std.ArrayList(Buffer).init(default_allocator);
    mutex = std.Mutex.init();
}



pub const OutgoingConnection = struct {
    const Self = @This();

    pub fn init(connect_point: [:0]const u8) !*OutgoingConnection {
        var connect_socket = Socket.init(context, c.ZMQ_REQ);

        var con = try default_allocator.create(Self);
        con.* = OutgoingConnection{
            .socket = connect_socket,
            .event_queue = p2p.event.EventQueue.init(default_allocator),
            .connect_point = try Buffer.init(default_allocator, connect_point),
            .active = true,
        };

        try con.connect(connect_point);
        return con;
    }

    pub fn connect(self: *Self, connect_point: [:0]const u8) !void {
        try self.socket.connect(connect_point);
    }

    pub fn deinit(self: *Self) void {
        self.connect_point.deinit();
        self.event_queue.deinit();
        self.socket.close();

        default_allocator.free(self);
    }

    pub fn queue_event(self: *OutgoingConnection, value: var) !void {
        try self.event_queue.queue_event(value);
    }

    pub fn start_event_queue(self: *OutgoingConnection) void {
        std.debug.warn("Starting connection event queue: {}\n", .{self.event_queue});
        self.event_queue.start_event_queue() catch return;
    }

    connect_point: Buffer,
    event_queue: p2p.event.EventQueue,
    socket: Socket,
    active: bool
};

pub fn ip4_to_zeromq(ip: [4]u8, port: i64) !Buffer {
    var buf: [100]u8 = undefined;

    const buf_printed = try fmt.allocPrint(default_allocator, "tcp://{}.{}.{}.{}:{}", .{ ip[0], ip[1], ip[2], ip[3], port });
    defer default_allocator.free(buf_printed);
    var buffer = try Buffer.init(default_allocator, buf_printed);
    return buffer;
}
