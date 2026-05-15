const std = @import("std");

const perm = blk: {
    const base = [_]u8{
        151, 160, 137, 91,  90,  15,  131, 13,  201, 95,  96,  53,  194, 233, 7,   225,
        140, 36,  103, 30,  69,  142, 8,   99,  37,  240, 21,  10,  23,  190, 6,   148,
        247, 120, 234, 75,  0,   26,  197, 62,  94,  252, 219, 203, 117, 35,  11,  32,
        57,  177, 33,  88,  237, 149, 56,  87,  174, 20,  125, 136, 171, 168, 68,  175,
        74,  165, 71,  134, 139, 48,  27,  166, 77,  146, 158, 231, 83,  111, 229, 122,
        60,  211, 133, 230, 220, 105, 92,  41,  55,  46,  245, 40,  244, 102, 143, 54,
        65,  25,  63,  161, 1,   216, 80,  73,  209, 76,  132, 187, 208, 89,  18,  169,
        200, 196, 135, 130, 116, 188, 159, 86,  164, 100, 109, 198, 173, 186, 3,   64,
        52,  217, 226, 250, 124, 123, 5,   202, 38,  147, 118, 126, 255, 82,  85,  212,
        207, 206, 59,  227, 47,  16,  58,  17,  182, 189, 28,  42,  223, 183, 170, 213,
        119, 248, 152, 2,   44,  154, 163, 70,  221, 153, 101, 155, 167, 43,  172, 9,
        129, 22,  39,  253, 19,  98,  108, 110, 79,  113, 224, 232, 178, 185, 112, 104,
        218, 246, 97,  228, 251, 34,  242, 193, 238, 210, 144, 12,  191, 179, 162, 241,
        81,  51,  145, 235, 249, 14,  239, 107, 49,  192, 214, 31,  181, 199, 106, 157,
        184, 84,  204, 176, 115, 121, 50,  45,  127, 4,   150, 254, 138, 236, 205, 93,
        222, 114, 67,  29,  24,  72,  243, 141, 128, 195, 78,  66,  215, 61,  156, 180,
    };
    var result: [512]u8 = undefined;
    for (0..512) |i| result[i] = base[i & 255];
    break :blk result;
};

fn fade(t: f32) f32 {
    return t * t * t * (t * (t * 6 - 15) + 10);
}

fn grad1(hash: u8, x: f32) f32 {
    return if (hash & 1 == 0) x else -x;
}

fn grad2(hash: u8, x: f32, y: f32) f32 {
    return (if (hash & 1 == 0) x else -x) + (if (hash & 2 == 0) y else -y);
}

fn grad3(hash: u8, x: f32, y: f32, z: f32) f32 {
    const h = hash & 15;
    const u = if (h < 8) x else y;
    const v = if (h < 4) y else if (h == 12 or h == 14) x else z;
    return (if (h & 1 == 0) u else -u) + (if (h & 2 == 0) v else -v);
}

fn lerpf(a: f32, b: f32, t: f32) f32 {
    return a + t * (b - a);
}

/// 1D Perlin noise. Returns value in approximately [-1, 1].
pub fn perlin1(x: f32) f32 {
    const xi: i32 = @intFromFloat(@floor(x));
    const xf = x - @floor(x);
    const u = fade(xf);

    const a: usize = @intCast(xi & 255);
    const b: usize = @intCast((xi + 1) & 255);

    return lerpf(grad1(perm[a], xf), grad1(perm[b], xf - 1), u);
}

/// 2D Perlin noise. Returns value in approximately [-1, 1].
pub fn perlin2(x: f32, y: f32) f32 {
    const xi: i32 = @intFromFloat(@floor(x));
    const yi: i32 = @intFromFloat(@floor(y));
    const xf = x - @floor(x);
    const yf = y - @floor(y);
    const u = fade(xf);
    const v = fade(yf);

    const a: usize = @intCast(xi & 255);
    const b: usize = @intCast((xi + 1) & 255);
    const aa: usize = perm[a] +% @as(usize, @intCast(yi & 255));
    const ab: usize = perm[a] +% @as(usize, @intCast((yi + 1) & 255));
    const ba: usize = perm[b] +% @as(usize, @intCast(yi & 255));
    const bb: usize = perm[b] +% @as(usize, @intCast((yi + 1) & 255));

    return lerpf(
        lerpf(grad2(perm[aa & 511], xf, yf), grad2(perm[ba & 511], xf - 1, yf), u),
        lerpf(grad2(perm[ab & 511], xf, yf - 1), grad2(perm[bb & 511], xf - 1, yf - 1), u),
        v,
    );
}

