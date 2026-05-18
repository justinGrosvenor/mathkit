const std = @import("std");
const Vec3 = @import("vec3.zig").Vec3;
const Mat4 = @import("mat4.zig").Mat4;

/// Quaternion stored as (x, y, z, w) where w is the scalar part.
pub const Quat = extern struct {
    x: f32 = 0,
    y: f32 = 0,
    z: f32 = 0,
    w: f32 = 1,

    pub const identity = Quat{};

    pub fn fromAxisAngle(axis: Vec3, angle: f32) Quat {
        if (axis.lengthSq() == 0) return identity;
        const half = angle * 0.5;
        const s = @sin(half);
        const a = axis.normalize();
        return .{ .x = a.x * s, .y = a.y * s, .z = a.z * s, .w = @cos(half) };
    }

    /// Shortest-arc quaternion rotating unit vector `from` to unit vector `to`.
    /// Antiparallel inputs are handled by picking an arbitrary perpendicular axis.
    pub fn fromTo(from: Vec3, to: Vec3) Quat {
        const f = from.normalize();
        const t = to.normalize();
        const d = Vec3.dot(f, t);

        if (d > 0.99999) return identity;

        if (d < -0.99999) {
            // Antiparallel: rotate 180° around any axis perpendicular to f.
            // Pick the world axis least aligned with f to avoid near-zero cross.
            const axis_seed = if (@abs(f.x) < 0.9) Vec3.unit_x else Vec3.unit_y;
            const axis = Vec3.cross(f, axis_seed).normalize();
            return .{ .x = axis.x, .y = axis.y, .z = axis.z, .w = 0 };
        }

        // Stable shortest-arc construction (Stan Melax).
        const c = Vec3.cross(f, t);
        const s = @sqrt((1.0 + d) * 2.0);
        const inv_s = 1.0 / s;
        return (Quat{
            .x = c.x * inv_s,
            .y = c.y * inv_s,
            .z = c.z * inv_s,
            .w = s * 0.5,
        }).normalize();
    }

    /// Build a quaternion from intrinsic X then Y then Z rotations, in radians.
    /// X is pitch, Y is yaw, Z is roll. Equivalent to
    /// Mat4.rotateZ(z) * Mat4.rotateY(y) * Mat4.rotateX(x).
    pub fn fromEulerXYZ(x: f32, y: f32, z: f32) Quat {
        const qx = fromAxisAngle(Vec3.unit_x, x);
        const qy = fromAxisAngle(Vec3.unit_y, y);
        const qz = fromAxisAngle(Vec3.unit_z, z);
        return normalize(mul(qz, mul(qy, qx)));
    }

    pub fn mul(a: Quat, b: Quat) Quat {
        return .{
            .x = a.w * b.x + a.x * b.w + a.y * b.z - a.z * b.y,
            .y = a.w * b.y - a.x * b.z + a.y * b.w + a.z * b.x,
            .z = a.w * b.z + a.x * b.y - a.y * b.x + a.z * b.w,
            .w = a.w * b.w - a.x * b.x - a.y * b.y - a.z * b.z,
        };
    }

    pub fn conjugate(q: Quat) Quat {
        return .{ .x = -q.x, .y = -q.y, .z = -q.z, .w = q.w };
    }

    pub fn neg(q: Quat) Quat {
        return .{ .x = -q.x, .y = -q.y, .z = -q.z, .w = -q.w };
    }

    pub fn lengthSq(q: Quat) f32 {
        return q.x * q.x + q.y * q.y + q.z * q.z + q.w * q.w;
    }

    pub fn length(q: Quat) f32 {
        return @sqrt(lengthSq(q));
    }

    /// Returns the identity quaternion if `q` has zero magnitude.
    pub fn normalize(q: Quat) Quat {
        const len = length(q);
        if (len == 0) return identity;
        const inv = 1.0 / len;
        return .{ .x = q.x * inv, .y = q.y * inv, .z = q.z * inv, .w = q.w * inv };
    }

    pub fn inverse(q: Quat) Quat {
        const len_sq = lengthSq(q);
        if (len_sq == 0) return identity;
        const inv = 1.0 / len_sq;
        return .{ .x = -q.x * inv, .y = -q.y * inv, .z = -q.z * inv, .w = q.w * inv };
    }

    pub fn isNormalized(q: Quat, eps: f32) bool {
        return @abs(q.lengthSq() - 1.0) <= eps;
    }

    pub fn rotateVec(q: Quat, v: Vec3) Vec3 {
        const u = Vec3.new(q.x, q.y, q.z);
        const s = q.w;
        return Vec3.add(
            Vec3.add(
                Vec3.scale(u, 2.0 * Vec3.dot(u, v)),
                Vec3.scale(v, s * s - Vec3.dot(u, u)),
            ),
            Vec3.scale(Vec3.cross(u, v), 2.0 * s),
        );
    }

    pub fn nlerp(a: Quat, b: Quat, t: f32) Quat {
        var b2 = b;
        if (dot(a, b) < 0) b2 = b.neg();
        return normalize(.{
            .x = a.x + (b2.x - a.x) * t,
            .y = a.y + (b2.y - a.y) * t,
            .z = a.z + (b2.z - a.z) * t,
            .w = a.w + (b2.w - a.w) * t,
        });
    }

    /// Extract a unit quaternion from the rotation part of a 3x3 matrix
    /// (Shoemake's trace-based method). Assumes `m` is a pure rotation; for a
    /// matrix that includes scale, divide each column by its length first.
    pub fn fromMat3(m: @import("mat3.zig").Mat3) Quat {
        const m00 = m.m[0];
        const m01 = m.m[1];
        const m02 = m.m[2];
        const m10 = m.m[3];
        const m11 = m.m[4];
        const m12 = m.m[5];
        const m20 = m.m[6];
        const m21 = m.m[7];
        const m22 = m.m[8];

        const trace = m00 + m11 + m22;
        if (trace > 0) {
            const s = @sqrt(trace + 1.0) * 2.0;
            return .{
                .w = 0.25 * s,
                .x = (m12 - m21) / s,
                .y = (m20 - m02) / s,
                .z = (m01 - m10) / s,
            };
        } else if (m00 > m11 and m00 > m22) {
            const s = @sqrt(1.0 + m00 - m11 - m22) * 2.0;
            return .{
                .w = (m12 - m21) / s,
                .x = 0.25 * s,
                .y = (m01 + m10) / s,
                .z = (m02 + m20) / s,
            };
        } else if (m11 > m22) {
            const s = @sqrt(1.0 + m11 - m00 - m22) * 2.0;
            return .{
                .w = (m20 - m02) / s,
                .x = (m01 + m10) / s,
                .y = 0.25 * s,
                .z = (m12 + m21) / s,
            };
        } else {
            const s = @sqrt(1.0 + m22 - m00 - m11) * 2.0;
            return .{
                .w = (m01 - m10) / s,
                .x = (m02 + m20) / s,
                .y = (m12 + m21) / s,
                .z = 0.25 * s,
            };
        }
    }

    /// Extract a unit quaternion from the upper-left 3x3 of a 4x4 matrix.
    /// Assumes the upper 3x3 is a pure rotation.
    pub fn fromMat4(m: Mat4) Quat {
        return fromMat3(@import("mat3.zig").Mat3.fromMat4(m));
    }

    pub fn toMat4(q: Quat) Mat4 {
        const xx = q.x * q.x;
        const yy = q.y * q.y;
        const zz = q.z * q.z;
        const xy = q.x * q.y;
        const xz = q.x * q.z;
        const yz = q.y * q.z;
        const wx = q.w * q.x;
        const wy = q.w * q.y;
        const wz = q.w * q.z;

        return .{ .m = .{
            1 - 2 * (yy + zz), 2 * (xy + wz),     2 * (xz - wy),     0,
            2 * (xy - wz),     1 - 2 * (xx + zz), 2 * (yz + wx),     0,
            2 * (xz + wy),     2 * (yz - wx),     1 - 2 * (xx + yy), 0,
            0,                 0,                 0,                 1,
        } };
    }

    pub fn dot(a: Quat, b: Quat) f32 {
        return a.x * b.x + a.y * b.y + a.z * b.z + a.w * b.w;
    }

    pub fn slerp(a: Quat, b: Quat, t: f32) Quat {
        var cos_theta = dot(a, b);
        var b2 = b;

        if (cos_theta < 0) {
            cos_theta = -cos_theta;
            b2 = .{ .x = -b.x, .y = -b.y, .z = -b.z, .w = -b.w };
        }

        if (cos_theta > 0.9995) {
            return normalize(.{
                .x = a.x + (b2.x - a.x) * t,
                .y = a.y + (b2.y - a.y) * t,
                .z = a.z + (b2.z - a.z) * t,
                .w = a.w + (b2.w - a.w) * t,
            });
        }

        const theta = std.math.acos(cos_theta);
        const sin_theta = @sin(theta);
        const wa = @sin((1.0 - t) * theta) / sin_theta;
        const wb = @sin(t * theta) / sin_theta;

        return .{
            .x = a.x * wa + b2.x * wb,
            .y = a.y * wa + b2.y * wb,
            .z = a.z * wa + b2.z * wb,
            .w = a.w * wa + b2.w * wb,
        };
    }

    /// Extract intrinsic XYZ Euler angles (radians) from a unit quaternion.
    /// Inverse of `fromEulerXYZ`. Returns (pitch, yaw, roll) as a Vec3.
    pub fn toEulerXYZ(q: Quat) Vec3 {
        const sinp = 2.0 * (q.w * q.y - q.z * q.x);
        const pitch_y = if (sinp >= 1.0)
            std.math.pi / 2.0
        else if (sinp <= -1.0)
            -std.math.pi / 2.0
        else
            std.math.asin(sinp);

        if (@abs(sinp) >= 0.9999) {
            const roll_x = 0;
            const yaw_z = 2.0 * std.math.atan2(q.x, q.w);
            return Vec3.new(roll_x, pitch_y, yaw_z);
        }

        const roll_x = std.math.atan2(
            2.0 * (q.w * q.x + q.y * q.z),
            1.0 - 2.0 * (q.x * q.x + q.y * q.y),
        );
        const yaw_z = std.math.atan2(
            2.0 * (q.w * q.z + q.x * q.y),
            1.0 - 2.0 * (q.y * q.y + q.z * q.z),
        );
        return Vec3.new(roll_x, pitch_y, yaw_z);
    }

    pub fn eql(a: Quat, b: Quat) bool {
        return a.x == b.x and a.y == b.y and a.z == b.z and a.w == b.w;
    }

    pub fn approxEql(a: Quat, b: Quat, eps: f32) bool {
        return @abs(a.x - b.x) <= eps and @abs(a.y - b.y) <= eps and
            @abs(a.z - b.z) <= eps and @abs(a.w - b.w) <= eps;
    }
};

