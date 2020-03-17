const std = @import("std");

pub const Serializer = struct {
    std_buffer: std.Buffer,

    pub fn init() !Serializer {
        return Serializer{
            .std_buffer = try std.Buffer.initSize(std.heap.direct_allocator, 0),
        };
    }

    pub fn buffer(self: *Serializer) []const u8 {
        return self.std_buffer.span();
    }

    pub fn deinit(self: *Serializer) void {
        self.buffer.deinit();
    }

    pub fn serialize(self: *Serializer, value: var) !void {
        var stream = self.std_buffer.outStream();
        try std.io.Serializer(.Little, .Byte, @TypeOf(stream)).init(stream).serialize(value);
    }
};
