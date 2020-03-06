const std = @import("std");
const Socket = @import("socket.zig").Socket;
const Message = @import("message.zig").Message;
const Serializer = @import("serialize.zig").Serializer;

const c = @cImport({
    @cInclude("zmq.h");
    @cInclude("monocypher.h");
});

const mem = std.mem;
const Allocator = mem.Allocator;

const baseSize = 1 << 8; //256 bytes

const Archive = struct {
    allocator: *Allocator,
    buffer: ?[]u8,

    size: u64,
    index: u64,

    pub fn new(allocator: *Allocator) Archive {
        return Archive{ .allocator = allocator, .buffer = null, .size = 0, .index = 0 };
    }

    pub fn reserve(self: *Archive, size: u64) !void {
        if (self.size == 0) {
            self.size = baseSize;
            self.buffer = try self.allocator.alloc(u8, baseSize);
        }

        while (self.index + size > self.size) {
            self.size = self.size << 1;
            self.buffer = try self.allocator.realloc(self.buffer.?, self.size);
        }
    }

    pub fn output(self: *Archive, value: var) !void {
        const valueSize = @sizeOf(@TypeOf(value));
        try self.reserve(valueSize);
        std.mem.copy(u8, self.buffer.?, mem.asBytes(&value));
        self.index += valueSize;
    }

    pub fn serialize(self: *Archive, value: var) !void {
        const T = @TypeOf(value);
        switch (@typeInfo(T)) {
            .Int => {
                try self.output(value);
            },
            else => @compileError("Unable to format type '" ++ @typeName(T) ++ "'"),
        }
    }
};

const Bla = struct {
    a: i64,
    b: f64,
};

pub fn main() anyerror!void {
    var archive = Archive.new(std.heap.direct_allocator);
    var abc: i64 = 4;
    try archive.serialize(abc);

    std.debug.warn("All your base are belong to us.\n", .{});
    var context = c.zmq_ctx_new();

    std.debug.warn("All your base are belong to us.\n", .{});

    var socket = c.zmq_socket(context, c.ZMQ_REP);

    const endpoint = "ipc:///tmp/test";
    var responder = c.zmq_bind(socket, endpoint);

    std.debug.warn("start while", .{});

    var serializer = try Serializer.init();
    var bla = Bla{ .a = 2, .b = 4 };
    var err = try serializer.serialize(bla);
    var buf = serializer.buffer;

    std.debug.warn("{} {}\n", .{ buf.len(), buf.toSlice() });

    while (true) {
        var msg: c.zmq_msg_t = undefined;
        var rc = c.zmq_msg_init(&msg);
        rc = c.zmq_msg_recv(&msg, socket, 0);
        std.debug.warn("recv rc: {}\n", .{rc});

        std.debug.warn("Received", .{});
        rc = c.zmq_msg_send(&msg, socket, 0);
        std.debug.warn("send rc: {}\n", .{rc});
    }

    std.debug.warn("All your base are belong to us.\n");
}
