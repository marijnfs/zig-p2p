const std = @import("std");
const p2p = @import("p2p.zig");
const serialize = p2p.serialize;
const mem = std.mem;
const default_allocator = p2p.default_allocator;

const c = p2p.c;
pub const Hash = [32]u8;

pub fn hash(v: var) !Hash {
    var buffer = try serialize(v);
    defer buffer.deinit();
    var H = p2p.blake_hash(buffer.span());
    return H;
}

pub fn blake_hash_allocate(data: []u8, allocator: *mem.Allocator, key_size: u64) ![]u8 {
    var hash = try allocator.alloc(u8, key_size);

    c.crypto_blake2b_general(hash.ptr, hash.len, null, 0, data.ptr, data.len);
    return hash;
}

pub fn blake_hash(data: []u8) Hash {
    var H: Hash = undefined;
    c.crypto_blake2b_general(&H, H.len, null, 0, data.ptr, data.len);
    return H;
}