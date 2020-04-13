const std = @import("std");
const chat = @import("chat.zig");
const p2p = chat.p2p;

const work = p2p.work;
const pool = p2p.pool; 
const Socket = p2p.Socket;
const Message = p2p.Message;

const make_work_item = p2p.work.make_work_item;
const cm = p2p.connection_management;

const Allocator = std.mem.Allocator;
const default_allocator = std.heap.page_allocator;
const Buffer = std.ArrayListSentineled(u8, 0);

var PRNG = std.rand.DefaultPrng.init(0);

// Work Items
pub const WorkItems = .{
    .SendToBindSocket = work.make_work_item(RouterIdMessage, send_to_bind_socket),
    // .ReplyRouter = make_work_item(chat.ChatMessage, send_callback),
    // .SendChatWorkItem = make_work_item(chat.ChatMessage, send_callback),
    // .RelayWorkItem = make_work_item(chat.ChatMessage, relay_callback),
    .AddConnectionWorkItem = make_work_item(AddConnectionData, add_connection_callback),
    .AddKnownAddressWorkItem = make_work_item(AddKnownAddressData, add_known_address_callback),
    .SendMessage = make_work_item(SendMessageData, send_message_callback)
    // .CheckConnectionWorkItem = make_work_item(work.DummyWorkData, check_connection_callback),
};

// Data Structs
const RouterIdMessage = struct {
    id: [4]u8,
    buffer: Buffer,

    fn deinit(self: *RouterIdMessage) void {
        self.buffer.deinit();
    }
};

const SendMessageData = struct {
    socket: p2p.Socket,
    buffer: Buffer,

    fn deinit(self: *RouterIdMessage) void {
        self.buffer.deinit();
    }
};

pub fn send_message_callback(message_data: *SendMessageData) void {
    var msg = Message.init_slice(message_data.buffer.span()) catch return;
    defer msg.deinit();

    var rc = message_data.socket.send(&msg);
}


pub fn send_to_bind_socket(id_message: *RouterIdMessage) void {
    var id_msg = Message.init_slice(id_message.id[0..]) catch unreachable;
    defer id_msg.deinit();
    var rc = chat.router_socket.send(&id_msg);

    var delim_msg = Message.init() catch unreachable;
    defer delim_msg.deinit();
    rc = chat.router_socket.send(&delim_msg);


    var payload_msg = Message.init_slice(id_message.buffer.span()) catch unreachable;
    defer payload_msg.deinit();
    rc = chat.router_socket.send(&payload_msg);
}

pub fn send_callback(chat_message: *chat.ChatMessage) void {
    var buffer = p2p.serialize_tagged(1, chat_message) catch unreachable;
    defer buffer.deinit();

    var i: usize = 0;
    while (i < cm.outgoing_connections.items.len) : (i += 1) {
        var msg = Message.init_slice(buffer.span()) catch unreachable;
        cm.outgoing_connections.ptrAt(i).queue_message(msg) catch unreachable;
    }
}


pub fn relay_callback(chat: *Chat) void {
    var buffer = p2p.serialize_tagged(1, chat) catch unreachable;
    defer buffer.deinit();

    for (cm.outgoing_connections.span()) |*conn| {
        var msg = Message.init_slice(buffer.span()) catch unreachable;
        conn.queue_message(msg) catch unreachable;
    }
}

const AddConnectionData = Buffer;

fn add_connection_callback(connection_point: *AddConnectionData) void {
    std.debug.warn("connecting to: {}\n", .{connection_point.span()});
    var outgoing_connection = cm.OutgoingConnection.init(connection_point.span()) catch return;
    outgoing_connection.start_work_process();

    //Say hello
    var buffer = p2p.serialize_tagged(0, @as(i64, 0)) catch unreachable;
    var work_item = WorkItems.SendMessage.init(default_allocator, .{.socket = outgoing_connection.socket, .buffer = buffer}) catch unreachable;

    outgoing_connection.queue_work_item(work_item) catch unreachable;

    //add connection and start thread
    cm.outgoing_connections.append(outgoing_connection) catch unreachable;
}

const AddKnownAddressData = Buffer;
fn add_known_address_callback(conn_data: *AddKnownAddressData) void {
    for (cm.known_addresses.span()) |addr| {
        if (std.mem.eql(u8, addr.span(), conn_data.span()))
            return;
    }
    std.debug.warn("Adding: {s}\n", .{conn_data.span()});
    cm.known_addresses.append(Buffer.initFromBuffer(conn_data.*) catch unreachable) catch unreachable;
}

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
}

pub fn expand_connection_callback(data: *work.DummyWorkData) void {
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



const DataRequest = struct {
    id: Buffer,

};

pub fn process_datarequest_callback(data: *DataRequest) void {
    
}

