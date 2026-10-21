#include <metal_stdlib>
using namespace metal;

// Procedural backgrounds, one kernel to each style, rendered at the window's pixel size and cached
// until it changes. Every style paints a light picture and a dark one (`dark`), and is veiled toward
// its ground at the end so that the ink drawn straight on it can always be read: no light pixel is
// under 62% bright and no dark one over 42% (the probe in tests/run checks every style).
struct Background_Parameters {
    uint2 resolution;
    float seed;
    float hue;     // the base hue, chosen by the program so that its colours can follow it
    uint dark;     // 1 for a dark picture, 0 for a light one
    uint mood;     // 0 pastel, 1 vivid, 2 rich, 3 muted: how bold the colours are, from the seed
};

// ---------- hashing / noise ----------
float hash11(float p){ p = fract(p * .1031); p *= p + 33.33; p *= p + p; return fract(p); }
float hash21(float2 p){ float3 p3 = fract(float3(p.xyx) * .1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z); }
float2  hash22(float2 p){ float3 p3 = fract(float3(p.xyx) * float3(.1031, .1030, .0973));
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.xx + p3.yz) * p3.zy); }

float vnoise(float2 p){
    float2 i = floor(p), f = fract(p);
    float2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash21(i),              hash21(i + float2(1, 0)), u.x),
               mix(hash21(i + float2(0, 1)), hash21(i + float2(1, 1)), u.x), u.y);
}

constant float2x2 ROT = float2x2(float2(0.8, -0.6), float2(0.6, 0.8));

float fbm(float2 p){
    float a = 0.5, s = 0.0;
    for (int i = 0; i < 5; i++){
        s += a * vnoise(p);
        p = ROT * p * 2.03 + 17.0;
        a *= 0.5;
    }
    return s / 0.96875;
}

float3 hsv2rgb(float3 c){
    float3 p = abs(fract(c.xxx + float3(0.0, 2.0/3.0, 1.0/3.0)) * 6.0 - 3.0);
    return c.z * mix(float3(1.0), clamp(p - 1.0, 0.0, 1.0), c.y);
}

float paperTex(float2 p){
    return 0.50 * vnoise(p * 260.0)
         + 0.30 * vnoise(p * 520.0 + 7.3)
         + 0.20 * vnoise(p * 110.0 + 3.1);
}

float2x2 rotation(float angle){ float c = cos(angle), s = sin(angle); return float2x2(float2(c, -s), float2(s, c)); }

// What a style is given: p is centred, a unit tall; px is in pixels from the top left.
struct Scene {
    float2 p;
    float2 px;
    float2 resolution;
    float seed;
    float hue;
    bool dark;
    uint mood;
};

// A colour in hue, saturation and value, as bold as the mood says: pastels as they are written, vivid
// ones twice as saturated and brighter, rich ones deeper, muted ones half as saturated.
float3 hsvm(Scene s, float3 c){
    float sat = c.y, val = c.z;
    if (s.mood == 1u)      { sat = c.y * 2.1;  val = mix(c.z, 1.0, 0.35); }
    else if (s.mood == 2u) { sat = c.y * 1.7;  val = c.z * 0.82; }
    // The dark ones start low in value, and a bold colour wants more of it, or it is only black.
    if (s.dark && (s.mood == 1u || s.mood == 2u)) val = c.z * 1.9;
    else if (s.mood == 3u) { sat = c.y * 0.45; val = c.z * 0.97; }
    return hsv2rgb(float3(c.x, clamp(sat, 0.0, 1.0), clamp(val, 0.0, 1.0)));
}

// How much of the old toward-the-ground veil a mood keeps: bold colours would be washed out by it.
float soft_of(uint mood){ return mood == 1u ? 0.25 : (mood == 2u ? 0.35 : (mood == 3u ? 0.8 : 1.0)); }

// Where a picture sits, so that the ink drawn straight on it can be read. The picture is moved toward
// its ground (less for the bold moods), and then, in linear light, its brightness is held in a band --
// a light picture no darker than LIGHT_FLOOR, a dark one no brighter than DARK_CEILING, as relative
// luminance -- by scaling it, so that its hues and how saturated they are are kept.
#define LIGHT_FLOOR 0.34
#define DARK_CEILING 0.125

