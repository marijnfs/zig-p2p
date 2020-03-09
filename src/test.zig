const std = @import("std");
 
const Bla = struct {
    a: i64,
    b: f64
};
 
const Error = std.BufferOutStream.Error;
const StdSerializer = std.io.Serializer(.Little, .Byte, Error);
 
pub const Serializer = struct {
    buffer: []std.Buffer,
    buffered_stream: []std.BufferOutStream,
    serializer: StdSerializer,
 
    pub fn init_fields(self: *Serializer) !void {
        self.buffer = try std.heap.direct_allocator.alloc(std.Buffer, 1);
        self.buffer[0] = try std.Buffer.initSize(std.heap.direct_allocator, 0);
        self.buffered_stream = try std.heap.direct_allocator.alloc(std.BufferOutStream, 1);
        self.buffered_stream[0] = std.BufferOutStream.init(&self.buffer[0]);
        self.serializer = StdSerializer.init(&self.buffered_stream[0].stream);
    }

    pub fn init() !Serializer {
        var serializer: Serializer = undefined;
        try serializer.init_fields();
        return serializer;
    }
 
    pub fn deinit() void {
        self.buffer.deinit();
        self.buffered_stream.deinit();
        self.serializer.deinit();
        std.heap.direct_allocator.free(self.buffer);
        std.heap.direct_allocator.free(self.buffered_stream);
    }
 
    pub fn serialize(self: *Serializer, value: var) !void {
        try self.serializer.serialize(value);
    }
};
 
pub fn main() !void {
    //Direct code
    var buffer = try std.Buffer.initSize(std.heap.direct_allocator, 0);
    var buffered_stream = std.BufferOutStream.init(&buffer);
    
    var std_serializer = StdSerializer.init(&buffered_stream.stream);

    var bla = Bla{.a = 1, .b = 2.0};
    try std_serializer.serialize(bla);
 
 
    //through struct
    var my_serializer : Serializer = undefined;
    try my_serializer.init_fields();

    var my_serializer2 = try Serializer.init();

    try my_serializer.serialize(bla); //ok
    try my_serializer2.serialize(bla); //ok
}
