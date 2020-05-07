const std = @import("std");
const chat = @import("../chat.zig");
const p2p = chat.p2p;
const default_allocator = p2p.default_allocator;
const Buffer = p2p.Buffer;

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

        std.debug.warn("buf: {} {}\n", .{ buffer.span(), buffer.items.len });
        var chat_message = chat.ChatMessage.init(username, buffer.span(), 0) catch break;
        var chat_event = chat.Events.CheckMessage.init(default_allocator, chat_message) catch break;
        chat.main_event_queue.queue_event(chat_event) catch break;
    }
}
