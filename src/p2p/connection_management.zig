const std = @import("std");
const fmt = std.fmt;
const warn = std.debug.warn;
const Allocator = std.mem.Allocator;

const p2p = @import("p2p.zig");
const Socket = p2p.Socket;
const OutgoingConnection = p2p.OutgoingConnection;
const Message = p2p.Message;
const Chat = p2p.Chat;
var default_allocator = p2p.default_allocator;

const Buffer = p2p.Buffer;

pub var outgoing_connections: std.ArrayList(*OutgoingConnection) = undefined;
pub var mutex: std.Mutex = undefined;

pub var known_addresses: std.ArrayList(Buffer) = undefined;

const c = p2p.c;

pub fn init() void {
    outgoing_connections = std.ArrayList(*OutgoingConnection).init(default_allocator);
    known_addresses = std.ArrayList(Buffer).init(default_allocator);
    mutex = std.Mutex.init();
}

pub fn ip4_to_zeromq(ip: [4]u8, port: i64) !Buffer {
    const buf_printed = try fmt.allocPrint(default_allocator, "tcp://{}.{}.{}.{}:{}", .{ ip[0], ip[1], ip[2], ip[3], port });
    defer default_allocator.free(buf_printed);
    var buffer = try Buffer.init(default_allocator, buf_printed);
    return buffer;
}
