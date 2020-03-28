const std = @import("std");
const p2p = @import("p2p.zig");
const mem = std.mem;

const c = p2p.c;

pub fn blake_hash_allocate(data: []u8, allocator: *mem.Allocator) ![]u8 {
    const key_size = 32;
    var hash = try allocator.alloc(u8, key_size);

    c.crypto_blake2b_general(hash.ptr, hash.len, null, 0, data.ptr, data.len);
    return hash;
}

pub fn blake_hash(data: []u8) [32]u8 {
    var hash: [32]u8 = undefined;
    c.crypto_blake2b_general(&hash, hash.len, null, 0, data.ptr, data.len);
    return hash;
}