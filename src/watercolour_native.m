#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#include <math.h>
#include <stdint.h>
#include <stdio.h>
#include <time.h>

// Only the clock supplies entropy. Keep the float small enough for shader noise.
float bonxie_background_seed(void)
{
    struct timespec now;
    clock_gettime(CLOCK_REALTIME, &now);
    return (float)fmod((double)now.tv_sec * 1000000.0 + now.tv_nsec / 1000.0, 16777216.0) / 65536.0;
}

// The painting's base hue, 0 .. 1, from its seed: the one place it is chosen, so
// that the shader and the program's colours agree on it.
float bonxie_background_hue(float seed)
{
    float p = fmodf(seed * 3.7f * 0.1031f, 1.0f);
    if (p < 0.0f) p += 1.0f;
    p *= p + 33.33f;
    p *= p + p;
    p = fmodf(p, 1.0f);
    return p < 0.0f ? p + 1.0f : p;
}

@interface BonxieBackground : NSObject
@property(nonatomic, strong) id<MTLDevice> device;
@property(nonatomic, strong) id<MTLCommandQueue> queue;
@property(nonatomic, strong) id<MTLComputePipelineState> pipeline;
@property(nonatomic, strong) id<MTLBuffer> pixels;
@end
@implementation BonxieBackground
@end

void *bonxie_background_create(const char *source)
{
    if (!source) return NULL;
    @autoreleasepool {
        BonxieBackground *background = [BonxieBackground new];
        background.device = MTLCreateSystemDefaultDevice();
        if (!background.device) {
            fprintf(stderr, "Watercolour: no Metal device\n");
            return NULL;
        }
        NSError *error = nil;
        NSString *text = [NSString stringWithUTF8String:source];
        if (!text) return NULL;
        id<MTLLibrary> library = [background.device newLibraryWithSource:text options:nil error:&error];
        id<MTLFunction> function = [library newFunctionWithName:@"watercolour"];
        if (function) {
            background.pipeline = [background.device newComputePipelineStateWithFunction:function error:&error];
        }
        background.queue = [background.device newCommandQueue];
        if (!background.pipeline || !background.queue) {
            fprintf(stderr, "Watercolour Metal pipeline: %s\n", error.localizedDescription.UTF8String ?: "unavailable");
            return NULL;
        }
        return (__bridge_retained void *)background;
    }
}

// The returned pixels stay valid until the next render or release. SDL copies
// them immediately. Dark asks for luminous pigments on a dark ground, not light. Size-dependent storage lives on the heap, never Ada's stack.
const void *bonxie_background_render(void *handle, float seed, int width, int height, int dark)
{
    if (!handle || width <= 0 || height <= 0 || !isfinite(seed)) return NULL;
    @autoreleasepool {
        BonxieBackground *background = (__bridge BonxieBackground *)handle;
        size_t pitch = (size_t)width * 4;
        if ((size_t)height > SIZE_MAX / pitch) return NULL;
        size_t bytes = pitch * (size_t)height;
        if (bytes > background.device.maxBufferLength) return NULL;
        if (!background.pixels || background.pixels.length != bytes) {
            background.pixels = [background.device newBufferWithLength:bytes options:MTLResourceStorageModeShared];
        }
        if (!background.pixels) return NULL;
        struct {
            uint32_t width, height;
            float seed;
            float hue;
            uint32_t dark;
            uint32_t padding;
        } parameters = {(uint32_t)width, (uint32_t)height, seed, bonxie_background_hue(seed), dark ? 1u : 0u, 0};
        _Static_assert(sizeof parameters == 24, "MSL parameter layout must match");
        id<MTLCommandBuffer> command = [background.queue commandBuffer];
        id<MTLComputeCommandEncoder> encoder = [command computeCommandEncoder];
        if (!command || !encoder) return NULL;
        [encoder setComputePipelineState:background.pipeline];
        [encoder setBuffer:background.pixels offset:0 atIndex:0];
        [encoder setBytes:&parameters length:sizeof parameters atIndex:1];
        NSUInteger across = background.pipeline.threadExecutionWidth;
        NSUInteger down = MIN((NSUInteger)8, background.pipeline.maxTotalThreadsPerThreadgroup / across);
        MTLSize group = MTLSizeMake(across, down, 1);
        MTLSize groups = MTLSizeMake(((NSUInteger)width + across - 1) / across,
                                     ((NSUInteger)height + down - 1) / down, 1);
        [encoder dispatchThreadgroups:groups threadsPerThreadgroup:group];
        [encoder endEncoding];
        [command commit];
        [command waitUntilCompleted];
        if (command.status != MTLCommandBufferStatusCompleted) {
            fprintf(stderr, "Watercolour Metal render: %s\n", command.error.localizedDescription.UTF8String);
            return NULL;
        }
        return background.pixels.contents;
    }
}

void bonxie_background_release(void *handle)
{
    if (handle) {
        @autoreleasepool {
            __unused BonxieBackground *background = (__bridge_transfer BonxieBackground *)handle;
        }
    }
}
