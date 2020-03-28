const std = @import("std");
const p2p = @import("p2p.zig");
const cm = p2p.connection_management;
const testing = std.testing;
const mem = std.mem;
const Allocator = mem.Allocator;

const direct_allocator = std.heap.direct_allocator;
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
