const std = @import("std");
const gpu = @import("gpu");

pub const GPUInterface = gpu.dawn.Interface;

pub const Setup = struct {
    instance: *gpu.Instance,
    adapter: *gpu.Adapter,
    device: *gpu.Device,
};

extern fn __errno_location() callconv(.C) *c_int;

export fn ioctl(fd: c_int, request: u32, arg: usize) callconv(.C) c_int {
    // std.log.info("glass!", .{});
    std.debug.print(".", .{});
    const result = @bitCast(isize, std.os.linux.ioctl(fd, request, arg));
    if (result < 0) {
        __errno_location().* = @intCast(c_int, -result);
        return -1;
    }
    return @intCast(c_int, result);
}

pub fn main() !void {
    const s = try setup();
    const dev = s.device;
    const elm = 128;
    const size = 4 * elm;

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    if (false) {
        const features = try dev.enumerateFeaturesOwned(allocator);
        defer allocator.free(features);
        for (features) |namm| {
            std.debug.print("feat: {}\n", .{namm});
        }
    }

    const buf = dev.createBuffer(&.{
        // .mapped_at_creation = true,
        .size = size,
        .usage = .{ .storage = true, .copy_src = true },
    });

    const buf_read = dev.createBuffer(&.{
        // .mapped_at_creation = true,
        .size = size,
        .usage = .{ .copy_dst = true, .map_read = true },
    });

    const layout = dev.createBindGroupLayout(&gpu.BindGroupLayout.Descriptor.init(.{
        .entries = &[_]gpu.BindGroupLayout.Entry{
            .{
                .binding = 0,
                .visibility = .{ .compute = true },
                .buffer = .{ .type = .storage },
            },
        },
    }));

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

    const kod = @embedFile("./shader.wgsl");
    const module = dev.createShaderModuleWGSL(null, kod);

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

    const commandEncoder = dev.createCommandEncoder(&.{});
    const passEncoder = commandEncoder.beginComputePass(&.{});
    passEncoder.setPipeline(pipeline);
    passEncoder.setBindGroup(0, bind_group, null);
    passEncoder.dispatchWorkgroups(2, 1, 1);
    passEncoder.end();

    commandEncoder.copyBufferToBuffer(buf, 0, buf_read, 0, size);
    const gpuCommands = commandEncoder.finish(&.{});
    var cmdbuf: [1]*gpu.CommandBuffer = .{gpuCommands};
    dev.getQueue().submit(&cmdbuf);
    std.debug.print("\nsubmitted!\n", .{});

    var status: ?gpu.Buffer.MapAsyncStatus = null;
    buf_read.mapAsync(.{ .read = true }, 0, size, &status, callback);
    var i: u32 = 0;
    const result = res: {
        while (true) : (i += 1) {
            dev.tick();
            if (status) |st| break :res st;
        }
    };
    std.debug.print("\ntickade: {}\n", .{i});
    std.debug.print("here is the result: {}!\n", .{result});
}

inline fn callback(ctx: *?gpu.Buffer.MapAsyncStatus, status: gpu.Buffer.MapAsyncStatus) void {
    ctx.* = status;
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
    std.debug.print("\nfound GLUGG backend on {s} adapter: {s}, {s}\n", .{
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
