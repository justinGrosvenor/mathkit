const std = @import("std");

pub const Vec2 = extern struct {
    x: f32 = 0,
    y: f32 = 0,

    pub const zero = Vec2{};
    pub const one = Vec2{ .x = 1, .y = 1 };
    pub const unit_x = Vec2{ .x = 1 };
    pub const unit_y = Vec2{ .y = 1 };

    pub fn new(x: f32, y: f32) Vec2 {
        return .{ .x = x, .y = y };
    }

    pub fn splat(v: f32) Vec2 {
        return .{ .x = v, .y = v };
    }

    pub fn add(a: Vec2, b: Vec2) Vec2 {
        return .{ .x = a.x + b.x, .y = a.y + b.y };
    }

    pub fn sub(a: Vec2, b: Vec2) Vec2 {
        return .{ .x = a.x - b.x, .y = a.y - b.y };
    }

    pub fn mul(a: Vec2, b: Vec2) Vec2 {
        return .{ .x = a.x * b.x, .y = a.y * b.y };
    }

    pub fn scale(v: Vec2, s: f32) Vec2 {
        return .{ .x = v.x * s, .y = v.y * s };
    }

    pub fn neg(v: Vec2) Vec2 {
        return .{ .x = -v.x, .y = -v.y };
    }

    pub fn dot(a: Vec2, b: Vec2) f32 {
        return a.x * b.x + a.y * b.y;
    }

    pub fn lengthSq(v: Vec2) f32 {
        return dot(v, v);
    }

    pub fn length(v: Vec2) f32 {
        return @sqrt(lengthSq(v));
    }

    /// Returns the zero vector if `v` is zero.
    pub fn normalize(v: Vec2) Vec2 {
        const len = length(v);
        if (len == 0) return zero;
        return scale(v, 1.0 / len);
    }

    pub fn lerp(a: Vec2, b: Vec2, t: f32) Vec2 {
        return add(a, scale(sub(b, a), t));
    }

    pub fn dist(a: Vec2, b: Vec2) f32 {
        return length(sub(b, a));
    }

    pub fn distSq(a: Vec2, b: Vec2) f32 {
        return lengthSq(sub(b, a));
    }

    pub fn min(a: Vec2, b: Vec2) Vec2 {
        return .{ .x = @min(a.x, b.x), .y = @min(a.y, b.y) };
    }

    pub fn max(a: Vec2, b: Vec2) Vec2 {
        return .{ .x = @max(a.x, b.x), .y = @max(a.y, b.y) };
    }

    pub fn clamp(v: Vec2, lo: Vec2, hi: Vec2) Vec2 {
        return max(lo, min(hi, v));
    }

    pub fn saturate(v: Vec2) Vec2 {
        return clamp(v, zero, one);
    }

    pub fn abs(v: Vec2) Vec2 {
        return .{ .x = @abs(v.x), .y = @abs(v.y) };
    }

    pub fn perp(v: Vec2) Vec2 {
        return .{ .x = -v.y, .y = v.x };
    }

    pub fn cross(a: Vec2, b: Vec2) f32 {
        return a.x * b.y - a.y * b.x;
    }

    pub fn reflect(v: Vec2, normal: Vec2) Vec2 {
        return sub(v, scale(normal, 2.0 * dot(v, normal)));
    }

    /// Project `v` onto `onto`. Returns zero if `onto` is zero.
    pub fn project(v: Vec2, onto: Vec2) Vec2 {
        const denom = lengthSq(onto);
        if (denom == 0) return zero;
        return scale(onto, dot(v, onto) / denom);
    }

    pub fn reject(v: Vec2, onto: Vec2) Vec2 {
        return sub(v, project(v, onto));
    }

    /// Unsigned angle in radians between `a` and `b`. Returns 0 if either is zero.
    pub fn angleBetween(a: Vec2, b: Vec2) f32 {
        const denom = length(a) * length(b);
        if (denom == 0) return 0;
        const c = @max(-1.0, @min(1.0, dot(a, b) / denom));
        return std.math.acos(c);
    }

    pub fn eql(a: Vec2, b: Vec2) bool {
        return a.x == b.x and a.y == b.y;
    }

    pub fn approxEql(a: Vec2, b: Vec2, eps: f32) bool {
        return @abs(a.x - b.x) <= eps and @abs(a.y - b.y) <= eps;
    }
};

test "vec2 basics" {
    const a = Vec2.new(3, 4);
    try std.testing.expectApproxEqAbs(@as(f32, 5.0), a.length(), 1e-6);

    const n = a.normalize();
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), n.length(), 1e-6);

    const b = Vec2.new(1, 2);
    try std.testing.expectApproxEqAbs(@as(f32, 11.0), Vec2.dot(a, b), 1e-6);
}

test "vec2 lerp" {
    const a = Vec2.zero;
    const b = Vec2.new(10, 20);
    const mid = Vec2.lerp(a, b, 0.5);
    try std.testing.expect(mid.approxEql(Vec2.new(5, 10), 1e-6));
}

test "vec2 helpers" {
    const v = Vec2.new(-2, 3);
    try std.testing.expect(v.abs().eql(Vec2.new(2, 3)));
    try std.testing.expect(Vec2.cross(Vec2.unit_x, Vec2.unit_y) == 1);
    try std.testing.expect(Vec2.unit_x.perp().eql(Vec2.unit_y));
    try std.testing.expect(Vec2.saturate(Vec2.new(-1, 2)).eql(Vec2.new(0, 1)));
    try std.testing.expectApproxEqAbs(@as(f32, 25), Vec2.distSq(Vec2.zero, Vec2.new(3, 4)), 1e-6);
}

test "vec2 reflect / project / reject / angleBetween" {
    // Reflect across the X axis.
    const v = Vec2.new(1, -1).normalize();
    const r = Vec2.reflect(v, Vec2.unit_y);
    try std.testing.expect(r.approxEql(Vec2.new(1, 1).normalize(), 1e-5));

    const p = Vec2.new(2, 2);
    try std.testing.expect(p.project(Vec2.unit_x).approxEql(Vec2.new(2, 0), 1e-6));
    try std.testing.expect(p.reject(Vec2.unit_x).approxEql(Vec2.new(0, 2), 1e-6));

    try std.testing.expectApproxEqAbs(std.math.pi / 2.0, Vec2.angleBetween(Vec2.unit_x, Vec2.unit_y), 1e-6);
}
