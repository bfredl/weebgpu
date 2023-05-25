const std = @import("std");
const v = @import("./c_vulkan.zig");
const print = std.debug.print;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    const s = try setup(allocator);
    _ = s;
}

pub const Setup = struct {};

pub fn setup(allocator: std.mem.Allocator) !Setup {
    if (false) {
        var extensionCount: u32 = 0;
        _ = v.vkEnumerateInstanceExtensionProperties(null, &extensionCount, null);
        const exts = try allocator.alloc(v.VkExtensionProperties, extensionCount);
        _ = v.vkEnumerateInstanceExtensionProperties(null, &extensionCount, exts.ptr);
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
    const result = v.vkCreateInstance(&info, null, &instance);
    if (result != v.VK_SUCCESS) {
        print("fooka: {}\n", .{result});
        return error.VulkanError;
    }
    var deviceCount: u32 = 0;
    _ = v.vkEnumeratePhysicalDevices(instance, &deviceCount, null);
    const devs = try allocator.alloc(v.VkPhysicalDevice, deviceCount);
    _ = v.vkEnumeratePhysicalDevices(instance, &deviceCount, devs.ptr);

    print("device: {}\n", .{deviceCount});
    if (deviceCount == 0) return error.VulkanError;
    const dev = devs[0];

    var deviceProperties: v.VkPhysicalDeviceProperties = undefined;
    v.vkGetPhysicalDeviceProperties(dev, &deviceProperties);
    // print("propert: {}\n", .{deviceProperties});
    print("namm: {s}\n", .{deviceProperties.deviceName});

    var deviceFeatures: v.VkPhysicalDeviceFeatures = undefined;
    v.vkGetPhysicalDeviceFeatures(dev, &deviceFeatures);
    print("feat: {}\n", .{deviceFeatures});

    return .{};
}
