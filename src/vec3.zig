const std = @import("std");

pub const Vec3 = extern struct {
    x: f32 = 0,
    y: f32 = 0,
    z: f32 = 0,

    pub const zero = Vec3{};
    pub const one = Vec3{ .x = 1, .y = 1, .z = 1 };
    pub const unit_x = Vec3{ .x = 1 };
    pub const unit_y = Vec3{ .y = 1 };
    pub const unit_z = Vec3{ .z = 1 };
    pub const up = unit_y;
    pub const forward = Vec3{ .z = -1 };
    pub const forward_lh = Vec3{ .z = 1 };
    pub const right = unit_x;

    pub fn new(x: f32, y: f32, z: f32) Vec3 {
        return .{ .x = x, .y = y, .z = z };
    }

    pub fn splat(v: f32) Vec3 {
        return .{ .x = v, .y = v, .z = v };
    }

    pub fn add(a: Vec3, b: Vec3) Vec3 {
        return .{ .x = a.x + b.x, .y = a.y + b.y, .z = a.z + b.z };
    }

    pub fn sub(a: Vec3, b: Vec3) Vec3 {
        return .{ .x = a.x - b.x, .y = a.y - b.y, .z = a.z - b.z };
    }

    pub fn mul(a: Vec3, b: Vec3) Vec3 {
        return .{ .x = a.x * b.x, .y = a.y * b.y, .z = a.z * b.z };
    }

    pub fn scale(v: Vec3, s: f32) Vec3 {
        return .{ .x = v.x * s, .y = v.y * s, .z = v.z * s };
    }

    pub fn neg(v: Vec3) Vec3 {
        return .{ .x = -v.x, .y = -v.y, .z = -v.z };
    }

    pub fn dot(a: Vec3, b: Vec3) f32 {
        return a.x * b.x + a.y * b.y + a.z * b.z;
    }

    pub fn cross(a: Vec3, b: Vec3) Vec3 {
        return .{
            .x = a.y * b.z - a.z * b.y,
            .y = a.z * b.x - a.x * b.z,
            .z = a.x * b.y - a.y * b.x,
        };
    }

    pub fn lengthSq(v: Vec3) f32 {
        return dot(v, v);
    }

    pub fn length(v: Vec3) f32 {
        return @sqrt(lengthSq(v));
    }

    /// Returns the zero vector if `v` is zero.
    pub fn normalize(v: Vec3) Vec3 {
        const len = length(v);
        if (len == 0) return zero;
        return scale(v, 1.0 / len);
    }

    pub fn lerp(a: Vec3, b: Vec3, t: f32) Vec3 {
        return add(a, scale(sub(b, a), t));
    }

    pub fn dist(a: Vec3, b: Vec3) f32 {
        return length(sub(b, a));
    }

    pub fn distSq(a: Vec3, b: Vec3) f32 {
        return lengthSq(sub(b, a));
    }

    pub fn min(a: Vec3, b: Vec3) Vec3 {
        return .{ .x = @min(a.x, b.x), .y = @min(a.y, b.y), .z = @min(a.z, b.z) };
    }

    pub fn max(a: Vec3, b: Vec3) Vec3 {
        return .{ .x = @max(a.x, b.x), .y = @max(a.y, b.y), .z = @max(a.z, b.z) };
    }

    pub fn clamp(v: Vec3, lo: Vec3, hi: Vec3) Vec3 {
        return max(lo, min(hi, v));
    }

    pub fn saturate(v: Vec3) Vec3 {
        return clamp(v, zero, one);
    }

    pub fn abs(v: Vec3) Vec3 {
        return .{ .x = @abs(v.x), .y = @abs(v.y), .z = @abs(v.z) };
    }

    pub fn reflect(v: Vec3, normal: Vec3) Vec3 {
        return sub(v, scale(normal, 2.0 * dot(v, normal)));
    }

    pub fn project(v: Vec3, onto: Vec3) Vec3 {
        const denom = lengthSq(onto);
        if (denom == 0) return zero;
        return scale(onto, dot(v, onto) / denom);
    }

    pub fn reject(v: Vec3, onto: Vec3) Vec3 {
        return sub(v, project(v, onto));
    }

    pub fn angleBetween(a: Vec3, b: Vec3) f32 {
        const denom = length(a) * length(b);
        if (denom == 0) return 0;
        const c = @max(-1.0, @min(1.0, dot(a, b) / denom));
        return std.math.acos(c);
    }

    pub fn eql(a: Vec3, b: Vec3) bool {
        return a.x == b.x and a.y == b.y and a.z == b.z;
    }

    pub fn approxEql(a: Vec3, b: Vec3, eps: f32) bool {
        return @abs(a.x - b.x) <= eps and @abs(a.y - b.y) <= eps and @abs(a.z - b.z) <= eps;
    }
};

test "vec3 cross product" {
    const x = Vec3.unit_x;
    const y = Vec3.unit_y;
    const z = Vec3.cross(x, y);
    try std.testing.expect(z.approxEql(Vec3.unit_z, 1e-6));
}

test "vec3 normalize" {
    const v = Vec3.new(1, 2, 3);
    const n = v.normalize();
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), n.length(), 1e-6);
}

test "vec3 reflect" {
    const v = Vec3.new(1, -1, 0).normalize();
    const n = Vec3.unit_y;
    const r = Vec3.reflect(v, n);
    try std.testing.expect(r.approxEql(Vec3.new(1, 1, 0).normalize(), 1e-5));
}

test "vec3 helpers" {
    try std.testing.expect(Vec3.saturate(Vec3.new(-1, 0.5, 2)).eql(Vec3.new(0, 0.5, 1)));
    try std.testing.expectApproxEqAbs(@as(f32, 25), Vec3.distSq(Vec3.zero, Vec3.new(3, 4, 0)), 1e-6);

    const v = Vec3.new(2, 2, 0);
    try std.testing.expect(v.project(Vec3.unit_x).approxEql(Vec3.new(2, 0, 0), 1e-6));
    try std.testing.expect(v.reject(Vec3.unit_x).approxEql(Vec3.new(0, 2, 0), 1e-6));
    try std.testing.expectApproxEqAbs(std.math.pi / 2.0, Vec3.angleBetween(Vec3.unit_x, Vec3.unit_y), 1e-6);
}
