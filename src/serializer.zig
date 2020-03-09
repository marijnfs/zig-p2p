const std = @import("std");

const Error = std.BufferOutStream.Error;
const StdSerializer = std.io.Serializer(.Little, .Byte, Error);
 
pub const Serializer = struct {
    std_buffer: std.Buffer,
 
    pub fn init() !Serializer {
        return Serializer {
            .std_buffer = try std.Buffer.initSize(std.heap.direct_allocator, 0),
        };
    }
 
    pub fn buffer(self: *Serializer) []const u8 {
        return self.std_buffer.toSliceConst();
    }

    pub fn deinit(self: *Serializer) void {
        self.buffer.deinit();
    }
 
    pub fn serialize(self: *Serializer, value: var) !void {
        var stream = std.BufferOutStream.init(&self.std_buffer);
        try StdSerializer.init(&stream.stream).serialize(value);
    }
};