float luminance_of(float3 lin){ return dot(lin, float3(0.2126, 0.7152, 0.0722)); }

float3 finish(Scene s, float3 col, float3 ground, float light_amount, float dark_amount){
    col = mix(col, ground, soft_of(s.mood) * (s.dark ? dark_amount : light_amount));
    float3 lin = pow(clamp(col, 0.0, 1.0), float3(2.2));
    float y = max(luminance_of(lin), 1e-4);
    float wanted = s.dark ? DARK_CEILING * y : LIGHT_FLOOR + (1.0 - LIGHT_FLOOR) * y;
    float3 scaled = lin * (wanted / y);
    float top = max(scaled.x, max(scaled.y, scaled.z));
    if (top > 1.0){
        // Past white: keep the brightness, give up some of the saturation.
        scaled = mix(float3(wanted), scaled, (1.0 - wanted) / (top - wanted));
    }
    return pow(clamp(scaled, 0.0, 1.0), float3(1.0 / 2.2));
}

// ================= watercolour: soft pigment washes and splatter on textured paper =================
#define WASHES 6

float3 pastel(Scene s, float baseHue, float k, float r1, float r2, bool dark){
    float off;
    if      (k < 0.5) off = 0.00;
    else if (k < 1.5) off = 0.07;
    else if (k < 2.5) off = -0.09;
    else if (k < 3.5) off = 0.50;    // complementary accent
    else              off = 0.33;
    // Light: soft, high value, multiplied into the paper. Dark: deep and saturated, screened over the ground.
    float sat = dark ? 0.55 + 0.30 * r1 : 0.22 + 0.28 * r1;
    float val = dark ? 0.40 + 0.30 * r2 : 0.84 + 0.13 * r2;
    return hsvm(s, float3(fract(baseHue + off), sat, val));
}

float3 scene_watercolour(Scene s){
    float2 p = s.p;
    float seed = s.seed;
    bool dark = s.dark;
    float paper = paperTex(p);
    float3 paperCol = dark ? float3(0.075, 0.075, 0.09) : float3(0.972, 0.955, 0.918);
    float3 col = paperCol;
    float baseHue = s.hue;
    float3 lastPig = float3(dark ? 0.2 : 0.8);

    for (int i = 0; i < WASHES; i++){
        float fi = float(i);
        float2  s2 = float2(seed * 1.7 + fi, fi * 3.1 + 0.5);
        float3  h  = float3(hash21(s2), hash21(s2 + 11.3), hash21(s2 + 23.7));
        float2  h2 = hash22(s2 + 5.0);

        float2  c    = (h2 - 0.5) * float2(1.7, 1.0);
        float r    = 0.14 + 0.26 * h.x;
        float soft = mix(0.006, 0.06, h.y * h.y);
        float dens = 1.5 + 1.2 * h.z;
        if (i == 0){ r = 0.80; soft = 0.20; dens = 1.1; c = float2(0.0); }

        float3 pig = pastel(s, baseHue, floor(h.x * 4.99), h.y, h.z, dark);
        if (i == 0) pig = pastel(s, baseHue, 0.0, 0.2, 0.9, dark);

        float2 q = p + 0.38 * (float2(fbm(p * 1.4 + seed * 3.1 + fi * 7.0),
                                  fbm(p * 1.4 + float2(5.2, 1.3) + seed * 1.7 + fi * 5.0)) - 0.5);
        float ang = h2.x * 6.2831;
        float2  e   = rotation(ang) * (q - c) * float2(1.0, mix(0.55, 1.7, h.z));
        float d   = length(e) - r;
        d += (fbm(p * 5.0 + fi * 11.0 + seed) - 0.5) * 0.15;

        float mask  = 1.0 - smoothstep(-soft, soft * 0.5 + 0.004, d);
        float rim   = smoothstep(-0.05, -0.004, d) * mask;
        float body  = 0.35 + 0.50 * fbm(p * 3.0 + fi * 4.0 + seed * 2.0);
        float bloom = smoothstep(0.62, 0.78, fbm(p * 7.0 + fi * 9.0 + seed));
        body *= 1.0 - 0.40 * bloom * mask;
        float density = (mask * body + rim * (0.35 + 0.30 * fbm(p * 12.0 + fi))) * dens;

        float gran = (i == 0) ? 0.2 : mix(0.25, 0.8, h.y);
        density *= 1.0 + gran * (0.5 - paper) * 2.0;
        density = max(density, 0.0);

        // Pigment darkens paper by multiplying; light on a dark ground adds, by screening.
        col = dark ? 1.0 - (1.0 - col) * pow(1.0 - pig, float3(density * 0.9))
                   : col * pow(pig, float3(density));
        lastPig = pig;
    }

    {   // splatter
        float2  g  = p * 9.0 + seed * 13.0;
        float2  id = floor(g);
        float2  hh = hash22(id);
        float ex = hash21(id + 3.3);
        float2  pos = id + 0.2 + 0.6 * hh;
        float rr = 0.04 + 0.16 * ex * ex;
        float dd = length(g - pos) / rr;
        float on = step(0.93, hash21(id + seed));
        float dm = (1.0 - smoothstep(0.8, 1.0, dd)) * on;
        float rimD = smoothstep(0.45, 0.95, dd) * dm;
        float ds = (dm * 0.5 + rimD * 0.5) * (1.0 + 0.6 * (0.5 - paper));
        float3 spot = pow(dark ? 1.0 - lastPig : lastPig, float3(max(ds, 0.0) * 2.0));
        col = dark ? 1.0 - (1.0 - col) * spot : col * spot;
    }

    col *= dark ? 0.90 + 0.20 * paper : 0.940 + 0.105 * paper;   // paper tooth
    float l = dot(col, float3(0.299, 0.587, 0.114));
    col = mix(float3(l), col, 0.95);                       // keep it soft
    col *= 1.0 - 0.14 * dot(p, p);                       // faint vignette
    return finish(s, col, paperCol, 0.68, 0.64);
}

