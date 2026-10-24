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

// The styles, in the order of Backgrounds.Styles: the kernel that paints each.
static const char *const kernel_names[] = {
    "watercolour", "paper", "inkwash", "mist", "grain", "marbling", "riso", "contours", "bauhaus"
};
#define STYLE_COUNT ((int)(sizeof kernel_names / sizeof kernel_names[0]))

static float fract_of(float x)
{
    float p = fmodf(x, 1.0f);
    return p < 0.0f ? p + 1.0f : p;
}

// The painting's base hue, 0 .. 1, from its style and seed: the one place it is chosen, so that the
// shader and the program's colours agree on it. Some styles keep to hues that suit them.
float bonxie_background_hue(int style, float seed)
{
    float p = fract_of(seed * 3.7f * 0.1031f);
    p *= p + 33.33f;
    p *= p + p;
    float base = fract_of(p);
    switch (style) {
        case 1: return 0.04f + 0.08f * base;           // paper: warm, from vellum to parchment
        case 2: return 0.52f + 0.12f * base;           // ink wash: blue-grey
        case 8: {                                      // bauhaus: red, yellow or blue to lead
            static const float leads[] = {0.0f, 0.12f, 0.6f};
            return leads[(int)(base * 2.999f)];
        }
        default: return base;
    }
}

// How bold the colours are, from the seed alone, whatever the style: 0 pastel, 1 vivid, 2 rich (deep and
// saturated), 3 muted. Pastel is the commonest, as it was the only one.
int bonxie_background_mood(float seed)
{
    float p = fract_of(seed * 9.1f * 0.1031f + 0.11f);
    p *= p + 33.33f;
    p *= p + p;
    float u = fract_of(p);
    return u < 0.40f ? 0 : (u < 0.65f ? 1 : (u < 0.85f ? 2 : 3));
}

@interface BonxieBackground : NSObject
@property(nonatomic, strong) id<MTLDevice> device;
@property(nonatomic, strong) id<MTLCommandQueue> queue;
@property(nonatomic, strong) NSMutableArray<id<MTLComputePipelineState>> *pipelines;
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
            fprintf(stderr, "Backgrounds: no Metal device\n");
            return NULL;
        }
        NSError *error = nil;
        NSString *text = [NSString stringWithUTF8String:source];
        if (!text) return NULL;
        id<MTLLibrary> library = [background.device newLibraryWithSource:text options:nil error:&error];
        if (!library) {
            fprintf(stderr, "Backgrounds Metal library: %s\n", error.localizedDescription.UTF8String ?: "unavailable");
            return NULL;
        }
        background.pipelines = [NSMutableArray new];
        for (int style = 0; style < STYLE_COUNT; style++) {
            id<MTLFunction> function = [library newFunctionWithName:[NSString stringWithUTF8String:kernel_names[style]]];
            id<MTLComputePipelineState> pipeline =
                function ? [background.device newComputePipelineStateWithFunction:function error:&error] : nil;
            if (!pipeline) {
                fprintf(stderr, "Backgrounds Metal pipeline %s: %s\n", kernel_names[style],
                        error.localizedDescription.UTF8String ?: "unavailable");
            }
            [background.pipelines addObject:pipeline ?: (id)[NSNull null]];
        }
        background.queue = [background.device newCommandQueue];
        if (!background.queue) return NULL;
        return (__bridge_retained void *)background;
    }
}

// The returned pixels stay valid until the next render or release. SDL copies
// them immediately. Dark asks for luminous pigments on a dark ground, not light. Size-dependent storage lives on the heap, never Ada's stack.
const void *bonxie_background_render(void *handle, int style, float seed, int width, int height, int dark)
{
    if (!handle || style < 0 || style >= STYLE_COUNT || width <= 0 || height <= 0 || !isfinite(seed)) return NULL;
    @autoreleasepool {
        BonxieBackground *background = (__bridge BonxieBackground *)handle;
        id<MTLComputePipelineState> pipeline = background.pipelines[style];
        if ((id)pipeline == (id)[NSNull null]) return NULL;
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
            uint32_t mood;
        } parameters = {(uint32_t)width, (uint32_t)height, seed, bonxie_background_hue(style, seed), dark ? 1u : 0u,
                        (uint32_t)bonxie_background_mood(seed)};
        _Static_assert(sizeof parameters == 24, "MSL parameter layout must match");
        id<MTLCommandBuffer> command = [background.queue commandBuffer];
        id<MTLComputeCommandEncoder> encoder = [command computeCommandEncoder];
        if (!command || !encoder) return NULL;
        [encoder setComputePipelineState:pipeline];
        [encoder setBuffer:background.pixels offset:0 atIndex:0];
        [encoder setBytes:&parameters length:sizeof parameters atIndex:1];
        NSUInteger across = pipeline.threadExecutionWidth;
        NSUInteger down = MIN((NSUInteger)8, pipeline.maxTotalThreadsPerThreadgroup / across);
        MTLSize group = MTLSizeMake(across, down, 1);
        MTLSize groups = MTLSizeMake(((NSUInteger)width + across - 1) / across,
                                     ((NSUInteger)height + down - 1) / down, 1);
        [encoder dispatchThreadgroups:groups threadsPerThreadgroup:group];
        [encoder endEncoding];
        [command commit];
        [command waitUntilCompleted];
        if (command.status != MTLCommandBufferStatusCompleted) {
            fprintf(stderr, "Backgrounds Metal render: %s\n", command.error.localizedDescription.UTF8String);
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
