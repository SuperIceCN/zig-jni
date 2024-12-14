const std = @import("std");

pub fn build(b: *std.Build) void {
    // build options
    const optimize = b.standardOptimizeOption(.{});
    const target = b.standardTargetOptions(.{});

    // module exports
    const module = b.addModule("JNI", .{
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
    module.addImport("cjni", cjni.createModule());
}
