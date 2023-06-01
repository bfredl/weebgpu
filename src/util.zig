pub const Dir = enum(u32) {
    R = 1,
    W = 2,
    WR = 3,
};

const _IOC_NRBITS = 8;
const _IOC_TYPEBITS = 8;
const _IOC_SIZEBITS = 14;

const _IOC_NRSHIFT = 0;
const _IOC_TYPESHIFT = (_IOC_NRSHIFT + _IOC_NRBITS);
const _IOC_SIZESHIFT = (_IOC_TYPESHIFT + _IOC_TYPEBITS);
const _IOC_DIRSHIFT = (_IOC_SIZESHIFT + _IOC_SIZEBITS);

pub fn ioctlnr(dir: Dir, num: u32, size: u32) u32 {
    return ((@enumToInt(dir) << _IOC_DIRSHIFT) |
        (('d') << _IOC_TYPESHIFT) |
        ((num + 0x40) << _IOC_NRSHIFT) |
        ((size) << _IOC_SIZESHIFT));
}

pub fn parse_nr(request: u32) struct { nr: u32, size: u32, dir: u32 } {
    const nr = request & ((1 << _IOC_NRBITS) - 1);
    const size = (request >> _IOC_SIZESHIFT) & ((1 << _IOC_SIZEBITS) - 1);
    const dirval = (request >> _IOC_DIRSHIFT) & ((1 << 2) - 1);
    return .{ .nr = nr - 0x40, .size = size, .dir = dirval };
}

pub const drm_i915_gem_exec_object2 = extern struct {
    handle: u32,
    relocation_count: u32,
    relocs_ptr: u64,
    alignment: u64,
    offset: u64,
    flags: u64,
    rsvd1: u64,
    rsvd2: u64,
};
