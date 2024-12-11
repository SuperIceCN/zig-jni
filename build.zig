const std = @import("std");

pub fn build(b: *std.Build) void {
    // module exports
    const module = b.addModule("JNI", .{ .root_source_file = .{ .src_path = .{
        .owner = b,
        .sub_path = "src/main/zig/lib.zig",
    } } });
    module.addIncludePath(.{ .src_path = .{
        .owner = b,
        .sub_path = "src/include/jni",
    } });
    module.link_libc = true;
    // build options
    const optimize = b.standardOptimizeOption(.{});
    const target = b.standardTargetOptions(.{});
    const lib = b.addStaticLibrary(.{
        .name = "zig-jni",
        .version = .{ .major = 0, .minor = 0, .patch = 1 },
        .root_source_file = b.path("src/main/zig/lib.zig"),
        .target = target,
        .optimize = optimize,
    });
    const cjni = b.addTranslateC(.{
        .root_source_file = b.path("src/include/jni/jni.h"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    lib.root_module.addImport("cjni", cjni.createModule());

    lib.addIncludePath(.{ .src_path = .{
        .owner = b,
        .sub_path = "src/include/jni",
    } });
    b.installArtifact(lib);
}
