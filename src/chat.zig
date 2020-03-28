const std = @import("std");
const mem = std.mem;

const default_allocator = std.heap.direct_allocator;

pub const Chat = struct {
    user: []u8,
    message: []u8,

    pub fn init(user: [:0]const u8, message: [:0]const u8) !Chat {
        const user_buf = try default_allocator.alloc(u8, user.len);
        std.mem.copy(u8, user_buf, user);

        const message_buf = try default_allocator.alloc(u8, message.len);
        std.mem.copy(u8, message_buf, message);

        return Chat{
            .user = user_buf,
            .message = message_buf,
        };
    }

    pub fn deinit(self: *Chat) void {
        default_allocator.free(self.user);
        default_allocator.free(self.message);
    }
};
