const std = @import("std");
const chat = @import("chat.zig");
const p2p = chat.p2p;

const make_event = p2p.event.make_event;
const pool = p2p.pool;
const Socket = p2p.Socket;
const Message = p2p.Message;
const cm = p2p.connection_management;

const messages = chat.messages;

const Allocator = std.mem.Allocator;
const default_allocator = std.heap.page_allocator;
const Buffer = p2p.Buffer;
const warn = std.debug.warn;

var PRNG = std.rand.DefaultPrng.init(0);

// Work Items
pub const Events = .{
    .RouterReply = make_event(RouterIdMessage, router_reply_callback),

    // .SendChatWorkItem = make_event(chat.ChatMessage, send_callback),
    // .RelayWorkItem = make_event(chat.ChatMessage, relay_callback),
    .AddConnection = make_event(AddConnectionData, add_connection_callback),
    .AddKnownAddress = make_event(AddKnownAddressData, add_known_address_callback),
    .InputMessage = make_event(chat.ChatMessage, input_message_callback),

    .SayHello = make_event(SendMessageData, say_hello_callback),
    .SendChat = make_event(SendMessageData, send_chat_callback),
    // .CheckConnectionWorkItem = make_work_item(work.DummyWorkData, check_connection_callback),
};

// Data Structs
pub const RouterIdMessage = struct {
    id: p2p.router.RouteId,
    buffer: Buffer,

    fn deinit(self: *RouterIdMessage) void {
        self.buffer.deinit();
    }
};

const SendMessageData = struct {
    socket: *p2p.Socket,
    buffer: Buffer,

    fn deinit(self: *RouterIdMessage) void {
        self.buffer.deinit();
    }
};

pub fn say_hello_callback(message_data: *SendMessageData) void {
    warn("sending hello\n", .{});
    var msg = Message.init_slice(message_data.buffer.span()) catch return;
    defer msg.deinit();

    warn("sending msg, sock: {}\n", .{message_data.socket});
    var rc = message_data.socket.send(&msg);

    warn("rcv msg\n", .{});
    var rcv_msg = message_data.socket.recv() catch return;
    defer rcv_msg.deinit();

    warn("getting buffer\n", .{});
    var buf = rcv_msg.get_buffer() catch return;
    warn("Said hello, got {}\n", .{buf.span()});
}

pub fn send_chat_callback(message_data: *SendMessageData) void {
    warn("Sending chat\n", .{});
    var msg = Message.init_slice(message_data.buffer.span()) catch return;
    defer msg.deinit();

    var rc = message_data.socket.send(&msg);

    var rcv_msg = message_data.socket.recv() catch return;
    defer rcv_msg.deinit();

    var buf = rcv_msg.get_buffer() catch return;
    warn("Sent chat, got {}\n", .{buf.span()});
}

pub fn router_reply_callback(id_message: *RouterIdMessage) void {
    warn("Router reply to {x} :{}\n", .{ id_message.id, id_message.buffer.span() });
    var id_msg = Message.init_slice(id_message.id[0..]) catch unreachable;
    defer id_msg.deinit();
    var rc = chat.router.?.socket.send_more(&id_msg);

    var delim_msg = Message.init() catch unreachable;
    defer delim_msg.deinit();
    rc = chat.router.?.socket.send_more(&delim_msg);

    var payload_msg = Message.init_slice(id_message.buffer.span()) catch unreachable;
    defer payload_msg.deinit();
    rc = chat.router.?.socket.send(&payload_msg);
}

pub fn input_message_callback(chat_message: *chat.ChatMessage) void {
    warn("Input Message: {}\n", .{chat_message});

    const held = cm.mutex.acquire();
    defer held.release();

    for (cm.outgoing_connections.items) |con| {
        warn("adding announce chat\n", .{});
        var chat_buffer = messages.AnnounceChat(chat_message) catch continue;
        var chat_event = Events.SendChat.init(default_allocator, .{ .socket = con.socket, .buffer = chat_buffer }) catch unreachable;

        con.queue_event(chat_event) catch continue;
    }
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
    var outgoing_connection = cm.OutgoingConnection.init(connection_point.span()) catch return;

    outgoing_connection.start_event_loop();

    //Say hello
    // var hello_msg = messages.Hello() catch return;
    // var event = Events.SayHello.init(default_allocator, .{ .socket = outgoing_connection.socket, .buffer = hello_msg }) catch unreachable;

    // outgoing_connection.queue_event(event) catch unreachable;

    //add connection and start thread
    cm.outgoing_connections.append(outgoing_connection) catch unreachable;
}

const AddKnownAddressData = Buffer;
fn add_known_address_callback(conn_data: *AddKnownAddressData) void {
    for (cm.known_addresses.span()) |addr| {
        if (std.mem.eql(u8, addr.span(), conn_data.span()))
            return;
    }
    warn("Adding: {s}\n", .{conn_data.span()});
    cm.known_addresses.append(Buffer.initFromBuffer(conn_data.*) catch unreachable) catch unreachable;
}

pub fn check_connection_callback(data: *void) void {
    var i: usize = 0;
    while (i < cm.outgoing_connections.items.len) {
        var current = cm.outgoing_connections.ptrAt(i);
        if (!current.active) {
            warn("Removing connection: {}\n", .{current});

            current.deinit();
            _ = cm.outgoing_connections.swapRemove(i);
        } else {
            i += 1;
        }
    }
}

pub fn expand_connection_callback(data: *void) void {
    const K: usize = 4;

    if (cm.known_addresses.items.len > cm.outgoing_connections.items.len) {
        var n: usize = 0;
        while (n < 1 and cm.outgoing_connections.items.len < K) : (n += 1) {
            var selection = PRNG.random.uintLessThan(usize, cm.known_addresses.items.len);
            warn("selection: {}/{}\n", .{ selection, cm.known_addresses.items.len });
            var selected_address = cm.known_addresses.ptrAt(selection);

            var found: bool = false;
            for (cm.outgoing_connections.span()) |*conn| {
                if (std.mem.eql(u8, conn.connect_point.span(), selected_address.span())) {
                    found = true;
                    break;
                }
            }
            if (found) continue;
            warn("add item for: {s}\n", .{selected_address.span()});

            var event = AddConnectionWorkItem.init(default_allocator, Buffer.initFromBuffer(selected_address.*) catch unreachable) catch unreachable;
            work.queue_event(event) catch unreachable;
        }
    }
    // outgoing_connections
}

const DataRequest = struct {
    id: Buffer,
};

pub fn process_datarequest_callback(data: *DataRequest) void {}