// ================= paper: parchment, linen or vellum, by the seed =================
float3 scene_paper(Scene s){
    float2 p = s.p;
    bool dark = s.dark;
    float kind = floor(hash11(s.seed * 5.3 + 1.0) * 3.0);   // 0 parchment, 1 linen, 2 vellum
    float3 base = dark ? hsvm(s, float3(s.hue, 0.32, 0.17)) : hsvm(s, float3(s.hue, 0.17, 0.95));
    float3 col = base;
    float tooth = paperTex(p);
    float cloud = fbm(p * 2.6 + s.seed * 7.0);

    if (kind < 0.5){
        // Parchment: mottled, stained, and burned a little darker at the edges.
        float blot = smoothstep(0.35, 0.75, fbm(p * 5.0 + s.seed * 3.0));
        col *= (dark ? 0.70 : 0.82) + 0.30 * cloud;
        col = mix(col, col * (dark ? 1.5 : 0.80), blot * 0.5);
        float ring = smoothstep(0.012, 0.0, abs(fbm(p * 1.8 + 9.0 + s.seed) - 0.56) - 0.004);
        col *= 1.0 - 0.14 * ring;
        col *= 1.0 - 0.38 * smoothstep(0.25, 1.0, length(p * float2(0.75, 1.0)));
    } else if (kind < 1.5){
        // Linen: threads over and under, each a little different.
        float2 u = (s.px / max(s.resolution.y, 1.0)) * 150.0 + 0.5 * float2(fbm(p * 9.0), fbm(p * 9.0 + 4.0));
        float2 cell = floor(u);
        float over = fmod(cell.x + cell.y, 2.0);
        float2 f = fract(u);
        float warp = 0.5 + 0.5 * cos(6.2831 * (f.y - 0.5)) ;
        float weft = 0.5 + 0.5 * cos(6.2831 * (f.x - 0.5)) ;
        float strand = mix(weft, warp, over);
        float slub = 0.8 + 0.4 * hash11(cell.x * 1.7 + (over > 0.5 ? 0.0 : cell.y * 3.1) + s.seed);
        col *= (dark ? 0.62 : 0.84) + (dark ? 0.55 : 0.16) * strand * slub;
        col *= 0.92 + 0.12 * cloud;
    } else {
        // Vellum: smooth and a little translucent, with long fibres and faint veins.
        float2 q = rotation(hash11(s.seed * 2.1) * 3.14159) * p;
        float fibre = fbm(float2(q.x * 420.0, q.y * 9.0));
        float vein = smoothstep(0.03, 0.0, abs(fbm(p * 3.2 + s.seed * 5.0) - 0.5) - 0.012);
        col *= (dark ? 0.78 : 0.90) + 0.22 * cloud;
        col *= 0.93 + 0.12 * fibre;
        col = mix(col, col * (dark ? 1.6 : 0.78), vein * 0.35);
    }
    col *= 0.95 + 0.07 * tooth;
    return finish(s, col, base, 0.45, 0.30);
}

