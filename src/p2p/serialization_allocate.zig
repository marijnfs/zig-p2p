const std = @import("std");

const builtin = std.builtin;
const io = std.io;
const assert = std.debug.assert;
const math = std.math;
const meta = std.meta;
const trait = meta.trait;

pub const Packing = io.Packing;

/// Creates a deserializer that deserializes types from any stream.
///  If `is_packed` is true, the data stream is treated as bit-packed,
///  otherwise data is expected to be packed to the smallest byte.
///  Types may implement a custom deserialization routine with a
///  function named `deserialize` in the form of:
///    pub fn deserialize(self: *Self, deserializer: var) !void
///  which will be called when the deserializer is used to deserialize
///  that type. It will pass a pointer to the type instance to deserialize
///  into and a pointer to the deserializer struct.
pub fn DeserializerAllocate(comptime endian: builtin.Endian, comptime packing: Packing, comptime InStreamType: type) type {
    return struct {
        in_stream: if (packing == .Bit) io.BitInStream(endian, InStreamType) else InStreamType,
        allocator: *std.mem.Allocator,

        const Self = @This();

        pub fn init(in_stream: InStreamType, allocator: *std.mem.Allocator) Self {
            return Self{
                .in_stream = switch (packing) {
                    .Bit => io.bitInStream(endian, in_stream),
                    .Byte => in_stream,
                },
                .allocator = allocator,
            };
        }

        pub fn alignToByte(self: *Self) void {
            if (packing == .Byte) return;
            self.in_stream.alignToByte();
        }

        //@BUG: inferred error issue. See: #1386
        pub fn deserializeInt(self: *Self, comptime T: type) (InStreamType.Error || error{EndOfStream})!T {
            comptime assert(trait.is(.Int)(T) or trait.is(.Float)(T));

            const u8_bit_count = 8;
            const t_bit_count = comptime meta.bitCount(T);

            const U = std.meta.IntType(false, t_bit_count);
            const Log2U = math.Log2Int(U);
            const int_size = (U.bit_count + 7) / 8;

            if (packing == .Bit) {
                const result = try self.in_stream.readBitsNoEof(U, t_bit_count);
                return @bitCast(T, result);
            }

            var buffer: [int_size]u8 = undefined;
            const read_size = try self.in_stream.read(buffer[0..]);
            if (read_size < int_size) return error.EndOfStream;

            if (int_size == 1) {
                if (t_bit_count == 8) return @bitCast(T, buffer[0]);
                const PossiblySignedByte = std.meta.IntType(T.is_signed, 8);
                return @truncate(T, @bitCast(PossiblySignedByte, buffer[0]));
            }

            var result = @as(U, 0);
            for (buffer) |byte, i| {
                switch (endian) {
                    .Big => {
                        result = (result << u8_bit_count) | byte;
                    },
                    .Little => {
                        result |= @as(U, byte) << @intCast(Log2U, u8_bit_count * i);
                    },
                }
            }

            return @bitCast(T, result);
        }

        /// Deserializes and returns data of the specified type from the stream
        pub fn deserialize(self: *Self, comptime T: type) !T {
            var value: T = undefined;
            try self.deserializeInto(&value);
            return value;
        }

        /// Deserializes data into the type pointed to by `ptr`
        pub fn deserializeInto(self: *Self, ptr: anytype) !void {
            const T = @TypeOf(ptr);
            comptime assert(trait.is(.Pointer)(T));
            comptime assert(trait.isSingleItemPtr(T));

            const C = comptime meta.Child(T);
            const child_type_id = @typeInfo(C);

            if (comptime trait.is(.Array)(C)) {
                for (ptr.*) |*item|
                    try self.deserializeInto(item);
                return;
            } else if (comptime trait.isIndexable(C)) {
                //It's a variable array, store the size first
                const len = try self.deserializeInt(usize);
                if (comptime meta.sentinel(C) == null) {
                    ptr.* = try self.allocator.alloc(meta.Child(C), len);
                } else {
                    var buffer = try self.allocator.alloc(meta.Child(C), len + 1);
                    buffer[len] = meta.sentinel(C).?;
                    ptr.* = buffer[0..len :0];
                }

                for (ptr.*) |*item|
                    try self.deserializeInto(item);
                return;
            } else if (comptime trait.is(.Pointer)(C)) {
                ptr.* = try self.allocator.create(meta.Child(C));
                try self.deserializeInto(ptr.*);
                return;
            }

            //custom deserializer: fn(self: *Self, deserializer: var) !void
            if (comptime trait.hasFn("deserialize")(C)) return C.deserialize(ptr, self);

            if (comptime trait.isPacked(C) and packing != .Bit) {
                var packed_deserializer = deserializer_allocate(endian, .Bit, self.in_stream, std.heap.direct_allocator);
                return packed_deserializer.deserializeInto(ptr);
            }

            switch (child_type_id) {
                .Void => return,
                .Bool => ptr.* = (try self.deserializeInt(u1)) > 0,
                .Float, .Int => ptr.* = try self.deserializeInt(C),
                .Struct => {
                    const info = @typeInfo(C).Struct;

                    inline for (info.fields) |*field_info| {
                        const name = field_info.name;
                        const FieldType = field_info.field_type;

                        if (FieldType == void or FieldType == u0) continue;

                        try self.deserializeInto(&@field(ptr, name));
                    }
                },
                .Union => {
                    const info = @typeInfo(C).Union;
                    if (info.tag_type) |TagType| {
                        //we avoid duplicate iteration over the enum tags
                        // by getting the int directly and casting it without
                        // safety. If it is bad, it will be caught anyway.
                        const TagInt = @TagType(TagType);
                        const tag = try self.deserializeInt(TagInt);

                        inline for (info.fields) |field_info| {
                            if (field_info.enum_field.?.value == tag) {
                                const name = field_info.name;
                                const FieldType = field_info.field_type;
                                ptr.* = @unionInit(C, name, undefined);
                                try self.deserializeInto(&@field(ptr, name));
                                return;
                            }
                        }
                        //This is reachable if the enum data is bad
                        return error.InvalidEnumTag;
                    }
                    @compileError("Cannot meaningfully deserialize " ++ @typeName(C) ++
                        " because it is an untagged union. Use a custom deserialize().");
                },
                .Optional => {
                    const OC = comptime meta.Child(C);
                    const exists = (try self.deserializeInt(u1)) > 0;
                    if (!exists) {
                        ptr.* = null;
                        return;
                    }

                    ptr.* = @as(OC, undefined); //make it non-null so the following .? is guaranteed safe
                    const val_ptr = &ptr.*.?;
                    try self.deserializeInto(val_ptr);
                },
                .Enum => {
                    var value = try self.deserializeInt(@TagType(C));
                    ptr.* = try meta.intToEnum(C, value);
                },
                else => {
                    @compileError("Cannot deserialize " ++ @tagName(child_type_id) ++ " types (unimplemented).");
                },
            }
        }
    };
}

