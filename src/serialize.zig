const std = @import("std");

const Error = std.BufferOutStream.Error;
const StdSerializer = std.io.Serializer(.Little, .Byte, Error);

pub const Serializer = struct {
    buffer: std.Buffer,
    buffered_stream: std.BufferOutStream,
    serializer: StdSerializer,

    pub fn init() !*Serializer {
        var buffer = try std.Buffer.initSize(std.heap.direct_allocator, 0);
        var buffered_stream = std.BufferOutStream.init(&buffer);
        var serializer = StdSerializer.init(&buffered_stream.stream);

        return &Serializer{
            .buffer = buffer,
            .buffered_stream = buffered_stream,
            .serializer = serializer,
        };
    }

    pub fn deinit() void {}

    pub fn serialize(self: *Serializer, value: var) Error!void {
        std.debug.warn("{}\n", .{self});
        try self.serializer.serialize(value);
    }
};
