const std = @import("std");
const pi = std.math.pi;

/// Easing functions. All take t in [0, 1] and return [0, 1].
pub fn linear(t: f32) f32 {
    return t;
}

pub fn inQuad(t: f32) f32 {
    return t * t;
}

pub fn outQuad(t: f32) f32 {
    return t * (2 - t);
}

pub fn inOutQuad(t: f32) f32 {
    if (t < 0.5) return 2 * t * t;
    return -1 + (4 - 2 * t) * t;
}

pub fn inCubic(t: f32) f32 {
    return t * t * t;
}

pub fn outCubic(t: f32) f32 {
    const u = t - 1;
    return u * u * u + 1;
}

pub fn inOutCubic(t: f32) f32 {
    if (t < 0.5) return 4 * t * t * t;
    const u = 2 * t - 2;
    return 0.5 * u * u * u + 1;
}

pub fn inQuart(t: f32) f32 {
    return t * t * t * t;
}

pub fn outQuart(t: f32) f32 {
    const u = t - 1;
    return 1 - u * u * u * u;
}

pub fn inOutQuart(t: f32) f32 {
    if (t < 0.5) return 8 * t * t * t * t;
    const u = t - 1;
    return 1 - 8 * u * u * u * u;
}

pub fn inSine(t: f32) f32 {
    return 1 - @cos(t * pi * 0.5);
}

pub fn outSine(t: f32) f32 {
    return @sin(t * pi * 0.5);
}

pub fn inOutSine(t: f32) f32 {
    return 0.5 * (1 - @cos(pi * t));
}

pub fn inExpo(t: f32) f32 {
    if (t == 0) return 0;
    return std.math.pow(f32, 2, 10 * (t - 1));
}

pub fn outExpo(t: f32) f32 {
    if (t == 1) return 1;
    return 1 - std.math.pow(f32, 2, -10 * t);
}

pub fn inOutExpo(t: f32) f32 {
    if (t == 0) return 0;
    if (t == 1) return 1;
    if (t < 0.5) return 0.5 * std.math.pow(f32, 2, 20 * t - 10);
    return 1 - 0.5 * std.math.pow(f32, 2, -20 * t + 10);
}

pub fn inCirc(t: f32) f32 {
    return 1 - @sqrt(1 - t * t);
}

pub fn outCirc(t: f32) f32 {
    const u = t - 1;
    return @sqrt(1 - u * u);
}

pub fn inOutCirc(t: f32) f32 {
    if (t < 0.5) return 0.5 * (1 - @sqrt(1 - 4 * t * t));
    const u = 2 * t - 2;
    return 0.5 * (@sqrt(1 - u * u) + 1);
}

pub fn inBack(t: f32) f32 {
    const s: f32 = 1.70158;
    return t * t * ((s + 1) * t - s);
}

pub fn outBack(t: f32) f32 {
    const s: f32 = 1.70158;
    const u = t - 1;
    return u * u * ((s + 1) * u + s) + 1;
}

pub fn inOutBack(t: f32) f32 {
    const s: f32 = 1.70158 * 1.525;
    if (t < 0.5) {
        const u = 2 * t;
        return 0.5 * (u * u * ((s + 1) * u - s));
    }
    const u = 2 * t - 2;
    return 0.5 * (u * u * ((s + 1) * u + s) + 2);
}

pub fn inElastic(t: f32) f32 {
    if (t == 0) return 0;
    if (t == 1) return 1;
    return -std.math.pow(f32, 2, 10 * t - 10) * @sin((t * 10 - 10.75) * (2 * pi / 3));
}

pub fn outElastic(t: f32) f32 {
    if (t == 0) return 0;
    if (t == 1) return 1;
    return std.math.pow(f32, 2, -10 * t) * @sin((t * 10 - 0.75) * (2 * pi / 3)) + 1;
}

pub fn inBounce(t: f32) f32 {
    return 1 - outBounce(1 - t);
}

pub fn outBounce(t: f32) f32 {
    const n1: f32 = 7.5625;
    const d1: f32 = 2.75;

    if (t < 1 / d1) {
        return n1 * t * t;
    } else if (t < 2 / d1) {
        const u = t - 1.5 / d1;
        return n1 * u * u + 0.75;
    } else if (t < 2.5 / d1) {
        const u = t - 2.25 / d1;
        return n1 * u * u + 0.9375;
    } else {
        const u = t - 2.625 / d1;
        return n1 * u * u + 0.984375;
    }
}

pub fn inOutBounce(t: f32) f32 {
    if (t < 0.5) return 0.5 * inBounce(2 * t);
    return 0.5 * outBounce(2 * t - 1) + 0.5;
}

/// Hermite smoothstep. Returns 0 at edge0, 1 at edge1, with zero first derivative at both ends.
pub fn smoothstep(edge0: f32, edge1: f32, x: f32) f32 {
    const t = @max(0.0, @min(1.0, (x - edge0) / (edge1 - edge0)));
    return t * t * (3 - 2 * t);
}

/// Ken Perlin's smootherstep. Same boundary conditions as smoothstep, plus zero second derivative at the ends.
pub fn smootherstep(edge0: f32, edge1: f32, x: f32) f32 {
    const t = @max(0.0, @min(1.0, (x - edge0) / (edge1 - edge0)));
    return t * t * t * (t * (t * 6 - 15) + 10);
}

test "ease endpoints" {
    const fns = [_]*const fn (f32) f32{
        linear,    inQuad,      outQuad,    inOutQuad,
        inCubic,   outCubic,    inOutCubic, inQuart,
        outQuart,  inOutQuart,  inSine,     outSine,
        inOutSine, inExpo,      outExpo,    inOutExpo,
        inCirc,    outCirc,     inOutCirc,  inBounce,
        outBounce, inOutBounce,
    };
    for (fns) |f| {
        try std.testing.expectApproxEqAbs(@as(f32, 0.0), f(0.0), 1e-5);
        try std.testing.expectApproxEqAbs(@as(f32, 1.0), f(1.0), 1e-5);
    }
}

test "smoothstep" {
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), smoothstep(0, 1, 0), 1e-5);
    try std.testing.expectApproxEqAbs(@as(f32, 0.5), smoothstep(0, 1, 0.5), 1e-5);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), smoothstep(0, 1, 1), 1e-5);
}
