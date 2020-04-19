const chat = @import("../chat.zig");
const std = @import("std");
const p2p = chat.p2p;
const cm = p2p.connection_management;
// On receiving a Hello messsage

pub fn incoming_chat_callback(chat_message: chat.ChatMessage, id: p2p.router.RouteId, id_msg: *p2p.Message) void {
    std.debug.warn("got chat: {}\n", .{chat_message});
    // chat.main_work_queue.queue_work_item();
}
