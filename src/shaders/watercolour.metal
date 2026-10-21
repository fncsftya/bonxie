#include <metal_stdlib>
using namespace metal;

// Rendered at the window pixel size and cached until it changes.
struct Background_Parameters {
    uint2 resolution;
    float seed;
};

// Soft pigment washes and splatter on textured paper.
#define WASHES 6

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

// ---------- pastel palette: 5 related hues ----------
float3 pastel(float baseHue, float k, float r1, float r2){
    float off;
    if      (k < 0.5) off = 0.00;
    else if (k < 1.5) off = 0.07;
    else if (k < 2.5) off = -0.09;
    else if (k < 3.5) off = 0.50;    // complementary accent
    else              off = 0.33;
    float sat = 0.22 + 0.28 * r1;                // soft saturation
    float val = 0.84 + 0.13 * r2;                // high value
    return hsv2rgb(float3(fract(baseHue + off), sat, val));
}

kernel void watercolour(
    device uchar4 *pixels [[buffer(0)]],
    constant Background_Parameters &parameters [[buffer(1)]],
    uint2 pixel [[thread_position_in_grid]])
{
    if (any(pixel >= parameters.resolution)) return;
    float2 resolution = float2(parameters.resolution);
    // SDL rows start at the top; retain the painting's upward Y axis.
    float2 position = float2(float(pixel.x) + 0.5, resolution.y - float(pixel.y) - 0.5);
    float2 p = (position - 0.5 * resolution) / resolution.y;
    float seed = parameters.seed;

    float paper = paperTex(p);
    float3  paperCol = float3(0.972, 0.955, 0.918);
    float3  col = paperCol;

    float baseHue = hash11(seed * 3.7);

    float3 lastPig = float3(0.8);

    // ================= 1. WASHES =================
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

        float3 pig = pastel(baseHue, floor(h.x * 4.99), h.y, h.z);
        if (i == 0) pig = pastel(baseHue, 0.0, 0.2, 0.9);

        float2 q = p + 0.38 * (float2(fbm(p * 1.4 + seed * 3.1 + fi * 7.0),
                                  fbm(p * 1.4 + float2(5.2, 1.3) + seed * 1.7 + fi * 5.0)) - 0.5);
        float ang = h2.x * 6.2831;
        float2x2  rm  = float2x2(float2(cos(ang), -sin(ang)), float2(sin(ang), cos(ang)));
        float2  e   = rm * (q - c) * float2(1.0, mix(0.55, 1.7, h.z));
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

        col *= pow(pig, float3(density));
        lastPig = pig;
    }

    // ================= 2. SPLATTER =================
    {
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
        col *= pow(lastPig, float3(max(ds, 0.0) * 2.0));
    }

    // ================= paper finish =================
    col *= 0.940 + 0.105 * paper;                       // paper tooth
    float l = dot(col, float3(0.299, 0.587, 0.114));
    col = mix(float3(l), col, 0.95);                       // keep it soft
    col *= 1.0 - 0.14 * dot(p, p);                       // faint vignette

    pixels[pixel.y * parameters.resolution.x + pixel.x] = uchar4(float4(clamp(col, 0.0, 1.0), 1.0) * 255.0);
}
