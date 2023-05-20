const std = @import("std");
const fs = std.fs;
const linux = std.os.linux;
const info = std.log.info;

pub fn retry_ioctl(fd: linux.fd_t, request: u32, arg: usize) usize {
    while (true) {
        const status = linux.ioctl(fd, request, arg);
        const err = linux.getErrno(status);
        if (err != .INTR and err != .AGAIN) return status;
    }
}

pub fn intel_ioctl(fd: linux.fd_t, dir: Dir, num: u32, arg: anytype) usize {
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

    var create: drm_i915_gem_context_create = .{};
    const cret = intel_ioctl(fd, .WR, DRM_I915_GEM_CONTEXT_CREATE, &create);
    if (cret != 0) {
        return;
    }

    const context_id = create.ctx_id;
    info("fin kontext: {}", .{context_id});

    const size = 4 * 4096;

    var gem_create: drm_i915_gem_create = .{
        .size = size,
    };

    var ret = intel_ioctl(fd, .WR, DRM_I915_GEM_CREATE, &gem_create);
    if (ret != 0) {
        return;
    }

    info("fin handel: {}", .{gem_create.handle});
    const gem_handle = gem_create.handle;

    var gem_mmap: drm_i915_gem_mmap_offset = .{
        .handle = gem_handle,
        .flags = I915_MMAP_OFFSET_WB,
    };
    ret = intel_ioctl(fd, .WR, DRM_I915_GEM_MMAP_GTT, &gem_mmap);
    if (ret != 0) {
        return;
    }

    info("ofsetten: {}", .{gem_mmap});

    const ptr = linux.mmap(null, size, linux.PROT.WRITE | linux.PROT.READ, linux.MAP.SHARED, fd, @intCast(i64, gem_mmap.offset));

    info("pekaren: {}", .{ptr});
}

const drm_i915_gem_create = extern struct {
    size: u64,
    handle: u32 = undefined,
    pad: u32 = undefined,
};

const drm_i915_gem_context_create = extern struct {
    ctx_id: u32 = undefined,
    pad: u32 = undefined,
};

const drm_i915_gem_mmap_offset = extern struct {
    handle: u32,
    pad: u32 = 0,
    offset: u64 = undefined,
    flags: u64,
    extensions: u64 = 0,
};

const Dir = enum(u32) {
    R = 1,
    W = 2,
    WR = 3,
};

fn ioctlnr(dir: Dir, num: u32, size: u32) u32 {
    const _IOC_NRBITS = 8;
    const _IOC_TYPEBITS = 8;
    const _IOC_SIZEBITS = 14;

    const _IOC_NRSHIFT = 0;
    const _IOC_TYPESHIFT = (_IOC_NRSHIFT + _IOC_NRBITS);
    const _IOC_SIZESHIFT = (_IOC_TYPESHIFT + _IOC_TYPEBITS);
    const _IOC_DIRSHIFT = (_IOC_SIZESHIFT + _IOC_SIZEBITS);
    return ((@enumToInt(dir) << _IOC_DIRSHIFT) |
        (('d') << _IOC_TYPESHIFT) |
        ((num + 0x40) << _IOC_NRSHIFT) |
        ((size) << _IOC_SIZESHIFT));
}

const DRM_I915_GEM_INIT = 0x13;
const DRM_I915_GEM_EXECBUFFER = 0x14;
const DRM_I915_GEM_PIN = 0x15;
const DRM_I915_GEM_UNPIN = 0x16;
const DRM_I915_GEM_BUSY = 0x17;
const DRM_I915_GEM_THROTTLE = 0x18;
const DRM_I915_GEM_ENTERVT = 0x19;
const DRM_I915_GEM_LEAVEVT = 0x1a;
const DRM_I915_GEM_CREATE = 0x1b;
const DRM_I915_GEM_PREAD = 0x1c;
const DRM_I915_GEM_PWRITE = 0x1d;
const DRM_I915_GEM_MMAP = 0x1e;
const DRM_I915_GEM_SET_DOMAIN = 0x1f;
const DRM_I915_GEM_SW_FINISH = 0x20;
const DRM_I915_GEM_SET_TILING = 0x21;
const DRM_I915_GEM_GET_TILING = 0x22;
const DRM_I915_GEM_GET_APERTURE = 0x23;
const DRM_I915_GEM_MMAP_GTT = 0x24;
const DRM_I915_GEM_CONTEXT_CREATE = 0x2d;

const I915_MMAP_OFFSET_WC = 1;
const I915_MMAP_OFFSET_WB = 2;
const I915_MMAP_OFFSET_UC = 3;
const I915_MMAP_OFFSET_FIXED = 4;