pub fn deserializer_allocate(comptime endian: builtin.Endian, comptime packing: Packing, in_stream: anytype, allocator: *std.mem.Allocator) DeserializerAllocate(endian, packing, @TypeOf(in_stream)) {
    return DeserializerAllocate(endian, packing, @TypeOf(in_stream)).init(in_stream, allocator);
}

/// Creates a serializer that serializes types to any stream.
///  If `is_packed` is true, the data will be bit-packed into the stream.
///  Note that the you must call `serializer.flush()` when you are done
///  writing bit-packed data in order ensure any unwritten bits are committed.
///  If `is_packed` is false, data is packed to the smallest byte. In the case
///  of packed structs, the struct will written bit-packed and with the specified
///  endianess, after which data will resume being written at the next byte boundary.
///  Types may implement a custom serialization routine with a
///  function named `serialize` in the form of:
///    pub fn serialize(self: Self, serializer: var) !void
///  which will be called when the serializer is used to serialize that type. It will
///  pass a const pointer to the type instance to be serialized and a pointer
///  to the serializer struct.
pub fn SerializerAllocate(comptime endian: builtin.Endian, comptime packing: Packing, comptime OutStreamType: type) type {
    return struct {
        out_stream: if (packing == .Bit) io.BitOutStream(endian, OutStreamType) else OutStreamType,

        const Self = @This();
        pub const Error = OutStreamType.Error;

        pub fn init(out_stream: OutStreamType) Self {
            return Self{
                .out_stream = switch (packing) {
                    .Bit => io.bitOutStream(endian, out_stream),
                    .Byte => out_stream,
                },
            };
        }

        /// Flushes any unwritten bits to the stream
        pub fn flush(self: *Self) Error!void {
            if (packing == .Bit) return self.out_stream.flushBits();
        }

        pub fn serializeInt(self: *Self, value: anytype) Error!void {
            const T = @TypeOf(value);
            comptime assert(trait.is(.Int)(T) or trait.is(.Float)(T));

            const t_bit_count = comptime meta.bitCount(T);
            const u8_bit_count = comptime meta.bitCount(u8);

            const U = std.meta.IntType(false, t_bit_count);
            const Log2U = math.Log2Int(U);
            const int_size = (U.bit_count + 7) / 8;

            const u_value = @bitCast(U, value);

            if (packing == .Bit) return self.out_stream.writeBits(u_value, t_bit_count);

            var buffer: [int_size]u8 = undefined;
            if (int_size == 1) buffer[0] = u_value;

            for (buffer) |*byte, i| {
                const idx = switch (endian) {
                    .Big => int_size - i - 1,
                    .Little => i,
                };
                const shift = @intCast(Log2U, idx * u8_bit_count);
                const v = u_value >> shift;
                byte.* = if (t_bit_count < u8_bit_count) v else @truncate(u8, v);
            }

            try self.out_stream.writeAll(&buffer);
        }

        /// Serializes the passed value into the stream
        pub fn serialize(self: *Self, value: anytype) Error!void {
            const T = comptime @TypeOf(value);

            if (comptime trait.is(.Array)(T)) {
                for (value) |item|
                    try self.serialize(item);
                return;
            } else if (comptime trait.isIndexable(T)) {
                //It's a variable array, store the size first
                try self.serializeInt(value.len);
                for (value) |item|
                    try self.serialize(item);
                return;
            } else if (comptime trait.is(.Pointer)(T)) {
                try self.serialize(value.*);
                return;
            }

            //custom serializer: fn(self: Self, serializer: var) !void
            if (comptime trait.hasFn("serialize")(T)) return T.serialize(value, self);

            if (comptime trait.isPacked(T) and packing != .Bit) {
                var packed_serializer = serializer_allocate(endian, .Bit, self.out_stream);
                try packed_serializer.serialize(value);
                try packed_serializer.flush();
                return;
            }

            switch (@typeInfo(T)) {
                .Void => return,
                .Bool => try self.serializeInt(@as(u1, @boolToInt(value))),
                .Float, .Int => try self.serializeInt(value),
                .Struct => {
                    const info = @typeInfo(T);

                    inline for (info.Struct.fields) |*field_info| {
                        const name = field_info.name;
                        const FieldType = field_info.field_type;

                        if (FieldType == void or FieldType == u0) continue;

                        try self.serialize(@field(value, name));
                    }
                },
                .Union => {
                    const info = @typeInfo(T).Union;
                    if (info.tag_type) |TagType| {
                        const active_tag = meta.activeTag(value);
                        try self.serialize(active_tag);
                        //This inline loop is necessary because active_tag is a runtime
                        // value, but @field requires a comptime value. Our alternative
                        // is to check each field for a match
                        inline for (info.fields) |field_info| {
                            if (field_info.enum_field.?.value == @enumToInt(active_tag)) {
                                const name = field_info.name;
                                const FieldType = field_info.field_type;
                                try self.serialize(@field(value, name));
                                return;
                            }
                        }
                        unreachable;
                    }
                    @compileError("Cannot meaningfully serialize " ++ @typeName(T) ++
                        " because it is an untagged union. Use a custom serialize().");
                },
                .Optional => {
                    if (value == null) {
                        try self.serializeInt(@as(u1, @boolToInt(false)));
                        return;
                    }
                    try self.serializeInt(@as(u1, @boolToInt(true)));

                    const OC = comptime meta.Child(T);
                    const val_ptr = &value.?;
                    try self.serialize(val_ptr.*);
                },
                .Enum => {
                    try self.serializeInt(@enumToInt(value));
                },
                else => {},
            }
        }
    };
}

