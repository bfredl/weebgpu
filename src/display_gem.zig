const std = @import("std");
const util = @import("./util.zig");
const ioctlnr = util.ioctlnr;
const print = std.debug.print;

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

pub var tystnad: bool = true;

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
        print("it is time to muck about!\n", .{});
        // a_ = std.os.linux.kill(0, 5); // SIGTRAP for debugger
        if ((data.flags & c.I915_EXEC_FENCE_ARRAY) != 0) {
            const fences = @intToPtr([*]const c.struct_drm_i915_gem_exec_fence, data.cliprects_ptr)[0..data.num_cliprects];
            for (fences) |b| {
                print("MAN KLIPPA: ", .{});
                display(b) catch unreachable;
                print("\n", .{});
            }
        }
        const bufs = @intToPtr([*]const util.drm_i915_gem_exec_object2, data.buffers_ptr)[0..data.buffer_count];
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
