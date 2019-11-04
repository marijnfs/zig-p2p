const std = @import("std");
const testing = std.testing;
const mem = std.mem;
const Allocator = mem.Allocator;

const direct_allocator = std.heap.direct_allocator;

const c = @cImport({
    @cInclude("zmq.h");
    @cInclude("monocypher.h");
});

//dirty cast to deal with c_void*! etc.
fn hardCast(comptime T: type, comptime ptrT: type, ptr: ptrT) T {
    return @intToPtr(T, @ptrToInt(ptr));
}

const Message = struct {
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
        var zig_ptr = hardCast([*]const u8, @typeOf(ptr), ptr);
        var len = c.zmq_msg_size(&self.msg);
        var alloc_data = direct_allocator.alloc(u8, len) catch unreachable;
        @memcpy(alloc_data.ptr, zig_ptr, len);
        return alloc_data;
    }

};

const Socket = struct {
    socket_type: c_int,
    socket: ?*c_void,

    pub fn init(context: ?*c_void, socket_type_: c_int) Socket {
        return Socket {
            .socket_type = socket_type_,
            .socket = c.zmq_socket(context, socket_type_)
        };
    }

    pub fn connect(self: *Socket, endpoint: [] const u8) void {
        var c_endpoint = direct_allocator.alloc(u8, endpoint.len + 1) catch unreachable;
        @memcpy(c_endpoint.ptr, endpoint.ptr, endpoint.len);
        c_endpoint[endpoint.len] = 0;

        _ = c.zmq_connect(self.socket, c_endpoint.ptr);
    }

    pub fn send(self: *Socket, mesage: *Message) void {
        _ = c.zmq_msg_send(&mesage.msg, self.socket, 0);
    }

    pub fn recv(self: *Socket, message: *Message) void {
        _ = c.zmq_msg_recv(&message.msg, self.socket, 0);
    }
};



pub fn main() anyerror!void {
    std.debug.warn("All your base are belong to us.\n");
    var context = c.zmq_ctx_new();

    var test_socket = Socket.init(context, c.ZMQ_REQ);
    std.debug.warn("All your base are belong to us.\n");
    test_socket.connect("ipc:///tmp/test");


    std.debug.warn("start while");

    var counter : u64 = 0;
    var data = try std.heap.direct_allocator.alloc(u8, 1024);
    while (true) {
        if (counter % 10000 == 0)
            std.debug.warn("bla\n");

        var msg = Message.init("Some msg");
        test_socket.send(&msg);
        test_socket.recv(&msg);
        var recv_data = msg.data();
        std.debug.warn("{}", recv_data);

        counter += 1;

    }

    std.debug.warn("All your base are belong to us.\n");
}
