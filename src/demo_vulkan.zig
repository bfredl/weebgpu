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

pub fn venum(self: anytype, comptime meth: anytype, comptime Kind: type, allocator: std.mem.Allocator) ![]Kind {
    var count: u32 = 0;
    if (meth(self, &count, null) != v.VK_SUCCESS) return error.VulkanError;
    const arr = try allocator.alloc(Kind, count);
    if (meth(self, &count, arr.ptr) != v.VK_SUCCESS) return error.VulkanError;
    return arr;
}

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
    const result = v.vkCreateInstance(&info, null, &instance);
    if (result != v.VK_SUCCESS) {
        print("fooka: {}\n", .{result});
        return error.VulkanError;
    }
    const devs = try venum(instance, v.vkEnumeratePhysicalDevices, v.VkPhysicalDevice, a);

    print("device: {}\n", .{devs.len});
    if (devs.len == 0) return error.VulkanError;
    const dev = devs[0];

    var deviceProperties: v.VkPhysicalDeviceProperties = undefined;
    v.vkGetPhysicalDeviceProperties(dev, &deviceProperties);
    // print("propert: {}\n", .{deviceProperties});
    print("namm: {s}\n", .{deviceProperties.deviceName});

    var deviceFeatures: v.VkPhysicalDeviceFeatures = undefined;
    v.vkGetPhysicalDeviceFeatures(dev, &deviceFeatures);
    // print("feat: {}\n", .{deviceFeatures});

    return .{};
}