/// 3D Perlin noise. Returns value in approximately [-1, 1].
pub fn perlin3(x: f32, y: f32, z: f32) f32 {
    const xi: i32 = @intFromFloat(@floor(x));
    const yi: i32 = @intFromFloat(@floor(y));
    const zi: i32 = @intFromFloat(@floor(z));
    const xf = x - @floor(x);
    const yf = y - @floor(y);
    const zf = z - @floor(z);
    const u = fade(xf);
    const v = fade(yf);
    const w = fade(zf);

    const a: usize = @intCast(xi & 255);
    const b: usize = @intCast((xi + 1) & 255);
    const ya: usize = @intCast(yi & 255);
    const yb: usize = @intCast((yi + 1) & 255);
    const za: usize = @intCast(zi & 255);
    const zb: usize = @intCast((zi + 1) & 255);

    const aa = perm[a] +% ya;
    const ab = perm[a] +% yb;
    const ba = perm[b] +% ya;
    const bb = perm[b] +% yb;

    const aaa = (perm[aa & 511] +% za) & 511;
    const aab = (perm[aa & 511] +% zb) & 511;
    const aba = (perm[ab & 511] +% za) & 511;
    const abb = (perm[ab & 511] +% zb) & 511;
    const baa = (perm[ba & 511] +% za) & 511;
    const bab = (perm[ba & 511] +% zb) & 511;
    const bba = (perm[bb & 511] +% za) & 511;
    const bbb = (perm[bb & 511] +% zb) & 511;

    return lerpf(
        lerpf(
            lerpf(grad3(perm[aaa], xf, yf, zf), grad3(perm[baa], xf - 1, yf, zf), u),
            lerpf(grad3(perm[aba], xf, yf - 1, zf), grad3(perm[bba], xf - 1, yf - 1, zf), u),
            v,
        ),
        lerpf(
            lerpf(grad3(perm[aab], xf, yf, zf - 1), grad3(perm[bab], xf - 1, yf, zf - 1), u),
            lerpf(grad3(perm[abb], xf, yf - 1, zf - 1), grad3(perm[bbb], xf - 1, yf - 1, zf - 1), u),
            v,
        ),
        w,
    );
}

/// Fractal Brownian motion (layered noise).
pub fn fbm2(x: f32, y: f32, octaves: u32, lacunarity: f32, gain: f32) f32 {
    if (octaves == 0) return 0;

    var value: f32 = 0;
    var amplitude: f32 = 1;
    var frequency: f32 = 1;
    var max_amp: f32 = 0;

    for (0..octaves) |_| {
        value += perlin2(x * frequency, y * frequency) * amplitude;
        max_amp += amplitude;
        amplitude *= gain;
        frequency *= lacunarity;
    }

    return value / max_amp;
}

pub fn fbm3(x: f32, y: f32, z: f32, octaves: u32, lacunarity: f32, gain: f32) f32 {
    if (octaves == 0) return 0;

    var value: f32 = 0;
    var amplitude: f32 = 1;
    var frequency: f32 = 1;
    var max_amp: f32 = 0;

    for (0..octaves) |_| {
        value += perlin3(x * frequency, y * frequency, z * frequency) * amplitude;
        max_amp += amplitude;
        amplitude *= gain;
        frequency *= lacunarity;
    }

    return value / max_amp;
}

test "perlin2 range" {
    var min_val: f32 = 1;
    var max_val: f32 = -1;
    for (0..100) |ix| {
        for (0..100) |iy| {
            const x = @as(f32, @floatFromInt(ix)) * 0.1;
            const y = @as(f32, @floatFromInt(iy)) * 0.1;
            const v = perlin2(x, y);
            min_val = @min(min_val, v);
            max_val = @max(max_val, v);
        }
    }
    try std.testing.expect(min_val >= -1.5);
    try std.testing.expect(max_val <= 1.5);
}

test "perlin2 deterministic" {
    const a = perlin2(3.14, 2.72);
    const b = perlin2(3.14, 2.72);
    try std.testing.expectEqual(a, b);
}

test "fbm2 range" {
    const v = fbm2(1.5, 2.5, 6, 2.0, 0.5);
    try std.testing.expect(v >= -1.5 and v <= 1.5);
}

test "fbm zero octaves returns zero" {
    try std.testing.expectEqual(@as(f32, 0), fbm2(1.5, 2.5, 0, 2.0, 0.5));
    try std.testing.expectEqual(@as(f32, 0), fbm3(1.5, 2.5, 3.5, 0, 2.0, 0.5));
}
