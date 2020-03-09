const std = @import("std");

const Error = std.BufferOutStream.Error;
const StdSerializer = std.io.Serializer(.Little, .Byte, Error);
 
pub const Serializer = struct {
    buffer_ptr: []std.Buffer,
    buffered_stream_ptr: []std.BufferOutStream,
    serializer: StdSerializer,
 
    pub fn init_fields(self: *Serializer) !void {
        self.buffer_ptr = try std.heap.direct_allocator.alloc(std.Buffer, 1);
        self.buffer_ptr[0] = try std.Buffer.initSize(std.heap.direct_allocator, 0);
        self.buffered_stream_ptr = try std.heap.direct_allocator.alloc(std.BufferOutStream, 1);
        self.buffered_stream_ptr[0] = std.BufferOutStream.init(&self.buffer_ptr[0]);
        self.serializer = StdSerializer.init(&self.buffered_stream_ptr[0].stream);
    }

    pub fn buffer(self: *Serializer) std.Buffer {
        return self.buffer_ptr[0];
    }

    pub fn init() !Serializer {
        var serializer: Serializer = undefined;
        try serializer.init_fields();
        return serializer;
    }
 
    pub fn deinit() void {
        self.buffer_ptr.deinit();
        self.buffered_stream_ptr.deinit();
        self.serializer.deinit();
        std.heap.direct_allocator.free(self.buffer_ptr);
        std.heap.direct_allocator.free(self.buffered_stream_ptr);
    }
 
    pub fn serialize(self: *Serializer, value: var) !void {
        try self.serializer.serialize(value);
    }
};