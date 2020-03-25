const std = @import("std");

pub const Serializer = struct {
    pub fn serialize(self: *Serializer, value: var) !std.Buffer {
        var buffer = try std.Buffer.initSize(std.heap.direct_allocator, 0);
        var stream = buffer.outStream();
        var serializer = std.io.Serializer(.Little, .Byte, @TypeOf(stream)).init(stream);
        try serializer.serialize(value);
        try serializer.flush();
        return buffer;
    }
};

pub const Deserializer = struct {
    pub fn init() Deserializer {
        return Deserializer{};
    }

    pub fn deinit(self: *Deserializer) void {}

    pub fn deserialize(self: *Deserializer, comptime Type: type, buffer: []u8) !Type {
        var in_stream = std.io.fixedBufferStream(buffer).inStream();
        var deserializer = std.io.DeserializerAllocate(.Little, .Byte, std.io.FixedBufferStream([]u8).InStream, std.heap.direct_allocator).init(in_stream);
        return try deserializer.deserialize(Type);
    }
};
