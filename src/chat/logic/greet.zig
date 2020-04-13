const chat = @import("../chat.zig");
const p2p = chat.p2p;
const cm = p2p.connection_management;
const default_allocator = p2p.default_allocator;

// On receiving a Hello messsage
const AddKnownAddressWorkItem = chat.work_items.WorkItems.AddKnownAddressWorkItem;

pub fn greet_callback(val: void, id: p2p.router.RouteId, id_msg: *p2p.Message) void {
    var ip = id_msg.get_peer_ip4();
    var ip_buffer = cm.ip4_to_zeromq(ip, 4040) catch unreachable;

    var work_item = AddKnownAddressWorkItem.init(default_allocator, ip_buffer) catch return;
    chat.main_work_queue.queue_work_item(work_item) catch return;
}