const std = @import("std");
const v = @import("./c_vulkan.zig");
const print = std.debug.print;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    const s = try setup(allocator);

    const bufferInfo: v.VkBufferCreateInfo = .{
        .sType = v.VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO,
        .usage = v.VK_BUFFER_USAGE_STORAGE_BUFFER_BIT,
        .size = 4096,
        .sharingMode = v.VK_SHARING_MODE_EXCLUSIVE,
        .pNext = null,
        .flags = 0,
        .queueFamilyIndexCount = 0,
        .pQueueFamilyIndices = null,
    };

    var buf: v.VkBuffer = undefined;
    try verify(v.vkCreateBuffer(s.dev, &bufferInfo, null, &buf));

    var memRequirements: v.VkMemoryRequirements = undefined;
    v.vkGetBufferMemoryRequirements(s.dev, buf, &memRequirements);
    print("mem: {}\n", .{memRequirements});

    if ((memRequirements.memoryTypeBits & 1) == 0) return error.NowYouDoneIt;

    var bufmem: v.VkDeviceMemory = undefined;
    const allocInfo: v.VkMemoryAllocateInfo = .{
        .sType = v.VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO,
        .allocationSize = memRequirements.size,
        .memoryTypeIndex = 0,
        .pNext = null,
    };
    try verify(v.vkAllocateMemory(s.dev, &allocInfo, null, &bufmem));
    try verify(v.vkBindBufferMemory(s.dev, buf, bufmem, 0));
}

pub const Setup = struct {
    instance: v.VkInstance,
    dev: v.VkDevice,
    queue: v.VkQueue,
};

pub fn setup(a: std.mem.Allocator) !Setup {
    if (false) {
        const exts = try venum(null, v.vkEnumerateInstanceExtensionProperties, v.VkExtensionProperties, a);
        for (exts) |e| {
            print("ITYM: {s}\n", .{e.extensionName});
        }
    }

    const info = v.VkInstanceCreateInfo{
        .sType = v.VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO,
        .pApplicationInfo = null,
        .enabledExtensionCount = 0,
        .ppEnabledExtensionNames = null,
        .enabledLayerCount = 0,
        .ppEnabledLayerNames = null,
        .pNext = null,
        .flags = 0,
    };

    var instance: v.VkInstance = undefined;
    try verify(v.vkCreateInstance(&info, null, &instance));
    const devs = try venum(instance, v.vkEnumeratePhysicalDevices, v.VkPhysicalDevice, a);

    if (devs.len != 1) {
        print("fooka. select the device\n", .{});
        return error.Fooka;
    }
    const phys_dev = devs[0];

    var deviceProperties: v.VkPhysicalDeviceProperties = undefined;
    v.vkGetPhysicalDeviceProperties(phys_dev, &deviceProperties);
    // print("propert: {}\n", .{deviceProperties});
    print("namm: {s}\n", .{deviceProperties.deviceName});

    var deviceFeatures: v.VkPhysicalDeviceFeatures = undefined;
    v.vkGetPhysicalDeviceFeatures(phys_dev, &deviceFeatures);
    // print("feat: {}\n", .{deviceFeatures});

    const queue_fams = try venum(phys_dev, v.vkGetPhysicalDeviceQueueFamilyProperties, v.VkQueueFamilyProperties, a);
    if (queue_fams.len != 1) {
        print("fooka. select the right queue\n", .{});
        return error.Fooka;
    }

    const queuePriority: f32 = 1.0;
    const queueCreateInfo: v.VkDeviceQueueCreateInfo = .{
        .sType = v.VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO,
        .queueFamilyIndex = 0,
        .queueCount = 1,
        .pNext = null,
        .flags = 0,
        .pQueuePriorities = &queuePriority,
    };

    const enabledFeatures = std.mem.zeroInit(v.VkPhysicalDeviceFeatures, .{});

    const createInfo: v.VkDeviceCreateInfo = .{
        .sType = v.VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO,
        .queueCreateInfoCount = 1,
        .pQueueCreateInfos = &queueCreateInfo,
        .pNext = null,
        .flags = 0,
        .ppEnabledLayerNames = null,
        .enabledLayerCount = 0,
        .ppEnabledExtensionNames = null,
        .enabledExtensionCount = 0,
        .pEnabledFeatures = &enabledFeatures,
    };
    var dev: v.VkDevice = undefined;
    try verify(v.vkCreateDevice(phys_dev, &createInfo, null, &dev));

    var queue: v.VkQueue = undefined;
    try verify(v.vkGetDeviceQueue(dev, 0, 0, &queue));

    if (false) {
        var memProperties: v.VkPhysicalDeviceMemoryProperties = undefined;
        v.vkGetPhysicalDeviceMemoryProperties(phys_dev, &memProperties);
        print("mems: {}, heaps: {}\n", .{ memProperties.memoryTypeCount, memProperties.memoryHeapCount });
    }

    return .{
        .instance = instance,
        .dev = dev,
        .queue = queue,
    };
}

pub fn verify(sak: anytype) !void {
    if (@TypeOf(sak) == void) {
        return;
    }
    if (sak != v.VK_SUCCESS) {
        print("fooka: {}\n", .{sak});
        return error.VulkanError;
    }
}

pub fn venum(self: anytype, comptime meth: anytype, comptime Kind: type, allocator: std.mem.Allocator) ![]Kind {
    var count: u32 = 0;
    try verify(meth(self, &count, null));
    const arr = try allocator.alloc(Kind, count);
    try verify(meth(self, &count, arr.ptr));
    return arr;
}