test "quat identity" {
    const v = Vec3.new(1, 2, 3);
    const result = Quat.identity.rotateVec(v);
    try std.testing.expect(result.approxEql(v, 1e-6));
}

test "quat axis angle 90 deg Y" {
    const q = Quat.fromAxisAngle(Vec3.unit_y, std.math.pi / 2.0);
    const v = Vec3.unit_x;
    const result = q.rotateVec(v);
    try std.testing.expect(result.approxEql(Vec3.new(0, 0, -1), 1e-5));
}

test "quat axis angle zero axis is identity" {
    const q = Quat.fromAxisAngle(Vec3.zero, 1.0);
    try std.testing.expect(q.approxEql(Quat.identity, 1e-6));
}

test "quat euler xyz matches matrix order" {
    const x: f32 = 0.2;
    const y: f32 = -0.7;
    const z: f32 = 1.1;
    const q = Quat.fromEulerXYZ(x, y, z);
    const qm = q.toMat4();
    const rm = Mat4.mul(Mat4.rotateZ(z), Mat4.mul(Mat4.rotateY(y), Mat4.rotateX(x)));
    try std.testing.expect(qm.approxEql(rm, 1e-5));
}

test "quat fromEulerXYZ maps pitch yaw roll to X Y Z" {
    const angle: f32 = 0.6;
    try std.testing.expect(Quat.fromEulerXYZ(angle, 0, 0).toMat4().approxEql(Mat4.rotateX(angle), 1e-5));
    try std.testing.expect(Quat.fromEulerXYZ(0, angle, 0).toMat4().approxEql(Mat4.rotateY(angle), 1e-5));
    try std.testing.expect(Quat.fromEulerXYZ(0, 0, angle).toMat4().approxEql(Mat4.rotateZ(angle), 1e-5));
}

