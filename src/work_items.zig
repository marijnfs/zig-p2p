const p2p = @import("p2p.zig");
const std = @import("std");
const work = p2p.work;

const Allocator = std.mem.Allocator;
const Socket = p2p.Socket;
const Message = p2p.Message;
const Chat = p2p.Chat;
const direct_allocator = std.heap.direct_allocator;
const make_work_item = p2p.work.make_work_item;
const functions = p2p.process_functions;
const cm = p2p.connection_management;


var PRNG = std.rand.DefaultPrng.init(0);

pub fn send_callback(chat: *Chat) void {
    var buffer = p2p.serialize_tagged(1, chat) catch unreachable;
    defer buffer.deinit();

    var i: usize = 0;
    while (i < cm.outgoing_connections.len) : (i += 1) {
        var msg = Message.init_slice(buffer.span()) catch unreachable;
        cm.outgoing_connections.ptrAt(i).queue_message(msg) catch unreachable;
    }
}

pub const SendChatWorkItem = make_work_item(Chat, send_callback);



pub fn present_callback(chat: *Chat) void {
    std.debug.warn("{}: {}\n", .{ chat.user, chat.message });
}

pub const PresentWorkItem = make_work_item(Chat, present_callback);


pub fn relay_callback(chat: *Chat) void {
    var buffer = p2p.serialize_tagged(1, chat) catch unreachable;
    defer buffer.deinit();

    for (cm.outgoing_connections.span()) |*conn| {
        var msg = Message.init_slice(buffer.span()) catch unreachable;
        conn.queue_message(msg) catch unreachable;
    }
}

pub const RelayWorkItem = make_work_item(Chat, relay_callback);


const AddConnectionData = std.Buffer;

fn add_connection_callback(conn_data: *AddConnectionData) void {
    var outgoing_connection = cm.OutgoingConnection.init(conn_data.span()) catch unreachable;
    cm.outgoing_connections.append(outgoing_connection) catch unreachable;
    var connection_thread = std.Thread.spawn(cm.outgoing_connections.ptrAt(0), functions.connection_processor) catch unreachable;
    cm.connection_threads.append(connection_thread) catch unreachable;

    var buffer = p2p.serialize_tagged(0, @as(i64, 0)) catch unreachable;

    var msg = Message.init_slice(buffer.span()) catch unreachable;
    outgoing_connection.queue_message(msg) catch unreachable;
}

pub const AddConnectionWorkItem = make_work_item(AddConnectionData, add_connection_callback);


pub fn check_connection_callback(data: *work.DummyWorkData) void {
    var i: usize = 0;
    while (i < cm.outgoing_connections.len) {
        var current = cm.outgoing_connections.ptrAt(i);
        if (!current.active) {
            std.debug.warn("Removing connection: {}\n", .{current});

            current.deinit();
            _ = cm.outgoing_connections.swapRemove(i);
        } else {
            i += 1;
        }
    }

    const K: usize = 8;
    if (cm.known_addresses.len > cm.outgoing_connections.len) {
        var n: usize = 0;
        while (n < K and cm.outgoing_connections.len < K) {
            var selection = PRNG.random.uintLessThan(usize, cm.known_addresses.len);
            var selected_address = cm.known_addresses.at(selection);

            var found: bool = false;
            for (cm.outgoing_connections.span()) |*conn| {
                if (std.mem.eql(u8, conn.connect_point.span(), selected_address)) {
                    found = true;
                    break;
                }
            }
            if (found) continue;

            var outgoing_connection = cm.OutgoingConnection.init(selected_address) catch unreachable;
            cm.outgoing_connections.append(outgoing_connection) catch unreachable;
        }
    }
    // outgoing_connections
}

pub const CheckConnectionWorkItem = make_work_item(work.DummyWorkData, check_connection_callback);
