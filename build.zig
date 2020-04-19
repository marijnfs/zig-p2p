const std = @import("std");
const fmt = std.fmt;
const Builder = std.build.Builder;
const Package = @import("std").build.Pkg;

var allocator = std.heap.page_allocator;

fn build_exe(b: *Builder, name: []const u8) !*std.build.LibExeObjStep {
    const mode = b.standardReleaseOptions();
    const cflags = &[_][]const u8{
        "-std=c99",
        "-pedantic",
        "-Werror",
        "-Wall",
    };

    const exe = b.addExecutable(name, try fmt.allocPrint(allocator, "bin/{}.zig", .{name}));

    exe.addCSourceFile("ext/monocypher-2.0.5/src/monocypher.c", cflags);
    exe.addIncludeDir("ext/monocypher-2.0.5/src");
    exe.addLibPath("/usr/lib64");
    exe.addLibPath("/usr/lib64/gcc/x86_64-suse-linux/7");
    exe.linkSystemLibrary("zmq");

    exe.addPackagePath("chat", "src/chat/chat.zig");
    exe.addPackagePath("p2p", "src/p2p/p2p.zig");
    exe.linkLibC();
    exe.linkSystemLibrary("stdc++");

    exe.setBuildMode(mode);
    exe.install();

    const run_cmd = exe.run();
    run_cmd.step.dependOn(b.getInstallStep());

    exe.install();
    return exe;
}

pub fn build(b: *Builder) void {
    const exe_chat = build_exe(b, "relaychat");
    const exe_send_test = build_exe(b, "send_test");
    const exe_router_test = build_exe(b, "router_test");

}
