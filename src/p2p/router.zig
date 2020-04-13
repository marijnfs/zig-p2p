const p2p = @import("p2p.zig");
const std = @import("std");


const default_allocator = p2p.default_allocator;
const DeserializerTagged = p2p.serializer.DeserializerTagged;

pub const RouteId = [4]u8;

pub const Router = struct {
    const CallbackType = fn (*DeserializerTagged, RouteId, *p2p.Message) void;

    socket: p2p.Socket,
    callback_map: std.AutoHashMap(i64, CallbackType),

    pub fn init(allocator: *std.mem.Allocator, socket: p2p.Socket) Router {
        return .{
            .socket = socket,
            .callback_map = std.AutoHashMap(i64, CallbackType).init(allocator),
        };
    }

    pub fn add_route(self: *Router, tag: i64, comptime T: type, comptime callback: fn (T, RouteId, *p2p.Message) void) !void {
        const bla = struct {
            fn f(deserializer: *DeserializerTagged, id: RouteId, id_message: *p2p.Message) void {
                var value = deserializer.deserialize(T) catch unreachable;
                callback(value, id, id_message);
            }
        }.f;
        _ = try self.callback_map.put(tag, bla);
    }

    pub fn router_processor(self: *Router) void {
        //receive a message
        while (true) {
            var msg_id = self.socket.recv() catch break;
            defer msg_id.deinit();

            var id_buffer = msg_id.get_buffer() catch break;
            defer id_buffer.deinit();

            var id: RouteId = id_buffer.span()[0..4].*;

            if (!msg_id.more()) {
                break;
            }

            //delimiter
            var msg_delim = self.socket.recv() catch break;
            if (!msg_delim.more()) {
                break;
            }

            var msg_payload = self.socket.recv() catch break; //actual package


            // setup deserializer for package
            var buffer = msg_payload.get_buffer() catch break;
            defer buffer.deinit();

            var deserializer = p2p.deserialize_tagged(buffer.span(), default_allocator);
            defer deserializer.deinit();

            var tag = deserializer.tag() catch break;
            var callback_kv = self.callback_map.get(tag);
            if (callback_kv == null) {
                std.debug.warn("False tag: {}\n", .{tag});
                continue;
            }
            callback_kv.?.value(&deserializer, id, &msg_id);
        }
    }

    fn start_thread(self: *Router) !void {
        try p2p.thread_pool.add_thread(self, Router.router_processor);
    } 
};
