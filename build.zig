const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const lib = b.addSharedLibrary(.{
        .name = "zig-metrics",
        .root_source_file = b.path("src/metrics.zig"),
        .target = target,
        .optimize = optimize,
        .version = .{ .major = 0, .minor = 9, .patch = 0 },
    });

    const m = b.addModule("metrics", .{
        .root_source_file = b.path("src/metrics.zig"),
        .target = target,
        .optimize = optimize,
    });
    m.linkLibrary(lib);

    var main_tests = b.addTest(.{
        .name = "tests",
        .root_source_file = b.path("src/test.zig"),
        .target = target,
        .optimize = optimize,
    });
    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&main_tests.step);

    b.default_step.dependOn(test_step);

    b.installArtifact(lib);
}