test "quat mul inverse is identity" {
    const q = Quat.fromAxisAngle(Vec3.new(1, 1, 0).normalize(), 1.2);
    const qi = q.inverse();
    const product = Quat.mul(q, qi);
    try std.testing.expect(product.approxEql(Quat.identity, 1e-5));
}

test "quat nlerp normalized" {
    const a = Quat.identity;
    const b = Quat.fromAxisAngle(Vec3.unit_y, std.math.pi);
    const mid = Quat.nlerp(a, b, 0.5);
    try std.testing.expect(mid.isNormalized(1e-5));
}

test "quat to mat4 matches rotate" {
    const angle: f32 = 0.7;
    const q = Quat.fromAxisAngle(Vec3.unit_y, angle);
    const qm = q.toMat4();
    const rm = Mat4.rotateY(angle);
    try std.testing.expect(qm.approxEql(rm, 1e-5));
}

test "quat to mat4 matches rotateVec for non-axis quat" {
    const q = Quat.fromAxisAngle(Vec3.new(1, 2, 3).normalize(), 1.3);
    const m = q.toMat4();
    const v = Vec3.new(0.7, -1.4, 2.1);
    const direct = q.rotateVec(v);
    const via_matrix = m.transformVector(v);
    try std.testing.expect(direct.approxEql(via_matrix, 1e-5));
}

