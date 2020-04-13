const chat_message = @import("chat_message.zig");
const process_functions = @import("process_functions.zig");
const work_items = @import("work_items.zig");
pub const work_queues = @import("work_queues.zig");
pub const main_work_queue = work_queues.main_work_queue;

pub const line_reader = @import("logic/linereader.zig").line_reader;



pub const callbacks = .{
    .greet = @import("logic/greet.zig").greet_callback,
};


pub const p2p = @import("../p2p/p2p.zig");
pub fn init() void {
    work_queues.init();
}