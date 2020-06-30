const std = @import("std");
const chat = @import("../chat.zig");
const p2p = chat.p2p;
const default_allocator = p2p.default_allocator;
const Buffer = p2p.Buffer;

// Line reader to read lines from standard in
pub fn line_reader(username: [:0]const u8) !void {
    const stdin = std.io.getStdIn().inStream();

    while (true) {
        // read a line
        var buffer = std.ArrayList(u8).init(default_allocator);
        defer buffer.deinit();
        try stdin.readUntilDelimiterArrayList(&buffer, '\n', 10000);

        if (buffer.items.len == 0)
            continue;

        std.debug.warn("buf: {} {}\n", .{ buffer.span(), buffer.items.len });
        var chat_message = try chat.ChatMessage.init(username, buffer.span(), 0);
        var chat_event = try chat.Events.CheckMessage.create(chat_message);
        try chat.main_event_queue.queue_event(chat_event);
    }
}
