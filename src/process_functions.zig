const std = @import("std");
const p2p = @import("p2p.zig");
const Socket = p2p.Socket;
const Message = p2p.Message;
const Chat = p2p.Chat;
const cm = p2p.connection_management;
const wi = p2p.work_items;

const work = p2p.work;
const default_allocator = std.heap.page_allocator;
const c = p2p.c;

const warn = std.debug.warn;

var sent_map: std.AutoHashMap([32]u8, bool) = undefined;

pub fn init() void {
    sent_map = std.AutoHashMap([32]u8, bool).init(default_allocator);
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
        std.time.sleep(400000000);
        var check_connection_item = wi.CheckConnectionWorkItem.init(default_allocator, .{}) catch unreachable;
        work.work_queue.push(&check_connection_item.work_item) catch unreachable;
    }
}

// Socket reader thread
pub fn receiver(socket: *Socket) void {
    while (true) {
        //receive a message
        var id_msg = Message.init();
        defer id_msg.deinit();
        var rc_recv = socket.recv(&id_msg);

        warn("more: {}\n", .{id_msg.more()});

        var id_buffer = id_msg.get_buffer() catch unreachable;
        defer id_buffer.deinit();
        warn("id: 0x{x}\n", .{id_buffer.span()});

        if (!id_msg.more()) {
            unreachable;
        }

        var msg = Message.init();
        defer msg.deinit();

        _ = socket.recv(&msg); //sep
        if (!id_msg.more()) {
            unreachable;
        }

        _ = socket.recv(&msg); //actual package

        // Send response
        _ = socket.send_more(&id_msg);
        {
            var sep_msg = Message.init();
            defer sep_msg.deinit();
            _ = socket.send_more(&sep_msg);

            var reply_msg = Message.init();
            defer reply_msg.deinit();
            _ = socket.send(&reply_msg);
        }
        // setup deserializer for package
        var buffer = msg.get_buffer() catch unreachable;
        defer buffer.deinit();

        var deserializer = p2p.deserialize_tagged(buffer.span(), default_allocator);
        defer deserializer.deinit();

        var tag = deserializer.tag() catch unreachable;
        if (tag == 0) {
            warn("got hello\n", .{});
            var ip = msg.get_peer_ip4();
            var ip_buffer = cm.ip4_to_zeromq(ip, 4040) catch unreachable;

            var work_item = wi.AddKnownAddressWorkItem.init(default_allocator, ip_buffer) catch unreachable;
            work.queue_work_item(work_item) catch unreachable;
            warn("ip: {s}\n", .{ip_buffer.span()});
        }
        if (tag == 1) {
            warn("got chat\n", .{});
            var chat = deserializer.deserialize(Chat) catch unreachable;
            const hash = p2p.blake_hash(chat.message);
            var optional_kv = sent_map.put(hash, true) catch unreachable;
            if (optional_kv) |kv| {
                continue;
            }

            var present_work_item = wi.PresentWorkItem.init(default_allocator, chat) catch unreachable;
            work.work_queue.push(&present_work_item.work_item) catch unreachable;

            var chat_copy = chat.copy() catch unreachable;
            var relay_work_item = wi.RelayWorkItem.init(default_allocator, chat_copy) catch unreachable;
            work.work_queue.push(&relay_work_item.work_item) catch unreachable;
        }
    }
}

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
        var chat = Chat.init(username, std.mem.dupeZ(default_allocator, u8, buffer.span()) catch unreachable, std.time.timestamp()) catch unreachable;

        // add work item to queue
        var send_work_item = wi.SendChatWorkItem.init(default_allocator, chat) catch unreachable;
        work.work_queue.push(&send_work_item.work_item) catch unreachable;
    }
}
