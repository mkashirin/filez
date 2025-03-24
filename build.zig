const std = @import("std");
const builtin = std.builtin;
const Build = std.Build;

pub fn build(b: *Build) void {
    const linux = b.resolveTargetQuery(.{
        .cpu_arch = .x86_64,
        .os_tag = .linux,
    });
    const windows = b.resolveTargetQuery(.{
        .cpu_arch = .x86_64,
        .os_tag = .windows,
    });
    const optimize = b.standardOptimizeOption(.{});
    const linux_options: BuildOptions = .{
        .target = linux,
        .optimize = optimize,
        .run_step = "run-linux",
        .test_step = "test-linux",
    };
    const windows_options: BuildOptions = .{
        .target = windows,
        .optimize = optimize,
        .run_step = "run-windows",
        .test_step = "test-windows",
    };

    inline for (.{ linux_options, windows_options }) |options| {
        build_target(b, options);
    }
}

const BuildOptions = struct {
    target: Build.ResolvedTarget,
    optimize: builtin.OptimizeMode,
    run_step: []const u8,
    test_step: []const u8,
};

fn build_target(b: *Build, options: BuildOptions) void {
    const exe = b.addExecutable(.{
        .name = "filez",
        .root_source_file = b.path("src/main.zig"),
        .target = options.target,
        .optimize = options.optimize,
    });
    b.installArtifact(exe);
    const run_cmd = b.addRunArtifact(exe);

    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
    const run_step = b.step(options.run_step, "Run the app");
    run_step.dependOn(&run_cmd.step);

    const unit_tests = b.addTest(.{
        .root_source_file = b.path("src/main.zig"),
        .target = options.target,
        .optimize = options.optimize,
    });
    const run_unit_tests = b.addRunArtifact(unit_tests);
    const test_step = b.step(options.test_step, "Run unit tests");
    test_step.dependOn(&run_unit_tests.step);
}
