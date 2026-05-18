const std = @import("std");
const Vec3 = @import("vec3.zig").Vec3;
const Vec4 = @import("vec4.zig").Vec4;

/// Column-major 4x4 matrix. Columns stored contiguously for GPU upload.
/// m[col][row] — m[0] is the first column.
pub const Mat4 = extern struct {
    m: [16]f32,

    pub const identity = Mat4{ .m = .{
        1, 0, 0, 0,
        0, 1, 0, 0,
        0, 0, 1, 0,
        0, 0, 0, 1,
    } };

    pub const zero = Mat4{ .m = .{
        0, 0, 0, 0,
        0, 0, 0, 0,
        0, 0, 0, 0,
        0, 0, 0, 0,
    } };

    pub fn fromColumns(c0: Vec4, c1: Vec4, c2: Vec4, c3: Vec4) Mat4 {
        return .{ .m = .{
            c0.x, c0.y, c0.z, c0.w,
            c1.x, c1.y, c1.z, c1.w,
            c2.x, c2.y, c2.z, c2.w,
            c3.x, c3.y, c3.z, c3.w,
        } };
    }

    pub fn col(self: Mat4, c: u2) Vec4 {
        const i: usize = @as(usize, c) * 4;
        return .{ .x = self.m[i], .y = self.m[i + 1], .z = self.m[i + 2], .w = self.m[i + 3] };
    }

    pub fn row(self: Mat4, r: u2) Vec4 {
        const i: usize = r;
        return .{ .x = self.m[i], .y = self.m[i + 4], .z = self.m[i + 8], .w = self.m[i + 12] };
    }

    pub fn at(self: Mat4, c: u2, r: u2) f32 {
        return self.m[@as(usize, c) * 4 + r];
    }

    pub fn mulVec(a: Mat4, v: Vec4) Vec4 {
        const c0 = a.col(0);
        const c1 = a.col(1);
        const c2 = a.col(2);
        const c3 = a.col(3);
        return .{
            .x = c0.x * v.x + c1.x * v.y + c2.x * v.z + c3.x * v.w,
            .y = c0.y * v.x + c1.y * v.y + c2.y * v.z + c3.y * v.w,
            .z = c0.z * v.x + c1.z * v.y + c2.z * v.z + c3.z * v.w,
            .w = c0.w * v.x + c1.w * v.y + c2.w * v.z + c3.w * v.w,
        };
    }

    pub fn transformPoint(a: Mat4, p: Vec3) Vec3 {
        const v = a.mulVec(Vec4.fromVec3(p, 1));
        if (v.w == 0) return v.xyz();
        return Vec3.scale(v.xyz(), 1.0 / v.w);
    }

    pub fn transformVector(a: Mat4, v: Vec3) Vec3 {
        return a.mulVec(Vec4.fromVec3(v, 0)).xyz();
    }

    /// Apply the upper 3x3 (rotation + scale) and renormalize.
    /// Fast, but not correct for non-uniform scale — the result is not
    /// guaranteed perpendicular to surfaces transformed by the same matrix.
    /// For surface normals under arbitrary scale, use `transformNormal`.
    pub fn transformDirectionFast(a: Mat4, dir: Vec3) Vec3 {
        return a.transformVector(dir).normalize();
    }

    /// Transform a surface normal correctly under arbitrary scale by applying
    /// the normal matrix (inverse-transpose of the upper 3x3). Returns null if
    /// the upper 3x3 is singular.
    pub fn transformNormal(a: Mat4, normal: Vec3) ?Vec3 {
        const nm = @import("mat3.zig").Mat3.normalMatrix(a) orelse return null;
        return nm.mulVec(normal).normalize();
    }

    pub fn mul(a: Mat4, b: Mat4) Mat4 {
        var result: Mat4 = undefined;
        inline for (0..4) |c| {
            const bc = b.col(@intCast(c));
            const r = mulVec(a, bc);
            const i = c * 4;
            result.m[i] = r.x;
            result.m[i + 1] = r.y;
            result.m[i + 2] = r.z;
            result.m[i + 3] = r.w;
        }
        return result;
    }

    pub fn transpose(a: Mat4) Mat4 {
        var result: Mat4 = undefined;
        inline for (0..4) |c| {
            inline for (0..4) |r| {
                result.m[c * 4 + r] = a.m[r * 4 + c];
            }
        }
        return result;
    }

    pub fn translate(v: Vec3) Mat4 {
        var result = identity;
        result.m[12] = v.x;
        result.m[13] = v.y;
        result.m[14] = v.z;
        return result;
    }

    pub fn scale(v: Vec3) Mat4 {
        var result = zero;
        result.m[0] = v.x;
        result.m[5] = v.y;
        result.m[10] = v.z;
        result.m[15] = 1;
        return result;
    }

    pub fn uniformScale(s: f32) Mat4 {
        return scale(Vec3.splat(s));
    }

    pub fn fromTranslationRotationScale(translation: Vec3, rotation: @import("quat.zig").Quat, scale_: Vec3) Mat4 {
        return Mat4.mul(translate(translation), Mat4.mul(rotation.toMat4(), scale(scale_)));
    }

    pub fn rotateX(angle: f32) Mat4 {
        const c = @cos(angle);
        const s = @sin(angle);
        var result = identity;
        result.m[5] = c;
        result.m[6] = s;
        result.m[9] = -s;
        result.m[10] = c;
        return result;
    }

    pub fn rotateY(angle: f32) Mat4 {
        const c = @cos(angle);
        const s = @sin(angle);
        var result = identity;
        result.m[0] = c;
        result.m[2] = -s;
        result.m[8] = s;
        result.m[10] = c;
        return result;
    }

    pub fn rotateZ(angle: f32) Mat4 {
        const c = @cos(angle);
        const s = @sin(angle);
        var result = identity;
        result.m[0] = c;
        result.m[1] = s;
        result.m[4] = -s;
        result.m[5] = c;
        return result;
    }

    pub fn rotateAxis(axis: Vec3, angle: f32) Mat4 {
        if (axis.lengthSq() == 0) return identity;
        const a = axis.normalize();
        const c = @cos(angle);
        const s = @sin(angle);
        const t = 1.0 - c;

        return .{ .m = .{
            t * a.x * a.x + c,       t * a.x * a.y + s * a.z, t * a.x * a.z - s * a.y, 0,
            t * a.x * a.y - s * a.z, t * a.y * a.y + c,       t * a.y * a.z + s * a.x, 0,
            t * a.x * a.z + s * a.y, t * a.y * a.z - s * a.x, t * a.z * a.z + c,       0,
            0,                       0,                       0,                       1,
        } };
    }

    /// Right-handed look-at view matrix.
    /// Returns null if eye equals target, or if the forward direction is parallel to world_up.
    pub fn lookAt(eye: Vec3, target: Vec3, world_up: Vec3) ?Mat4 {
        const f = Vec3.normalize(Vec3.sub(target, eye));
        if (f.lengthSq() == 0) return null;
        const s = Vec3.normalize(Vec3.cross(f, world_up));
        if (s.lengthSq() == 0) return null;
        const u = Vec3.cross(s, f);

        return .{ .m = .{
            s.x,               u.x,               -f.x,             0,
            s.y,               u.y,               -f.y,             0,
            s.z,               u.z,               -f.z,             0,
            -Vec3.dot(s, eye), -Vec3.dot(u, eye), Vec3.dot(f, eye), 1,
        } };
    }

    /// Perspective projection. fov_y in radians. Clip space z: [0, 1] (WebGPU).
    pub fn perspective(fov_y: f32, aspect: f32, near: f32, far: f32) Mat4 {
        const f = 1.0 / @tan(fov_y * 0.5);
        const range_inv = 1.0 / (near - far);

        var result = zero;
        result.m[0] = f / aspect;
        result.m[5] = f;
        result.m[10] = far * range_inv;
        result.m[11] = -1;
        result.m[14] = near * far * range_inv;
        return result;
    }

    /// Orthographic projection. Clip space z: [0, 1] (WebGPU).
    pub fn ortho(left: f32, right_: f32, bottom: f32, top: f32, near: f32, far: f32) Mat4 {
        const rl = 1.0 / (right_ - left);
        const tb = 1.0 / (top - bottom);
        const fn_ = 1.0 / (near - far);

        var result = zero;
        result.m[0] = 2 * rl;
        result.m[5] = 2 * tb;
        result.m[10] = fn_;
        result.m[12] = -(right_ + left) * rl;
        result.m[13] = -(top + bottom) * tb;
        result.m[14] = near * fn_;
        result.m[15] = 1;
        return result;
    }

    pub fn determinant(self: Mat4) f32 {
        const m = self.m;

        const a00 = m[0];
        const a01 = m[1];
        const a02 = m[2];
        const a03 = m[3];
        const a10 = m[4];
        const a11 = m[5];
        const a12 = m[6];
        const a13 = m[7];
        const a20 = m[8];
        const a21 = m[9];
        const a22 = m[10];
        const a23 = m[11];
        const a30 = m[12];
        const a31 = m[13];
        const a32 = m[14];
        const a33 = m[15];

        return a00 * (a11 * (a22 * a33 - a23 * a32) - a21 * (a12 * a33 - a13 * a32) + a31 * (a12 * a23 - a13 * a22)) -
            a10 * (a01 * (a22 * a33 - a23 * a32) - a21 * (a02 * a33 - a03 * a32) + a31 * (a02 * a23 - a03 * a22)) +
            a20 * (a01 * (a12 * a33 - a13 * a32) - a11 * (a02 * a33 - a03 * a32) + a31 * (a02 * a13 - a03 * a12)) -
            a30 * (a01 * (a12 * a23 - a13 * a22) - a11 * (a02 * a23 - a03 * a22) + a21 * (a02 * a13 - a03 * a12));
    }

    /// Returns null if the matrix is singular or near-singular at f32 precision.
    pub fn inverse(self: Mat4) ?Mat4 {
        const m = self.m;

        const a00 = m[0];
        const a01 = m[1];
        const a02 = m[2];
        const a03 = m[3];
        const a10 = m[4];
        const a11 = m[5];
        const a12 = m[6];
        const a13 = m[7];
        const a20 = m[8];
        const a21 = m[9];
        const a22 = m[10];
        const a23 = m[11];
        const a30 = m[12];
        const a31 = m[13];
        const a32 = m[14];
        const a33 = m[15];

        const b00 = a00 * a11 - a01 * a10;
        const b01 = a00 * a12 - a02 * a10;
        const b02 = a00 * a13 - a03 * a10;
        const b03 = a01 * a12 - a02 * a11;
        const b04 = a01 * a13 - a03 * a11;
        const b05 = a02 * a13 - a03 * a12;
        const b06 = a20 * a31 - a21 * a30;
        const b07 = a20 * a32 - a22 * a30;
        const b08 = a20 * a33 - a23 * a30;
        const b09 = a21 * a32 - a22 * a31;
        const b10 = a21 * a33 - a23 * a31;
        const b11 = a22 * a33 - a23 * a32;

        const det = b00 * b11 - b01 * b10 + b02 * b09 + b03 * b08 - b04 * b07 + b05 * b06;
        if (@abs(det) < 1e-6) return null;

        const inv_det = 1.0 / det;

        return .{ .m = .{
            (a11 * b11 - a12 * b10 + a13 * b09) * inv_det,
            (-a01 * b11 + a02 * b10 - a03 * b09) * inv_det,
            (a31 * b05 - a32 * b04 + a33 * b03) * inv_det,
            (-a21 * b05 + a22 * b04 - a23 * b03) * inv_det,
            (-a10 * b11 + a12 * b08 - a13 * b07) * inv_det,
            (a00 * b11 - a02 * b08 + a03 * b07) * inv_det,
            (-a30 * b05 + a32 * b02 - a33 * b01) * inv_det,
            (a20 * b05 - a22 * b02 + a23 * b01) * inv_det,
            (a10 * b10 - a11 * b08 + a13 * b06) * inv_det,
            (-a00 * b10 + a01 * b08 - a03 * b06) * inv_det,
            (a30 * b04 - a31 * b02 + a33 * b00) * inv_det,
            (-a20 * b04 + a21 * b02 - a23 * b00) * inv_det,
            (-a10 * b09 + a11 * b07 - a12 * b06) * inv_det,
            (a00 * b09 - a01 * b07 + a02 * b06) * inv_det,
            (-a30 * b03 + a31 * b01 - a32 * b00) * inv_det,
            (a20 * b03 - a21 * b01 + a22 * b00) * inv_det,
        } };
    }

    pub fn eql(a: Mat4, b: Mat4) bool {
        return std.mem.eql(f32, &a.m, &b.m);
    }

    pub fn approxEql(a: Mat4, b: Mat4, eps: f32) bool {
        for (0..16) |i| {
            if (@abs(a.m[i] - b.m[i]) > eps) return false;
        }
        return true;
    }
};

