const std = @import("std");
const p2p = @import("p2p");

const Socket = p2p.Socket;
const Message = p2p.Message;
const Chat = p2p.Chat;
const cm = p2p.connection_management;
const wi = p2p.work_items;
const Pool = p2p.Pool;
const work = p2p.work;

const default_allocator = p2p.default_allocator;

const c = p2p.c;
const warn = std.debug.warn;

pub fn init() void {
    var root_pool_name = [_]u8{0} ** 32;
    var name = "ROOT";
    std.mem.copy(u8, root_pool_name[0..name.len], name);
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
        var reply = Message.init() catch break;
        rc = outgoing_connection.socket.recv(&reply);
        if (rc == -1)
            break;
    }

    warn("Connection Processor ended\n", .{});

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
