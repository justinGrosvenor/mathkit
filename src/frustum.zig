const std = @import("std");
const Vec3 = @import("vec3.zig").Vec3;
const Vec4 = @import("vec4.zig").Vec4;
const Mat4 = @import("mat4.zig").Mat4;
const AABB = @import("bounds.zig").AABB;

pub const Plane = struct {
    normal: Vec3,
    d: f32,

    /// XZ plane at y=0, normal pointing up. Useful as a ground reference for picking.
    pub const ground = Plane{ .normal = Vec3.unit_y, .d = 0 };

    /// Returns the plane unchanged if its normal has zero length.
    pub fn normalize(self: Plane) Plane {
        const len = self.normal.length();
        if (len == 0) return self;
        const inv = 1.0 / len;
        return .{
            .normal = self.normal.scale(inv),
            .d = self.d * inv,
        };
    }

    pub fn distToPoint(self: Plane, p: Vec3) f32 {
        return Vec3.dot(self.normal, p) + self.d;
    }
};

/// View frustum extracted from a view-projection matrix.
pub const Frustum = struct {
    planes: [6]Plane,

    pub const Left = 0;
    pub const Right = 1;
    pub const Bottom = 2;
    pub const Top = 3;
    pub const Near = 4;
    pub const Far = 5;

    /// Extract frustum planes from a view-projection matrix.
    pub fn fromViewProj(vp: Mat4) Frustum {
        const m = vp.m;
        var planes: [6]Plane = undefined;

        // Left:   row3 + row0
        planes[Left] = (Plane{
            .normal = Vec3.new(m[3] + m[0], m[7] + m[4], m[11] + m[8]),
            .d = m[15] + m[12],
        }).normalize();

        // Right:  row3 - row0
        planes[Right] = (Plane{
            .normal = Vec3.new(m[3] - m[0], m[7] - m[4], m[11] - m[8]),
            .d = m[15] - m[12],
        }).normalize();

        // Bottom: row3 + row1
        planes[Bottom] = (Plane{
            .normal = Vec3.new(m[3] + m[1], m[7] + m[5], m[11] + m[9]),
            .d = m[15] + m[13],
        }).normalize();

        // Top:    row3 - row1
        planes[Top] = (Plane{
            .normal = Vec3.new(m[3] - m[1], m[7] - m[5], m[11] - m[9]),
            .d = m[15] - m[13],
        }).normalize();

        // Near:   row3 + row2  (for [0,1] clip z)
        planes[Near] = (Plane{
            .normal = Vec3.new(m[2], m[6], m[10]),
            .d = m[14],
        }).normalize();

        // Far:    row3 - row2
        planes[Far] = (Plane{
            .normal = Vec3.new(m[3] - m[2], m[7] - m[6], m[11] - m[10]),
            .d = m[15] - m[14],
        }).normalize();

        return .{ .planes = planes };
    }

    /// Test if a point is inside the frustum.
    pub fn containsPoint(self: Frustum, p: Vec3) bool {
        for (self.planes) |plane| {
            if (plane.distToPoint(p) < 0) return false;
        }
        return true;
    }

    /// Test if an AABB intersects or is inside the frustum.
    pub fn intersectsAABB(self: Frustum, box: AABB) bool {
        for (self.planes) |plane| {
            const px = if (plane.normal.x >= 0) box.max.x else box.min.x;
            const py = if (plane.normal.y >= 0) box.max.y else box.min.y;
            const pz = if (plane.normal.z >= 0) box.max.z else box.min.z;

            if (plane.distToPoint(Vec3.new(px, py, pz)) < 0) return false;
        }
        return true;
    }

    /// Test if a sphere intersects or is inside the frustum.
    pub fn intersectsSphere(self: Frustum, center: Vec3, radius: f32) bool {
        for (self.planes) |plane| {
            if (plane.distToPoint(center) < -radius) return false;
        }
        return true;
    }
};

test "frustum contains origin" {
    const view = Mat4.lookAt(Vec3.new(0, 0, 5), Vec3.zero, Vec3.up).?;
    const proj = Mat4.perspective(std.math.pi / 4.0, 1.0, 0.1, 100.0);
    const vp = Mat4.mul(proj, view);
    const frustum = Frustum.fromViewProj(vp);
    try std.testing.expect(frustum.containsPoint(Vec3.zero));
    try std.testing.expect(!frustum.containsPoint(Vec3.new(100, 0, 0)));
}

test "frustum aabb intersection" {
    const view = Mat4.lookAt(Vec3.new(0, 0, 5), Vec3.zero, Vec3.up).?;
    const proj = Mat4.perspective(std.math.pi / 4.0, 1.0, 0.1, 100.0);
    const vp = Mat4.mul(proj, view);
    const frustum = Frustum.fromViewProj(vp);

    const visible = AABB.fromCenterExtents(Vec3.zero, Vec3.one);
    const offscreen = AABB.fromCenterExtents(Vec3.new(100, 0, 0), Vec3.one);

    try std.testing.expect(frustum.intersectsAABB(visible));
    try std.testing.expect(!frustum.intersectsAABB(offscreen));
}

test "frustum aabb straddling and fully outside" {
    const view = Mat4.lookAt(Vec3.new(0, 0, 5), Vec3.zero, Vec3.up).?;
    const proj = Mat4.perspective(std.math.pi / 4.0, 1.0, 0.1, 100.0);
    const frustum = Frustum.fromViewProj(Mat4.mul(proj, view));

    // Box straddles the near plane: half inside, half behind the camera.
    const straddling = AABB.new(Vec3.new(-0.5, -0.5, 4), Vec3.new(0.5, 0.5, 6));
    try std.testing.expect(frustum.intersectsAABB(straddling));

    // Box well above the top plane.
    const above = AABB.fromCenterExtents(Vec3.new(0, 100, 0), Vec3.one);
    try std.testing.expect(!frustum.intersectsAABB(above));
}

test "frustum sphere intersection" {
    const view = Mat4.lookAt(Vec3.new(0, 0, 5), Vec3.zero, Vec3.up).?;
    const proj = Mat4.perspective(std.math.pi / 4.0, 1.0, 0.1, 100.0);
    const frustum = Frustum.fromViewProj(Mat4.mul(proj, view));

    try std.testing.expect(frustum.intersectsSphere(Vec3.zero, 1.0));
    try std.testing.expect(!frustum.intersectsSphere(Vec3.new(100, 0, 0), 1.0));
}
