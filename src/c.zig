// C imports:

pub const c = @cImport({
    @cInclude("zmq.h");
    @cInclude("monocypher.h");
    @cInclude("sys/socket.h");
});
