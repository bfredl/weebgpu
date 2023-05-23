const std = @import("std");
const gpu = @import("gpu");
const util = @import("./util.zig");
const ioctlnr = util.ioctlnr;
const print = std.debug.print;

pub const GPUInterface = gpu.dawn.Interface;

pub const Setup = struct {
    instance: *gpu.Instance,
    adapter: *gpu.Adapter,
    device: *gpu.Device,
};

extern fn __errno_location() callconv(.C) *c_int;

const c = @import("./c.zig");

pub fn unpack(request: u32, arg: usize, dir: util.Dir, kind: u32, comptime Data: type) ?*const Data {
    if (request == ioctlnr(dir, kind, @sizeOf(Data))) {
        return @intToPtr(*const Data, arg);
    }
    return null;
}

fn display(value: anytype) !void {
    const ANY = "any";
    const info = @typeInfo(@TypeOf(value)).Struct;
    const writer = std.io.getStdErr().writer();
    try writer.writeAll("{");
    inline for (info.fields, 0..) |f, i| {
        if (i == 0) {
            try writer.writeAll(" .");
        } else {
            try writer.writeAll(", .");
        }
        try writer.writeAll(f.name);
        try writer.writeAll(" = ");
        try std.fmt.formatType(@field(value, f.name), ANY, .{}, writer, 2);
    }
    try writer.writeAll(" }");
}

fn display_if(request: u32, arg: usize, dir: util.Dir, kind: u32, comptime Data: type, titel: []const u8) ?*const Data {
    const d = unpack(request, arg, dir, kind, Data);
    if (d) |data| {
        print("{s}! ", .{titel});
        display(data.*) catch unreachable;
        print("\n", .{});
    }
    return d;
}

var tystnad: bool = true;

export fn ioctl(fd: c_int, request: u32, arg: usize) callconv(.C) c_int {
    // std.log.info("glass! {}", .{request});
    const result = @bitCast(isize, std.os.linux.ioctl(fd, request, arg));
    if (result < 0) {
        __errno_location().* = @intCast(c_int, -result);
        return -1;
    }

    if (tystnad) {
        return @intCast(c_int, result);
    }

    print("{} ", .{fd});
    if (display_if(request, arg, .WR, c.DRM_I915_GEM_MMAP_GTT, c.drm_i915_gem_mmap_offset, "mmap")) |data| {
        _ = data;
    } else if (display_if(request, arg, .WR, c.DRM_I915_GEM_CREATE, c.drm_i915_gem_create, "gem_create")) |data| {
        _ = data;
    } else if (display_if(request, arg, .WR, c.DRM_I915_GEM_CONTEXT_CREATE, c.drm_i915_gem_context_create_ext, "gem_context_create")) |data| {
        _ = data;
    } else if (display_if(request, arg, .WR, c.DRM_I915_GEM_CONTEXT_SETPARAM, c.drm_i915_gem_context_param, "gem_context_setparam")) |data| {
        _ = data;
    } else if (display_if(request, arg, .WR, c.DRM_I915_QUERY, c.drm_i915_query, "query")) |data| {
        _ = data;
    } else if (display_if(request, arg, .WR, c.DRM_I915_GETPARAM, c.drm_i915_getparam, "getparam")) |data| {
        _ = data;
    } else if (display_if(request, arg, .WR, c.DRM_I915_GEM_CONTEXT_GETPARAM, c.drm_i915_gem_context_param, "context_getparam")) |data| {
        _ = data;
    } else if (display_if(request, arg, .WR, c.DRM_I915_GEM_GET_APERTURE, c.drm_i915_gem_get_aperture, "aperture")) |data| {
        _ = data;
    } else if (display_if(request, arg, .R, c.DRM_I915_GEM_EXECBUFFER2, c.drm_i915_gem_execbuffer2, "exec time!!")) |data| {
        if ((data.flags & c.I915_EXEC_FENCE_ARRAY) != 0) {
            const fences = @intToPtr([*]const c.struct_drm_i915_gem_exec_fence, data.cliprects_ptr)[0..data.num_cliprects];
            for (fences) |b| {
                print("MAN KLIPPA: ", .{});
                display(b) catch unreachable;
                print("\n", .{});
            }
        }
        const bufs = @intToPtr([*]const drm_i915_gem_exec_object2, data.buffers_ptr)[0..data.buffer_count];
        for (bufs) |b| {
            print("BUF ", .{});
            display(b) catch unreachable;
            print("\n", .{});
        }
    } else if (display_if(request, arg, .WR, c.DRM_I915_GEM_WAIT, c.drm_i915_gem_wait, "gem_wait!")) |data| {
        _ = data;
    } else if (display_if(request, arg, .WR, 0xbf - 0x40, c.drm_syncobj_create, "syncobj!")) |data| {
        _ = data;
    } else if (display_if(request, arg, .WR, 0xc3 - 0x40, c.drm_syncobj_wait, "sync wait")) |data| {
        _ = data;
    } else if (display_if(request, arg, .WR, 0xc4 - 0x40, c.drm_syncobj_array, "sync reset")) |data| {
        _ = data;
    } else {
        print(". {}: {}\n", .{ request, util.parse_nr(request) });
    }
    return @intCast(c_int, result);
}

pub fn main() !void {
    std.log.info("ful {}!", .{c.DRM_IOCTL_I915_GEM_MMAP_GTT});
    const s = try setup();
    const dev = s.device;
    const elm = 128;
    const size = 4 * elm;

    print("\n[FOUND]\n\n", .{});

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    if (false) {
        const features = try dev.enumerateFeaturesOwned(allocator);
        defer allocator.free(features);
        for (features) |namm| {
            print("feat: {}\n", .{namm});
        }
    }

    print("buffer 1\n", .{});
    const buf = dev.createBuffer(&.{
        // .mapped_at_creation = true,
        .size = size,
        .usage = .{ .storage = true, .copy_src = true },
    });

    print("buffer 2\n", .{});

    const buf_read = dev.createBuffer(&.{
        // .mapped_at_creation = true,
        .size = size,
        .usage = .{ .copy_dst = true, .map_read = true },
    });

    print("layouten \n", .{});

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

    print("KOD:\n", .{});

    const kod = @embedFile("./shader.wgsl");
    const module = dev.createShaderModuleWGSL(null, kod);

    print("piplinje!!:\n", .{});

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

    print("kommando kodning:\n", .{});

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
    print("\nsubmitted!\n", .{});

    var status: ?gpu.Buffer.MapAsyncStatus = null;
    buf_read.mapAsync(.{ .read = true }, 0, size, &status, callback);
    var i: u32 = 0;
    const result = res: {
        while (true) : (i += 1) {
            dev.tick();
            if (status) |st| break :res st;
        }
    };
    print("\ntickade: {}\n", .{i});
    print("here is the result: {}!\n", .{result});
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
    std.debug.print("\nfound GLUGG backend on {s} adapter: {s}, {s}\n\n", .{
        // props.backend_type.name(),
        props.adapter_type.name(),
        props.name,
        props.driver_description,
    });

    tystnad = false;

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
const drm_i915_gem_exec_object2 = extern struct {
    handle: u32,
    relocation_count: u32,
    relocs_ptr: u64,
    alignment: u64,
    offset: u64,
    flags: u64,
    rsvd1: u64,
    rsvd2: u64,
};
