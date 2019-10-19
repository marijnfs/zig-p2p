const std = @import("std");

const c = @cImport({
    @cInclude("czmq.h");
});


pub fn main() anyerror!void {
    std.debug.warn("All your base are belong to us.\n");
}
