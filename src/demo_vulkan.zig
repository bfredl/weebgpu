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

    const layoutBinding: v.VkDescriptorSetLayoutBinding = .{
        .binding = 0,
        .descriptorCount = 1,
        .descriptorType = v.VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER,
        .pImmutableSamplers = null,
        .stageFlags = v.VK_SHADER_STAGE_COMPUTE_BIT,
    };

    const layoutInfo: v.VkDescriptorSetLayoutCreateInfo = .{
        .sType = v.VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO,
        .bindingCount = 1,
        .pBindings = &layoutBinding,
        .flags = 0,
        .pNext = null,
    };
    var descriptorSetLayout: v.VkDescriptorSetLayout = undefined;
    try verify(v.vkCreateDescriptorSetLayout(s.dev, &layoutInfo, null, &descriptorSetLayout));

    const pipelineLayoutInfo: v.VkPipelineLayoutCreateInfo = .{
        .sType = v.VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO,
        .setLayoutCount = 1,
        .pSetLayouts = &descriptorSetLayout,
        .pPushConstantRanges = null,
        .pushConstantRangeCount = 0,
        .flags = 0,
        .pNext = null,
    };
    var pipelineLayout: v.VkPipelineLayout = undefined;
    try verify(v.vkCreatePipelineLayout(s.dev, &pipelineLayoutInfo, null, &pipelineLayout));

    const poolSize: v.VkDescriptorPoolSize = .{
        .type = v.VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER,
        .descriptorCount = 1,
    };

    const descPoolInfo: v.VkDescriptorPoolCreateInfo = .{
        .sType = v.VK_STRUCTURE_TYPE_DESCRIPTOR_POOL_CREATE_INFO,
        .poolSizeCount = 1,
        .pPoolSizes = &poolSize,
        .maxSets = 1,
        .flags = 0,
        .pNext = null,
    };

    var descriptorPool: v.VkDescriptorPool = undefined;
    try verify(v.vkCreateDescriptorPool(s.dev, &descPoolInfo, null, &descriptorPool));

    const setAllocInfo: v.VkDescriptorSetAllocateInfo = .{
        .sType = v.VK_STRUCTURE_TYPE_DESCRIPTOR_SET_ALLOCATE_INFO,
        .descriptorPool = descriptorPool,
        .descriptorSetCount = 1,
        .pSetLayouts = &descriptorSetLayout,
        .pNext = null,
    };

    var descriptorSet: v.VkDescriptorSet = undefined;
    try verify(v.vkAllocateDescriptorSets(s.dev, &setAllocInfo, &descriptorSet));

    const descBufferInfo: v.VkDescriptorBufferInfo = .{
        .buffer = buf,
        .offset = 0,
        .range = v.VK_WHOLE_SIZE,
    };
    const descriptorWrite: v.VkWriteDescriptorSet = .{
        .sType = v.VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET,
        .dstSet = descriptorSet,
        .dstBinding = 0,
        .dstArrayElement = 0,
        .descriptorType = v.VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER,
        .descriptorCount = 1,
        .pBufferInfo = &descBufferInfo,
        .pImageInfo = null,
        .pTexelBufferView = null,
        .pNext = null,
    };
    v.vkUpdateDescriptorSets(s.dev, 1, &descriptorWrite, 0, null);

    const kod = @embedFile("./shader.spv");

    const createInfo: v.VkShaderModuleCreateInfo = .{
        .sType = v.VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO,
        .codeSize = kod.len,
        .pCode = @ptrCast(*const u32, @alignCast(4, kod.ptr)),
        .flags = 0,
        .pNext = null,
    };

    var shaderModule: v.VkShaderModule = undefined;
    try verify(v.vkCreateShaderModule(s.dev, &createInfo, null, &shaderModule));

    const computeShaderStageInfo: v.VkPipelineShaderStageCreateInfo = .{
        .sType = v.VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
        .stage = v.VK_SHADER_STAGE_COMPUTE_BIT,
        .module = shaderModule,
        .pName = "main",
        .pSpecializationInfo = null,
        .flags = 0,
        .pNext = null,
    };

    const pipelineInfo: v.VkComputePipelineCreateInfo = .{
        .sType = v.VK_STRUCTURE_TYPE_COMPUTE_PIPELINE_CREATE_INFO,
        .layout = pipelineLayout,
        .stage = computeShaderStageInfo,
        .basePipelineIndex = 0,
        .basePipelineHandle = null,
        .flags = 0,
        .pNext = null,
    };

    var computePipeline: v.VkPipeline = undefined;
    try verify(v.vkCreateComputePipelines(s.dev, null, 1, &pipelineInfo, null, &computePipeline));

    const poolInfo: v.VkCommandPoolCreateInfo = .{
        .sType = v.VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO,
        .flags = v.VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT,
        .queueFamilyIndex = 0,
        .pNext = null,
    };

    var commandPool: v.VkCommandPool = undefined;
    try verify(v.vkCreateCommandPool(s.dev, &poolInfo, null, &commandPool));

    const cmdAllocInfo: v.VkCommandBufferAllocateInfo = .{
        .sType = v.VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO,
        .commandPool = commandPool,
        .level = v.VK_COMMAND_BUFFER_LEVEL_PRIMARY,
        .commandBufferCount = 1,
        .pNext = null,
    };

    var commandBuffer: v.VkCommandBuffer = undefined;
    try verify(v.vkAllocateCommandBuffers(s.dev, &cmdAllocInfo, &commandBuffer));

    const beginInfo: v.VkCommandBufferBeginInfo = .{
        .sType = v.VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO,
        .pInheritanceInfo = null,
        .flags = 0,
        .pNext = null,
    };

    try verify(v.vkBeginCommandBuffer(commandBuffer, &beginInfo));

    v.vkCmdBindPipeline(commandBuffer, v.VK_PIPELINE_BIND_POINT_COMPUTE, computePipeline);
    v.vkCmdBindDescriptorSets(commandBuffer, v.VK_PIPELINE_BIND_POINT_COMPUTE, pipelineLayout, 0, 1, &descriptorSet, 0, 0);

    v.vkCmdDispatch(commandBuffer, 1, 1, 1);

    try verify(v.vkEndCommandBuffer(commandBuffer));
    const submitInfo: v.VkSubmitInfo = .{
        .sType = v.VK_STRUCTURE_TYPE_SUBMIT_INFO,
        .pSignalSemaphores = null,
        .signalSemaphoreCount = 0,
        .pCommandBuffers = &commandBuffer,
        .commandBufferCount = 1,
        .pWaitDstStageMask = 0,
        .pWaitSemaphores = 0,
        .waitSemaphoreCount = 0,
        .pNext = null,
    };
    try verify(v.vkQueueSubmit(s.queue, 1, &submitInfo, null));
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
