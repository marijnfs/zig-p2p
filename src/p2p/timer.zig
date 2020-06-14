const std = @import("std");
const p2p = @import("p2p.zig");
const default_allocator = p2p.default_allocator;

const time = std.time;

const Alarm = struct {
    duration: i64, t: i64, callback: fn () void
};

pub const Timer = struct {
    alarms: std.ArrayList(Alarm),
    mutex: std.Mutex,

    pub fn init() Timer {
        return .{
            .alarms = std.ArrayList(Alarm).init(default_allocator),
            .mutex = std.Mutex.init(),
        };
    }

    pub fn deinit(self: *Timer) void {
        alarm.deinit();
    }

    pub fn add_timer(self: *Timer, duration: i64, callback: fn () void) !void {
        const lock = self.mutex.acquire();
        defer lock.release();
    //        try self.alarms.append(Alarm{ .duration = duration, .t = time.timestamp() + duration, .callback = callback });
    }

    fn process_timer(self: *Timer) void {
        var current = time.milliTimestamp();
        for (self.alarms.span()) |*alarm| {
//            alarm.t = current + alarm.duration;
        }

        while (true) {
            current = time.milliTimestamp();
            const lock = self.mutex.acquire();
            defer lock.release();

            for (self.alarms.span()) |*alarm| {
                if (alarm.t < current) {
                    alarm.callback();
                    current = time.milliTimestamp();
//                    alarm.t = current + alarm.duration;
                }
            }
            std.time.sleep(10000000);
        }
    }

    pub fn start(self: *Timer) !void {
        _ = try p2p.thread_pool.add_thread(self, Timer.process_timer);
    }
};
