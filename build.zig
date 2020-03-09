const std = @import("std");
const fmt = std.fmt;
const Builder = std.build.Builder;
var allocator = std.heap.direct_allocator;

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
    exe.addPackagePath("p2p", "src/p2p.zig");
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
    const exe_main = build_exe(b, "main");
    const exe_test = build_exe(b, "test");
    const exe_sender = build_exe(b, "sender");
}
