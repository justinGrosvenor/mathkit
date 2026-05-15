const Vec3 = @import("vec3.zig").Vec3;
const Vec4 = @import("vec4.zig").Vec4;
const Quat = @import("quat.zig").Quat;
const Mat4 = @import("mat4.zig").Mat4;

pub const Transform = struct {
    position: Vec3 = Vec3.zero,
    rotation: Quat = Quat.identity,
    scale: Vec3 = Vec3.one,

    pub const identity = Transform{};

    pub fn toMat4(self: Transform) Mat4 {
        const s = Mat4.scale(self.scale);
        const r = self.rotation.toMat4();
        const t = Mat4.translate(self.position);
        return Mat4.mul(t, Mat4.mul(r, s));
    }

    /// Decompose a 4x4 into TRS. Loses information if the matrix encodes shear
    /// (rotated non-uniform scale) — the result is the closest TRS approximation.
    /// If the upper 3x3 has negative determinant, the X scale axis absorbs the
    /// sign flip so the rotation stays a proper (det=+1) rotation.
    pub fn fromMat4(m: Mat4) Transform {
        const Mat3 = @import("mat3.zig").Mat3;
        const position = Vec3.new(m.m[12], m.m[13], m.m[14]);

        var sx = Vec3.new(m.m[0], m.m[1], m.m[2]).length();
        const sy = Vec3.new(m.m[4], m.m[5], m.m[6]).length();
        const sz = Vec3.new(m.m[8], m.m[9], m.m[10]).length();

        // Detect reflection: if det of upper 3x3 is negative, flip sx.
        const upper_det =
            m.m[0] * (m.m[5] * m.m[10] - m.m[6] * m.m[9]) -
            m.m[4] * (m.m[1] * m.m[10] - m.m[2] * m.m[9]) +
            m.m[8] * (m.m[1] * m.m[6] - m.m[2] * m.m[5]);
        if (upper_det < 0) sx = -sx;

        const inv_sx = if (sx != 0) 1.0 / sx else 0;
        const inv_sy = if (sy != 0) 1.0 / sy else 0;
        const inv_sz = if (sz != 0) 1.0 / sz else 0;
        const rot_mat = Mat3{ .m = .{
            m.m[0] * inv_sx, m.m[1] * inv_sx, m.m[2] * inv_sx,
            m.m[4] * inv_sy, m.m[5] * inv_sy, m.m[6] * inv_sy,
            m.m[8] * inv_sz, m.m[9] * inv_sz, m.m[10] * inv_sz,
        } };

        return .{
            .position = position,
            .rotation = Quat.fromMat3(rot_mat),
            .scale = Vec3.new(sx, sy, sz),
        };
    }

    pub fn forward(self: Transform) Vec3 {
        return self.rotation.rotateVec(Vec3.forward);
    }

    pub fn right(self: Transform) Vec3 {
        return self.rotation.rotateVec(Vec3.right);
    }

    pub fn up(self: Transform) Vec3 {
        return self.rotation.rotateVec(Vec3.up);
    }

    pub fn transformPoint(self: Transform, point: Vec3) Vec3 {
        const scaled = Vec3.mul(point, self.scale);
        const rotated = self.rotation.rotateVec(scaled);
        return Vec3.add(rotated, self.position);
    }

    /// Transform a free vector by scale and rotation, without translation.
    pub fn transformVector(self: Transform, vector: Vec3) Vec3 {
        return self.rotation.rotateVec(Vec3.mul(vector, self.scale));
    }

    /// Transform a direction by rotation only.
    pub fn transformDirection(self: Transform, dir: Vec3) Vec3 {
        return self.rotation.rotateVec(dir);
    }

    pub fn lerp(a: Transform, b: Transform, t: f32) Transform {
        return .{
            .position = Vec3.lerp(a.position, b.position, t),
            .rotation = Quat.slerp(a.rotation, b.rotation, t),
            .scale = Vec3.lerp(a.scale, b.scale, t),
        };
    }

    /// Compose parent and child TRS transforms.
    /// This cannot represent shear created by rotated non-uniform scale. Use
    /// Mat4.mul(parent.toMat4(), child.toMat4()) when exact matrix composition is required.
    pub fn mul(parent: Transform, child: Transform) Transform {
        return .{
            .position = parent.transformPoint(child.position),
            .rotation = Quat.mul(parent.rotation, child.rotation),
            .scale = Vec3.mul(parent.scale, child.scale),
        };
    }

    /// Returns the TRS inverse such that `Transform.mul(t, t.inverse())` is
    /// the identity. Like `Transform.mul`, this is exact only when the scale
    /// is uniform or the rotation is identity; with rotated non-uniform scale
    /// the result is an approximation and round-tripping a point via
    /// `t.inverse().transformPoint(t.transformPoint(p))` will not return `p`.
    /// For the general case use `t.toMat4().inverse()`.
    pub fn inverse(self: Transform) Transform {
        const inv_rot = self.rotation.inverse();
        const inv_scale = Vec3.new(
            if (self.scale.x != 0) 1.0 / self.scale.x else 0,
            if (self.scale.y != 0) 1.0 / self.scale.y else 0,
            if (self.scale.z != 0) 1.0 / self.scale.z else 0,
        );
        const neg_pos = Vec3.neg(self.position);
        const rotated = inv_rot.rotateVec(neg_pos);
        const inv_pos = Vec3.mul(rotated, inv_scale);
        return .{
            .position = inv_pos,
            .rotation = inv_rot,
            .scale = inv_scale,
        };
    }
};

