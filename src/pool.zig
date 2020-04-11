const std = @import("std");
const p2p = @import("p2p.zig");
const hash = p2p.hash;

var default_allocator = p2p.default_allocator;

pub fn Pool(comptime T: type) type {
    return struct {
        const Self = @This();

        uuid: p2p.Hash,

        sent_map: std.AutoHashMap([32]u8, T),

        items: std.ArrayList(T),

        new_item_callback: fn (T) void,

        pub fn put(self: *Self, item: T) !bool {
            var H = hash(item) catch unreachable;
            var optional_kv = try self.sent_map.put(H, item);
            if (optional_kv) |kv| {
                return true;
            }

            self.new_item_callback(item);
            try self.items.append(item);
            return false;
        }

        pub fn init(allocator: *std.mem.Allocator, uuid: [32]u8, new_item_callback: fn (T) void) Self {
            return .{
                .uuid = uuid,
                .sent_map = std.AutoHashMap([32]u8, T).init(allocator),
                .items = std.ArrayList(T).init(allocator),
                .new_item_callback = new_item_callback
            };
        }
    };
}
