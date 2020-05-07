const std = @import("std");
const mem = std.mem;
const warn = std.debug.warn;

const p2p = @import ("p2p");
const serialize = p2p.serialize;

const default_allocator = p2p.default_allocator;

const cm = p2p.connection_management;

const Chat = p2p.Chat;
const Pool = p2p.Pool;
const Socket = p2p.Socket;
const Message = p2p.Message;

const work = p2p.work;
const wi = p2p.work_items;
const relaychat = @import("relaychat.zig");


var chat_pool: Pool(Chat) = undefined;

pub fn add_to_pool_callback(chat: *Chat) void {
    var exists = chat_pool.put(chat.*);
}

pub const AddToPoolWorkItem = work.make_work_item(Chat, add_to_pool_callback);



pub fn new_chat(chat: Chat) void {
    std.debug.warn("chat {}\n", .{chat.message});

    var chat_copy = chat.copy() catch unreachable;

    var relay_work_item = wi.RelayWorkItem.init(default_allocator, chat_copy) catch unreachable;
    work.work_queue.push(&relay_work_item.work_item) catch unreachable;
}

pub fn init() void {
    var uuid = std.mem.zeroes([32]u8);
    chat_pool = Pool(Chat).init(default_allocator, uuid);
}



pub fn reply_peers_function(id: *[4]u8) void {
    var buffer = serialize(cm.known_addresses.items) catch unreachable;

    var work_item = relaychat.SendToBindSocketWorkItem.init(default_allocator, .{.id = id.*, .buffer = buffer}) catch unreachable;
    work.queue_work_item(work_item) catch unreachable;
}

pub const ReplyPeersWorkItem = work.make_work_item([4]u8, reply_peers_function);
