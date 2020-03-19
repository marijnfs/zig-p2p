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
        self.std_buffer.deinit();
    }

    pub fn serialize(self: *Serializer, value: var) !void {
        var stream = self.std_buffer.outStream();
        var serializer = std.io.Serializer(.Little, .Byte, @TypeOf(stream)).init(stream);
        try serializer.serialize(value);
        try serializer.flush();
    }
};

pub const Deserializer = struct {
    pub fn init() Deserializer {
        return Deserializer{};
    }

    pub fn deinit(self: *Deserializer) void {}

    pub fn deserialize(self: *Deserializer, comptime Type: type, buffer: []u8) !Type {
        var in_stream = std.io.fixedBufferStream(buffer).inStream();
        var deserializer = std.io.Deserializer(.Little, .Byte, std.io.FixedBufferStream([]u8).InStream).init(in_stream);
        return try deserializer.deserialize(Type);
    }
};
