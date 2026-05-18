const std = @import("std");
const Vec2 = @import("vec2.zig").Vec2;
const Vec3 = @import("vec3.zig").Vec3;
const Mat4 = @import("mat4.zig").Mat4;

/// Column-major 3x3 matrix. Used for normal transforms and 2D transforms.
pub const Mat3 = extern struct {
    m: [9]f32,

    pub const identity = Mat3{ .m = .{
        1, 0, 0,
        0, 1, 0,
        0, 0, 1,
    } };

    pub const zero = Mat3{ .m = .{
        0, 0, 0,
        0, 0, 0,
        0, 0, 0,
    } };

    pub fn col(self: Mat3, c: u2) Vec3 {
        const i: usize = @as(usize, c) * 3;
        return .{ .x = self.m[i], .y = self.m[i + 1], .z = self.m[i + 2] };
    }

    pub fn at(self: Mat3, c: u2, r: u2) f32 {
        return self.m[@as(usize, c) * 3 + r];
    }

    pub fn mulVec(a: Mat3, v: Vec3) Vec3 {
        const c0 = a.col(0);
        const c1 = a.col(1);
        const c2 = a.col(2);
        return .{
            .x = c0.x * v.x + c1.x * v.y + c2.x * v.z,
            .y = c0.y * v.x + c1.y * v.y + c2.y * v.z,
            .z = c0.z * v.x + c1.z * v.y + c2.z * v.z,
        };
    }

    pub fn mul(a: Mat3, b: Mat3) Mat3 {
        var result: Mat3 = undefined;
        inline for (0..3) |c| {
            const bc = b.col(@intCast(c));
            const r = mulVec(a, bc);
            const i = c * 3;
            result.m[i] = r.x;
            result.m[i + 1] = r.y;
            result.m[i + 2] = r.z;
        }
        return result;
    }

    pub fn transpose(a: Mat3) Mat3 {
        return .{ .m = .{
            a.m[0], a.m[3], a.m[6],
            a.m[1], a.m[4], a.m[7],
            a.m[2], a.m[5], a.m[8],
        } };
    }

    pub fn determinant(self: Mat3) f32 {
        return self.m[0] * (self.m[4] * self.m[8] - self.m[5] * self.m[7]) -
            self.m[3] * (self.m[1] * self.m[8] - self.m[2] * self.m[7]) +
            self.m[6] * (self.m[1] * self.m[5] - self.m[2] * self.m[4]);
    }

    /// Returns null if the matrix is singular or near-singular at f32 precision.
    pub fn inverse(self: Mat3) ?Mat3 {
        const det = self.determinant();
        if (@abs(det) < 1e-6) return null;
        const inv_det = 1.0 / det;

        return .{ .m = .{
            (self.m[4] * self.m[8] - self.m[5] * self.m[7]) * inv_det,
            (self.m[2] * self.m[7] - self.m[1] * self.m[8]) * inv_det,
            (self.m[1] * self.m[5] - self.m[2] * self.m[4]) * inv_det,
            (self.m[5] * self.m[6] - self.m[3] * self.m[8]) * inv_det,
            (self.m[0] * self.m[8] - self.m[2] * self.m[6]) * inv_det,
            (self.m[2] * self.m[3] - self.m[0] * self.m[5]) * inv_det,
            (self.m[3] * self.m[7] - self.m[4] * self.m[6]) * inv_det,
            (self.m[1] * self.m[6] - self.m[0] * self.m[7]) * inv_det,
            (self.m[0] * self.m[4] - self.m[1] * self.m[3]) * inv_det,
        } };
    }

    /// Extract upper-left 3x3 from a Mat4 (rotation + scale).
    pub fn fromMat4(m: Mat4) Mat3 {
        return .{ .m = .{
            m.m[0], m.m[1], m.m[2],
            m.m[4], m.m[5], m.m[6],
            m.m[8], m.m[9], m.m[10],
        } };
    }

    /// Normal matrix: inverse transpose of the upper-left 3x3.
    pub fn normalMatrix(model: Mat4) ?Mat3 {
        const upper = fromMat4(model);
        const inv = upper.inverse() orelse return null;
        return inv.transpose();
    }

    /// 2D translation (as a 3x3 homogeneous matrix).
    pub fn translate2D(v: Vec2) Mat3 {
        var result = identity;
        result.m[6] = v.x;
        result.m[7] = v.y;
        return result;
    }

    /// 2D rotation by `angle` radians, counter-clockwise.
    /// Literal layout below is column-major: each row of source text is one column of the matrix.
    pub fn rotate2D(angle: f32) Mat3 {
        const c = @cos(angle);
        const s = @sin(angle);
        return .{ .m = .{
            c,  s, 0,
            -s, c, 0,
            0,  0, 1,
        } };
    }

    /// 2D scaling.
    pub fn scale2D(v: Vec2) Mat3 {
        var result = zero;
        result.m[0] = v.x;
        result.m[4] = v.y;
        result.m[8] = 1;
        return result;
    }

    pub fn eql(a: Mat3, b: Mat3) bool {
        return std.mem.eql(f32, &a.m, &b.m);
    }

    pub fn approxEql(a: Mat3, b: Mat3, eps: f32) bool {
        for (0..9) |i| {
            if (@abs(a.m[i] - b.m[i]) > eps) return false;
        }
        return true;
    }
};

test "mat3 identity mul" {
    const v = Vec3.new(1, 2, 3);
    const result = Mat3.identity.mulVec(v);
    try std.testing.expect(result.eql(v));
}

test "mat3 inverse" {
    const r = Mat3.rotate2D(1.0);
    const inv = r.inverse().?;
    const product = Mat3.mul(r, inv);
    try std.testing.expect(product.approxEql(Mat3.identity, 1e-5));
}

test "mat3 inverse non-trivial" {
    // Non-uniform scale composed with rotation.
    const m = Mat3.mul(Mat3.rotate2D(0.7), Mat3.scale2D(Vec2.new(2, 5)));
    const inv = m.inverse().?;
    try std.testing.expect(Mat3.mul(m, inv).approxEql(Mat3.identity, 1e-4));
}

test "mat3 inverse singular returns null" {
    const singular = Mat3{ .m = .{ 1, 2, 3, 2, 4, 6, 3, 6, 9 } };
    try std.testing.expect(singular.inverse() == null);
}

test "mat3 normal matrix preserves angle under non-uniform scale" {
    // The whole point of a normal matrix is that surface normals stay perpendicular
    // to the surface after a non-uniform scale. Build a model with skewed scale,
    // transform a tangent and a normal, and check the angle stays 90 degrees.
    const model = Mat4.mul(Mat4.scale(Vec3.new(3, 1, 1)), Mat4.rotateY(0.4));
    const nm = Mat3.normalMatrix(model).?;
    const upper = Mat3.fromMat4(model);

    const tangent = Vec3.new(0, 0, 1); // unit Z in object space
    const normal = Vec3.new(0, 1, 0); // unit Y, perpendicular to tangent

    const t_world = upper.mulVec(tangent);
    const n_world = nm.mulVec(normal).normalize();
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), Vec3.dot(t_world, n_world), 1e-5);
}

test "mat3 2D translate" {
    const t = Mat3.translate2D(Vec2.new(5, 10));
    const p = t.mulVec(Vec3.new(0, 0, 1));
    try std.testing.expectApproxEqAbs(@as(f32, 5.0), p.x, 1e-5);
    try std.testing.expectApproxEqAbs(@as(f32, 10.0), p.y, 1e-5);
}
