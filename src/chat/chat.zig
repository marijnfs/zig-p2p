const chat_message = @import("chat_message.zig");
const process_functions = @import("process_functions.zig");
pub const work_items = @import("work_items.zig");
pub const work_queues = @import("work_queues.zig");
pub const main_work_queue = &work_queues.main_work_queue;

pub const line_reader = @import("logic/linereader.zig").line_reader;

pub const ChatMessage = chat_message.ChatMessage;


pub const callbacks = .{
    .greet = @import("logic/greet.zig").greet_callback,
    .incoming_chat = @import("logic/incoming_chat.zig").incoming_chat_callback,
};


pub const p2p = @import("../p2p/p2p.zig");
pub fn init() void {
    work_queues.init();
}

pub var router_socket: p2p.Socket = undefined;

pub fn bind_router_socket(bind_point: [:0]const u8) void {
    router_socket = p2p.Socket.init(p2p.connection_management.context, p2p.c.ZMQ_ROUTER);
}