test "mat4 identity mul" {
    const v = Vec4.new(1, 2, 3, 1);
    const result = Mat4.identity.mulVec(v);
    try std.testing.expect(result.eql(v));
}

test "mat4 translate" {
    const t = Mat4.translate(Vec3.new(10, 20, 30));
    const v = t.mulVec(Vec4.new(0, 0, 0, 1));
    try std.testing.expect(v.approxEql(Vec4.new(10, 20, 30, 1), 1e-6));
}

test "mat4 transform helpers" {
    const m = Mat4.mul(Mat4.translate(Vec3.new(10, 0, 0)), Mat4.scale(Vec3.new(2, 3, 4)));
    try std.testing.expect(m.transformPoint(Vec3.new(1, 1, 1)).approxEql(Vec3.new(12, 3, 4), 1e-6));
    try std.testing.expect(m.transformVector(Vec3.new(1, 1, 1)).approxEql(Vec3.new(2, 3, 4), 1e-6));
}

test "mat4 transformNormal preserves perpendicularity under non-uniform scale" {
    // Tangent and normal start perpendicular in object space.
    // Under a stretching scale, transformVector(tangent) and transformDirectionFast(normal)
    // are no longer perpendicular, but transformVector(tangent) and transformNormal(normal) are.
    const m = Mat4.scale(Vec3.new(5, 1, 1));
    const tangent_obj = Vec3.new(0, 0, 1);
    const normal_obj = Vec3.new(0, 1, 0);

    const tangent_world = m.transformVector(tangent_obj);
    const normal_world = m.transformNormal(normal_obj).?;
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), Vec3.dot(tangent_world, normal_world), 1e-5);
}

