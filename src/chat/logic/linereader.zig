const std = @import("std");
//const p2p = @import("../../p2p/p2p.zig");
const chat = @import("../chat.zig");
const p2p = chat.p2p;
const default_allocator = p2p.default_allocator;

// Line reader to read lines from standard in
pub fn line_reader(username: [:0]const u8) void {
    const stdin = std.io.getStdIn().inStream();

    while (true) {
        // read a line
        var buffer = std.ArrayList(u8).init(default_allocator);
        defer buffer.deinit();
        stdin.readUntilDelimiterArrayList(&buffer, '\n', 10000) catch break;

        if (buffer.items.len == 0)
            continue;
        // set up chat
        // var chat = Chat.init(username, std.mem.dupeZ(default_allocator, u8, buffer.span()) catch unreachable, std.time.timestamp()) catch unreachable;

        // // add work item to queue
        // var send_work_item = wi.SendChatWorkItem.init(default_allocator, chat) catch unreachable;
        // work.work_queue.push(&send_work_item.work_item) catch unreachable;
    }
}
