// C imports:

pub const c = @cImport({
    @cInclude("zmq.h");
    @cInclude("monocypher.h");
    @cInclude("sys/socket.h");
    @cInclude("sys/types.h");
    @cInclude("sys/ioctl.h");
    @cInclude("netinet/in.h");
    @cInclude("net/if.h");
    @cInclude("arpa/inet.h");
    @cInclude("ifaddrs.h");
});
