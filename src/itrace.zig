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

    const obj = try gem_mmap(fd, size, gem_handle);
    info("objektet: {}", .{obj});

    var batch = CmdBatch.init(allocator);
    try batch.append(cmd.pipeline_select(2));
    for (batch.items) |i| {
        print("0x{x:08}\n", .{i});
    }
    defer batch.deinit();

    try execute_batch_simple(fd, context_id, obj, batch.items);
}

// ptr must be a mapping of gem_handle
pub fn execute_batch_simple(fd: fd_t, context_id: u32, obj: GemObj, batch: []u32) !void {
    // TODO assert size!
    @memcpy(@intToPtr([*]u32, obj.ptr)[0..batch.len], batch);
    // TODO: clflush each cacheline?
    @fence(.Release);

    var object: util.drm_i915_gem_exec_object2 = .{
        .handle = obj.handle,
        .relocation_count = 0,
        .relocs_ptr = 0,
        .alignment = 0,
        .offset = 0xFFFFFFFFFFFFFFFF,
        .flags = 0,
        .rsvd1 = 0,
        .rsvd2 = 0,
    };

    var execbuf: c.drm_i915_gem_execbuffer2 = .{
        .buffers_ptr = @ptrToInt(&object),
        .buffer_count = 1,
        .batch_start_offset = 0,
        .batch_len = @intCast(c_uint, 4 * batch.len),
        .flags = c.I915_EXEC_HANDLE_LUT | c.I915_EXEC_NO_RELOC, // TODO: mere
        .rsvd1 = context_id,
        .rsvd2 = 0,
        .DR1 = 0,
        .DR4 = 0,
        .num_cliprects = 0,
        .cliprects_ptr = 0,
    };

    _ = try intel_ioctl(fd, .WR, c.DRM_I915_GEM_EXECBUFFER2, &execbuf);
}

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

fn gem_create(fd: fd_t, size: usize) !u32 {
    var drm_gem_create = mem.zeroInit(c.drm_i915_gem_create, .{
        .size = size,
    });

    _ = try intel_ioctl(fd, .WR, c.DRM_I915_GEM_CREATE, &drm_gem_create);

    return drm_gem_create.handle;
}

const GemObj = struct {
    handle: u32,
    size: usize,
    offset: usize,
    ptr: usize,
};

fn gem_mmap(fd: fd_t, size: usize, handle: u32) !GemObj {
    var gem_mmap_param = mem.zeroInit(c.drm_i915_gem_mmap_offset, .{
        .handle = handle,
        .flags = c.I915_MMAP_OFFSET_WB,
    });
    _ = try intel_ioctl(fd, .WR, c.DRM_I915_GEM_MMAP_GTT, &gem_mmap_param);

    const ptr = linux.mmap(null, size, linux.PROT.WRITE | linux.PROT.READ, linux.MAP.SHARED, fd, @intCast(i64, gem_mmap_param.offset));
    return .{
        .handle = handle,
        .size = size,
        .offset = gem_mmap_param.offset,
        .ptr = ptr,
    };
}

const CmdBatch = std.ArrayList(u32);
const cmd = struct {
    pub fn pipeline_select(pipeline: u2) u32 {
        const base: u32 = ((0x3 << 29) | (0x1 << 27) | (0x1 << 24) | (0x4 << 16) | (0x3 << 8));
        return base + pipeline;
    }
};
