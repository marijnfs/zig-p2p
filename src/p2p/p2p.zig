pub const std = @import("std");

pub const connection_management = @import("connection_management.zig");
pub const thread_pool = @import("thread_pool.zig");

pub const Message = @import("message.zig").Message;
pub const Socket = @import("socket.zig").Socket;
pub const router = @import("router.zig");
pub const Router = router.Router;

pub const serializer = @import("serializer.zig");
pub const serialize = serializer.serialize;
pub const deserialize = serializer.deserialize;
pub const serialize_tagged = serializer.serialize_tagged;
pub const deserialize_tagged = serializer.deserialize_tagged;

pub const AtomicQueue = @import("queue.zig").AtomicQueue;
pub const event = @import("event.zig");
pub const proxy = @import("proxy.zig").proxy;
pub const OutgoingConnection = @import("outgoing_connection.zig").OutgoingConnection;

pub const Hash = @import("hash.zig").Hash;
pub const hash = @import("hash.zig").hash;

pub const blake_hash = @import("hash.zig").blake_hash;
pub const blake_hash_allocate = @import("hash.zig").blake_hash_allocate;
pub const Pool = @import("pool.zig").Pool;

pub const timer = @import("timer.zig");

pub const Buffer = std.ArrayListSentineled(u8, 0);

pub const c = @import("c.zig").c;

pub const default_allocator = std.heap.page_allocator;

pub var zmq_context: ?*c_void = undefined; //zmq context

pub fn init() void {
    std.debug.warn("Initializing ZMQ context\n", .{});
    zmq_context = c.zmq_ctx_new();

    thread_pool.init();
    connection_management.init();
}
