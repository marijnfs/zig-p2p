const std = @import("std");

const p2p = @import("chat.zig").p2p;

const Buffer = std.ArrayListSentineled(u8, 0);


pub fn Hello() !Buffer {
    var buffer = try p2p.serialize_tagged(0, @as(i64, 0));
    return buffer;
}