// ================= ink wash: sumi-e hills and mist in greys, with bleeding edges =================
float3 scene_ink_wash(Scene s){
    float2 p = s.p;
    bool dark = s.dark;
    float3 ground = dark ? hsvm(s, float3(s.hue, 0.20, 0.075)) : hsvm(s, float3(s.hue, 0.05, 0.955));
    float3 ink = dark ? hsvm(s, float3(s.hue, 0.10, 0.80)) : hsvm(s, float3(s.hue, 0.22, 0.16));
    float paper = paperTex(p);
    float density = 0.0;

    // Ridges, near ones darker, each fading into mist below its line.
    for (int i = 0; i < 4; i++){
        float fi = float(i);
        float x = p.x * (1.1 + 0.35 * fi) + s.seed * 6.0 + fi * 13.0;
        float ridge = -0.34 + 0.20 * fi + 0.17 * fbm(float2(x, fi * 3.7)) + 0.04 * sin(x * 2.0 + fi);
        // The edge bleeds: it wanders with the paper's grain.
        float wobble = (fbm(p * 14.0 + fi * 5.0) - 0.5) * 0.035;
        float below = (ridge + wobble) - p.y;                  // positive under the line
        float body = smoothstep(0.0, 0.012 + 0.02 * fi, below);
        float mist = exp(-max(below, 0.0) * (3.2 - 0.4 * fi));  // thick at the line, thinning down
        float rim = exp(-abs(below) * 70.0);                    // ink gathers at the edge, as it dries
        float layer = body * (0.20 + 0.14 * fi) * (0.35 + 0.65 * mist) + 0.10 * rim * body;
        density = density + layer * (1.0 - density * 0.5);
    }
    // A pale disc of moon or sun, with its own soft bleed.
    float2 c = float2((hash11(s.seed * 1.3) - 0.5) * 0.9, 0.22 + 0.15 * hash11(s.seed * 4.1));
    float disc = 1.0 - smoothstep(0.045, 0.075 + 0.02 * fbm(p * 8.0), length(p - c));
    density *= 1.0 - 0.9 * disc;
    density += 0.08 * disc * (dark ? 0.0 : 1.0);
    // A few strokes of drifting ink, wide and pale.
    float drift = smoothstep(0.55, 0.85, fbm(p * float2(1.5, 5.0) + s.seed * 2.0)) * 0.16;
    density += drift * smoothstep(0.55, -0.1, p.y);
    density *= 1.0 + 0.5 * (0.5 - paper);
    density = clamp(density, 0.0, 0.95);

    float3 col = mix(ground, ink, density);
    col *= 0.96 + 0.06 * paper;
    return finish(s, col, ground, 0.66, 0.55);
}

// ================= mist: slow, domain-warped fields of muted colour =================
float3 scene_mist(Scene s){
    float2 p = s.p;
    bool dark = s.dark;
    float h = s.hue;
    float2 w = float2(fbm(p * 1.1 + s.seed * 2.0), fbm(p * 1.1 + float2(5.2, 1.3) + s.seed * 3.0));
    float f = fbm(p * 0.9 + 2.2 * w);
    float g = fbm(p * 0.7 - 1.6 * w + float2(3.0, 8.0) + s.seed);
    float k = fbm(p * 1.6 + 3.0 * float2(f, g));
    float3 a = dark ? hsvm(s, float3(h, 0.40, 0.11)) : hsvm(s, float3(h, 0.14, 0.96));
    float3 b = dark ? hsvm(s, float3(h + 0.07, 0.34, 0.24)) : hsvm(s, float3(h + 0.07, 0.26, 0.86));
    float3 c = dark ? hsvm(s, float3(h - 0.09, 0.30, 0.19)) : hsvm(s, float3(h - 0.09, 0.20, 0.91));
    float3 col = mix(a, b, smoothstep(0.30, 0.72, f));
    col = mix(col, c, smoothstep(0.35, 0.75, g) * 0.65);
    col = mix(col, a, smoothstep(0.5, 0.8, k) * 0.35);
    col *= 0.97 + 0.04 * paperTex(p);
    return finish(s, col, a, 0.30, 0.25);
}

