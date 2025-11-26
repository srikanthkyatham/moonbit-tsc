const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Build option to enable MoonBit FFI (dynamic linking)
    const enable_moonbit_ffi = b.option(bool, "moonbit-ffi", "Link MoonBit compiler library (dynamic)") orelse false;

    // Static library path (passed from CMake for static linking)
    const moonbit_static_lib = b.option(
        []const u8,
        "moonbit-static-lib",
        "Path to static MoonBit library (libmoonbit_tsc.a)",
    );

    // Main executable
    const exe = b.addExecutable(.{
        .name = "moonbit-tsc",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    // Add include path for FFI headers
    exe.addIncludePath(b.path("include"));
    exe.addIncludePath(b.path("../moonbit/ffi_lib"));

    // Link libc (required for FFI)
    exe.linkLibC();

    // Static linking of MoonBit library (preferred for single binary)
    if (moonbit_static_lib) |lib_path| {
        exe.addObjectFile(.{ .cwd_relative = lib_path });
    } else if (enable_moonbit_ffi) {
        // Fallback to dynamic linking if -Dmoonbit-ffi is specified
        // Add MoonBit library path
        exe.addLibraryPath(b.path("../moonbit/ffi_lib/lib"));

        // Link the MoonBit TypeScript compiler library
        exe.linkSystemLibrary("moonbit_tsc");

        // On macOS, we need to set the rpath
        exe.addRPath(.{ .cwd_relative = "../moonbit/ffi_lib/lib" });
    }

    b.installArtifact(exe);

    // Create run command
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the compiler");
    run_step.dependOn(&run_cmd.step);

    // Unit tests
    const unit_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    const run_unit_tests = b.addRunArtifact(unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_unit_tests.step);

    // Integration tests
    const integration_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/test_integration.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    const run_integration_tests = b.addRunArtifact(integration_tests);

    const integration_test_step = b.step("test-integration", "Run integration tests");
    integration_test_step.dependOn(&run_integration_tests.step);
}
