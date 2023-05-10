const std = @import("std");
const gpu = @import("gpu");

pub const GPUInterface = gpu.dawn.Interface;

pub const Setup = struct {
    instance: *gpu.Instance,
    adapter: *gpu.Adapter,
    device: *gpu.Device,
};

pub fn main() !void {
    const s = try setup();
    const dev = s.device;
    const size = 512;

    const buf = dev.createBuffer(&.{
        // .mapped_at_creation = true,
        .size = size,
        .usage = .{ .storage = true },
    });

    std.debug.print("fin buffer {}!\n", .{buf});

    const layout = dev.createBindGroupLayout(&gpu.BindGroupLayout.Descriptor.init(.{
        .entries = &[_]gpu.BindGroupLayout.Entry{
            .{
                .binding = 0,
                .visibility = .{ .compute = true },
                .buffer = .{ .type = .storage },
            },
        },
    }));

    std.debug.print("fin layout {}!\n", .{layout});

    const bind_group = dev.createBindGroup(&gpu.BindGroup.Descriptor.init(.{
        .layout = layout,
        .entries = &[_]gpu.BindGroup.Entry{
            .{
                .binding = 0,
                .buffer = buf,
                .size = size,
            },
        },
    }));

    std.debug.print("fin grupp {}!\n", .{bind_group});

    const kod = @embedFile("./shader.wgsl");
    const module = dev.createShaderModule(&.{ .next_in_chain = .{ .wgsl_descriptor = &.{ .source = kod } } });

    std.debug.print("fin shader {}!\n", .{module});

    const pipeline_layout = dev.createPipelineLayout(&gpu.PipelineLayout.Descriptor.init(.{
        .bind_group_layouts = &[_]*gpu.BindGroupLayout{layout},
    }));

    const pipeline = dev.createComputePipeline(&.{
        .layout = pipeline_layout,
        .compute = .{
            .module = module,
            .entry_point = "main",
        },
    });

    std.debug.print("fin pipeline {}!\n", .{pipeline});

    const commandEncoder = dev.createCommandEncoder(&.{});
    const passEncoder = commandEncoder.beginComputePass(&.{});
    passEncoder.setPipeline(pipeline);
    passEncoder.setBindGroup(0, bind_group, null);
    passEncoder.dispatchWorkgroups(2, 1, 1);
    passEncoder.end();

    std.debug.print("iin passkodare {}!\n", .{passEncoder});

    const gpuCommands = commandEncoder.finish(&.{});
    dev.getQueue().submit(&[_]*gpu.CommandBuffer{gpuCommands});
    std.debug.print("dunit!\n", .{});
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