// ================= grain: a quiet gradient under film grain =================
float3 scene_grain(Scene s){
    float2 p = s.p;
    bool dark = s.dark;
    float h = s.hue;
    float angle = hash11(s.seed * 2.7) * 6.2831;
    float t = 0.5 + 0.5 * dot(p, float2(cos(angle), sin(angle))) * 1.2;
    t = clamp(t + 0.25 * (fbm(p * 1.3 + s.seed) - 0.5), 0.0, 1.0);
    float3 a = dark ? hsvm(s, float3(h, 0.30, 0.06)) : hsvm(s, float3(h, 0.08, 0.95));
    float3 b = dark ? hsvm(s, float3(h + 0.04, 0.36, 0.20)) : hsvm(s, float3(h + 0.04, 0.20, 0.80));
    float3 col = mix(a, b, smoothstep(0.0, 1.0, t));
    // Grain at the pixel, finer grain between, and a slower mottle that is nearly not there.
    float2 q = floor(s.px);
    float fine = hash21(q + s.seed * 57.0) - 0.5;
    float coarse = hash21(floor(q / 2.0) + 11.0 + s.seed * 31.0) - 0.5;
    float mottle = fbm(p * 60.0 + s.seed) - 0.5;
    float grain = 0.55 * fine + 0.30 * coarse + 0.35 * mottle;
    col *= 1.0 + (dark ? 0.55 : 0.16) * grain;
    col *= 1.0 - 0.18 * dot(p, p);
    return finish(s, col, a, 0.40, 0.40);
}

// ================= marbling: ebru / suminagashi, bands of colour from warped, swirled stripes =================
float3 scene_marbling(Scene s){
    float2 p = s.p;
    bool dark = s.dark;
    float h = s.hue;
    float2 q = p;
    // Swirls round a few points, then the whole sheet drawn through a comb.
    for (int i = 0; i < 3; i++){
        float fi = float(i);
        float2 c = (hash22(float2(s.seed * 1.3 + fi, 7.7 + fi)) - 0.5) * float2(1.6, 0.9);
        float2 d = q - c;
        float r = length(d);
        q = c + rotation(0.9 * (hash11(s.seed + fi * 2.3) - 0.5) * 6.0 * exp(-r * 3.0)) * d;
    }
    q += 0.30 * float2(fbm(q * 1.7 + s.seed * 2.0), fbm(q * 1.7 + 6.0 + s.seed)) - 0.15;
    float v = q.y * 9.0 + 1.3 * sin(q.x * 2.6 + 2.0 * fbm(q * 2.0)) + 0.8 * fbm(q * 3.0);
    float id = floor(v);
    float f = fract(v);
    float pick = hash11(id * 1.37 + s.seed);
    float3 ground = dark ? hsvm(s, float3(h, 0.30, 0.07)) : hsvm(s, float3(h, 0.06, 0.96));
    float off = pick < 0.3 ? 0.0 : (pick < 0.55 ? 0.08 : (pick < 0.8 ? 0.50 : 0.58));
    float3 band = dark ? hsvm(s, float3(h + off, 0.55, 0.28 + 0.25 * pick))
                       : hsvm(s, float3(h + off, 0.32 + 0.25 * pick, 0.88 - 0.1 * pick));
    // Between the bands a thin line of ground; and where the next band starts, a darker edge.
    float gap = smoothstep(0.0, 0.07, f) * smoothstep(0.0, 0.07, 1.0 - f);
    float3 col = mix(ground, band, gap);
    col *= 1.0 - 0.10 * smoothstep(0.6, 1.0, f);
    col *= 0.97 + 0.05 * paperTex(p);
    return finish(s, col, ground, 0.52, 0.40);
}

