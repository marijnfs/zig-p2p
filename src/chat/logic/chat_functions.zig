const std = @import("std");
const mem = std.mem;
const warn = std.debug.warn;

const p2p = @import ("p2p");
const serialize = p2p.serialize;

const default_allocator = p2p.default_allocator;

const cm = p2p.connection_management;

const Chat = p2p.Chat;
const Pool = p2p.Pool;
const Socket = p2p.Socket;
const Message = p2p.Message;

const work = p2p.work;
const wi = p2p.work_items;
const relaychat = @import("relaychat.zig");


var chat_pool: Pool(Chat) = undefined;

pub fn add_to_pool_callback(chat: *Chat) void {
    var exists = chat_pool.put(chat.*);
}

pub const AddToPoolWorkItem = work.make_work_item(Chat, add_to_pool_callback);



pub fn new_chat(chat: Chat) void {
    std.debug.warn("chat {}\n", .{chat.message});

    var chat_copy = chat.copy() catch unreachable;

    var relay_work_item = wi.RelayWorkItem.init(default_allocator, chat_copy) catch unreachable;
    work.work_queue.push(&relay_work_item.work_item) catch unreachable;
}

pub fn init() void {
    var uuid = std.mem.zeroes([32]u8);
    chat_pool = Pool(Chat).init(default_allocator, uuid);
}


// Socket reader thread
pub fn router_receiver(socket: *Socket) void {
    while (true) {
        //receive a message

        var msg_id = socket.recv2() catch break;
        defer msg_id.deinit();

        var ID = msg_id.get_buffer() catch break;
        defer ID.deinit();

        if (!msg_id.more()) {
            break;
        }

        //delimiter
        var msg_delim = socket.recv2() catch break;
        if (!msg_delim.more()) {
            break;
        }

        var msg_payload = socket.recv2() catch break; //actual package


        // setup deserializer for package
        var buffer = msg_payload.get_buffer() catch break;
        defer buffer.deinit();

        var deserializer = p2p.deserialize_tagged(buffer.span(), default_allocator);
        defer deserializer.deinit();

        var tag = deserializer.tag() catch break;
        if (tag == 0) { //Introduction Message
            warn("got hello\n", .{});
            var ip = msg_id.get_peer_ip4();
            var ip_buffer = cm.ip4_to_zeromq(ip, 4040) catch break;

            var work_item = wi.AddKnownAddressWorkItem.init(default_allocator, ip_buffer) catch break;
            work.queue_work_item(work_item) catch break;
            warn("ip: {s}\n", .{ip_buffer.span()});

            // Send response
            _ = socket.send_more(&msg_id);
        
            var sep_msg = Message.init() catch break;
            defer sep_msg.deinit();
            _ = socket.send_more(&sep_msg);

            var reply_msg = Message.init() catch break;
            defer reply_msg.deinit();
            _ = socket.send(&reply_msg);
        }
        if (tag == 1) { //New Chat
            // Send response
            _ = socket.send_more(&msg_id);
        
            var sep_msg = Message.init() catch break;
            defer sep_msg.deinit();
            _ = socket.send_more(&sep_msg);

            var reply_msg = Message.init() catch break;
            defer reply_msg.deinit();
            _ = socket.send(&reply_msg);

            var chat = deserializer.deserialize(Chat) catch break;
            var exists = chat_pool.put(chat) catch break;


            var add_to_chatpool_work_item = AddToPoolWorkItem.init(default_allocator, chat) catch break;
            work.work_queue.push(&add_to_chatpool_work_item.work_item) catch break;
        }
        if (tag == 2) { //Peer discovery
            const id = ID.span()[0..4];
            var reply_peers_work_item = ReplyPeersWorkItem.init(default_allocator, id.*) catch break;
            work.queue_work_item(reply_peers_work_item) catch break;
        }
    }

    warn("Broke out of Loop\n", .{});
}


pub fn reply_peers_function(id: *[4]u8) void {
    var buffer = serialize(cm.known_addresses.items) catch unreachable;

    var work_item = relaychat.SendToBindSocketWorkItem.init(default_allocator, .{.id = id.*, .buffer = buffer}) catch unreachable;
    work.queue_work_item(work_item) catch unreachable;
}

pub const ReplyPeersWorkItem = work.make_work_item([4]u8, reply_peers_function);