pub fn serializer_allocate(
    comptime endian: builtin.Endian,
    comptime packing: Packing,
    out_stream: anytype,
) SerializerAllocate(endian, packing, @TypeOf(out_stream)) {
    return SerializerAllocate(endian, packing, @TypeOf(out_stream)).init(out_stream);
}

fn testIntSerializerDeserializer(comptime endian: builtin.Endian, comptime packing: io.Packing) !void {
    @setEvalBranchQuota(1500);
    //@NOTE: if this test is taking too long, reduce the maximum tested bitsize
    const max_test_bitsize = 128;

    const total_bytes = comptime blk: {
        var bytes = 0;
        comptime var i = 0;
        while (i <= max_test_bitsize) : (i += 1) bytes += (i / 8) + @boolToInt(i % 8 > 0);
        break :blk bytes * 2;
    };

    var data_mem: [total_bytes]u8 = undefined;
    var out = io.fixedBufferStream(&data_mem);
    var serializer = serializer_allocate(endian, packing, out.outStream());

    var in = io.fixedBufferStream(&data_mem);
    var deserializer = deserializer_allocate(endian, packing, in.inStream(), std.heap.direct_allocator);

    comptime var i = 0;
    inline while (i <= max_test_bitsize) : (i += 1) {
        const U = std.meta.IntType(false, i);
        const S = std.meta.IntType(true, i);
        try serializer.serializeInt(@as(U, i));
        if (i != 0) try serializer.serializeInt(@as(S, -1)) else try serializer.serialize(@as(S, 0));
    }
    try serializer.flush();

    i = 0;
    inline while (i <= max_test_bitsize) : (i += 1) {
        const U = std.meta.IntType(false, i);
        const S = std.meta.IntType(true, i);
        const x = try deserializer.deserializeInt(U);
        const y = try deserializer.deserializeInt(S);
        expect(x == @as(U, i));
        if (i != 0) expect(y == @as(S, -1)) else expect(y == 0);
    }

    const u8_bit_count = comptime meta.bitCount(u8);
    //0 + 1 + 2 + ... n = (n * (n + 1)) / 2
    //and we have each for unsigned and signed, so * 2
    const total_bits = (max_test_bitsize * (max_test_bitsize + 1));
    const extra_packed_byte = @boolToInt(total_bits % u8_bit_count > 0);
    const total_packed_bytes = (total_bits / u8_bit_count) + extra_packed_byte;

    expect(in.pos == if (packing == .Bit) total_packed_bytes else total_bytes);

    //Verify that empty error set works with serializer.
    //deserializer is covered by FixedBufferStream
    var null_serializer = io.serializer_allocate(endian, packing, std.io.null_out_stream);
    try null_serializer.serialize(data_mem[0..]);
    try null_serializer.flush();
}

