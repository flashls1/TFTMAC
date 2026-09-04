#include <android/asset_manager.h>
#include <android/log.h>
#include <android/native_window.h>
#include <android_native_app_glue.h>
#include <sys/system_properties.h>
#include <vulkan/vulkan.h>
#include <vulkan/vulkan_android.h>

#include <algorithm>
#include <array>
#include <chrono>
#include <cmath>
#include <cstdint>
#include <cstring>
#include <limits>
#include <numeric>
#include <optional>
#include <string>
#include <thread>
#include <vector>

namespace {

constexpr char kLogTag[] = "TFTMAC_VKPROBE";
constexpr uint32_t kTextureWidth = 256;
constexpr uint32_t kTextureHeight = 256;

#define PROBE_LOG(...) __android_log_print(ANDROID_LOG_INFO, kLogTag, __VA_ARGS__)
#define PROBE_ERROR(...) __android_log_print(ANDROID_LOG_ERROR, kLogTag, __VA_ARGS__)

struct Workload {
    const char* id;
    uint32_t drawsPerFrame;
    bool textureUpload;
    bool pipelineChurn;
    bool queueWaitIdle;
};

constexpr std::array<Workload, 5> kWorkloads{{
    {"stable_descriptor_draw", 1, false, false, false},
    {"texture_upload_sampling", 1, true, false, false},
    {"pipeline_shader_churn", 1, false, true, false},
    {"fill_rate_overdraw", 64, false, false, false},
    {"queue_fence_present_pressure", 4, false, false, true},
}};

struct PushConstants {
    float tint[4];
    float offset;
};

struct VulkanProbe {
    android_app* app = nullptr;
    VkInstance instance = VK_NULL_HANDLE;
    VkSurfaceKHR surface = VK_NULL_HANDLE;
    VkPhysicalDevice physicalDevice = VK_NULL_HANDLE;
    VkDevice device = VK_NULL_HANDLE;
    VkQueue queue = VK_NULL_HANDLE;
    uint32_t queueFamily = 0;
    VkSwapchainKHR swapchain = VK_NULL_HANDLE;
    VkFormat swapchainFormat = VK_FORMAT_UNDEFINED;
    VkExtent2D extent{};
    std::vector<VkImage> swapchainImages;
    std::vector<VkImageView> swapchainViews;
    std::vector<VkFramebuffer> framebuffers;
    VkRenderPass renderPass = VK_NULL_HANDLE;
    VkDescriptorSetLayout descriptorSetLayout = VK_NULL_HANDLE;
    VkPipelineLayout pipelineLayout = VK_NULL_HANDLE;
    VkPipeline pipeline = VK_NULL_HANDLE;
    VkDescriptorPool descriptorPool = VK_NULL_HANDLE;
    VkDescriptorSet descriptorSet = VK_NULL_HANDLE;
    VkCommandPool commandPool = VK_NULL_HANDLE;
    VkCommandBuffer commandBuffer = VK_NULL_HANDLE;
    VkSemaphore imageAvailable = VK_NULL_HANDLE;
    VkSemaphore renderFinished = VK_NULL_HANDLE;
    VkFence frameFence = VK_NULL_HANDLE;
    VkQueryPool timestampPool = VK_NULL_HANDLE;
    VkImage textureImage = VK_NULL_HANDLE;
    VkDeviceMemory textureMemory = VK_NULL_HANDLE;
    VkImageView textureView = VK_NULL_HANDLE;
    VkSampler sampler = VK_NULL_HANDLE;
    VkBuffer stagingBuffer = VK_NULL_HANDLE;
    VkDeviceMemory stagingMemory = VK_NULL_HANDLE;
    void* stagingMap = nullptr;
    VkPhysicalDeviceProperties physicalProperties{};
    PFN_vkCmdBeginDebugUtilsLabelEXT cmdBeginLabel = nullptr;
    PFN_vkCmdEndDebugUtilsLabelEXT cmdEndLabel = nullptr;
    PFN_vkQueueBeginDebugUtilsLabelEXT queueBeginLabel = nullptr;
    PFN_vkQueueEndDebugUtilsLabelEXT queueEndLabel = nullptr;
    VkSemaphore timelineSemaphore = VK_NULL_HANDLE;
    bool timelineSemaphoreAvailable = false;
    bool hasTimestamps = false;
    bool textureInitialized = false;
    uint64_t textureGeneration = 0;
    uint64_t errorCount = 0;
};

uint64_t fnv1a64(const void* bytes, size_t length, uint64_t hash = 1469598103934665603ULL) {
    const auto* cursor = static_cast<const uint8_t*>(bytes);
    for (size_t index = 0; index < length; ++index) {
        hash ^= cursor[index];
        hash *= 1099511628211ULL;
    }
    return hash;
}

uint64_t frameIdentity(
    const std::string& profile,
    const char* workload,
    uint64_t frame,
    uint64_t textureGeneration
) {
    uint64_t hash = fnv1a64(profile.data(), profile.size());
    hash = fnv1a64(workload, std::strlen(workload), hash);
    hash = fnv1a64(&frame, sizeof(frame), hash);
    return fnv1a64(&textureGeneration, sizeof(textureGeneration), hash);
}

std::string property(const char* key, const char* fallback) {
    std::array<char, PROP_VALUE_MAX> value{};
    const int length = __system_property_get(key, value.data());
    return length > 0 ? std::string(value.data(), static_cast<size_t>(length)) : std::string(fallback);
}

std::vector<uint8_t> readAsset(AAssetManager* manager, const char* name) {
    AAsset* asset = AAssetManager_open(manager, name, AASSET_MODE_BUFFER);
    if (!asset) return {};
    const auto length = static_cast<size_t>(AAsset_getLength(asset));
    std::vector<uint8_t> bytes(length);
    const int64_t read = AAsset_read(asset, bytes.data(), length);
    AAsset_close(asset);
    if (read != static_cast<int64_t>(length)) return {};
    return bytes;
}

bool check(VulkanProbe& probe, VkResult result, const char* operation) {
    if (result == VK_SUCCESS) return true;
    ++probe.errorCount;
    PROBE_ERROR("{\"event\":\"vulkan_error\",\"operation\":\"%s\",\"result\":%d}", operation, result);
    return false;
}

std::optional<uint32_t> memoryType(
    const VulkanProbe& probe,
    uint32_t typeBits,
    VkMemoryPropertyFlags required
) {
    VkPhysicalDeviceMemoryProperties properties{};
    vkGetPhysicalDeviceMemoryProperties(probe.physicalDevice, &properties);
    for (uint32_t index = 0; index < properties.memoryTypeCount; ++index) {
        if ((typeBits & (1U << index)) != 0 &&
            (properties.memoryTypes[index].propertyFlags & required) == required) {
            return index;
        }
    }
    return std::nullopt;
}

bool createBuffer(
    VulkanProbe& probe,
    VkDeviceSize size,
    VkBufferUsageFlags usage,
    VkMemoryPropertyFlags memoryFlags,
    VkBuffer* buffer,
    VkDeviceMemory* memory
) {
    VkBufferCreateInfo bufferInfo{VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO};
    bufferInfo.size = size;
    bufferInfo.usage = usage;
    bufferInfo.sharingMode = VK_SHARING_MODE_EXCLUSIVE;
    if (!check(probe, vkCreateBuffer(probe.device, &bufferInfo, nullptr, buffer), "vkCreateBuffer")) return false;
    VkMemoryRequirements requirements{};
    vkGetBufferMemoryRequirements(probe.device, *buffer, &requirements);
    const auto type = memoryType(probe, requirements.memoryTypeBits, memoryFlags);
    if (!type) return false;
    VkMemoryAllocateInfo allocation{VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO};
    allocation.allocationSize = requirements.size;
    allocation.memoryTypeIndex = *type;
    if (!check(probe, vkAllocateMemory(probe.device, &allocation, nullptr, memory), "vkAllocateMemory(buffer)")) return false;
    return check(probe, vkBindBufferMemory(probe.device, *buffer, *memory, 0), "vkBindBufferMemory");
}

VkCommandBuffer beginOneShot(VulkanProbe& probe) {
    VkCommandBufferAllocateInfo allocation{VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO};
    allocation.commandPool = probe.commandPool;
    allocation.level = VK_COMMAND_BUFFER_LEVEL_PRIMARY;
    allocation.commandBufferCount = 1;
    VkCommandBuffer command = VK_NULL_HANDLE;
    if (vkAllocateCommandBuffers(probe.device, &allocation, &command) != VK_SUCCESS) return VK_NULL_HANDLE;
    VkCommandBufferBeginInfo begin{VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO};
    begin.flags = VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT;
    if (vkBeginCommandBuffer(command, &begin) != VK_SUCCESS) {
        vkFreeCommandBuffers(probe.device, probe.commandPool, 1, &command);
        return VK_NULL_HANDLE;
    }
    return command;
}

bool endOneShot(VulkanProbe& probe, VkCommandBuffer command) {
    if (command == VK_NULL_HANDLE || !check(probe, vkEndCommandBuffer(command), "vkEndCommandBuffer(one-shot)")) return false;
    VkSubmitInfo submit{VK_STRUCTURE_TYPE_SUBMIT_INFO};
    submit.commandBufferCount = 1;
    submit.pCommandBuffers = &command;
    const bool submitted = check(probe, vkQueueSubmit(probe.queue, 1, &submit, VK_NULL_HANDLE), "vkQueueSubmit(one-shot)");
    const bool idle = submitted && check(probe, vkQueueWaitIdle(probe.queue), "vkQueueWaitIdle(one-shot)");
    vkFreeCommandBuffers(probe.device, probe.commandPool, 1, &command);
    return submitted && idle;
}

bool uploadTexture(VulkanProbe& probe, uint64_t generation) {
    auto* pixels = static_cast<uint32_t*>(probe.stagingMap);
    for (uint32_t y = 0; y < kTextureHeight; ++y) {
        for (uint32_t x = 0; x < kTextureWidth; ++x) {
            const uint32_t checker = ((x / 16U) ^ (y / 16U) ^ static_cast<uint32_t>(generation)) & 1U;
            const uint32_t red = checker ? 0xE8U : static_cast<uint32_t>((x + generation) & 0xFFU);
            const uint32_t green = checker ? static_cast<uint32_t>((y + generation * 3U) & 0xFFU) : 0x44U;
            const uint32_t blue = checker ? 0x65U : 0xD9U;
            pixels[y * kTextureWidth + x] = 0xFF000000U | (blue << 16U) | (green << 8U) | red;
        }
    }

    VkCommandBuffer command = beginOneShot(probe);
    if (command == VK_NULL_HANDLE) return false;
    VkImageMemoryBarrier before{VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER};
    before.oldLayout = probe.textureInitialized ? VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL : VK_IMAGE_LAYOUT_UNDEFINED;
    before.newLayout = VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL;
    before.srcQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED;
    before.dstQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED;
    before.image = probe.textureImage;
    before.subresourceRange.aspectMask = VK_IMAGE_ASPECT_COLOR_BIT;
    before.subresourceRange.levelCount = 1;
    before.subresourceRange.layerCount = 1;
    before.srcAccessMask = probe.textureInitialized ? VK_ACCESS_SHADER_READ_BIT : 0;
    before.dstAccessMask = VK_ACCESS_TRANSFER_WRITE_BIT;
    vkCmdPipelineBarrier(
        command,
        probe.textureInitialized ? VK_PIPELINE_STAGE_FRAGMENT_SHADER_BIT : VK_PIPELINE_STAGE_TOP_OF_PIPE_BIT,
        VK_PIPELINE_STAGE_TRANSFER_BIT,
        0,
        0, nullptr,
        0, nullptr,
        1, &before
    );
    VkBufferImageCopy copy{};
    copy.imageSubresource.aspectMask = VK_IMAGE_ASPECT_COLOR_BIT;
    copy.imageSubresource.layerCount = 1;
    copy.imageExtent = {kTextureWidth, kTextureHeight, 1};
    vkCmdCopyBufferToImage(
        command,
        probe.stagingBuffer,
        probe.textureImage,
        VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL,
        1,
        &copy
    );
    VkImageMemoryBarrier after{VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER};
    after.oldLayout = VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL;
    after.newLayout = VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL;
    after.srcQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED;
    after.dstQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED;
    after.image = probe.textureImage;
    after.subresourceRange = before.subresourceRange;
    after.srcAccessMask = VK_ACCESS_TRANSFER_WRITE_BIT;
    after.dstAccessMask = VK_ACCESS_SHADER_READ_BIT;
    vkCmdPipelineBarrier(
        command,
        VK_PIPELINE_STAGE_TRANSFER_BIT,
        VK_PIPELINE_STAGE_FRAGMENT_SHADER_BIT,
        0,
        0, nullptr,
        0, nullptr,
        1, &after
    );
    if (!endOneShot(probe, command)) return false;
    probe.textureInitialized = true;
    probe.textureGeneration = generation;
    return true;
}

bool createTexture(VulkanProbe& probe) {
    VkImageCreateInfo image{VK_STRUCTURE_TYPE_IMAGE_CREATE_INFO};
    image.imageType = VK_IMAGE_TYPE_2D;
    image.format = VK_FORMAT_R8G8B8A8_UNORM;
    image.extent = {kTextureWidth, kTextureHeight, 1};
    image.mipLevels = 1;
    image.arrayLayers = 1;
    image.samples = VK_SAMPLE_COUNT_1_BIT;
    image.tiling = VK_IMAGE_TILING_OPTIMAL;
    image.usage = VK_IMAGE_USAGE_TRANSFER_DST_BIT | VK_IMAGE_USAGE_SAMPLED_BIT;
    image.sharingMode = VK_SHARING_MODE_EXCLUSIVE;
    image.initialLayout = VK_IMAGE_LAYOUT_UNDEFINED;
    if (!check(probe, vkCreateImage(probe.device, &image, nullptr, &probe.textureImage), "vkCreateImage")) return false;
    VkMemoryRequirements requirements{};
    vkGetImageMemoryRequirements(probe.device, probe.textureImage, &requirements);
    const auto type = memoryType(probe, requirements.memoryTypeBits, VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT);
    if (!type) return false;
    VkMemoryAllocateInfo allocation{VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO};
    allocation.allocationSize = requirements.size;
    allocation.memoryTypeIndex = *type;
    if (!check(probe, vkAllocateMemory(probe.device, &allocation, nullptr, &probe.textureMemory), "vkAllocateMemory(image)")) return false;
    if (!check(probe, vkBindImageMemory(probe.device, probe.textureImage, probe.textureMemory, 0), "vkBindImageMemory")) return false;

    VkImageViewCreateInfo view{VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO};
    view.image = probe.textureImage;
    view.viewType = VK_IMAGE_VIEW_TYPE_2D;
    view.format = image.format;
    view.subresourceRange.aspectMask = VK_IMAGE_ASPECT_COLOR_BIT;
    view.subresourceRange.levelCount = 1;
    view.subresourceRange.layerCount = 1;
    if (!check(probe, vkCreateImageView(probe.device, &view, nullptr, &probe.textureView), "vkCreateImageView(texture)")) return false;

    VkSamplerCreateInfo sampler{VK_STRUCTURE_TYPE_SAMPLER_CREATE_INFO};
    sampler.magFilter = VK_FILTER_LINEAR;
    sampler.minFilter = VK_FILTER_LINEAR;
    sampler.mipmapMode = VK_SAMPLER_MIPMAP_MODE_NEAREST;
    sampler.addressModeU = VK_SAMPLER_ADDRESS_MODE_REPEAT;
    sampler.addressModeV = VK_SAMPLER_ADDRESS_MODE_REPEAT;
    sampler.addressModeW = VK_SAMPLER_ADDRESS_MODE_REPEAT;
    sampler.maxLod = 1.0F;
    if (!check(probe, vkCreateSampler(probe.device, &sampler, nullptr, &probe.sampler), "vkCreateSampler")) return false;

    constexpr VkDeviceSize textureBytes = kTextureWidth * kTextureHeight * 4ULL;
    if (!createBuffer(
            probe,
            textureBytes,
            VK_BUFFER_USAGE_TRANSFER_SRC_BIT,
            VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | VK_MEMORY_PROPERTY_HOST_COHERENT_BIT,
            &probe.stagingBuffer,
            &probe.stagingMemory)) return false;
    if (!check(probe, vkMapMemory(probe.device, probe.stagingMemory, 0, textureBytes, 0, &probe.stagingMap), "vkMapMemory")) return false;
    return uploadTexture(probe, 0);
}

bool createPipeline(VulkanProbe& probe) {
    const auto vertexBytes = readAsset(probe.app->activity->assetManager, "probe.vert.spv");
    const auto fragmentBytes = readAsset(probe.app->activity->assetManager, "probe.frag.spv");
    if (vertexBytes.empty() || fragmentBytes.empty()) {
        PROBE_ERROR("{\"event\":\"asset_error\",\"detail\":\"SPIR-V assets unavailable\"}");
        return false;
    }
    VkShaderModuleCreateInfo module{VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO};
    module.codeSize = vertexBytes.size();
    module.pCode = reinterpret_cast<const uint32_t*>(vertexBytes.data());
    VkShaderModule vertex = VK_NULL_HANDLE;
    if (!check(probe, vkCreateShaderModule(probe.device, &module, nullptr, &vertex), "vkCreateShaderModule(vertex)")) return false;
    module.codeSize = fragmentBytes.size();
    module.pCode = reinterpret_cast<const uint32_t*>(fragmentBytes.data());
    VkShaderModule fragment = VK_NULL_HANDLE;
    if (!check(probe, vkCreateShaderModule(probe.device, &module, nullptr, &fragment), "vkCreateShaderModule(fragment)")) {
        vkDestroyShaderModule(probe.device, vertex, nullptr);
        return false;
    }
    std::array<VkPipelineShaderStageCreateInfo, 2> stages{};
    stages[0] = {VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO};
    stages[0].stage = VK_SHADER_STAGE_VERTEX_BIT;
    stages[0].module = vertex;
    stages[0].pName = "main";
    stages[1] = {VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO};
    stages[1].stage = VK_SHADER_STAGE_FRAGMENT_BIT;
    stages[1].module = fragment;
    stages[1].pName = "main";
    VkPipelineVertexInputStateCreateInfo vertexInput{VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO};
    VkPipelineInputAssemblyStateCreateInfo assembly{VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO};
    assembly.topology = VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST;
    VkPipelineViewportStateCreateInfo viewportState{VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO};
    viewportState.viewportCount = 1;
    viewportState.scissorCount = 1;
    VkPipelineRasterizationStateCreateInfo raster{VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO};
    raster.polygonMode = VK_POLYGON_MODE_FILL;
    raster.cullMode = VK_CULL_MODE_NONE;
    raster.frontFace = VK_FRONT_FACE_COUNTER_CLOCKWISE;
    raster.lineWidth = 1.0F;
    VkPipelineMultisampleStateCreateInfo multisample{VK_STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO};
    multisample.rasterizationSamples = VK_SAMPLE_COUNT_1_BIT;
    VkPipelineColorBlendAttachmentState attachment{};
    attachment.colorWriteMask = VK_COLOR_COMPONENT_R_BIT | VK_COLOR_COMPONENT_G_BIT |
                                VK_COLOR_COMPONENT_B_BIT | VK_COLOR_COMPONENT_A_BIT;
    VkPipelineColorBlendStateCreateInfo blend{VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO};
    blend.attachmentCount = 1;
    blend.pAttachments = &attachment;
    std::array<VkDynamicState, 2> dynamicStates{VK_DYNAMIC_STATE_VIEWPORT, VK_DYNAMIC_STATE_SCISSOR};
    VkPipelineDynamicStateCreateInfo dynamic{VK_STRUCTURE_TYPE_PIPELINE_DYNAMIC_STATE_CREATE_INFO};
    dynamic.dynamicStateCount = dynamicStates.size();
    dynamic.pDynamicStates = dynamicStates.data();
    VkGraphicsPipelineCreateInfo pipeline{VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO};
    pipeline.stageCount = stages.size();
    pipeline.pStages = stages.data();
    pipeline.pVertexInputState = &vertexInput;
    pipeline.pInputAssemblyState = &assembly;
    pipeline.pViewportState = &viewportState;
    pipeline.pRasterizationState = &raster;
    pipeline.pMultisampleState = &multisample;
    pipeline.pColorBlendState = &blend;
    pipeline.pDynamicState = &dynamic;
    pipeline.layout = probe.pipelineLayout;
    pipeline.renderPass = probe.renderPass;
    pipeline.subpass = 0;
    const bool success = check(
        probe,
        vkCreateGraphicsPipelines(probe.device, VK_NULL_HANDLE, 1, &pipeline, nullptr, &probe.pipeline),
        "vkCreateGraphicsPipelines"
    );
    vkDestroyShaderModule(probe.device, fragment, nullptr);
    vkDestroyShaderModule(probe.device, vertex, nullptr);
    return success;
}

bool createSwapchain(VulkanProbe& probe) {
    VkSurfaceCapabilitiesKHR capabilities{};
    if (!check(probe, vkGetPhysicalDeviceSurfaceCapabilitiesKHR(probe.physicalDevice, probe.surface, &capabilities), "vkGetPhysicalDeviceSurfaceCapabilitiesKHR")) return false;
    uint32_t formatCount = 0;
    vkGetPhysicalDeviceSurfaceFormatsKHR(probe.physicalDevice, probe.surface, &formatCount, nullptr);
    std::vector<VkSurfaceFormatKHR> formats(formatCount);
    vkGetPhysicalDeviceSurfaceFormatsKHR(probe.physicalDevice, probe.surface, &formatCount, formats.data());
    if (formats.empty()) return false;
    VkSurfaceFormatKHR chosen = formats.front();
    for (const auto& format : formats) {
        if (format.format == VK_FORMAT_R8G8B8A8_UNORM || format.format == VK_FORMAT_B8G8R8A8_UNORM) {
            chosen = format;
            break;
        }
    }
    probe.swapchainFormat = chosen.format;
    probe.extent = capabilities.currentExtent.width != std::numeric_limits<uint32_t>::max()
        ? capabilities.currentExtent
        : VkExtent2D{
              std::clamp<uint32_t>(ANativeWindow_getWidth(probe.app->window), capabilities.minImageExtent.width, capabilities.maxImageExtent.width),
              std::clamp<uint32_t>(ANativeWindow_getHeight(probe.app->window), capabilities.minImageExtent.height, capabilities.maxImageExtent.height)};
    uint32_t imageCount = std::max(3U, capabilities.minImageCount + 1U);
    if (capabilities.maxImageCount > 0) imageCount = std::min(imageCount, capabilities.maxImageCount);
    VkSwapchainCreateInfoKHR swapchain{VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR};
    swapchain.surface = probe.surface;
    swapchain.minImageCount = imageCount;
    swapchain.imageFormat = chosen.format;
    swapchain.imageColorSpace = chosen.colorSpace;
    swapchain.imageExtent = probe.extent;
    swapchain.imageArrayLayers = 1;
    swapchain.imageUsage = VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT;
    swapchain.imageSharingMode = VK_SHARING_MODE_EXCLUSIVE;
    swapchain.preTransform = capabilities.currentTransform;
    swapchain.compositeAlpha = (capabilities.supportedCompositeAlpha & VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR)
        ? VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR
        : VK_COMPOSITE_ALPHA_INHERIT_BIT_KHR;
    swapchain.presentMode = VK_PRESENT_MODE_FIFO_KHR;
    swapchain.clipped = VK_TRUE;
    if (!check(probe, vkCreateSwapchainKHR(probe.device, &swapchain, nullptr, &probe.swapchain), "vkCreateSwapchainKHR")) return false;
    vkGetSwapchainImagesKHR(probe.device, probe.swapchain, &imageCount, nullptr);
    probe.swapchainImages.resize(imageCount);
    vkGetSwapchainImagesKHR(probe.device, probe.swapchain, &imageCount, probe.swapchainImages.data());
    probe.swapchainViews.resize(imageCount);
    for (uint32_t index = 0; index < imageCount; ++index) {
        VkImageViewCreateInfo view{VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO};
        view.image = probe.swapchainImages[index];
        view.viewType = VK_IMAGE_VIEW_TYPE_2D;
        view.format = probe.swapchainFormat;
        view.subresourceRange.aspectMask = VK_IMAGE_ASPECT_COLOR_BIT;
        view.subresourceRange.levelCount = 1;
        view.subresourceRange.layerCount = 1;
        if (!check(probe, vkCreateImageView(probe.device, &view, nullptr, &probe.swapchainViews[index]), "vkCreateImageView(swapchain)")) return false;
    }
    return true;
}

bool initialize(VulkanProbe& probe) {
    std::vector<const char*> instanceExtensions{
        VK_KHR_SURFACE_EXTENSION_NAME,
        VK_KHR_ANDROID_SURFACE_EXTENSION_NAME,
    };
    uint32_t instanceExtensionCount = 0;
    vkEnumerateInstanceExtensionProperties(nullptr, &instanceExtensionCount, nullptr);
    std::vector<VkExtensionProperties> availableInstanceExtensions(instanceExtensionCount);
    vkEnumerateInstanceExtensionProperties(
        nullptr,
        &instanceExtensionCount,
        availableInstanceExtensions.data()
    );
    const bool debugUtilsAvailable = std::any_of(
        availableInstanceExtensions.begin(),
        availableInstanceExtensions.end(),
        [](const VkExtensionProperties& extension) {
            return std::strcmp(extension.extensionName, VK_EXT_DEBUG_UTILS_EXTENSION_NAME) == 0;
        }
    );
    if (debugUtilsAvailable) instanceExtensions.push_back(VK_EXT_DEBUG_UTILS_EXTENSION_NAME);
    VkApplicationInfo application{VK_STRUCTURE_TYPE_APPLICATION_INFO};
    application.pApplicationName = "TFTMAC Vulkan Probe";
    application.applicationVersion = VK_MAKE_VERSION(1, 0, 0);
    application.pEngineName = "TFTMAC Deterministic Probe";
    application.engineVersion = VK_MAKE_VERSION(1, 0, 0);
    application.apiVersion = VK_API_VERSION_1_1;
    VkInstanceCreateInfo instance{VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO};
    instance.pApplicationInfo = &application;
    instance.enabledExtensionCount = static_cast<uint32_t>(instanceExtensions.size());
    instance.ppEnabledExtensionNames = instanceExtensions.data();
    if (!check(probe, vkCreateInstance(&instance, nullptr, &probe.instance), "vkCreateInstance")) return false;
    VkAndroidSurfaceCreateInfoKHR surface{VK_STRUCTURE_TYPE_ANDROID_SURFACE_CREATE_INFO_KHR};
    surface.window = probe.app->window;
    if (!check(probe, vkCreateAndroidSurfaceKHR(probe.instance, &surface, nullptr, &probe.surface), "vkCreateAndroidSurfaceKHR")) return false;

    uint32_t deviceCount = 0;
    vkEnumeratePhysicalDevices(probe.instance, &deviceCount, nullptr);
    std::vector<VkPhysicalDevice> devices(deviceCount);
    vkEnumeratePhysicalDevices(probe.instance, &deviceCount, devices.data());
    for (VkPhysicalDevice candidate : devices) {
        uint32_t familyCount = 0;
        vkGetPhysicalDeviceQueueFamilyProperties(candidate, &familyCount, nullptr);
        std::vector<VkQueueFamilyProperties> families(familyCount);
        vkGetPhysicalDeviceQueueFamilyProperties(candidate, &familyCount, families.data());
        for (uint32_t family = 0; family < familyCount; ++family) {
            VkBool32 present = VK_FALSE;
            vkGetPhysicalDeviceSurfaceSupportKHR(candidate, family, probe.surface, &present);
            if ((families[family].queueFlags & VK_QUEUE_GRAPHICS_BIT) && present) {
                probe.physicalDevice = candidate;
                probe.queueFamily = family;
                probe.hasTimestamps = families[family].timestampValidBits > 0;
                break;
            }
        }
        if (probe.physicalDevice != VK_NULL_HANDLE) break;
    }
    if (probe.physicalDevice == VK_NULL_HANDLE) return false;
    vkGetPhysicalDeviceProperties(probe.physicalDevice, &probe.physicalProperties);
    const float queuePriority = 1.0F;
    VkDeviceQueueCreateInfo queue{VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO};
    queue.queueFamilyIndex = probe.queueFamily;
    queue.queueCount = 1;
    queue.pQueuePriorities = &queuePriority;
    uint32_t deviceExtensionCount = 0;
    vkEnumerateDeviceExtensionProperties(probe.physicalDevice, nullptr, &deviceExtensionCount, nullptr);
    std::vector<VkExtensionProperties> availableDeviceExtensions(deviceExtensionCount);
    vkEnumerateDeviceExtensionProperties(probe.physicalDevice, nullptr, &deviceExtensionCount, availableDeviceExtensions.data());

    std::vector<const char*> deviceExtensions{VK_KHR_SWAPCHAIN_EXTENSION_NAME};
    bool timelineExtensionSupported = false;
    for (const auto& extension : availableDeviceExtensions) {
        if (std::strcmp(extension.extensionName, VK_KHR_TIMELINE_SEMAPHORE_EXTENSION_NAME) == 0) {
            timelineExtensionSupported = true;
            break;
        }
    }
    if (timelineExtensionSupported) {
        deviceExtensions.push_back(VK_KHR_TIMELINE_SEMAPHORE_EXTENSION_NAME);
    }

    VkPhysicalDeviceTimelineSemaphoreFeatures timelineFeatures{VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_TIMELINE_SEMAPHORE_FEATURES};
    timelineFeatures.timelineSemaphore = VK_TRUE;

    VkDeviceCreateInfo device{VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO};
    device.pNext = timelineExtensionSupported ? &timelineFeatures : nullptr;
    device.queueCreateInfoCount = 1;
    device.pQueueCreateInfos = &queue;
    device.enabledExtensionCount = static_cast<uint32_t>(deviceExtensions.size());
    device.ppEnabledExtensionNames = deviceExtensions.data();
    if (!check(probe, vkCreateDevice(probe.physicalDevice, &device, nullptr, &probe.device), "vkCreateDevice")) return false;
    vkGetDeviceQueue(probe.device, probe.queueFamily, 0, &probe.queue);
    probe.cmdBeginLabel = reinterpret_cast<PFN_vkCmdBeginDebugUtilsLabelEXT>(
        vkGetInstanceProcAddr(probe.instance, "vkCmdBeginDebugUtilsLabelEXT")
    );
    probe.cmdEndLabel = reinterpret_cast<PFN_vkCmdEndDebugUtilsLabelEXT>(
        vkGetInstanceProcAddr(probe.instance, "vkCmdEndDebugUtilsLabelEXT")
    );
    probe.queueBeginLabel = reinterpret_cast<PFN_vkQueueBeginDebugUtilsLabelEXT>(
        vkGetInstanceProcAddr(probe.instance, "vkQueueBeginDebugUtilsLabelEXT")
    );
    probe.queueEndLabel = reinterpret_cast<PFN_vkQueueEndDebugUtilsLabelEXT>(
        vkGetInstanceProcAddr(probe.instance, "vkQueueEndDebugUtilsLabelEXT")
    );

    VkCommandPoolCreateInfo pool{VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO};
    pool.flags = VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT;
    pool.queueFamilyIndex = probe.queueFamily;
    if (!check(probe, vkCreateCommandPool(probe.device, &pool, nullptr, &probe.commandPool), "vkCreateCommandPool")) return false;
    if (!createSwapchain(probe)) return false;

    VkAttachmentDescription color{};
    color.format = probe.swapchainFormat;
    color.samples = VK_SAMPLE_COUNT_1_BIT;
    color.loadOp = VK_ATTACHMENT_LOAD_OP_CLEAR;
    color.storeOp = VK_ATTACHMENT_STORE_OP_STORE;
    color.initialLayout = VK_IMAGE_LAYOUT_UNDEFINED;
    color.finalLayout = VK_IMAGE_LAYOUT_PRESENT_SRC_KHR;
    VkAttachmentReference colorReference{0, VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL};
    VkSubpassDescription subpass{};
    subpass.pipelineBindPoint = VK_PIPELINE_BIND_POINT_GRAPHICS;
    subpass.colorAttachmentCount = 1;
    subpass.pColorAttachments = &colorReference;
    VkSubpassDependency dependency{};
    dependency.srcSubpass = VK_SUBPASS_EXTERNAL;
    dependency.dstSubpass = 0;
    dependency.srcStageMask = VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT;
    dependency.dstStageMask = VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT;
    dependency.dstAccessMask = VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT;
    VkRenderPassCreateInfo renderPass{VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO};
    renderPass.attachmentCount = 1;
    renderPass.pAttachments = &color;
    renderPass.subpassCount = 1;
    renderPass.pSubpasses = &subpass;
    renderPass.dependencyCount = 1;
    renderPass.pDependencies = &dependency;
    if (!check(probe, vkCreateRenderPass(probe.device, &renderPass, nullptr, &probe.renderPass), "vkCreateRenderPass")) return false;

    probe.framebuffers.resize(probe.swapchainViews.size());
    for (size_t index = 0; index < probe.swapchainViews.size(); ++index) {
        VkFramebufferCreateInfo framebuffer{VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO};
        framebuffer.renderPass = probe.renderPass;
        framebuffer.attachmentCount = 1;
        framebuffer.pAttachments = &probe.swapchainViews[index];
        framebuffer.width = probe.extent.width;
        framebuffer.height = probe.extent.height;
        framebuffer.layers = 1;
        if (!check(probe, vkCreateFramebuffer(probe.device, &framebuffer, nullptr, &probe.framebuffers[index]), "vkCreateFramebuffer")) return false;
    }

    VkDescriptorSetLayoutBinding binding{};
    binding.binding = 0;
    binding.descriptorType = VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER;
    binding.descriptorCount = 1;
    binding.stageFlags = VK_SHADER_STAGE_FRAGMENT_BIT;
    VkDescriptorSetLayoutCreateInfo setLayout{VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO};
    setLayout.bindingCount = 1;
    setLayout.pBindings = &binding;
    if (!check(probe, vkCreateDescriptorSetLayout(probe.device, &setLayout, nullptr, &probe.descriptorSetLayout), "vkCreateDescriptorSetLayout")) return false;
    VkPushConstantRange push{};
    push.stageFlags = VK_SHADER_STAGE_VERTEX_BIT | VK_SHADER_STAGE_FRAGMENT_BIT;
    push.size = sizeof(PushConstants);
    VkPipelineLayoutCreateInfo pipelineLayout{VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO};
    pipelineLayout.setLayoutCount = 1;
    pipelineLayout.pSetLayouts = &probe.descriptorSetLayout;
    pipelineLayout.pushConstantRangeCount = 1;
    pipelineLayout.pPushConstantRanges = &push;
    if (!check(probe, vkCreatePipelineLayout(probe.device, &pipelineLayout, nullptr, &probe.pipelineLayout), "vkCreatePipelineLayout")) return false;
    if (!createPipeline(probe) || !createTexture(probe)) return false;

    VkDescriptorPoolSize poolSize{VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER, 1};
    VkDescriptorPoolCreateInfo descriptorPool{VK_STRUCTURE_TYPE_DESCRIPTOR_POOL_CREATE_INFO};
    descriptorPool.maxSets = 1;
    descriptorPool.poolSizeCount = 1;
    descriptorPool.pPoolSizes = &poolSize;
    if (!check(probe, vkCreateDescriptorPool(probe.device, &descriptorPool, nullptr, &probe.descriptorPool), "vkCreateDescriptorPool")) return false;
    VkDescriptorSetAllocateInfo descriptorAllocation{VK_STRUCTURE_TYPE_DESCRIPTOR_SET_ALLOCATE_INFO};
    descriptorAllocation.descriptorPool = probe.descriptorPool;
    descriptorAllocation.descriptorSetCount = 1;
    descriptorAllocation.pSetLayouts = &probe.descriptorSetLayout;
    if (!check(probe, vkAllocateDescriptorSets(probe.device, &descriptorAllocation, &probe.descriptorSet), "vkAllocateDescriptorSets")) return false;
    VkDescriptorImageInfo imageInfo{};
    imageInfo.sampler = probe.sampler;
    imageInfo.imageView = probe.textureView;
    imageInfo.imageLayout = VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL;
    VkWriteDescriptorSet descriptor{VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET};
    descriptor.dstSet = probe.descriptorSet;
    descriptor.dstBinding = 0;
    descriptor.descriptorCount = 1;
    descriptor.descriptorType = VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER;
    descriptor.pImageInfo = &imageInfo;
    vkUpdateDescriptorSets(probe.device, 1, &descriptor, 0, nullptr);

    VkCommandBufferAllocateInfo command{VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO};
    command.commandPool = probe.commandPool;
    command.level = VK_COMMAND_BUFFER_LEVEL_PRIMARY;
    command.commandBufferCount = 1;
    if (!check(probe, vkAllocateCommandBuffers(probe.device, &command, &probe.commandBuffer), "vkAllocateCommandBuffers")) return false;
    VkSemaphoreCreateInfo semaphore{VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO};
    if (!check(probe, vkCreateSemaphore(probe.device, &semaphore, nullptr, &probe.imageAvailable), "vkCreateSemaphore(image)")) return false;
    if (!check(probe, vkCreateSemaphore(probe.device, &semaphore, nullptr, &probe.renderFinished), "vkCreateSemaphore(render)")) return false;
    if (timelineExtensionSupported) {
        VkSemaphoreTypeCreateInfo timelineTypeInfo{VK_STRUCTURE_TYPE_SEMAPHORE_TYPE_CREATE_INFO};
        timelineTypeInfo.semaphoreType = VK_SEMAPHORE_TYPE_TIMELINE;
        timelineTypeInfo.initialValue = 0;

        VkSemaphoreCreateInfo timelineSemInfo{VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO};
        timelineSemInfo.pNext = &timelineTypeInfo;
        if (check(probe, vkCreateSemaphore(probe.device, &timelineSemInfo, nullptr, &probe.timelineSemaphore), "vkCreateSemaphore(timeline)")) {
            probe.timelineSemaphoreAvailable = true;
        }
    }
    VkFenceCreateInfo fence{VK_STRUCTURE_TYPE_FENCE_CREATE_INFO};
    fence.flags = VK_FENCE_CREATE_SIGNALED_BIT;
    if (!check(probe, vkCreateFence(probe.device, &fence, nullptr, &probe.frameFence), "vkCreateFence")) return false;
    if (probe.hasTimestamps) {
        VkQueryPoolCreateInfo query{VK_STRUCTURE_TYPE_QUERY_POOL_CREATE_INFO};
        query.queryType = VK_QUERY_TYPE_TIMESTAMP;
        query.queryCount = 2;
        if (!check(probe, vkCreateQueryPool(probe.device, &query, nullptr, &probe.timestampPool), "vkCreateQueryPool")) {
            probe.hasTimestamps = false;
        }
    }

    PROBE_LOG(
        "{\"event\":\"initialized\",\"device\":\"%s\",\"api_version\":%u,\"driver_version\":%u,\"width\":%u,\"height\":%u,\"timestamp_period_ns\":%.6f,\"debug_labels_available\":%s,\"queue_labels_available\":%s,\"timeline_semaphore_available\":%s}",
        probe.physicalProperties.deviceName,
        probe.physicalProperties.apiVersion,
        probe.physicalProperties.driverVersion,
        probe.extent.width,
        probe.extent.height,
        probe.physicalProperties.limits.timestampPeriod,
        (probe.cmdBeginLabel && probe.cmdEndLabel) ? "true" : "false",
        (probe.queueBeginLabel && probe.queueEndLabel) ? "true" : "false",
        probe.timelineSemaphoreAvailable ? "true" : "false"
    );
    return true;
}

void destroy(VulkanProbe& probe) {
    if (probe.device != VK_NULL_HANDLE) vkDeviceWaitIdle(probe.device);
    if (probe.stagingMap) vkUnmapMemory(probe.device, probe.stagingMemory);
    if (probe.timestampPool) vkDestroyQueryPool(probe.device, probe.timestampPool, nullptr);
    if (probe.frameFence) vkDestroyFence(probe.device, probe.frameFence, nullptr);
    if (probe.timelineSemaphore) vkDestroySemaphore(probe.device, probe.timelineSemaphore, nullptr);
    if (probe.renderFinished) vkDestroySemaphore(probe.device, probe.renderFinished, nullptr);
    if (probe.imageAvailable) vkDestroySemaphore(probe.device, probe.imageAvailable, nullptr);
    if (probe.descriptorPool) vkDestroyDescriptorPool(probe.device, probe.descriptorPool, nullptr);
    if (probe.sampler) vkDestroySampler(probe.device, probe.sampler, nullptr);
    if (probe.textureView) vkDestroyImageView(probe.device, probe.textureView, nullptr);
    if (probe.textureImage) vkDestroyImage(probe.device, probe.textureImage, nullptr);
    if (probe.textureMemory) vkFreeMemory(probe.device, probe.textureMemory, nullptr);
    if (probe.stagingBuffer) vkDestroyBuffer(probe.device, probe.stagingBuffer, nullptr);
    if (probe.stagingMemory) vkFreeMemory(probe.device, probe.stagingMemory, nullptr);
    if (probe.pipeline) vkDestroyPipeline(probe.device, probe.pipeline, nullptr);
    if (probe.pipelineLayout) vkDestroyPipelineLayout(probe.device, probe.pipelineLayout, nullptr);
    if (probe.descriptorSetLayout) vkDestroyDescriptorSetLayout(probe.device, probe.descriptorSetLayout, nullptr);
    for (VkFramebuffer framebuffer : probe.framebuffers) vkDestroyFramebuffer(probe.device, framebuffer, nullptr);
    if (probe.renderPass) vkDestroyRenderPass(probe.device, probe.renderPass, nullptr);
    for (VkImageView view : probe.swapchainViews) vkDestroyImageView(probe.device, view, nullptr);
    if (probe.swapchain) vkDestroySwapchainKHR(probe.device, probe.swapchain, nullptr);
    if (probe.commandPool) vkDestroyCommandPool(probe.device, probe.commandPool, nullptr);
    if (probe.device) vkDestroyDevice(probe.device, nullptr);
    if (probe.surface) vkDestroySurfaceKHR(probe.instance, probe.surface, nullptr);
    if (probe.instance) vkDestroyInstance(probe.instance, nullptr);
}

double percentile(std::vector<double> values, double quantile) {
    if (values.empty()) return 0.0;
    std::sort(values.begin(), values.end());
    const size_t index = std::min(values.size() - 1, static_cast<size_t>(std::floor((values.size() - 1) * quantile)));
    return values[index];
}

bool renderFrame(
    VulkanProbe& probe,
    const Workload& workload,
    const std::string& profile,
    uint64_t frame,
    double* cpuMS,
    double* gpuMS,
    double* queueWaitMS,
    uint64_t* identity
) {
    const auto cpuStart = std::chrono::steady_clock::now();
    if (!check(probe, vkWaitForFences(probe.device, 1, &probe.frameFence, VK_TRUE, 3'000'000'000ULL), "vkWaitForFences")) return false;
    if (probe.hasTimestamps) {
        std::array<uint64_t, 2> timestamps{};
        if (vkGetQueryPoolResults(
                probe.device,
                probe.timestampPool,
                0,
                2,
                sizeof(timestamps),
                timestamps.data(),
                sizeof(uint64_t),
                VK_QUERY_RESULT_64_BIT) == VK_SUCCESS && timestamps[1] >= timestamps[0]) {
            *gpuMS = static_cast<double>(timestamps[1] - timestamps[0]) *
                static_cast<double>(probe.physicalProperties.limits.timestampPeriod) / 1'000'000.0;
        }
    }
    vkResetFences(probe.device, 1, &probe.frameFence);
    if (workload.textureUpload && !uploadTexture(probe, probe.textureGeneration + 1)) return false;
    if (workload.pipelineChurn) {
        vkDestroyPipeline(probe.device, probe.pipeline, nullptr);
        probe.pipeline = VK_NULL_HANDLE;
        if (!createPipeline(probe)) return false;
    }

    uint32_t imageIndex = 0;
    const VkResult acquired = vkAcquireNextImageKHR(
        probe.device,
        probe.swapchain,
        2'000'000'000ULL,
        probe.imageAvailable,
        VK_NULL_HANDLE,
        &imageIndex
    );
    if (acquired != VK_SUCCESS && acquired != VK_SUBOPTIMAL_KHR) {
        return check(probe, acquired, "vkAcquireNextImageKHR");
    }
    vkResetCommandBuffer(probe.commandBuffer, 0);
    VkCommandBufferBeginInfo begin{VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO};
    begin.flags = VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT;
    if (!check(probe, vkBeginCommandBuffer(probe.commandBuffer, &begin), "vkBeginCommandBuffer(frame)")) return false;
    if (probe.hasTimestamps) {
        vkCmdResetQueryPool(probe.commandBuffer, probe.timestampPool, 0, 2);
        vkCmdWriteTimestamp(probe.commandBuffer, VK_PIPELINE_STAGE_TOP_OF_PIPE_BIT, probe.timestampPool, 0);
    }

    *identity = frameIdentity(profile, workload.id, frame, probe.textureGeneration);
    std::string label = "TFTMAC/" + profile + "/" + workload.id + "/" + std::to_string(*identity);
    if (probe.cmdBeginLabel && probe.cmdEndLabel) {
        VkDebugUtilsLabelEXT debugLabel{VK_STRUCTURE_TYPE_DEBUG_UTILS_LABEL_EXT};
        debugLabel.pLabelName = label.c_str();
        debugLabel.color[0] = 0.91F;
        debugLabel.color[1] = 0.31F;
        debugLabel.color[2] = 0.44F;
        debugLabel.color[3] = 1.0F;
        probe.cmdBeginLabel(probe.commandBuffer, &debugLabel);
    }
    VkClearValue clear{{{0.015F, 0.02F, 0.06F, 1.0F}}};
    VkRenderPassBeginInfo pass{VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO};
    pass.renderPass = probe.renderPass;
    pass.framebuffer = probe.framebuffers[imageIndex];
    pass.renderArea.extent = probe.extent;
    pass.clearValueCount = 1;
    pass.pClearValues = &clear;
    vkCmdBeginRenderPass(probe.commandBuffer, &pass, VK_SUBPASS_CONTENTS_INLINE);
    VkViewport viewport{0.0F, 0.0F, static_cast<float>(probe.extent.width), static_cast<float>(probe.extent.height), 0.0F, 1.0F};
    VkRect2D scissor{{0, 0}, probe.extent};
    vkCmdSetViewport(probe.commandBuffer, 0, 1, &viewport);
    vkCmdSetScissor(probe.commandBuffer, 0, 1, &scissor);
    vkCmdBindPipeline(probe.commandBuffer, VK_PIPELINE_BIND_POINT_GRAPHICS, probe.pipeline);
    vkCmdBindDescriptorSets(probe.commandBuffer, VK_PIPELINE_BIND_POINT_GRAPHICS, probe.pipelineLayout, 0, 1, &probe.descriptorSet, 0, nullptr);
    for (uint32_t draw = 0; draw < workload.drawsPerFrame; ++draw) {
        const float phase = static_cast<float>((frame + draw * 17ULL) % 360ULL) * 0.017453292519943295F;
        PushConstants push{{
            0.62F + 0.38F * std::sin(phase),
            0.62F + 0.38F * std::sin(phase + 2.094F),
            0.62F + 0.38F * std::sin(phase + 4.188F),
            1.0F},
            workload.drawsPerFrame > 1 ? (static_cast<float>(draw % 9U) - 4.0F) * 0.008F : 0.0F};
        vkCmdPushConstants(
            probe.commandBuffer,
            probe.pipelineLayout,
            VK_SHADER_STAGE_VERTEX_BIT | VK_SHADER_STAGE_FRAGMENT_BIT,
            0,
            sizeof(push),
            &push
        );
        vkCmdDraw(probe.commandBuffer, 3, 1, 0, 0);
    }
    vkCmdEndRenderPass(probe.commandBuffer);
    if (probe.cmdBeginLabel && probe.cmdEndLabel) probe.cmdEndLabel(probe.commandBuffer);
    if (probe.hasTimestamps) {
        vkCmdWriteTimestamp(probe.commandBuffer, VK_PIPELINE_STAGE_BOTTOM_OF_PIPE_BIT, probe.timestampPool, 1);
    }
    if (!check(probe, vkEndCommandBuffer(probe.commandBuffer), "vkEndCommandBuffer(frame)")) return false;

    const VkPipelineStageFlags waitStage = VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT;
    VkSubmitInfo submit{VK_STRUCTURE_TYPE_SUBMIT_INFO};
    submit.waitSemaphoreCount = 1;
    submit.pWaitSemaphores = &probe.imageAvailable;
    submit.pWaitDstStageMask = &waitStage;
    submit.commandBufferCount = 1;
    submit.pCommandBuffers = &probe.commandBuffer;

    const uint64_t transportWorkId = frame + 1;
    const VkSemaphore signalSemaphores[2] = {probe.renderFinished, probe.timelineSemaphore};
    const uint64_t signalValues[2] = {0, transportWorkId};

    VkTimelineSemaphoreSubmitInfo timelineSubmitInfo{VK_STRUCTURE_TYPE_TIMELINE_SEMAPHORE_SUBMIT_INFO};
    timelineSubmitInfo.signalSemaphoreValueCount = 2;
    timelineSubmitInfo.pSignalSemaphoreValues = signalValues;

    if (probe.timelineSemaphoreAvailable) {
        submit.pNext = &timelineSubmitInfo;
        submit.signalSemaphoreCount = 2;
        submit.pSignalSemaphores = signalSemaphores;
    } else {
        submit.signalSemaphoreCount = 1;
        submit.pSignalSemaphores = &probe.renderFinished;
    }
    if (probe.queueBeginLabel && probe.queueEndLabel) {
        VkDebugUtilsLabelEXT queueLabel{VK_STRUCTURE_TYPE_DEBUG_UTILS_LABEL_EXT};
        queueLabel.pLabelName = label.c_str();
        queueLabel.color[0] = 0.91F;
        queueLabel.color[1] = 0.31F;
        queueLabel.color[2] = 0.44F;
        queueLabel.color[3] = 1.0F;
        probe.queueBeginLabel(probe.queue, &queueLabel);
    }
    const VkResult submitted = vkQueueSubmit(probe.queue, 1, &submit, probe.frameFence);
    if (probe.queueBeginLabel && probe.queueEndLabel) probe.queueEndLabel(probe.queue);
    if (!check(probe, submitted, "vkQueueSubmit(frame)")) return false;
    VkPresentInfoKHR present{VK_STRUCTURE_TYPE_PRESENT_INFO_KHR};
    present.waitSemaphoreCount = 1;
    present.pWaitSemaphores = &probe.renderFinished;
    present.swapchainCount = 1;
    present.pSwapchains = &probe.swapchain;
    present.pImageIndices = &imageIndex;
    const VkResult presented = vkQueuePresentKHR(probe.queue, &present);
    if (presented != VK_SUCCESS && presented != VK_SUBOPTIMAL_KHR) {
        return check(probe, presented, "vkQueuePresentKHR");
    }
    if (workload.queueWaitIdle) {
        const auto waitStart = std::chrono::steady_clock::now();
        if (!check(probe, vkQueueWaitIdle(probe.queue), "vkQueueWaitIdle(workload)")) return false;
        *queueWaitMS = std::chrono::duration<double, std::milli>(std::chrono::steady_clock::now() - waitStart).count();
    }
    *cpuMS = std::chrono::duration<double, std::milli>(std::chrono::steady_clock::now() - cpuStart).count();
    return true;
}

void runProbe(android_app* app) {
    while (!app->destroyRequested && app->window == nullptr) {
        int events = 0;
        android_poll_source* source = nullptr;
        const int result = ALooper_pollOnce(100, nullptr, &events, reinterpret_cast<void**>(&source));
        if (result >= 0 && source) source->process(app, source);
    }
    if (app->destroyRequested || !app->window) return;

    VulkanProbe probe{};
    probe.app = app;
    if (!initialize(probe)) {
        PROBE_ERROR("{\"event\":\"complete\",\"state\":\"FAILED_INITIALIZATION\",\"errors\":%llu}", static_cast<unsigned long long>(probe.errorCount));
        destroy(probe);
        ANativeActivity_finish(app->activity);
        return;
    }

    const std::string profile = property("debug.tftmac.probe.profile", "control");
    const bool smoke = property("debug.tftmac.probe.smoke", "0") == "1";
    const double warmupSeconds = smoke ? 2.0 : 30.0;
    const double workloadSeconds = smoke ? 3.0 : 60.0;
    PROBE_LOG(
        "{\"event\":\"start\",\"contract\":\"TFTMAC_VULKAN_PROBE_WORKLOAD_V1\",\"profile\":\"%s\",\"mode\":\"%s\",\"warmup_seconds\":%.0f,\"workload_seconds\":%.0f}",
        profile.c_str(), smoke ? "NON_COMPARABLE_SMOKE" : "SEALED_CAMPAIGN", warmupSeconds, workloadSeconds
    );

    using Clock = std::chrono::steady_clock;
    size_t workloadIndex = 0;
    bool warmingUp = true;
    uint64_t globalFrame = 0;
    uint64_t windowIndex = 0;
    uint64_t windowChecksum = 1469598103934665603ULL;
    auto phaseStart = Clock::now();
    auto windowStart = phaseStart;
    std::vector<double> cpuSamples;
    std::vector<double> gpuSamples;
    std::vector<double> queueWaitSamples;

    while (!app->destroyRequested && workloadIndex < kWorkloads.size()) {
        int events = 0;
        android_poll_source* source = nullptr;
        while (ALooper_pollOnce(0, nullptr, &events, reinterpret_cast<void**>(&source)) >= 0) {
            if (source) source->process(app, source);
            if (app->destroyRequested) break;
        }
        if (app->destroyRequested || app->window == nullptr) break;
        const Workload& workload = warmingUp ? kWorkloads[0] : kWorkloads[workloadIndex];
        double cpuMS = 0.0;
        double gpuMS = 0.0;
        double queueWaitMS = 0.0;
        uint64_t identity = 0;
        if (!renderFrame(probe, workload, profile, globalFrame, &cpuMS, &gpuMS, &queueWaitMS, &identity)) break;
        ++globalFrame;
        cpuSamples.push_back(cpuMS);
        if (gpuMS > 0.0) gpuSamples.push_back(gpuMS);
        if (queueWaitMS > 0.0) queueWaitSamples.push_back(queueWaitMS);
        windowChecksum = fnv1a64(&identity, sizeof(identity), windowChecksum);

        const auto now = Clock::now();
        const double windowElapsed = std::chrono::duration<double>(now - windowStart).count();
        if (windowElapsed >= 1.0) {
            const double cpuSum = std::accumulate(cpuSamples.begin(), cpuSamples.end(), 0.0);
            const double fps = cpuSamples.size() / windowElapsed;
            const double onePercentLow = cpuSamples.empty() ? 0.0 : 1000.0 / std::max(0.001, percentile(cpuSamples, 0.99));
            PROBE_LOG(
                "{\"event\":\"window\",\"profile\":\"%s\",\"phase\":\"%s\",\"workload\":\"%s\",\"window_index\":%llu,\"frames\":%zu,\"fps\":%.4f,\"one_percent_low_fps\":%.4f,\"cpu_mean_ms\":%.4f,\"cpu_p95_ms\":%.4f,\"cpu_p99_ms\":%.4f,\"cpu_max_ms\":%.4f,\"gpu_mean_ms\":%.4f,\"gpu_p99_ms\":%.4f,\"queue_wait_p99_ms\":%.4f,\"command_checksum\":\"%016llx\",\"error_count\":%llu}",
                profile.c_str(),
                warmingUp ? "warmup" : "measurement",
                workload.id,
                static_cast<unsigned long long>(windowIndex++),
                cpuSamples.size(),
                fps,
                onePercentLow,
                cpuSamples.empty() ? 0.0 : cpuSum / cpuSamples.size(),
                percentile(cpuSamples, 0.95),
                percentile(cpuSamples, 0.99),
                cpuSamples.empty() ? 0.0 : *std::max_element(cpuSamples.begin(), cpuSamples.end()),
                gpuSamples.empty() ? 0.0 : std::accumulate(gpuSamples.begin(), gpuSamples.end(), 0.0) / gpuSamples.size(),
                percentile(gpuSamples, 0.99),
                percentile(queueWaitSamples, 0.99),
                static_cast<unsigned long long>(windowChecksum),
                static_cast<unsigned long long>(probe.errorCount)
            );
            cpuSamples.clear();
            gpuSamples.clear();
            queueWaitSamples.clear();
            windowChecksum = 1469598103934665603ULL;
            windowStart = now;
        }

        const double phaseElapsed = std::chrono::duration<double>(now - phaseStart).count();
        const double phaseDuration = warmingUp ? warmupSeconds : workloadSeconds;
        if (phaseElapsed >= phaseDuration) {
            PROBE_LOG(
                "{\"event\":\"phase_complete\",\"phase\":\"%s\",\"workload\":\"%s\",\"global_frames\":%llu}",
                warmingUp ? "warmup" : "measurement",
                workload.id,
                static_cast<unsigned long long>(globalFrame)
            );
            if (warmingUp) {
                warmingUp = false;
            } else {
                ++workloadIndex;
            }
            phaseStart = now;
            windowStart = now;
            cpuSamples.clear();
            gpuSamples.clear();
            queueWaitSamples.clear();
            windowChecksum = 1469598103934665603ULL;
        }
    }

    const bool complete = workloadIndex == kWorkloads.size() && probe.errorCount == 0;
    PROBE_LOG(
        "{\"event\":\"complete\",\"state\":\"%s\",\"profile\":\"%s\",\"frames\":%llu,\"errors\":%llu}",
        complete ? "PASS" : "FAILED_RUNTIME",
        profile.c_str(),
        static_cast<unsigned long long>(globalFrame),
        static_cast<unsigned long long>(probe.errorCount)
    );
    destroy(probe);
    ANativeActivity_finish(app->activity);
}

}  // namespace

void android_main(android_app* app) {
    runProbe(app);
}
