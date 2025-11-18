const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // MenuBar library module
    const menubar_mod = b.addModule("menubar", .{
        .root_source_file = b.path("src/menu_bar.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Example application
    const example = b.addExecutable(.{
        .name = "menubar-example",
        .root_source_file = b.path("examples/basic.zig"),
        .target = target,
        .optimize = optimize,
    });
    example.root_module.addImport("menubar", menubar_mod);

    // Link GTK3 for Linux
    example.linkSystemLibrary("gtk+-3.0");
    example.linkLibC();

    b.installArtifact(example);

    // Run command
    const run_cmd = b.addRunArtifact(example);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the example application");
    run_step.dependOn(&run_cmd.step);

    // Tests
    const lib_tests = b.addTest(.{
        .root_source_file = b.path("src/menu_bar.zig"),
        .target = target,
        .optimize = optimize,
    });

    const run_lib_tests = b.addRunArtifact(lib_tests);
    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&run_lib_tests.step);
}