test "Serializer/Deserializer Int" {
    try testIntSerializerDeserializer(.Big, .Byte);
    try testIntSerializerDeserializer(.Little, .Byte);
    // TODO these tests are disabled due to tripping an LLVM assertion
    // https://github.com/ziglang/zig/issues/2019
    //try testIntSerializerDeserializer(builtin.Endian.Big, true);
    //try testIntSerializerDeserializer(builtin.Endian.Little, true);
}

fn testIntSerializerDeserializerInfNaN(
    comptime endian: builtin.Endian,
    comptime packing: io.Packing,
) !void {
    const mem_size = (16 * 2 + 32 * 2 + 64 * 2 + 128 * 2) / comptime meta.bitCount(u8);
    var data_mem: [mem_size]u8 = undefined;

    var out = io.fixedBufferStream(&data_mem);
    var serializer = serializer_allocate(endian, packing, out.outStream());

    var in = io.fixedBufferStream(&data_mem);
    var deserializer = deserializer_allocate(endian, packing, in.inStream(), std.heap.direct_allocator);

    //@TODO: isInf/isNan not currently implemented for f128.
    try serializer.serialize(std.math.nan(f16));
    try serializer.serialize(std.math.inf(f16));
    try serializer.serialize(std.math.nan(f32));
    try serializer.serialize(std.math.inf(f32));
    try serializer.serialize(std.math.nan(f64));
    try serializer.serialize(std.math.inf(f64));
    //try serializer.serialize(std.math.nan(f128));
    //try serializer.serialize(std.math.inf(f128));
    const nan_check_f16 = try deserializer.deserialize(f16);
    const inf_check_f16 = try deserializer.deserialize(f16);
    const nan_check_f32 = try deserializer.deserialize(f32);
    deserializer.alignToByte();
    const inf_check_f32 = try deserializer.deserialize(f32);
    const nan_check_f64 = try deserializer.deserialize(f64);
    const inf_check_f64 = try deserializer.deserialize(f64);
    //const nan_check_f128 = try deserializer.deserialize(f128);
    //const inf_check_f128 = try deserializer.deserialize(f128);
    expect(std.math.isNan(nan_check_f16));
    expect(std.math.isInf(inf_check_f16));
    expect(std.math.isNan(nan_check_f32));
    expect(std.math.isInf(inf_check_f32));
    expect(std.math.isNan(nan_check_f64));
    expect(std.math.isInf(inf_check_f64));
    //expect(std.math.isNan(nan_check_f128));
    //expect(std.math.isInf(inf_check_f128));
}

