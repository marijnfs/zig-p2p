const std = @import("std");
const Builder = std.build.Builder;

fn build_exe(b: *Builder, name: [] const u8) *std.build.LibExeObjStep {
    const mode = b.standardReleaseOptions();
    const cflags = [_][]const u8{
        "-std=c99",
        "-pedantic",
        "-Werror",
        "-Wall",
    };

    const path = std.fmt.allocPrint(std.heap.direct_allocator, "src/{}.zig", name) catch unreachable;
    const exe = b.addExecutable(name, path);
    exe.setBuildMode(mode);
    exe.addCSourceFile("ext/monocypher-2.0.5/src/monocypher.c", cflags);
    exe.addIncludeDir("ext/monocypher-2.0.5/src");
    exe.addLibPath("/usr/lib64");    

    exe.linkSystemLibrary("zmq");

    exe.linkSystemLibrary("c");
    exe.linkSystemLibrary("c++");
    exe.install();
    return exe;
}

pub fn build(b: *Builder) void {


    const exe_pub = build_exe(b, "pub");
    const exe_sub = build_exe(b, "sub");

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
