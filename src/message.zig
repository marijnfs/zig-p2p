const std = @import("std");
const p2p = @import("p2p.zig");
const cm = p2p.connection_management;
const testing = std.testing;
const mem = std.mem;
const Allocator = mem.Allocator;
const Buffer = std.ArrayListSentineled(u8, 0);

const default_allocator = std.heap.page_allocator;
const warn = std.debug.warn;
const c = p2p.c;

pub const Message = struct {
    msg: c.zmq_msg_t,

    pub fn init() Message {
        var tmp_msg: c.zmq_msg_t = undefined;
        var rc = c.zmq_msg_init(&tmp_msg);
        return Message{
            .msg = tmp_msg,
        };
    }

    pub fn init_slice(buffer: []const u8) !Message {
        var tmp_msg: c.zmq_msg_t = undefined;
        // allocate new buffer, as zeromq will take ownership of this memory
        var rc = c.zmq_msg_init_size(&tmp_msg, buffer.len);

        mem.copy(u8, @ptrCast([*]u8, c.zmq_msg_data(&tmp_msg))[0..buffer.len], buffer[0..]);
    
        return Message{
            .msg = tmp_msg,
        };
    }

    pub fn deinit(self: *Message) void {
        _ = c.zmq_msg_close(&self.msg);
    }

    pub fn more(self: *Message) bool {
        return c.zmq_msg_more(&self.msg) == 1;
    }

    pub fn get_peer_ip4(self: *Message) [4]u8 {
        var ip: [4]u8 = undefined;
        const fd = c.zmq_msg_get(&self.msg, c.ZMQ_SRCFD);

        var addr_in: c.sockaddr_in = undefined;
        var len: c.socklen_t = @sizeOf(c.sockaddr_in);

        var result = c.getpeername(fd, @ptrCast([*c]c.sockaddr, &addr_in), &len);
        if (result == -1) {
            return ip;
        }
        var ip_int = addr_in.sin_addr.s_addr;

        var i: usize = 0;
        while (i < 4) : (i += 1) {
            ip[i] = @intCast(u8, ip_int % (1 << 8));
            ip_int /= 1 << 8;
        }

        return ip;
    }

    // returns copy of data in a buffer, buffer must be deinit()
    pub fn get_buffer(self: *Message) !Buffer {
        var ptr = c.zmq_msg_data(&self.msg);
        var zig_ptr = @ptrCast([*]const u8, ptr);
        var len = c.zmq_msg_size(&self.msg);

        var alloc_data = try default_allocator.alloc(u8, len);
        @memcpy(alloc_data.ptr, zig_ptr, len);
        var buffer = try Buffer.fromOwnedSlice(default_allocator, alloc_data);
        return buffer;
    }
};
