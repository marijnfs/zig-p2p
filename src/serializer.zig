const std = @import("std");
const serializer_allocate = @import("serialization_allocate.zig").serializer_allocate;
const deserializer_allocate = @import("serialization_allocate.zig").deserializer_allocate;
const DeserializerAllocate = @import("serialization_allocate.zig").DeserializerAllocate;

const p2p = @import("p2p.zig");
const default_allocator = p2p.default_allocator;
const Buffer = std.ArrayListSentineled(u8, 0);

pub fn serialize(value: var) !Buffer {
    var buffer = try Buffer.initSize(default_allocator, 0);
    var stream = buffer.outStream();
    var serializer = serializer_allocate(.Little, .Byte, stream);
    try serializer.serialize(value);
    try serializer.flush();
    return buffer;
}

pub fn deserialize(comptime Type: type, buffer: []u8, allocator: *std.mem.Allocator) !Type {
    var in_stream = std.io.fixedBufferStream(buffer).inStream();
    var deserializer = deserializer_allocate(.Little, .Byte, in_stream, allocator);
    var obj = try deserializer.deserialize(Type);
    return obj;
}

pub fn serialize_tagged(tag: i64, value: var) !Buffer {
    var buffer = try Buffer.initSize(default_allocator, 0);
    var stream = buffer.outStream();
    var serializer = serializer_allocate(.Little, .Byte, stream);
    try serializer.serializeInt(tag);
    try serializer.serialize(value);
    try serializer.flush();
    return buffer;
}

const FixedBufferStream = std.io.FixedBufferStream([]u8).InStream;
const DeserializerAllocateType = DeserializerAllocate(.Little, .Byte, FixedBufferStream);

const DeserializerTagged = struct {
    const Self = @This();

    buffer: std.io.FixedBufferStream([]u8),
    allocator: *std.mem.Allocator,

    pub fn init(buffer: []u8, allocator: *std.mem.Allocator) Self {
        var deserializer_tagged = DeserializerTagged{
            .buffer = std.io.fixedBufferStream(buffer),
            .allocator = allocator,
        };

        return deserializer_tagged;
    }

    pub fn deinit(self: *Self) void {}

    pub fn tag(self: *Self) !i64 {
        var deserializer = deserializer_allocate(.Little, .Byte, self.buffer.inStream(), self.allocator);
        var tag_value = try deserializer.deserialize(i64);
        return tag_value;
    }

    pub fn deserialize(self: *Self, comptime T: type) !T {
        var deserializer = deserializer_allocate(.Little, .Byte, self.buffer.inStream(), self.allocator);
        var obj = try deserializer.deserialize(T);
        return obj;
    }
};

pub fn deserialize_tagged(buffer: []u8, allocator: *std.mem.Allocator) DeserializerTagged {
    return DeserializerTagged.init(buffer, allocator);
}
