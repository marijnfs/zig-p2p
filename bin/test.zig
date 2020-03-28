const std = @import("std");


pub fn main() !void {
    try testArrayTypes();
}

pub fn testArrayTypes() !void {
    var allocator = std.heap.direct_allocator;

    const PackedStruct = struct {
        f_i3: i3,
        f_u2: u2,
    };

    const ArrayTypes = struct {
        arrayType: [10]u8,
        ptrArrayType: []u8,
        arraySentinelType: [4:0]u8,
        ptrArraySentinelType: [:0]u8,
        ptrType: *PackedStruct,

        fn deinit(self: *Self) void {
            std.heap.direct_allocator.free(self.ptrArrayType);
            std.heap.direct_allocator.destroy(self.ptrType);
        }

        const Self = @This();
    };

    var my_array_types = ArrayTypes {
        .arrayType = [10]u8{ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9 },
        .ptrArrayType = try allocator.alloc(u8, 5),
        .arraySentinelType = [4:0]u8 {0, 1, 2, 3},
        .ptrArraySentinelType = (try allocator.alloc(u8, 5))[0..:0],
        .ptrType = try allocator.create(PackedStruct),
    };
    for (my_array_types.ptrArrayType) |*item, i| {
        item.*= @intCast(u8, i);
    }
    for (my_array_types.ptrArraySentinelType) |*item, i| {
        item.*= @intCast(u8, i);
    }
    my_array_types.ptrType.* = PackedStruct{.f_i3 = 2, .f_u2 = 3};
    defer my_array_types.deinit();

    var buffer = try std.Buffer.initSize(allocator, 0);
    defer buffer.deinit();

    var stream = buffer.outStream();
    var serializer = std.io.serializer_allocate(.Little, .Byte, stream);
    try serializer.serialize(my_array_types);
    try serializer.flush();


    var in_stream = std.io.fixedBufferStream(buffer.span()).inStream();
    var deserializer = std.io.deserializer_allocate(.Little, .Byte, in_stream, allocator);

    var my_array_types_copy = try deserializer.deserialize(ArrayTypes);
    defer my_array_types_copy.deinit();


    for (my_array_types.arrayType) |v| {
        std.debug.warn("{}\n", .{v});
    }
    for (my_array_types.ptrArrayType) |v| {
        std.debug.warn("{}\n", .{v});
    }
    std.debug.warn("{}\n", .{my_array_types.ptrType});

    for (my_array_types_copy.arrayType) |v| {
        std.debug.warn("{}\n", .{v});
    }
    for (my_array_types_copy.ptrArrayType) |v| {
        std.debug.warn("{}\n", .{v});
    }
    for (my_array_types_copy.arraySentinelType) |v| {
        std.debug.warn("{}\n", .{v});
    }
    for (my_array_types_copy.ptrArraySentinelType) |v| {
        std.debug.warn("{}\n", .{v});
    }
    std.debug.warn("{}\n", .{my_array_types_copy.ptrType});
}
