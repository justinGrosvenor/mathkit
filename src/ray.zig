const std = @import("std");
const Vec3 = @import("vec3.zig").Vec3;
const AABB = @import("bounds.zig").AABB;
const Plane = @import("frustum.zig").Plane;

pub const Ray = struct {
    origin: Vec3,
    /// Expected to be a unit vector; callers should normalize before constructing.
    dir: Vec3,

    pub fn at(self: Ray, t: f32) Vec3 {
        return Vec3.add(self.origin, Vec3.scale(self.dir, t));
    }

    pub const Hit = struct {
        t: f32,
        point: Vec3,
        normal: Vec3,
    };

    pub const AABBHit = struct {
        t_min: f32,
        t_max: f32,

        pub fn entryPoint(self: AABBHit, ray: Ray) Vec3 {
            return ray.at(self.t_min);
        }

        pub fn exitPoint(self: AABBHit, ray: Ray) Vec3 {
            return ray.at(self.t_max);
        }
    };

    /// Ray-plane intersection. Plane normal must be normalized.
    pub fn intersectPlane(self: Ray, plane: Plane) ?Hit {
        const denom = Vec3.dot(plane.normal, self.dir);
        if (@abs(denom) < 1e-8) return null;

        const t = -(Vec3.dot(plane.normal, self.origin) + plane.d) / denom;
        if (t < 0) return null;

        return .{
            .t = t,
            .point = self.at(t),
            .normal = plane.normal,
        };
    }

    /// Ray-sphere intersection.
    pub fn intersectSphere(self: Ray, center: Vec3, radius: f32) ?Hit {
        const oc = Vec3.sub(self.origin, center);
        const a = Vec3.dot(self.dir, self.dir);
        const b = Vec3.dot(oc, self.dir);
        const c = Vec3.dot(oc, oc) - radius * radius;
        const disc = b * b - a * c;
        if (disc < 0) return null;

        const sqrt_disc = @sqrt(disc);
        var t = (-b - sqrt_disc) / a;
        if (t < 0) {
            t = (-b + sqrt_disc) / a;
            if (t < 0) return null;
        }

        const point = self.at(t);
        const normal = Vec3.scale(Vec3.sub(point, center), 1.0 / radius);

        return .{ .t = t, .point = point, .normal = normal };
    }

    /// Ray-AABB intersection (slab method).
    pub fn intersectAABB(self: Ray, box: AABB) ?f32 {
        const hit = self.intersectAABBInterval(box) orelse return null;
        return hit.t_min;
    }

    /// Ray-AABB intersection interval (slab method).
    pub fn intersectAABBInterval(self: Ray, box: AABB) ?AABBHit {
        var tmin: f32 = 0;
        var tmax: f32 = std.math.floatMax(f32);

        inline for (.{ .x, .y, .z }) |axis| {
            const origin = @field(self.origin, @tagName(axis));
            const dir = @field(self.dir, @tagName(axis));
            const bmin = @field(box.min, @tagName(axis));
            const bmax = @field(box.max, @tagName(axis));

            if (@abs(dir) < 1e-8) {
                if (origin < bmin or origin > bmax) return null;
            } else {
                const inv_d = 1.0 / dir;
                var t0 = (bmin - origin) * inv_d;
                var t1 = (bmax - origin) * inv_d;
                if (t0 > t1) {
                    const tmp = t0;
                    t0 = t1;
                    t1 = tmp;
                }
                tmin = @max(tmin, t0);
                tmax = @min(tmax, t1);
                if (tmin > tmax) return null;
            }
        }

        return .{ .t_min = tmin, .t_max = tmax };
    }

    /// Ray-triangle intersection (Moller-Trumbore).
    pub fn intersectTriangle(self: Ray, v0: Vec3, v1: Vec3, v2: Vec3) ?Hit {
        const edge1 = Vec3.sub(v1, v0);
        const edge2 = Vec3.sub(v2, v0);
        const h = Vec3.cross(self.dir, edge2);
        const a = Vec3.dot(edge1, h);

        if (@abs(a) < 1e-8) return null;

        const f = 1.0 / a;
        const s = Vec3.sub(self.origin, v0);
        const u = f * Vec3.dot(s, h);
        if (u < 0 or u > 1) return null;

        const q = Vec3.cross(s, edge1);
        const v = f * Vec3.dot(self.dir, q);
        if (v < 0 or u + v > 1) return null;

        const t = f * Vec3.dot(edge2, q);
        if (t < 0) return null;

        return .{
            .t = t,
            .point = self.at(t),
            .normal = Vec3.cross(edge1, edge2).normalize(),
        };
    }
};

test "ray-sphere intersection" {
    const ray = Ray{ .origin = Vec3.new(0, 0, -5), .dir = Vec3.unit_z };
    const hit = ray.intersectSphere(Vec3.zero, 1.0).?;
    try std.testing.expectApproxEqAbs(@as(f32, 4.0), hit.t, 1e-5);
    try std.testing.expect(hit.normal.approxEql(Vec3.new(0, 0, -1), 1e-5));
}

test "ray-sphere miss" {
    const ray = Ray{ .origin = Vec3.new(0, 5, -5), .dir = Vec3.unit_z };
    try std.testing.expect(ray.intersectSphere(Vec3.zero, 1.0) == null);
}

test "ray-aabb intersection" {
    const ray = Ray{ .origin = Vec3.new(0, 0, -5), .dir = Vec3.unit_z };
    const box = AABB.fromCenterExtents(Vec3.zero, Vec3.one);
    const t = ray.intersectAABB(box).?;
    try std.testing.expectApproxEqAbs(@as(f32, 4.0), t, 1e-5);
    const interval = ray.intersectAABBInterval(box).?;
    try std.testing.expectApproxEqAbs(@as(f32, 4.0), interval.t_min, 1e-5);
    try std.testing.expectApproxEqAbs(@as(f32, 6.0), interval.t_max, 1e-5);
}

test "ray-plane intersection" {
    const ray = Ray{ .origin = Vec3.new(0, 5, 0), .dir = Vec3.new(0, -1, 0) };
    const hit = ray.intersectPlane(Plane.ground).?;
    try std.testing.expectApproxEqAbs(@as(f32, 5.0), hit.t, 1e-5);
}

test "ray-aabb parallel to axis" {
    // Ray fired down +Z, parallel to the X and Y axes. Tests the |dir| ~ 0 slab branch.
    const box = AABB.new(Vec3.new(-1, -1, 0), Vec3.new(1, 1, 2));
    const inside_x = Ray{ .origin = Vec3.new(0.5, 0, -1), .dir = Vec3.unit_z };
    try std.testing.expect(inside_x.intersectAABB(box) != null);

    const outside_x = Ray{ .origin = Vec3.new(5, 0, -1), .dir = Vec3.unit_z };
    try std.testing.expect(outside_x.intersectAABB(box) == null);
}

test "ray-triangle intersection" {
    const ray = Ray{ .origin = Vec3.new(0, 0, -2), .dir = Vec3.unit_z };
    const v0 = Vec3.new(-1, -1, 0);
    const v1 = Vec3.new(1, -1, 0);
    const v2 = Vec3.new(0, 1, 0);
    const hit = ray.intersectTriangle(v0, v1, v2).?;
    try std.testing.expectApproxEqAbs(@as(f32, 2.0), hit.t, 1e-5);
}
