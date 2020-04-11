const std = @import("std");
const p2p = @import("p2p.zig");

const work = p2p.work;
const pool = p2p.pool;
const Socket = p2p.Socket;
const Message = p2p.Message;
const Chat = p2p.Chat;

const make_work_item = p2p.work.make_work_item;
const functions = p2p.process_functions;
const cm = p2p.connection_management;

const Allocator = std.mem.Allocator;
const default_allocator = std.heap.page_allocator;
const Buffer = std.ArrayListSentineled(u8, 0);

var PRNG = std.rand.DefaultPrng.init(0);

pub fn send_callback(chat: *Chat) void {
    var buffer = p2p.serialize_tagged(1, chat) catch unreachable;
    defer buffer.deinit();

    var i: usize = 0;
    while (i < cm.outgoing_connections.items.len) : (i += 1) {
        var msg = Message.init_slice(buffer.span()) catch unreachable;
        cm.outgoing_connections.ptrAt(i).queue_message(msg) catch unreachable;
    }
}

pub const SendChatWorkItem = make_work_item(Chat, send_callback);

// pub fn present_callback(chat: *Chat) void {
//     std.debug.warn("{}: {}\n", .{ chat.user, chat.message });
// }

// pub const PresentWorkItem = make_work_item(Chat, present_callback);


pub fn relay_callback(chat: *Chat) void {
    var buffer = p2p.serialize_tagged(1, chat) catch unreachable;
    defer buffer.deinit();

    for (cm.outgoing_connections.span()) |*conn| {
        var msg = Message.init_slice(buffer.span()) catch unreachable;
        conn.queue_message(msg) catch unreachable;
    }
}

pub const RelayWorkItem = make_work_item(Chat, relay_callback);

const AddConnectionData = Buffer;

fn add_connection_callback(conn_data: *AddConnectionData) void {
    std.debug.warn("conn data: {}\n", .{conn_data.span()});
    var outgoing_connection = cm.OutgoingConnection.init(conn_data.span()) catch return;

    //Say hello
    var buffer = p2p.serialize_tagged(0, @as(i64, 0)) catch unreachable;
    var msg = Message.init_slice(buffer.span()) catch unreachable;
    outgoing_connection.queue_message(msg) catch unreachable;

    //add connection and start thread
    cm.outgoing_connections.append(outgoing_connection) catch unreachable;
    var connection_thread = std.Thread.spawn(cm.outgoing_connections.ptrAt(0), functions.connection_processor) catch unreachable;
    cm.connection_threads.append(connection_thread) catch unreachable;
}
pub const AddConnectionWorkItem = make_work_item(AddConnectionData, add_connection_callback);

const AddKnownAddressData = Buffer;
fn add_known_address_callback(conn_data: *AddKnownAddressData) void {
    for (cm.known_addresses.span()) |addr| {
        if (std.mem.eql(u8, addr.span(), conn_data.span()))
            return;
    }
    std.debug.warn("Adding: {s}\n", .{conn_data.span()});
    cm.known_addresses.append(Buffer.initFromBuffer(conn_data.*) catch unreachable) catch unreachable;
}
pub const AddKnownAddressWorkItem = make_work_item(AddKnownAddressData, add_known_address_callback);

pub fn check_connection_callback(data: *work.DummyWorkData) void {
    var i: usize = 0;
    while (i < cm.outgoing_connections.items.len) {
        var current = cm.outgoing_connections.ptrAt(i);
        if (!current.active) {
            std.debug.warn("Removing connection: {}\n", .{current});

            current.deinit();
            _ = cm.outgoing_connections.swapRemove(i);
        } else {
            i += 1;
        }
    }

    const K: usize = 4;

    if (cm.known_addresses.items.len > cm.outgoing_connections.items.len) {
        var n: usize = 0;
        while (n < 1 and cm.outgoing_connections.items.len < K) : (n += 1) {
            var selection = PRNG.random.uintLessThan(usize, cm.known_addresses.items.len);
            std.debug.warn("selection: {}/{}\n", .{ selection, cm.known_addresses.items.len });
            var selected_address = cm.known_addresses.ptrAt(selection);

            var found: bool = false;
            for (cm.outgoing_connections.span()) |*conn| {
                if (std.mem.eql(u8, conn.connect_point.span(), selected_address.span())) {
                    found = true;
                    break;
                }
            }
            if (found) continue;
            std.debug.warn("add item for: {s}\n", .{selected_address.span()});

            var work_item = AddConnectionWorkItem.init(default_allocator, Buffer.initFromBuffer(selected_address.*) catch unreachable) catch unreachable;
            work.queue_work_item(work_item) catch unreachable;
        }
    }
    // outgoing_connections
}

pub const CheckConnectionWorkItem = make_work_item(work.DummyWorkData, check_connection_callback);


const DataRequest = struct {
    id: Buffer,

};

pub fn process_datarequest_callback(data: *DataRequest) void {
    
}

