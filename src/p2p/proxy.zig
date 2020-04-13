const p2p = @import("p2p.zig");

const c = p2p.c;
const Socket = p2p.Socket;

pub fn proxy(frontend: *Socket, backend: *Socket) void {
    _ = c.zmq_proxy(frontend.socket, backend.socket, null);
}