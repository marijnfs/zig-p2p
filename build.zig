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

    const exe = b.addExecutable(name, try fmt.allocPrint(allocator, "src/{}.zig", .{name}));

    exe.addCSourceFile("ext/monocypher-2.0.5/src/monocypher.c", cflags);
    exe.addIncludeDir("ext/monocypher-2.0.5/src");
    exe.addLibPath("/usr/lib64");

    exe.linkSystemLibrary("zmq");

    exe.linkLibC();
    exe.linkSystemLibrary("c++");

    exe.setBuildMode(mode);
    exe.install();

    const run_cmd = exe.run();
    run_cmd.step.dependOn(b.getInstallStep());

    exe.linkSystemLibrary("stdc++");
    exe.install();
    return exe;
}

pub fn build(b: *Builder) void {
    const exe_pub = build_exe(b, "pub");
    const exe_sub = build_exe(b, "sub");
    const exe_main = build_exe(b, "main");

    // const exe2 = b.addExecutable("sub", "src/sub.zig");
    // exe2.setBuildMode(mode);
    // exe2.addLibPath("/usr/lib64");
    // exe2.linkSystemLibrary("zmq");
    // exe2.install();

    // const run_cmd = exe.run();
    // run_cmd.step.dependOn(b.getInstallStep());

    // const run_step = b.step("run", "Run the app");
    // run_step.dependOn(&run_cmd.step);
}
