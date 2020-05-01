const std = @import("std");
const p2p = @import("p2p");
const default_allocator = p2p.default_allocator;

const time = std.time;

const Alarm = struct {
	duration: u64,
	t: u64,
	callback: fn () void,
;

const Timer = struct {
	alarms: std.ArrayList(Alarm),

	fn init() Timer {
		return .{
			alarms = std.ArrayList(Alarm).init(default_allocator),
		}
	}

	fn deinit(self: *Timer) void {
		alarm.deinit();
	}

	fn add_timer(self: *Timer, duration: u64, callback: fn () void) {
		self.alarms.append(Alarm{.duration = duration, .t = time.timestamp() + duration, .callback = callback});
	}

	fn process_timer(self: *Timer) void {
		while (true) {

		}
	}

	fn start_process_timer(self: *Timer) !void {
		try p2p.thread_pool.add_thread(self, Timer.process_timer);
	}
};
