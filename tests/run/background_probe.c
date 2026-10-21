// See TESTING.md for the Metal build and run commands.
#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

extern void *bonxie_background_create(const char *);
extern const void *bonxie_background_render(void *, float, int, int, int);
extern float bonxie_background_hue(float);
extern void bonxie_background_release(void *);
extern float bonxie_background_seed(void);

int main(int argc, char **argv)
{
    assert(argc == 2);
    FILE *file = fopen(argv[1], "rb");
    assert(file);
    assert(!fseek(file, 0, SEEK_END));
    long length = ftell(file);
    assert(length > 0);
    rewind(file);
    char *source = malloc((size_t)length + 1);
    assert(source);
    assert(fread(source, 1, (size_t)length, file) == (size_t)length);
    source[length] = 0;
    fclose(file);
    void *background = bonxie_background_create(source);
    free(source);
    assert(background);
    enum { width = 321, height = 203, bytes = width * height * 4 };
    static unsigned char first[bytes];
    float seed = bonxie_background_seed();
    assert(seed >= 0.0f && seed < 256.0f);
    const unsigned char *pixels = bonxie_background_render(background, seed, width, height, 0);
    assert(pixels);
    memcpy(first, pixels, bytes);
    pixels = bonxie_background_render(background, seed, width, height, 0);
    assert(pixels && !memcmp(first, pixels, bytes));
    pixels = bonxie_background_render(background, seed + 0.127f, width, height, 0);
    assert(pixels && memcmp(first, pixels, bytes));
    for (int i = 3; i < bytes; i += 4) assert(first[i] == 255);
    assert(bonxie_background_render(background, seed, height, width, 0));
    // The hue is a function of the seed alone, in 0 .. 1, and differs with it.
    float hue = bonxie_background_hue(seed);
    assert(hue >= 0.0f && hue < 1.0f && hue == bonxie_background_hue(seed));
    assert(hue != bonxie_background_hue(seed + 0.127f));
    // Dark is its own picture, opaque, and darker on the whole than the light.
    pixels = bonxie_background_render(background, seed, width, height, 1);
    assert(pixels && memcmp(first, pixels, bytes));
    long light = 0, dim = 0;
    for (int i = 0; i < bytes; i += 4) {
        assert(pixels[i + 3] == 255);
        light += first[i] + first[i + 1] + first[i + 2];
        dim += pixels[i] + pixels[i + 1] + pixels[i + 2];
    }
    // Ink is read straight on it: no light pixel under 62% brightness, no dark one over 42%.
    for (int i = 0; i < bytes; i += 4) {
        assert(0.2126f * first[i] + 0.7152f * first[i + 1] + 0.0722f * first[i + 2] >= 0.62f * 255);
        assert(0.2126f * pixels[i] + 0.7152f * pixels[i + 1] + 0.0722f * pixels[i + 2] <= 0.42f * 255);
    }
    assert(dim * 2 < light);  // whatever the seed, the dark is well under half the light
    file = fopen("/tmp/bonxie-background-dark.ppm", "wb");
    assert(file);
    fprintf(file, "P6\n%d %d\n255\n", width, height);
    for (int i = 0; i < bytes; i += 4) fwrite(pixels + i, 1, 3, file);
    fclose(file);
    // Exceed the old 1536-pixel cap in both directions; check the final
    // pixel to catch incomplete dispatches at non-multiple group sizes.
    pixels = bonxie_background_render(background, seed, 2049, 1601, 0);
    assert(pixels && pixels[(2049 * 1601 - 1) * 4 + 3] == 255);
    assert(!bonxie_background_render(background, seed, 0, height, 0));
    assert(!bonxie_background_render(background, seed, width, -1, 0));
    assert(!bonxie_background_render(NULL, seed, width, height, 0));
    // Resize back and ensure that changing size did not change the seed.
    pixels = bonxie_background_render(background, seed, width, height, 0);
    assert(pixels && !memcmp(first, pixels, bytes));
    bonxie_background_release(background);
    bonxie_background_release(NULL);
    file = fopen("/tmp/bonxie-background.ppm", "wb");
    assert(file);
    fprintf(file, "P6\n%d %d\n255\n", width, height);
    for (int i = 0; i < bytes; i += 4) fwrite(first + i, 1, 3, file);
    fclose(file);
    puts("Metal watercolour: compiled, repeatable, time-seeded, opaque, light and dark, resized beyond 1536, invalid sizes rejected.");
}