test "mat4 mul associativity" {
    const a = Mat4.rotateY(0.5);
    const b = Mat4.translate(Vec3.new(1, 0, 0));
    const c = Mat4.scale(Vec3.new(2, 2, 2));
    const ab_c = Mat4.mul(Mat4.mul(a, b), c);
    const a_bc = Mat4.mul(a, Mat4.mul(b, c));
    try std.testing.expect(ab_c.approxEql(a_bc, 1e-5));
}

test "mat4 inverse" {
    const t = Mat4.translate(Vec3.new(3, 4, 5));
    const inv = t.inverse().?;
    const product = Mat4.mul(t, inv);
    try std.testing.expect(product.approxEql(Mat4.identity, 1e-5));
}

test "mat4 inverse trs roundtrip" {
    const Quat = @import("quat.zig").Quat;
    const m = Mat4.mul(
        Mat4.translate(Vec3.new(1, 2, 3)),
        Mat4.mul(
            Quat.fromAxisAngle(Vec3.new(1, 1, 0).normalize(), 0.9).toMat4(),
            Mat4.scale(Vec3.new(2, 3, 4)),
        ),
    );
    const inv = m.inverse().?;
    try std.testing.expect(Mat4.mul(m, inv).approxEql(Mat4.identity, 1e-4));
    try std.testing.expect(Mat4.mul(inv, m).approxEql(Mat4.identity, 1e-4));
}

