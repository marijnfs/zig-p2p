const chat = @import("../chat.zig");
const std = @import("std");
const p2p = chat.p2p;
const cm = p2p.connection_management;
const default_allocator = p2p.default_allocator;
const RouterReply = chat.events.Events.RouterReply;
const CheckMessage = chat.events.Events.CheckMessage;
const Buffer = p2p.Buffer;

// On receiving a Hello messsage

pub fn incoming_chat_callback(chat_message: chat.ChatMessage, id: p2p.router.RouteId, id_msg: *p2p.Message) void {
    std.debug.warn("got chat: {}\n", .{chat_message});

    // var thanks = std.mem.dupe(default_allocator, u8, "got message") catch return;
    // var router_event = RouterReply.init(default_allocator, p2p.router.RouterIdMessage{
    //     .id = id,
    //     .buffer = Buffer.fromOwnedSlice(default_allocator, thanks) catch return,
    // }) catch return;

    // chat.main_event_queue.queue_event(router_event) catch return;
    var check_message = CheckMessage.init(default_allocator, chat_message) catch unreachable;
    chat.main_event_queue.queue_event(check_message) catch unreachable;
}
