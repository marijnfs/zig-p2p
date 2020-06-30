const std = @import("std");
const chat = @import("chat.zig");
const p2p = chat.p2p;
const RouterIdMessage = p2p.router.RouterIdMessage;

const make_event = p2p.event.make_event;
const pool = p2p.pool;
const Socket = p2p.Socket;
const Message = p2p.Message;
const cm = p2p.connection_management;
const OutgoingConnection = p2p.OutgoingConnection;
const messages = chat.messages;

const Allocator = std.mem.Allocator;
const default_allocator = p2p.default_allocator;
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
    .CheckMessage = make_event(chat.ChatMessage, check_message_callback),

    .SayHello = make_event(SendMessageData, say_hello_callback),
    .SendChat = make_event(SendMessageData, send_chat_callback),
    // .CheckConnectionWorkItem = make_work_item(work.DummyWorkData, check_connection_callback),
};

const SendMessageData = struct {
    socket: *p2p.Socket,
    buffer: Buffer,

    fn deinit(self: *RouterIdMessage) void {
        self.buffer.deinit();
    }
};

pub fn say_hello_callback(message_data: *SendMessageData) anyerror!void {
    var msg = try Message.init_slice(message_data.buffer.span());
    defer msg.deinit();

    warn("sending msg, sock: {}\n", .{message_data.socket});
    var rc = message_data.socket.send(&msg);
}

pub fn send_chat_callback(message_data: *SendMessageData) anyerror!void {
    warn("Sending chat\n", .{});
    var msg = try Message.init_slice(message_data.buffer.span());
    defer msg.deinit();

    var rc = message_data.socket.send(&msg);
}

pub fn router_reply_callback(id_message: *RouterIdMessage) anyerror!void {
    warn("Router reply to {x} :{}\n", .{ id_message.id, id_message.buffer.span() });
    try chat.router.?.queue_message(id_message.*);
}

pub fn check_message_callback(chat_message: *chat.ChatMessage) anyerror!void {
    const held = cm.mutex.acquire();
    defer held.release();

    var H = try p2p.hash(chat_message.*);
    var optional_kv = try chat.sent_map.put(H, true);
    if (optional_kv) |kv| {
        return;
    }

    warn("Chat [{}] {}\n", .{ chat_message.user, chat_message.message });

    for (cm.outgoing_connections.items) |con| {
        warn("adding announce chat to connection {}\n", .{con.connect_point.span()});
        var chat_buffer = try messages.AnnounceChat(chat_message);
        var chat_event = try Events.SendChat.create(.{ .socket = con.socket, .buffer = chat_buffer });

        con.queue_event(chat_event) catch continue;
    }
}

const AddConnectionData = Buffer;

fn add_connection_callback(connection_point: *AddConnectionData) anyerror!void {
    warn("creating connection to {}\n", .{connection_point.span()});
    var outgoing_connection = try OutgoingConnection.init(connection_point.span());

    //Say hello
    var hello_msg = try messages.Hello();
    var event = try Events.SayHello.create(.{ .socket = outgoing_connection.socket, .buffer = hello_msg });

    try outgoing_connection.queue_event(event);

    //add connection and start thread
    try outgoing_connection.start_event_loop();

    try cm.outgoing_connections.append(outgoing_connection);
}

const AddKnownAddressData = Buffer;
fn add_known_address_callback(conn_data: *AddKnownAddressData) !void {
    for (cm.known_addresses.span()) |addr| {
        if (std.mem.eql(u8, addr.span(), conn_data.span()))
            return;
    }
    warn("Adding: {s}\n", .{conn_data.span()});
    try cm.known_addresses.append(try Buffer.initFromBuffer(conn_data.*));
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
