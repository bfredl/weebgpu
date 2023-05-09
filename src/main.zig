const std = @import("std");
const gpu = @import("gpu");

pub const GPUInterface = gpu.dawn.Interface;

pub const Setup = struct {
    instance: *gpu.Instance,
    adapter: *gpu.Adapter,
    device: *gpu.Device,
};

pub fn main() !void {
    std.debug.print("gungen!\n", .{});
    const s = try setup();
    const size = 512;

    const buf = s.device.createBuffer(&.{
        .mapped_at_creation = true,
        .size = size,
        .usage = .{ .storage = true },
    });

    std.debug.print("fin buffer {}!\n", .{buf});
}

inline fn printUnhandledErrorCallback(_: void, typ: gpu.ErrorType, message: [*:0]const u8) void {
    switch (typ) {
        .validation => std.debug.print("gpu: validation error: {s}\n", .{message}),
        .out_of_memory => std.debug.print("gpu: out of memory: {s}\n", .{message}),
        .device_lost => std.debug.print("gpu: device lost: {s}\n", .{message}),
        .unknown => std.debug.print("gpu: unknown error: {s}\n", .{message}),
        else => unreachable,
    }
    std.process.exit(1);
}

const RequestAdapterResponse = struct {
    status: gpu.RequestAdapterStatus,
    adapter: *gpu.Adapter,
    message: ?[*:0]const u8,
};

inline fn requestAdapterCallback(
    context: *?RequestAdapterResponse,
    status: gpu.RequestAdapterStatus,
    adapter: *gpu.Adapter,
    message: ?[*:0]const u8,
) void {
    context.* = RequestAdapterResponse{
        .status = status,
        .adapter = adapter,
        .message = message,
    };
}

pub fn setup() !Setup {
    gpu.Impl.init();

    const instance = gpu.createInstance(null);
    if (instance == null) {
        std.debug.print("failed to create GPU instance\n", .{});
        std.process.exit(1);
    }

    var response: ?RequestAdapterResponse = null;
    instance.?.requestAdapter(&gpu.RequestAdapterOptions{
        // .compatible_surface = surface,
        .power_preference = .undefined,
        .force_fallback_adapter = false,
    }, &response, requestAdapterCallback);
    if (response.?.status != .success) {
        std.debug.print("failed to create GPU adapter: {s}\n", .{response.?.message.?});
        std.process.exit(1);
    }

    // Print which adapter we are using.
    var props = std.mem.zeroes(gpu.Adapter.Properties);
    response.?.adapter.getProperties(&props);
    std.debug.print("found GLUGG backend on {s} adapter: {s}, {s}\n", .{
        // props.backend_type.name(),
        props.adapter_type.name(),
        props.name,
        props.driver_description,
    });

    // Create a device with default limits/features.
    const device = response.?.adapter.createDevice(null);
    if (device == null) {
        std.debug.print("failed to create GPU device\n", .{});
        std.process.exit(1);
    }

    device.?.setUncapturedErrorCallback({}, printUnhandledErrorCallback);
    return Setup{
        .instance = instance.?,
        .adapter = response.?.adapter,
        .device = device.?,
    };
}
