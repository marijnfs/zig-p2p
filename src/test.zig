const std = @import("std");
 
const Bla = struct {
    a: i64,
    b: f64
};
 
const Error = std.BufferOutStream.Error;
const StdSerializer = std.io.Serializer(.Little, .Byte, Error);
 
pub const Serializer = struct {
    buffer: std.Buffer,
 
    pub fn init() !Serializer {
        return Serializer {
            .buffer = try std.Buffer.initSize(std.heap.direct_allocator, 0),
        };
    }
 
    pub fn deinit(self: *Serializer) void {
        self.buffer.deinit();
    }
 
    pub fn serialize(self: *Serializer, value: var) !void {
        var stream = std.BufferOutStream.init(&self.buffer);
        try StdSerializer.init(&stream.stream).serialize(value);
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
    var my_serializer = try Serializer.init();
    defer my_serializer.deinit();

    try my_serializer.serialize(bla); //ok

    std.debug.warn("first:  {x}\n", .{ buffer.toSliceConst() });
    std.debug.warn("second: {x}\n", .{ my_serializer.buffer.toSliceConst() });
}
