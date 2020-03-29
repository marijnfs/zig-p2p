pub const Message = @import("message.zig").Message;
pub const Socket = @import("socket.zig").Socket;
pub const serialize = @import("serializer.zig").serialize;
pub const deserialize = @import("serializer.zig").deserialize;
pub const serialize_tagged = @import("serializer.zig").serialize_tagged;
pub const deserialize_tagged = @import("serializer.zig").deserialize_tagged;
pub const AtomicQueue = @import("queue.zig").AtomicQueue;
pub const work = @import("work.zig");
pub const Chat = @import("chat.zig").Chat;
pub const connection_management = @import("connection_management.zig");
pub const OutgoingConnection = connection_management.OutgoingConnection;

pub const Hash = @import("hash.zig").Hash;
pub const blake_hash = @import("hash.zig").blake_hash;
pub const blake_hash_allocate = @import("hash.zig").blake_hash_allocate;
pub const process_functions = @import("process_functions.zig");
pub const pool = @import("pool.zig");
pub const work_items = @import("work_items.zig");
pub const c = @import("c.zig").c;

pub fn init() void {
    process_functions.init();
    connection_management.init();
    work.init();
}
