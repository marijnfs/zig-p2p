const chat = @import("../chat.zig");
const p2p = chat.p2p;
const cm = p2p.connection_management;
// On receiving a Hello messsage

pub fn greet_callback(val: void, id: p2p.router.RouteId, id_msg: *p2p.Message) void {
    var ip = id_msg.get_peer_ip4();
    var ip_buffer = cm.ip4_to_zeromq(ip, 4040) catch unreachable;

    
}