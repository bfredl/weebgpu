pub const Dir = enum(u32) {
    R = 1,
    W = 2,
    WR = 3,
};

pub fn ioctlnr(dir: Dir, num: u32, size: u32) u32 {
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
