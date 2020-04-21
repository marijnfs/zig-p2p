const std = @import("std");
const p2p = @import("p2p.zig");

const c = p2p.c;
const Socket = p2p.Socket;

const ProxyParams = struct {
    frontend: *Socket,
    backend: *Socket,
};

pub fn proxy_threadfunc(proxy_params: ProxyParams) void {
    std.debug.warn("proxy\n", .{});
    const rc = c.zmq_proxy(proxy_params.frontend.socket, proxy_params.backend.socket, null);
    std.debug.warn("proxy ended\n", .{});
}

pub fn proxy(frontend: *Socket, backend: *Socket) !void {
    _ = try p2p.thread_pool.add_thread(ProxyParams{ .frontend = frontend, .backend = backend }, proxy_threadfunc);
}
