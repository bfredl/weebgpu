const std = @import("std");
const fs = std.fs;
const linux = std.os.linux;
const info = std.log.info;
const util = @import("./util.zig");
const ioctlnr = util.ioctlnr;
const mem = std.mem;

const c = @import("./c.zig");

pub fn retry_ioctl(fd: linux.fd_t, request: u32, arg: usize) usize {
    while (true) {
        const status = linux.ioctl(fd, request, arg);
        const err = linux.getErrno(status);
        if (err != .INTR and err != .AGAIN) return status;
    }
}

pub fn intel_ioctl(fd: linux.fd_t, dir: util.Dir, num: u32, arg: anytype) usize {
    const typ = @typeInfo(@TypeOf(arg)).Pointer.child;
    const cmd = ioctlnr(dir, num, @sizeOf(typ));
    info("begå {s}: {}", .{ @typeName(typ), cmd });
    const status = retry_ioctl(fd, cmd, @ptrToInt(arg));
    const err = linux.getErrno(status);
    if (err != .SUCCESS) {
        // FIXME: What do we do if this fails?
        info("the cow jumped over the moon: {}", .{err});
    }
    return status;
}

pub fn main() !void {
    const fd = (try fs.cwd().openFileZ("/dev/dri/renderD128", .{ .mode = .read_write })).handle;
    info("the fd {}\n", .{fd});

    var create = mem.zeroes(c.drm_i915_gem_context_create);
    const cret = intel_ioctl(fd, .WR, c.DRM_I915_GEM_CONTEXT_CREATE, &create);
    if (cret != 0) {
        return;
    }

    const context_id = create.ctx_id;
    info("fin kontext: {}", .{context_id});

    const size = 4 * 4096;

    var gem_create = mem.zeroInit(c.drm_i915_gem_create, .{
        .size = size,
    });

    var ret = intel_ioctl(fd, .WR, c.DRM_I915_GEM_CREATE, &gem_create);
    if (ret != 0) {
        return;
    }

    info("fin handel: {}", .{gem_create.handle});
    const gem_handle = gem_create.handle;

    var gem_mmap = mem.zeroInit(c.drm_i915_gem_mmap_offset, .{
        .handle = gem_handle,
        .flags = c.I915_MMAP_OFFSET_WB,
    });
    info("fina: {}", .{c.DRM_I915_GEM_MMAP_GTT});
    ret = intel_ioctl(fd, .WR, c.DRM_I915_GEM_MMAP_GTT, &gem_mmap);
    if (ret != 0) {
        return;
    }

    info("ofsetten: {}", .{gem_mmap});

    const ptr = linux.mmap(null, size, linux.PROT.WRITE | linux.PROT.READ, linux.MAP.SHARED, fd, @intCast(i64, gem_mmap.offset));

    info("pekaren: {}", .{ptr});
}
