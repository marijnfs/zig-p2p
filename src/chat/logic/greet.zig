const chat = @import("../chat.zig");
const p2p = chat.p2p;
const std = @import("std");

const cm = p2p.connection_management;
const default_allocator = p2p.default_allocator;

// On receiving a Hello messsage
const AddKnownAddress = chat.events.Events.AddKnownAddress;
const RouterReply = chat.events.Events.RouterReply;
const Buffer = p2p.Buffer;

pub fn greet_callback(val: void, id: p2p.router.RouteId, id_msg: *p2p.Message) anyerror!void {
    std.debug.warn("Greet callback\n", .{});

    var ip = id_msg.get_peer_ip4();
    var ip_buffer = cm.ip4_to_zeromq(ip, 4040) catch unreachable;

    // var thanks = std.mem.dupe(default_allocator, u8, "thanks") catch return;
    // var router_event = RouterReply.init(default_allocator, p2p.router.RouterIdMessage{
    //     .id = id,
    //     .buffer = Buffer.fromOwnedSlice(default_allocator, thanks) catch return,
    // }) catch return;
    // chat.main_event_queue.queue_event(router_event) catch return;

    var event = AddKnownAddress.create(ip_buffer) catch return;
    chat.main_event_queue.queue_event(event) catch return;
}
