const std = @import("std");
const testing = std.testing;
const mem = std.mem;
const Allocator = mem.Allocator;

const direct_allocator = std.heap.direct_allocator;

const c = @cImport({
    @cInclude("zmq.h");
});



pub const Message = struct {
    msg: c.zmq_msg_t,

    pub fn init(buffer: [] const u8) Message {
        var tmp_msg: c.zmq_msg_t = undefined;
        var rc = c.zmq_msg_init_data(&tmp_msg, @intToPtr(*u8, @ptrToInt(buffer.ptr)), buffer.len, null, null);
        return Message{
            .msg = tmp_msg,
        };
    }

    pub fn deinit(self: *Socket) void {
        _ = c.zmq_msg_close(&msg);
    }

    pub fn data(self: *Message) []u8 {
        var ptr = c.zmq_msg_data(&self.msg);
        var zig_ptr = @ptrCast([*]const u8, ptr);
        var len = c.zmq_msg_size(&self.msg);
        var alloc_data = direct_allocator.alloc(u8, len) catch unreachable;
        @memcpy(alloc_data.ptr, zig_ptr, len);
        return alloc_data;
    }

};