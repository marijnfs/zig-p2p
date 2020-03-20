const std = @import("std");
const testing = std.testing;
const mem = std.mem;
const Allocator = mem.Allocator;

const direct_allocator = std.heap.direct_allocator;
const warn = std.debug.warn;
const c = @cImport({
    @cInclude("zmq.h");
});

pub const Message = struct {
    msg: c.zmq_msg_t,

    pub fn init() Message {
        var tmp_msg: c.zmq_msg_t = undefined;
        var rc = c.zmq_msg_init(&tmp_msg);
        return Message{
            .msg = tmp_msg,
        };
    }

    pub fn init_buffer(buffer: []const u8) !Message {
        var tmp_msg: c.zmq_msg_t = undefined;
        // allocate new buffer, as zeromq will take ownership of this memory
        var newbuf = try direct_allocator.alloc(u8, buffer.len);
        mem.copy(u8, newbuf[0..], buffer[0..]);
        var rc = c.zmq_msg_init_data(&tmp_msg, @intToPtr(*u8, @ptrToInt(newbuf.ptr)), newbuf.len, null, null);
        return Message{
            .msg = tmp_msg,
        };
    }

    pub fn deinit(self: *Message) void {
        _ = c.zmq_msg_close(&self.msg);
    }

    // returns copy of data in a buffer, buffer must be deinit()
    pub fn get_buffer(self: *Message) !std.Buffer {
        var ptr = c.zmq_msg_data(&self.msg);
        var zig_ptr = @ptrCast([*]const u8, ptr);
        var len = c.zmq_msg_size(&self.msg);

        var alloc_data = try direct_allocator.alloc(u8, len);
        @memcpy(alloc_data.ptr, zig_ptr, len);
        var buffer = try std.Buffer.fromOwnedSlice(direct_allocator, alloc_data);
        return buffer;
    }
};
