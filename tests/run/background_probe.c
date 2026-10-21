// See TESTING.md for the Metal build and run commands.
#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

extern void *bonxie_background_create(const char *);
extern const void *bonxie_background_render(void *, int, float, int, int, int);
extern float bonxie_background_hue(int, float);
extern void bonxie_background_release(void *);
extern float bonxie_background_seed(void);

enum { styles = 9, width = 321, height = 203, bytes = width * height * 4 };
static const char *const names[styles] = {
    "watercolour", "paper", "inkwash", "mist", "grain", "marbling", "riso", "contours", "bauhaus"
};

static float luma(const unsigned char *pixel)
{
    return 0.2126f * pixel[0] + 0.7152f * pixel[1] + 0.0722f * pixel[2];
}

static void save(const char *name, int dark, const unsigned char *pixels)
{
    char path[128];
    snprintf(path, sizeof path, "/tmp/bonxie-background-%s-%s.ppm", name, dark ? "dark" : "light");
    FILE *file = fopen(path, "wb");
    assert(file);
    fprintf(file, "P6\n%d %d\n255\n", width, height);
    for (int i = 0; i < bytes; i += 4) fwrite(pixels + i, 1, 3, file);
    fclose(file);
}

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
    static unsigned char first[bytes];
    float seed = bonxie_background_seed();
    assert(seed >= 0.0f && seed < 256.0f);

    for (int style = 0; style < styles; style++) {
        // Repeatable for a seed, a different picture for another, and a hue that follows the seed.
        const unsigned char *pixels = bonxie_background_render(background, style, seed, width, height, 0);
        assert(pixels);
        memcpy(first, pixels, bytes);
        save(names[style], 0, first);
        pixels = bonxie_background_render(background, style, seed, width, height, 0);
        assert(pixels && !memcmp(first, pixels, bytes));
        pixels = bonxie_background_render(background, style, seed + 0.127f, width, height, 0);
        assert(pixels && memcmp(first, pixels, bytes));
        float hue = bonxie_background_hue(style, seed);
        assert(hue >= 0.0f && hue < 1.0f && hue == bonxie_background_hue(style, seed));

        // Ink is read straight on it: no light pixel under 62% brightness, no dark one over 42%.
        for (int i = 0; i < bytes; i += 4) {
            assert(first[i + 3] == 255);
            if (luma(first + i) < 0.62f * 255) {
                fprintf(stderr, "%s: light pixel %d is %.0f%%\n", names[style], i / 4, 100 * luma(first + i) / 255);
                abort();
            }
        }
        pixels = bonxie_background_render(background, style, seed, width, height, 1);
        assert(pixels && memcmp(first, pixels, bytes));
        double light = 0, dim = 0;
        for (int i = 0; i < bytes; i += 4) {
            assert(pixels[i + 3] == 255);
            if (luma(pixels + i) > 0.42f * 255) {
                fprintf(stderr, "%s: dark pixel %d is %.0f%%\n", names[style], i / 4, 100 * luma(pixels + i) / 255);
                abort();
            }
            light += luma(first + i);
            dim += luma(pixels + i);
        }
        assert(dim < light);
        save(names[style], 1, pixels);
    }

    // The sizes and the refusals.
    assert(bonxie_background_render(background, 0, seed, height, width, 0));
    const unsigned char *pixels = bonxie_background_render(background, 0, seed, 2049, 1601, 0);
    assert(pixels && pixels[(2049 * 1601 - 1) * 4 + 3] == 255);
    assert(!bonxie_background_render(background, 0, seed, 0, height, 0));
    assert(!bonxie_background_render(background, 0, seed, width, -1, 0));
    assert(!bonxie_background_render(background, styles, seed, width, height, 0));
    assert(!bonxie_background_render(background, -1, seed, width, height, 0));
    assert(!bonxie_background_render(NULL, 0, seed, width, height, 0));
    bonxie_background_release(background);
    bonxie_background_release(NULL);
    puts("Metal backgrounds: every style compiled, repeatable, time-seeded, opaque, light and dark, readable under ink, "
         "resized beyond 1536, invalid sizes and styles rejected.");
}
