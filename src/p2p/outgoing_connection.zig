

pub const OutgoingConnection = struct {
    const Self = @This();

    pub fn init(connect_point: [:0]const u8) !*OutgoingConnection {
        var con = try default_allocator.create(Self);
        con.* = OutgoingConnection{
            .socket = try Socket.init(c.ZMQ_DEALER),
            .event_queue = p2p.event.EventQueue.init(default_allocator),
            .connect_point = try Buffer.init(default_allocator, connect_point),
            .active = true,
        };

        try con.connect();
        return con;
    }

    pub fn connect(self: *Self) !void {
        std.debug.warn("connecting {} {}\n", .{ self.socket, self.connect_point.span() });
        try self.socket.connect(self.connect_point.span());
    }

    pub fn deinit(self: *Self) void {
        self.connect_point.deinit();
        self.event_queue.deinit();
        self.socket.close();

        default_allocator.free(self);
    }

    pub fn queue_event(self: *OutgoingConnection, value: var) !void {
        std.debug.warn("queueing in outgoing connection {}\n", .{value});
        try self.event_queue.queue_event(value);
    }

    pub fn start_event_loop(self: *OutgoingConnection) !void {
        std.debug.warn("Starting connection event queue: {}\n", .{@ptrToInt(&self.event_queue)});
        try self.event_queue.start_event_loop();
        try self.start_monitor();
    }

    pub fn start_monitor(self: *OutgoingConnection) !void {
        var bind_point = "inproc://testingipc";
        std.debug.warn("Start Monitor\n", .{});
        try self.socket.start_zmq_monitor(bind_point);
        _ = try p2p.thread_pool.add_thread(self, monitor_reader);
    }

    connect_point: Buffer,
    event_queue: p2p.event.EventQueue,
    socket: *Socket,
    active: bool
};

pub fn monitor_reader(self: *OutgoingConnection) void {
    var bind_point = "inproc://testingipc";
    warn("Monitor Reader\n", .{});
    var pair_socket = Socket.init(p2p.connection_management.context, p2p.c.ZMQ_PAIR) catch unreachable;
    pair_socket.connect(bind_point) catch unreachable;

     warn("Monitor Reader\n", .{});
     while (true) {
        var msg = pair_socket.recv() catch unreachable;
        warn("Got monitor msg: {}\n", .{msg});

        var buf = msg.get_buffer() catch unreachable;
        defer buf.deinit();
    
        warn("Buf {x}\n", .{buf});
    }
     warn("End monitor\n", .{});
}