test "Serializer/Deserializer Int: Inf/NaN" {
    try testIntSerializerDeserializerInfNaN(.Big, .Byte);
    try testIntSerializerDeserializerInfNaN(.Little, .Byte);
    try testIntSerializerDeserializerInfNaN(.Big, .Bit);
    try testIntSerializerDeserializerInfNaN(.Little, .Bit);
}

fn testAlternateSerializer(self: anytype, serializer: anytype) !void {
    try serializer.serialize(self.f_f16);
}

fn testSerializerDeserializer(comptime endian: builtin.Endian, comptime packing: io.Packing) !void {
    const ColorType = enum(u4) {
        RGB8 = 1,
        RA16 = 2,
        R32 = 3,
    };

    const TagAlign = union(enum(u32)) {
        A: u8,
        B: u8,
        C: u8,
    };

    const Color = union(ColorType) {
        RGB8: struct {
            r: u8,
            g: u8,
            b: u8,
            a: u8,
        },
        RA16: struct {
            r: u16,
            a: u16,
        },
        R32: u32,
    };

    const PackedStruct = packed struct {
        f_i3: i3,
        f_u2: u2,
    };

    //to test custom serialization
    const Custom = struct {
        f_f16: f16,
        f_unused_u32: u32,

        pub fn deserialize(self: *@This(), deserializer: anytype) !void {
            try deserializer.deserializeInto(&self.f_f16);
            self.f_unused_u32 = 47;
        }

        pub const serialize = testAlternateSerializer;
    };

    const MyStruct = struct {
        f_i3: i3,
        f_u8: u8,
        f_tag_align: TagAlign,
        f_u24: u24,
        f_i19: i19,
        f_void: void,
        f_f32: f32,
        f_f128: f128,
        f_packed_0: PackedStruct,
        f_i7arr: [10]i7,
        f_of64n: ?f64,
        f_of64v: ?f64,
        f_color_type: ColorType,
        f_packed_1: PackedStruct,
        f_custom: Custom,
        f_color: Color,
    };

    const my_inst = MyStruct{
        .f_i3 = -1,
        .f_u8 = 8,
        .f_tag_align = TagAlign{ .B = 148 },
        .f_u24 = 24,
        .f_i19 = 19,
        .f_void = {},
        .f_f32 = 32.32,
        .f_f128 = 128.128,
        .f_packed_0 = PackedStruct{ .f_i3 = -1, .f_u2 = 2 },
        .f_i7arr = [10]i7{ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9 },
        .f_of64n = null,
        .f_of64v = 64.64,
        .f_color_type = ColorType.R32,
        .f_packed_1 = PackedStruct{ .f_i3 = 1, .f_u2 = 1 },
        .f_custom = Custom{ .f_f16 = 38.63, .f_unused_u32 = 47 },
        .f_color = Color{ .R32 = 123822 },
    };

    var data_mem: [@sizeOf(MyStruct)]u8 = undefined;
    var out = io.fixedBufferStream(&data_mem);
    var serializer = serializer_allocate(endian, packing, out.outStream());

    var in = io.fixedBufferStream(&data_mem);
    var deserializer = deserializer_allocate(endian, packing, in.inStream(), std.heap.direct_allocator);

    try serializer.serialize(my_inst);

    const my_copy = try deserializer.deserialize(MyStruct);
    expect(meta.eql(my_copy, my_inst));
}

