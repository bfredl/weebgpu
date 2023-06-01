const std = @import("std");
const system_sdk = @import("libs/mach-glfw/system_sdk.zig");
const glfw = @import("libs/mach-glfw/build.zig");
const gpu_dawn = @import("libs/mach-gpu-dawn/sdk.zig").Sdk(.{
    //.glfw = glfw,
    .glfw_include_dir = "glfw/upstream/glfw/include",
    .system_sdk = system_sdk,
});
const gpu = @import("libs/mach-gpu/sdk.zig").Sdk(.{
    //.glfw = glfw,
    .gpu_dawn = gpu_dawn,
});

pub fn build(b: *std.Build) !void {
    const opt = b.standardOptimizeOption(.{});

    var exe = b.addExecutable(.{
        .name = "main",
        .root_source_file = .{ .path = "src/main.zig" },
        .optimize = opt,
    });
    exe.addModule("gpu", gpu.module(b));
    exe.addIncludePath("src/uapi");
    try gpu.link(b, exe, .{});
    b.installArtifact(exe);

    var vulkan = b.addExecutable(.{
        .name = "demo_vulkan",
        .root_source_file = .{ .path = "src/demo_vulkan.zig" },
        .optimize = opt,
    });
    vulkan.linkSystemLibrary("c");
    vulkan.linkSystemLibrary("vulkan");
    vulkan.addIncludePath("src/uapi");
    b.installArtifact(vulkan);

    var itrace = b.addExecutable(.{
        .name = "itrace",
        .root_source_file = .{ .path = "src/itrace.zig" },
        .optimize = opt,
    });
    itrace.linkSystemLibrary("c"); // only includes??
    itrace.addIncludePath("src/uapi");
    b.installArtifact(itrace);
}
