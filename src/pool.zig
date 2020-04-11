const std = @import("std");
const p2p = @import("p2p.zig");

var default_allocator = p2p.default_allocator;

var pool_buffer: std.ArrayList(*Pool) = undefined;

pub fn init() void {
    pool_buffer = std.ArrayList(*Pool).init(default_allocator);
}

pub fn pool(u) *Pool {

}

pub const Pool = struct {
    uuid: p2p.Hash,

    sent_map: std.AutoHashMap([32]u8, bool),

    pub fn put(self: *Pool, data: []const u8) !bool {
        return false;

    }

    pub fn init(allocator: *std.mem.Allocator, uuid: [32]u8) Pool {
        return Pool {
            .uuid = uuid,
            .sent_map = std.AutoHashMap([32]u8, bool).init(allocator),

        };
    }
};
