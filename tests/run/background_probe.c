// See TESTING.md for the Metal build and run commands.
#include <assert.h>
#include <stdio.h>
#include <math.h>
#include <stdlib.h>
#include <string.h>

extern void *bonxie_background_create(const char *);
extern const void *bonxie_background_render(void *, int, float, int, int, int);
extern float bonxie_background_hue(int, float);
extern int bonxie_background_mood(float);
extern void bonxie_background_release(void *);
extern float bonxie_background_seed(void);

enum { styles = 9, width = 321, height = 203, bytes = width * height * 4 };
static const char *const names[styles] = {
    "watercolour", "paper", "inkwash", "mist", "grain", "marbling", "riso", "contours", "bauhaus"
};

// Relative luminance, as the shader holds it in a band: ink on a picture is read by it.
static float luma(const unsigned char *pixel)
{
    return 0.2126f * powf(pixel[0] / 255.0f, 2.2f) + 0.7152f * powf(pixel[1] / 255.0f, 2.2f)
         + 0.0722f * powf(pixel[2] / 255.0f, 2.2f);
}

static float chroma(const unsigned char *pixel)
{
    int high = pixel[0] > pixel[1] ? pixel[0] : pixel[1];
    int low = pixel[0] < pixel[1] ? pixel[0] : pixel[1];
    if (pixel[2] > high) high = pixel[2];
    if (pixel[2] < low) low = pixel[2];
    return (high - low) / 255.0f;
}

#define LIGHT_FLOOR 0.325f
#define DARK_CEILING 0.135f

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

        // Ink is read straight on it: no light pixel dimmer than the floor, no dark one brighter than the ceiling.
        for (int i = 0; i < bytes; i += 4) {
            assert(first[i + 3] == 255);
            if (luma(first + i) < LIGHT_FLOOR) {
                fprintf(stderr, "%s: light pixel %d has luminance %.2f\n", names[style], i / 4, luma(first + i));
                abort();
            }
        }
        pixels = bonxie_background_render(background, style, seed, width, height, 1);
        assert(pixels && memcmp(first, pixels, bytes));
        double light = 0, dim = 0;
        for (int i = 0; i < bytes; i += 4) {
            assert(pixels[i + 3] == 255);
            if (luma(pixels + i) > DARK_CEILING) {
                fprintf(stderr, "%s: dark pixel %d has luminance %.2f\n", names[style], i / 4, luma(pixels + i));
                abort();
            }
            light += luma(first + i);
            dim += luma(pixels + i);
        }
        assert(dim < light);
        save(names[style], 1, pixels);
    }

    // The same of many seeds, so of every mood, in every style, light and dark; and the moods differ in
    // how saturated they are (taken in the watercolour, which is coloured the most evenly).
    double chroma_of[4] = {0, 0, 0, 0};
    int count_of[4] = {0, 0, 0, 0};
    for (int k = 0; k < 40; k++) {
        float other = 0.31f + k * 6.137f;
        int mood = bonxie_background_mood(other);
        assert(mood >= 0 && mood < 4 && mood == bonxie_background_mood(other));
        for (int style = 0; style < styles; style++) {
            for (int dark = 0; dark < 2; dark++) {
                const unsigned char *pixels = bonxie_background_render(background, style, other, 160, 100, dark);
                assert(pixels);
                double total = 0;
                for (int i = 0; i < 160 * 100 * 4; i += 4) {
                    float y = luma(pixels + i);
                    if (dark ? y > DARK_CEILING : y < LIGHT_FLOOR) {
                        fprintf(stderr, "%s, seed %.2f (mood %d), %s: luminance %.3f\n", names[style], other, mood,
                                dark ? "dark" : "light", y);
                        abort();
                    }
                    total += chroma(pixels + i);
                }
                if (style == 0 && !dark) {
                    chroma_of[mood] += total / (160 * 100);
                    count_of[mood]++;
                }
            }
        }
    }
    for (int mood = 0; mood < 4; mood++) assert(count_of[mood] > 0);
    double pastel = chroma_of[0] / count_of[0], vivid = chroma_of[1] / count_of[1];
    double rich = chroma_of[2] / count_of[2], muted = chroma_of[3] / count_of[3];
    fprintf(stderr, "mean chroma: pastel %.3f vivid %.3f rich %.3f muted %.3f\n", pastel, vivid, rich, muted);
    assert(vivid > 1.4 * pastel && rich > 1.2 * pastel && muted < 0.8 * pastel);

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