// ================= risograph: flat inks in halftone, a little out of register, on paper =================
float halftone(float2 px, float angle, float period, float coverage, float2 shift){
    float2 u = rotation(angle) * (px + shift) / period;
    float2 cell = fract(u) - 0.5;
    float radius = sqrt(clamp(coverage, 0.0, 1.0)) * 0.72;
    float edge = 0.6 / period;
    return 1.0 - smoothstep(radius - edge, radius + edge, length(cell));
}

float3 scene_riso(Scene s){
    float2 p = s.p;
    bool dark = s.dark;
    float3 ground = dark ? float3(0.075, 0.07, 0.085) : float3(0.965, 0.945, 0.90);
    float3 col = ground;
    float period = max(5.0, s.resolution.y / 150.0);
    float grain = hash21(floor(s.px) + s.seed * 13.0);
    for (int i = 0; i < 3; i++){
        float fi = float(i);
        // Three inks, the first the hue given, the others across the wheel from it.
        float hue = fract(s.hue + (i == 0 ? 0.0 : (i == 1 ? 0.52 : 0.17)));
        float3 ink = dark ? hsvm(s, float3(hue, 0.75, 0.55)) : hsvm(s, float3(hue, 0.62 + 0.1 * fi, 0.98 - 0.12 * fi));
        // The shape: a broad blob of the ink, smooth, so that the screen gives it its gradient.
        float2 at = p * (1.5 + 0.4 * fi) + float2(s.seed * 3.0 + fi * 9.0, fi * 4.0);
        float shape = smoothstep(0.38, 0.78, fbm(at) + 0.25 * (fbm(at * 2.5) - 0.5));
        float2 shift = float2(2.0 * period * (hash11(s.seed + fi) - 0.5), 2.0 * period * (hash11(s.seed + fi + 5.0) - 0.5));
        float dots = halftone(s.px, 0.26 + 0.52 * fi, period, shape, shift);
        // A press never inks evenly.
        dots *= 0.88 + 0.12 * grain;
        col = dark ? 1.0 - (1.0 - col) * (1.0 - ink * dots * 0.85)
                   : col * mix(float3(1.0), ink, dots);
    }
    return finish(s, col, ground, 0.70, 0.54);
}

// ================= contours: isolines of a noise field, a map of nowhere =================
float field(float2 p, float seed){
    return 0.62 * fbm(p * 1.3 + seed * 3.0) + 0.28 * fbm(p * 3.1 + seed + 8.0) + 0.10 * fbm(p * 7.0 + 2.0);
}

float3 scene_contours(Scene s){
    float2 p = s.p;
    bool dark = s.dark;
    float h = s.hue;
    float levels = 16.0;
    float e = 1.0 / max(s.resolution.y, 1.0);
    float f = field(p, s.seed);
    float2 grad = float2(field(p + float2(e * 2.0, 0.0), s.seed) - f, field(p + float2(0.0, e * 2.0), s.seed) - f) / (2.0 * e);
    float slope = max(length(grad) * levels, 1e-3);          // levels per unit of p
    float v = f * levels;
    float near = abs(v - floor(v + 0.5));                     // levels from the nearest line
    float px = near / slope / e;                               // pixels from it
    float index = fmod(floor(v + 0.5), 5.0);                  // every fifth a heavier line
    float width = index < 0.5 ? 1.8 : 0.9;
    float line = 1.0 - smoothstep(width - 0.5, width + 0.7, px);
    float3 ground = dark ? hsvm(s, float3(h, 0.40, 0.08)) : hsvm(s, float3(h, 0.10, 0.96));
    float3 low = dark ? hsvm(s, float3(h, 0.45, 0.14)) : hsvm(s, float3(h + 0.05, 0.20, 0.90));
    float3 ink = dark ? hsvm(s, float3(h, 0.30, 0.85)) : hsvm(s, float3(h, 0.55, 0.30));
    float3 col = mix(ground, low, smoothstep(0.30, 0.62, f));      // the land, a little deeper where it is high
    col = mix(col, ink, line * (index < 0.5 ? 0.95 : 0.65));
    col *= 0.97 + 0.05 * paperTex(p);
    return finish(s, col, ground, 0.70, 0.58);
}

