const std = @import("std");
const p2p = @import("chat.zig").p2p;
const mem = std.mem;

const default_allocator = p2p.default_allocator;


pub const ChatMessage = struct {
    user: []u8,
    message: []u8,
    timestamp: u64,

    pub fn init(user: []const u8, message: []const u8, timestamp: u64) !ChatMessage {
        const user_buf = try default_allocator.alloc(u8, user.len);
        std.mem.copy(u8, user_buf, user);

        const message_buf = try default_allocator.alloc(u8, message.len);
        std.mem.copy(u8, message_buf, message);

        return ChatMessage{
            .user = user_buf,
            .message = message_buf,
            .timestamp = timestamp,
        };
    }

    pub fn deinit(self: *ChatMessage) void {
        default_allocator.free(self.user);
        default_allocator.free(self.message);
    }

    pub fn copy(self: ChatMessage) !ChatMessage {
        const user_buf = try mem.dupe(default_allocator, u8, self.user);
        const message_buf = try mem.dupe(default_allocator, u8, self.message);
        return .{
            .user = user_buf,
            .message = message_buf,
            .timestamp = self.timestamp,
        };
    }
};