const std = @import("std");

test "transform identity" {
    const t = Transform.identity;
    const m = t.toMat4();
    try std.testing.expect(m.approxEql(Mat4.identity, 1e-6));
}

test "transform compose" {
    const parent = Transform{
        .position = Vec3.new(10, 0, 0),
        .rotation = Quat.identity,
        .scale = Vec3.new(2, 2, 2),
    };
    const child = Transform{
        .position = Vec3.new(1, 0, 0),
    };
    const combined = Transform.mul(parent, child);
    try std.testing.expect(combined.position.approxEql(Vec3.new(12, 0, 0), 1e-5));
}

test "transform point matches matrix" {
    const t = Transform{
        .position = Vec3.new(3, 4, 5),
        .rotation = Quat.fromAxisAngle(Vec3.unit_y, 0.7),
        .scale = Vec3.new(2, 3, 4),
    };
    const p = Vec3.new(1, 2, 3);
    const direct = t.transformPoint(p);
    const matrix = t.toMat4().mulVec(Vec4.fromVec3(p, 1)).xyz();
    try std.testing.expect(direct.approxEql(matrix, 1e-5));
}

test "transform direction ignores scale" {
    const t = Transform{
        .rotation = Quat.fromAxisAngle(Vec3.unit_y, std.math.pi / 2.0),
        .scale = Vec3.new(2, 3, 4),
    };
    const dir = t.transformDirection(Vec3.unit_x);
    const vec = t.transformVector(Vec3.unit_x);
    try std.testing.expect(dir.approxEql(Vec3.new(0, 0, -1), 1e-5));
    try std.testing.expect(vec.approxEql(Vec3.new(0, 0, -2), 1e-5));
}

test "transform fromMat4 roundtrip" {
    const original = Transform{
        .position = Vec3.new(1.5, -2.0, 3.25),
        .rotation = Quat.fromAxisAngle(Vec3.new(1, 2, 3).normalize(), 1.1),
        .scale = Vec3.new(2.0, 3.0, 4.0),
    };
    const recovered = Transform.fromMat4(original.toMat4());

    try std.testing.expect(recovered.position.approxEql(original.position, 1e-4));
    try std.testing.expect(recovered.scale.approxEql(original.scale, 1e-4));

    // Compare rotations by their action on a vector — handles q vs -q.
    const v = Vec3.new(0.5, 1.2, -0.7);
    try std.testing.expect(
        recovered.rotation.rotateVec(v).approxEql(original.rotation.rotateVec(v), 1e-4),
    );
}

test "transform inverse roundtrip" {
    const t = Transform{
        .position = Vec3.new(3, 4, 5),
        .rotation = Quat.fromAxisAngle(Vec3.unit_y, 1.0),
        .scale = Vec3.new(2, 3, 4),
    };
    const inv = t.inverse();
    const product = Transform.mul(t, inv);
    try std.testing.expect(product.position.approxEql(Vec3.zero, 1e-4));
    try std.testing.expect(product.scale.approxEql(Vec3.one, 1e-4));
}
