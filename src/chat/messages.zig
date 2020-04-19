const std = @import("std");

const chat = @import("chat.zig");
const p2p = chat.p2p;

const Buffer = p2p.Buffer;


pub fn Hello() !Buffer {
    var buffer = try p2p.serialize_tagged(0, @as(i64, 0));
    return buffer;
}

pub fn AnnounceChat(chat_message: *chat.ChatMessage) !Buffer {
    var buffer = try p2p.serialize_tagged(1, chat_message);
    return buffer;
}