test "quat fromMat3 round trip" {
    const cases = [_]Quat{
        Quat.fromAxisAngle(Vec3.unit_x, 0.3),
        Quat.fromAxisAngle(Vec3.unit_y, -1.7),
        Quat.fromAxisAngle(Vec3.unit_z, 2.5),
        Quat.fromAxisAngle(Vec3.new(1, 2, 3).normalize(), 1.1),
        Quat.fromEulerXYZ(0.3, -0.7, 1.1),
    };
    for (cases) |q| {
        const m = @import("mat3.zig").Mat3.fromMat4(q.toMat4());
        const recovered = Quat.fromMat3(m);
        // q and -q represent the same rotation; check either matches.
        const same = recovered.approxEql(q, 1e-4) or recovered.approxEql(q.neg(), 1e-4);
        try std.testing.expect(same);
    }
}

test "quat fromTo rotates from onto to" {
    const cases = [_]struct { from: Vec3, to: Vec3 }{
        .{ .from = Vec3.unit_x, .to = Vec3.unit_y },
        .{ .from = Vec3.unit_y, .to = Vec3.unit_z },
        .{ .from = Vec3.new(1, 2, 3).normalize(), .to = Vec3.new(-2, 1, 0.5).normalize() },
        .{ .from = Vec3.unit_z, .to = Vec3.new(0, 0, -1) }, // antiparallel
        .{ .from = Vec3.unit_x, .to = Vec3.unit_x }, // identical
    };
    for (cases) |c| {
        const q = Quat.fromTo(c.from, c.to);
        const rotated = q.rotateVec(c.from);
        try std.testing.expect(rotated.approxEql(c.to, 1e-4));
    }
}

test "quat toEulerXYZ round trips fromEulerXYZ" {
    const cases = [_][3]f32{
        .{ 0.3, -0.7, 1.1 },
        .{ 0, 0, 0 },
        .{ 0.5, 0, 0 },
        .{ 0, 0.8, 0 },
        .{ 0, 0, -0.4 },
        .{ -1.2, 0.3, 0.6 },
    };
    for (cases) |c| {
        const q = Quat.fromEulerXYZ(c[0], c[1], c[2]);
        const e = q.toEulerXYZ();
        try std.testing.expectApproxEqAbs(c[0], e.x, 1e-4);
        try std.testing.expectApproxEqAbs(c[1], e.y, 1e-4);
        try std.testing.expectApproxEqAbs(c[2], e.z, 1e-4);
    }
}

test "quat composition matches sequential rotation" {
    const q1 = Quat.fromAxisAngle(Vec3.unit_y, 0.6);
    const q2 = Quat.fromAxisAngle(Vec3.new(1, 0, 1).normalize(), -0.9);
    const v = Vec3.new(0.5, 1.2, -0.4);

    const composed = Quat.mul(q1, q2).rotateVec(v);
    const sequential = q1.rotateVec(q2.rotateVec(v));
    try std.testing.expect(composed.approxEql(sequential, 1e-5));
}

test "quat slerp endpoints" {
    const a = Quat.fromAxisAngle(Vec3.unit_y, 0);
    const b = Quat.fromAxisAngle(Vec3.unit_y, std.math.pi / 2.0);
    const start = Quat.slerp(a, b, 0);
    const end_ = Quat.slerp(a, b, 1);
    try std.testing.expect(start.approxEql(a, 1e-5));
    try std.testing.expect(end_.approxEql(b, 1e-5));
}
