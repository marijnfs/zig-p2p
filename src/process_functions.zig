const std = @import("std");
const p2p = @import("p2p.zig");
const Socket = p2p.Socket;
const Message = p2p.Message;
const Chat = p2p.Chat;
const cm = p2p.connection_management;
const work = p2p.work;

const direct_allocator = std.heap.direct_allocator;

var sent_map: std.AutoHashMap([32]u8, bool) = undefined;

pub fn init() void {
    sent_map = std.AutoHashMap([32]u8, bool).init(direct_allocator);
}

// Function to process message queue in an OutgoingConnection
pub fn connection_processor(outgoing_connection: *cm.OutgoingConnection) void {
    while (true) {
        if (outgoing_connection.send_queue.empty()) {
            std.time.sleep(1000000);
            continue;
        }

        var message = outgoing_connection.send_queue.pop() catch break;
        defer message.deinit();

        var rc = outgoing_connection.socket.send(&message);
        if (rc == -1)
            break;
        var reply = Message.init();
        rc = outgoing_connection.socket.recv(&reply);
        if (rc == -1)
            break;
    }

    //when we get here the connection must be inactive
    outgoing_connection.active = false;
}

// Thread that intermittently adds a discovery task
pub fn discovery_reminder(discovery_period_sec: i64) void {
    while (true) {
        std.time.sleep(100000000 * discovery_period_sec);
    }
}

// Thread that intermittently adds a connection management task
pub fn connection_manager_reminder(check_period_sec: u64) void {
    while (true) {
        std.time.sleep(100000000 * check_period_sec);
        var check_connection_item = cm.CheckConnectionWorkItem.init(direct_allocator) catch unreachable;
        work.work_queue.push(&check_connection_item.work_item) catch unreachable;
    }
}

// Socket reader thread
pub fn receiver(socket: *Socket) void {
    while (true) {
        //receive a message
        var msg = Message.init();
        defer msg.deinit();
        var rc_recv = socket.recv(&msg);

        var buffer = msg.get_buffer() catch unreachable;
        defer buffer.deinit();

        //send response immediately
        var return_msg = Message.init();
        defer return_msg.deinit();

        var rc_send = socket.send(&return_msg);

        //setup work item and add to queue
        var chat = p2p.deserialize(Chat, buffer.span(), direct_allocator) catch unreachable;

        //var chat = Chat.init("incoming", buffer.span(), direct_allocator) catch unreachable;

        const hash = p2p.blake_hash(chat.message);
        var optional_kv = sent_map.put(hash, true) catch unreachable;
        if (optional_kv) |kv| {
            continue;
        }

        var present_work_item = cm.PresentWorkItem.init(direct_allocator, chat) catch unreachable;
        work.work_queue.push(&present_work_item.work_item) catch unreachable;

        var chat_copy = Chat.init("incoming", buffer.span()) catch unreachable;
        var relay_work_item = cm.RelayWorkItem.init(direct_allocator, chat_copy) catch unreachable;
        work.work_queue.push(&relay_work_item.work_item) catch unreachable;
    }
}

// Line reader to read lines from standard in
pub fn line_reader(username: [:0]const u8) void {
    const stdin = std.io.getStdIn().inStream();

    while (true) {
        // read a line
        var line = stdin.readUntilDelimiterAlloc(direct_allocator, '\n', 10000) catch break;
        if (line.len == 0)
            continue;
        // set up chat
        var chat = Chat.init(username, line[0..:0]) catch unreachable;

        // add work item to queue
        var send_work_item = cm.SendWorkItem.init(direct_allocator, chat) catch unreachable;
        work.work_queue.push(&send_work_item.work_item) catch unreachable;
    }
}