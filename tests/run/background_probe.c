// See TESTING.md for the Metal build and run commands.
#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

extern void *bonxie_background_create(const char *);
extern const void *bonxie_background_render(void *, float, int, int);
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
    const unsigned char *pixels = bonxie_background_render(background, seed, width, height);
    assert(pixels);
    memcpy(first, pixels, bytes);
    pixels = bonxie_background_render(background, seed, width, height);
    assert(pixels && !memcmp(first, pixels, bytes));
    pixels = bonxie_background_render(background, seed + 0.127f, width, height);
    assert(pixels && memcmp(first, pixels, bytes));
    for (int i = 3; i < bytes; i += 4) assert(first[i] == 255);
    assert(bonxie_background_render(background, seed, height, width));
    // Exceed the old 1536-pixel cap in both directions; check the final
    // pixel to catch incomplete dispatches at non-multiple group sizes.
    pixels = bonxie_background_render(background, seed, 2049, 1601);
    assert(pixels && pixels[(2049 * 1601 - 1) * 4 + 3] == 255);
    assert(!bonxie_background_render(background, seed, 0, height));
    assert(!bonxie_background_render(background, seed, width, -1));
    assert(!bonxie_background_render(NULL, seed, width, height));
    // Resize back and ensure that changing size did not change the seed.
    pixels = bonxie_background_render(background, seed, width, height);
    assert(pixels && !memcmp(first, pixels, bytes));
    bonxie_background_release(background);
    bonxie_background_release(NULL);
    file = fopen("/tmp/bonxie-background.ppm", "wb");
    assert(file);
    fprintf(file, "P6\n%d %d\n255\n", width, height);
    for (int i = 0; i < bytes; i += 4) fwrite(first + i, 1, 3, file);
    fclose(file);
    puts("Metal watercolour: compiled, repeatable, time-seeded, opaque, resized beyond 1536, invalid sizes rejected.");
}
