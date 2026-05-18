const std = @import("std");
const Vec3 = @import("vec3.zig").Vec3;

pub const Vec4 = extern struct {
    x: f32 = 0,
    y: f32 = 0,
    z: f32 = 0,
    w: f32 = 0,

    pub const zero = Vec4{};
    pub const one = Vec4{ .x = 1, .y = 1, .z = 1, .w = 1 };

    pub fn new(x: f32, y: f32, z: f32, w: f32) Vec4 {
        return .{ .x = x, .y = y, .z = z, .w = w };
    }

    pub fn fromVec3(v: Vec3, w: f32) Vec4 {
        return .{ .x = v.x, .y = v.y, .z = v.z, .w = w };
    }

    pub fn xyz(self: Vec4) Vec3 {
        return .{ .x = self.x, .y = self.y, .z = self.z };
    }

    pub fn splat(v: f32) Vec4 {
        return .{ .x = v, .y = v, .z = v, .w = v };
    }

    pub fn add(a: Vec4, b: Vec4) Vec4 {
        return .{ .x = a.x + b.x, .y = a.y + b.y, .z = a.z + b.z, .w = a.w + b.w };
    }

    pub fn sub(a: Vec4, b: Vec4) Vec4 {
        return .{ .x = a.x - b.x, .y = a.y - b.y, .z = a.z - b.z, .w = a.w - b.w };
    }

    pub fn mul(a: Vec4, b: Vec4) Vec4 {
        return .{ .x = a.x * b.x, .y = a.y * b.y, .z = a.z * b.z, .w = a.w * b.w };
    }

    pub fn scale(v: Vec4, s: f32) Vec4 {
        return .{ .x = v.x * s, .y = v.y * s, .z = v.z * s, .w = v.w * s };
    }

    pub fn neg(v: Vec4) Vec4 {
        return .{ .x = -v.x, .y = -v.y, .z = -v.z, .w = -v.w };
    }

    pub fn dot(a: Vec4, b: Vec4) f32 {
        return a.x * b.x + a.y * b.y + a.z * b.z + a.w * b.w;
    }

    pub fn lengthSq(v: Vec4) f32 {
        return dot(v, v);
    }

    pub fn length(v: Vec4) f32 {
        return @sqrt(lengthSq(v));
    }

    /// Returns the zero vector if `v` is zero.
    pub fn normalize(v: Vec4) Vec4 {
        const len = length(v);
        if (len == 0) return zero;
        return scale(v, 1.0 / len);
    }

    pub fn lerp(a: Vec4, b: Vec4, t: f32) Vec4 {
        return add(a, scale(sub(b, a), t));
    }

    pub fn min(a: Vec4, b: Vec4) Vec4 {
        return .{ .x = @min(a.x, b.x), .y = @min(a.y, b.y), .z = @min(a.z, b.z), .w = @min(a.w, b.w) };
    }

    pub fn max(a: Vec4, b: Vec4) Vec4 {
        return .{ .x = @max(a.x, b.x), .y = @max(a.y, b.y), .z = @max(a.z, b.z), .w = @max(a.w, b.w) };
    }

    pub fn clamp(v: Vec4, lo: Vec4, hi: Vec4) Vec4 {
        return max(lo, min(hi, v));
    }

    pub fn saturate(v: Vec4) Vec4 {
        return clamp(v, zero, one);
    }

    pub fn eql(a: Vec4, b: Vec4) bool {
        return a.x == b.x and a.y == b.y and a.z == b.z and a.w == b.w;
    }

    pub fn approxEql(a: Vec4, b: Vec4, eps: f32) bool {
        return @abs(a.x - b.x) <= eps and @abs(a.y - b.y) <= eps and
            @abs(a.z - b.z) <= eps and @abs(a.w - b.w) <= eps;
    }
};

test "vec4 from vec3" {
    const v3 = Vec3.new(1, 2, 3);
    const v4 = Vec4.fromVec3(v3, 1);
    try std.testing.expect(v4.eql(Vec4.new(1, 2, 3, 1)));
    try std.testing.expect(v4.xyz().eql(v3));
}

test "vec4 dot" {
    const a = Vec4.new(1, 2, 3, 4);
    const b = Vec4.new(5, 6, 7, 8);
    try std.testing.expectApproxEqAbs(@as(f32, 70.0), Vec4.dot(a, b), 1e-6);
}

test "vec4 helpers" {
    try std.testing.expect(Vec4.neg(Vec4.new(1, -2, 3, -4)).eql(Vec4.new(-1, 2, -3, 4)));
    try std.testing.expect(Vec4.saturate(Vec4.new(-1, 0.25, 2, 1)).eql(Vec4.new(0, 0.25, 1, 1)));
}

test "vec4 length and normalize" {
    const v = Vec4.new(1, 2, 2, 0);
    try std.testing.expectApproxEqAbs(@as(f32, 3.0), v.length(), 1e-6);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), v.normalize().length(), 1e-6);
    try std.testing.expect(Vec4.normalize(Vec4.zero).eql(Vec4.zero));
}

test "vec4 lerp" {
    const mid = Vec4.lerp(Vec4.zero, Vec4.new(2, 4, 6, 8), 0.5);
    try std.testing.expect(mid.approxEql(Vec4.new(1, 2, 3, 4), 1e-6));
}
