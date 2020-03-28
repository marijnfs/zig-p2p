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
    var deserializer = std.io.DeserializerAllocate(.Little, .Byte, std.io.FixedBufferStream([]u8).InStream).init(in_stream, allocator);
    return try deserializer.deserialize(Type);
}