test "mat4 inverse non-axis rotation" {
    const Quat = @import("quat.zig").Quat;
    const r = Quat.fromEulerXYZ(0.3, -0.7, 1.1).toMat4();
    const inv = r.inverse().?;
    try std.testing.expect(Mat4.mul(r, inv).approxEql(Mat4.identity, 1e-4));
}

test "mat4 inverse singular returns null" {
    // Rank-deficient: third column equals first.
    const singular = Mat4{ .m = .{
        1, 0, 0, 0,
        0, 1, 0, 0,
        1, 0, 0, 0,
        0, 0, 0, 1,
    } };
    try std.testing.expect(singular.inverse() == null);
}

test "mat4 perspective z range" {
    const p = Mat4.perspective(std.math.pi / 4.0, 1.0, 0.1, 100.0);
    // Near plane should map to z=0
    const near_pt = p.mulVec(Vec4.new(0, 0, -0.1, 1));
    const near_ndc_z = near_pt.z / near_pt.w;
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), near_ndc_z, 1e-5);
    // Far plane should map to z=1
    const far_pt = p.mulVec(Vec4.new(0, 0, -100, 1));
    const far_ndc_z = far_pt.z / far_pt.w;
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), far_ndc_z, 1e-4);
}

test "mat4 perspective non-square aspect" {
    // 16:9 aspect: a point on the +X side at the near plane should land
    // at NDC X = aspect-adjusted compared to the +Y side.
    const aspect: f32 = 16.0 / 9.0;
    const p = Mat4.perspective(std.math.pi / 3.0, aspect, 0.1, 100.0);

    // Pick a point at z=-1 with x=1, y=1. The clip-space x should be smaller
    // than clip-space y by a factor of 1/aspect.
    const clip = p.mulVec(Vec4.new(1, 1, -1, 1));
    try std.testing.expectApproxEqAbs(clip.x * aspect, clip.y, 1e-5);
}

test "mat4 fromColumns" {
    const m = Mat4.fromColumns(
        Vec4.new(1, 2, 3, 4),
        Vec4.new(5, 6, 7, 8),
        Vec4.new(9, 10, 11, 12),
        Vec4.new(13, 14, 15, 16),
    );
    try std.testing.expect(m.col(0).eql(Vec4.new(1, 2, 3, 4)));
    try std.testing.expect(m.col(3).eql(Vec4.new(13, 14, 15, 16)));
}

test "mat4 lookAt" {
    const view = Mat4.lookAt(Vec3.new(0, 0, 5), Vec3.zero, Vec3.up).?;
    const origin_view = view.mulVec(Vec4.new(0, 0, 0, 1));
    // Origin should be at -5 on the Z axis in view space
    try std.testing.expectApproxEqAbs(@as(f32, -5.0), origin_view.z, 1e-5);
}

test "mat4 lookAt degenerate inputs return null" {
    try std.testing.expect(Mat4.lookAt(Vec3.zero, Vec3.zero, Vec3.up) == null);
    // forward parallel to world_up
    try std.testing.expect(Mat4.lookAt(Vec3.zero, Vec3.new(0, 1, 0), Vec3.up) == null);
}