test "Serializer/Deserializer generic" {
    try testSerializerDeserializer(builtin.Endian.Big, .Byte);
    try testSerializerDeserializer(builtin.Endian.Little, .Byte);
    try testSerializerDeserializer(builtin.Endian.Big, .Bit);
    try testSerializerDeserializer(builtin.Endian.Little, .Bit);
}

fn testSerializerDeserializerArrayTypes(comptime endian: builtin.Endian, comptime packing: io.Packing) !void {
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

    var my_array_types = ArrayTypes{
        .arrayType = [10]u8{ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9 },
        .ptrArrayType = try allocator.alloc(u8, 5),
        .arraySentinelType = [4:0]u8{ 0, 1, 2, 3 },
        .ptrArraySentinelType = (try allocator.alloc(u8, 5))[0..:0],
        .ptrType = try allocator.create(PackedStruct),
    };
    for (my_array_types.ptrArrayType) |*item, i| {
        item.* = @intCast(u8, i);
    }
    for (my_array_types.ptrArraySentinelType) |*item, i| {
        item.* = @intCast(u8, i);
    }
    my_array_types.ptrType.* = PackedStruct{ .f_i3 = 2, .f_u2 = 3 };
    defer my_array_types.deinit();

    var buffer = try std.Buffer.initSize(allocator, 0);
    defer buffer.deinit();

    var stream = buffer.outStream();
    var serializer = std.io.serializer_allocate(endian, packing, stream);
    try serializer.serialize(my_array_types);
    try serializer.flush();

    var in_stream = std.io.fixedBufferStream(buffer.span()).inStream();
    var deserializer = std.io.deserializer_allocate(endian, packing, in_stream, allocator);

    var my_array_types_copy = try deserializer.deserialize(ArrayTypes);
    defer my_array_types_copy.deinit();

    expect(std.mem.eql(u8, my_array_types.arrayType[0..], my_array_types_copy.arrayType[0..]));
    expect(std.mem.eql(u8, my_array_types.ptrArrayType, my_array_types_copy.ptrArrayType));
    expect(std.mem.eql(u8, my_array_types.arraySentinelType[0..], my_array_types_copy.arraySentinelType[0..]));
    expect(std.mem.eql(u8, my_array_types.ptrArraySentinelType, my_array_types_copy.ptrArraySentinelType));
    expect(meta.eql(my_array_types.ptrType.*, my_array_types_copy.ptrType.*));
}

const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const expectError = std.testing.expectError;

test "Serializer/Deserializer arraytypes" {
    try testSerializerDeserializerArrayTypes(builtin.Endian.Big, .Byte);
    try testSerializerDeserializerArrayTypes(builtin.Endian.Little, .Byte);
    try testSerializerDeserializerArrayTypes(builtin.Endian.Big, .Bit);
    try testSerializerDeserializerArrayTypes(builtin.Endian.Little, .Bit);
}
