const std = @import("std");
const fs = std.fs;
const linux = std.os.linux;
const info = std.log.info;
const util = @import("./util.zig");
const ioctlnr = util.ioctlnr;
const mem = std.mem;
const print = std.debug.print;
const fd_t = linux.fd_t;

const c = @import("./c.zig");

pub fn retry_ioctl(fd: fd_t, request: u32, arg: usize) usize {
    while (true) {
        const status = linux.ioctl(fd, request, arg);
        const err = linux.getErrno(status);
        if (err != .INTR and err != .AGAIN) return status;
    }
}

pub fn intel_ioctl(fd: fd_t, dir: util.Dir, num: u32, arg: anytype) !usize {
    const typ = @typeInfo(@TypeOf(arg)).Pointer.child;
    const cmdnr = ioctlnr(dir, num, @sizeOf(typ));
    info("begå {s}: {}", .{ @typeName(typ), cmdnr });
    const status = retry_ioctl(fd, cmdnr, @ptrToInt(arg));
    const err = linux.getErrno(status);
    if (err != .SUCCESS) {
        // FIXME: What do we do if this fails?
        info("the cow jumped over the moon: {}", .{err});
        return error.IntelError;
    }
    return status;
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    const fd = (try fs.cwd().openFileZ("/dev/dri/renderD128", .{ .mode = .read_write })).handle;
    info("the fd {}\n", .{fd});

    var create = mem.zeroes(c.drm_i915_gem_context_create);
    _ = try intel_ioctl(fd, .WR, c.DRM_I915_GEM_CONTEXT_CREATE, &create);

    const context_id = create.ctx_id;
    info("fin kontext: {}", .{context_id});

    const size = 4 * 4096;

    const gem_handle = try gem_create(fd, size);

    const ptr = try gem_mmap(fd, size, gem_handle);
    info("pekaren: {}", .{ptr});

    var batch = CmdBatch.init(allocator);
    try batch.append(cmd.pipeline_select(2));
    for (batch.items) |i| {
        print("0x{x:08}\n", .{i});
    }
    defer batch.deinit();
}

fn gem_create(fd: fd_t, size: usize) !u32 {
    var drm_gem_create = mem.zeroInit(c.drm_i915_gem_create, .{
        .size = size,
    });

    _ = try intel_ioctl(fd, .WR, c.DRM_I915_GEM_CREATE, &drm_gem_create);

    return drm_gem_create.handle;
}

fn gem_mmap(fd: fd_t, size: usize, handle: u32) !usize {
    var gem_mmap_param = mem.zeroInit(c.drm_i915_gem_mmap_offset, .{
        .handle = handle,
        .flags = c.I915_MMAP_OFFSET_WB,
    });
    _ = try intel_ioctl(fd, .WR, c.DRM_I915_GEM_MMAP_GTT, &gem_mmap_param);

    return linux.mmap(null, size, linux.PROT.WRITE | linux.PROT.READ, linux.MAP.SHARED, fd, @intCast(i64, gem_mmap_param.offset));
}

const CmdBatch = std.ArrayList(u32);
const cmd = struct {
    pub fn pipeline_select(pipeline: u2) u32 {
        const base: u32 = ((0x3 << 29) | (0x1 << 27) | (0x1 << 24) | (0x4 << 16) | (0x3 << 8));
        return base + pipeline;
    }
};
