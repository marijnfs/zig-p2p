const std = @import("std");


pub fn serialize(value: var) !std.Buffer {
    var buffer = try std.Buffer.initSize(std.heap.direct_allocator, 0);
    var stream = buffer.outStream();
    var serializer = std.io.SerializerAllocate(.Little, .Byte, @TypeOf(stream)).init(stream);
    try serializer.serialize(value);
    try serializer.flush();
    return buffer;
}


pub fn deserialize(comptime Type: type, buffer: []u8, allocator: *std.mem.Allocator) !Type {
    var in_stream = std.io.fixedBufferStream(buffer).inStream();
    var deserializer = std.io.deserializer_allocate(.Little, .Byte, in_stream, allocator);
    var obj = try deserializer.deserialize(Type);
    return obj;
}

pub fn serialize_tagged(tag: u64, value: var) !std.Buffer {
    var buffer = try std.Buffer.initSize(std.heap.direct_allocator, 0);
    var stream = buffer.outStream();
    var serializer = std.io.SerializerAllocate(.Little, .Byte, @TypeOf(stream)).init(stream);
    try serializer.serializeInt(tag);
    try serializer.serialize(value);
    try serializer.flush();
    return buffer;
}

const Callback = fn (i64, std.io.Deserializer(.Little, .Byte, @typeOf(in_stream))) void;

pub fn deserialize_tagged(comptime T: type, buffer: []u8, allocator: *std.mem.Allocator) !T {
    var in_stream = std.io.fixedBufferStream(buffer).inStream();

    var deserializer = std.io.deserializer_allocate(.Little, .Byte, in_stream, allocator);
    var obj_type = try deserializer.deserialize(i64);
    var obj = try deserializer.deserialize(T);
    return obj;
}
