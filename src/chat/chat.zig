const chat_message = @import("chat_message.zig");
const process_functions = @import("process_functions.zig");
pub const events = @import("events.zig");
pub const messages = @import("messages.zig");
pub const event_queues = @import("event_queues.zig");

pub const Events = events.Events;
pub const ChatMessage = chat_message.ChatMessage;

pub const main_event_queue = &event_queues.main_event_queue;

pub const line_reader = @import("logic/linereader.zig").line_reader;


pub const callbacks = .{
    .greet = @import("logic/greet.zig").greet_callback,
    .incoming_chat = @import("logic/incoming_chat.zig").incoming_chat_callback,
};


pub const p2p = @import("../p2p/p2p.zig");

pub fn init() void {
    event_queues.init();
}

pub var router_socket: p2p.Socket = undefined;

pub fn bind_router_socket(bind_point: [:0]const u8) void {
    router_socket = p2p.Socket.init(p2p.connection_management.context, p2p.c.ZMQ_ROUTER);
}