// ================= bauhaus: simple shapes in primary colours, placed by seeded rules =================
float shape_mask(float2 f, float kind, float aa){
    // f in 0..1 square; kind picks the shape.
    if (kind < 0.5)  return 1.0 - smoothstep(0.42 - aa, 0.42 + aa, length(f - 0.5));              // disc
    if (kind < 1.5)  return 1.0 - smoothstep(1.0 - aa, 1.0 + aa, length(f));                       // quarter disc
    if (kind < 2.5)  return (1.0 - smoothstep(0.5 - aa, 0.5 + aa, length(f - float2(0.5, 0.0))))   // half disc
                          * step(0.0, f.y);
    if (kind < 3.5)  return smoothstep(-aa, aa, f.x - f.y);                                          // right triangle
    if (kind < 4.5)  return smoothstep(-aa, aa, 0.16 - abs(f.x - 0.5));                             // bar
    float r = length(f - 0.5);                                                                      // ring
    return smoothstep(0.30 - aa, 0.30 + aa, r) * (1.0 - smoothstep(0.44 - aa, 0.44 + aa, r));
}

float3 scene_bauhaus(Scene s){
    float2 p = s.p;
    bool dark = s.dark;
    float3 ground = dark ? float3(0.07, 0.07, 0.085) : float3(0.945, 0.915, 0.84);
    float3 col = ground;
    float across = 4.0 + floor(hash11(s.seed * 1.9) * 3.0);        // cells in a unit of height
    float2 g = p * across + float2(hash11(s.seed * 2.3), hash11(s.seed * 3.1)) * 7.0;
    float2 id = floor(g);
    float2 f = fract(g);
    float aa = 1.5 / max(s.resolution.y, 1.0) * across;
    float pick = hash21(id + s.seed * 17.0);
    if (pick > 0.34){
        float kind = floor(hash21(id * 1.7 + s.seed * 5.0) * 5.99);
        float turns = floor(hash21(id * 2.9 + s.seed) * 4.0);
        float2 c = f - 0.5;
        for (int i = 0; i < 4; i++){
            if (float(i) < turns) c = float2(-c.y, c.x);
        }
        float m = shape_mask(c + 0.5, kind, aa);
        float tone = hash21(id * 0.7 + s.seed * 9.0);
        float3 dominant = hsvm(s, float3(s.hue, 0.78, 0.86));
        float3 shade = tone < 0.34 ? dominant
                     : (tone < 0.58 ? float3(0.90, 0.72, 0.12)
                     : (tone < 0.80 ? float3(0.12, 0.30, 0.62) : float3(0.09, 0.09, 0.10)));
        if (dark) shade = tone >= 0.80 ? float3(0.78, 0.76, 0.70) : shade * 0.62;
        col = mix(ground, shade, m);
    }
    col *= 0.96 + 0.06 * paperTex(p);
    return finish(s, col, ground, 0.70, 0.58);
}

// ---------- the kernels ----------
#define KERNEL(NAME, SCENE) \
kernel void NAME( \
    device uchar4 *pixels [[buffer(0)]], \
    constant Background_Parameters &parameters [[buffer(1)]], \
    uint2 pixel [[thread_position_in_grid]]) \
{ \
    if (any(pixel >= parameters.resolution)) return; \
    float2 resolution = float2(parameters.resolution); \
    /* SDL rows start at the top; keep the painting's upward Y axis. */ \
    float2 position = float2(float(pixel.x) + 0.5, resolution.y - float(pixel.y) - 0.5); \
    Scene s; \
    s.p = (position - 0.5 * resolution) / resolution.y; \
    s.px = float2(float(pixel.x) + 0.5, float(pixel.y) + 0.5); \
    s.resolution = resolution; \
    s.seed = parameters.seed; \
    s.hue = parameters.hue; \
    s.dark = parameters.dark != 0; \
    s.mood = parameters.mood; \
    float3 col = SCENE(s); \
    pixels[pixel.y * parameters.resolution.x + pixel.x] = uchar4(float4(clamp(col, 0.0, 1.0), 1.0) * 255.0); \
}

KERNEL(watercolour, scene_watercolour)
KERNEL(paper, scene_paper)
KERNEL(inkwash, scene_ink_wash)
KERNEL(mist, scene_mist)
KERNEL(grain, scene_grain)
KERNEL(marbling, scene_marbling)
KERNEL(riso, scene_riso)
KERNEL(contours, scene_contours)
KERNEL(bauhaus, scene_bauhaus)
