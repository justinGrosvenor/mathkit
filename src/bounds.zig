const std = @import("std");
const Vec2 = @import("vec2.zig").Vec2;
const Vec3 = @import("vec3.zig").Vec3;
const Mat4 = @import("mat4.zig").Mat4;
const Vec4 = @import("vec4.zig").Vec4;

pub const Rect = struct {
    min: Vec2,
    max: Vec2,

    pub fn new(x: f32, y: f32, w: f32, h: f32) Rect {
        return .{ .min = Vec2.new(x, y), .max = Vec2.new(x + w, y + h) };
    }

    pub fn fromMinMax(min_pt: Vec2, max_pt: Vec2) Rect {
        return .{ .min = min_pt, .max = max_pt };
    }

    pub fn width(self: Rect) f32 {
        return self.max.x - self.min.x;
    }

    pub fn height(self: Rect) f32 {
        return self.max.y - self.min.y;
    }

    pub fn center(self: Rect) Vec2 {
        return Vec2.scale(Vec2.add(self.min, self.max), 0.5);
    }

    pub fn size(self: Rect) Vec2 {
        return Vec2.sub(self.max, self.min);
    }

    pub fn area(self: Rect) f32 {
        const s = self.size();
        return s.x * s.y;
    }

    pub fn contains(self: Rect, p: Vec2) bool {
        return p.x >= self.min.x and p.x <= self.max.x and
            p.y >= self.min.y and p.y <= self.max.y;
    }

    pub fn overlaps(a: Rect, b: Rect) bool {
        return a.min.x <= b.max.x and a.max.x >= b.min.x and
            a.min.y <= b.max.y and a.max.y >= b.min.y;
    }

    pub fn intersection(a: Rect, b: Rect) ?Rect {
        const min_pt = Vec2.max(a.min, b.min);
        const max_pt = Vec2.min(a.max, b.max);
        if (min_pt.x > max_pt.x or min_pt.y > max_pt.y) return null;
        return fromMinMax(min_pt, max_pt);
    }

    pub fn expand(self: Rect, point: Vec2) Rect {
        return .{
            .min = Vec2.min(self.min, point),
            .max = Vec2.max(self.max, point),
        };
    }

    pub fn merge(a: Rect, b: Rect) Rect {
        return .{
            .min = Vec2.min(a.min, b.min),
            .max = Vec2.max(a.max, b.max),
        };
    }

    pub fn pad(self: Rect, amount: f32) Rect {
        const v = Vec2.splat(amount);
        return .{ .min = Vec2.sub(self.min, v), .max = Vec2.add(self.max, v) };
    }

    pub fn eql(a: Rect, b: Rect) bool {
        return a.min.eql(b.min) and a.max.eql(b.max);
    }

    pub fn approxEql(a: Rect, b: Rect, eps: f32) bool {
        return a.min.approxEql(b.min, eps) and a.max.approxEql(b.max, eps);
    }
};

pub const AABB = struct {
    min: Vec3,
    max: Vec3,

    pub fn new(min_pt: Vec3, max_pt: Vec3) AABB {
        return .{ .min = min_pt, .max = max_pt };
    }

    pub fn fromCenterExtents(c: Vec3, half_size: Vec3) AABB {
        return .{ .min = Vec3.sub(c, half_size), .max = Vec3.add(c, half_size) };
    }

    /// Tight AABB enclosing the given points. Returns an empty (min > max) box
    /// when `points` is empty, which never tests as containing anything.
    pub fn fromPoints(points: []const Vec3) AABB {
        if (points.len == 0) {
            return .{
                .min = Vec3.splat(std.math.floatMax(f32)),
                .max = Vec3.splat(-std.math.floatMax(f32)),
            };
        }
        var result = AABB{ .min = points[0], .max = points[0] };
        for (points[1..]) |p| result = result.expand(p);
        return result;
    }

    pub fn center(self: AABB) Vec3 {
        return Vec3.scale(Vec3.add(self.min, self.max), 0.5);
    }

    pub fn extents(self: AABB) Vec3 {
        return Vec3.scale(Vec3.sub(self.max, self.min), 0.5);
    }

    pub fn size(self: AABB) Vec3 {
        return Vec3.sub(self.max, self.min);
    }

    pub fn volume(self: AABB) f32 {
        const s = self.size();
        return s.x * s.y * s.z;
    }

    pub fn contains(self: AABB, p: Vec3) bool {
        return p.x >= self.min.x and p.x <= self.max.x and
            p.y >= self.min.y and p.y <= self.max.y and
            p.z >= self.min.z and p.z <= self.max.z;
    }

    pub fn overlaps(a: AABB, b: AABB) bool {
        return a.min.x <= b.max.x and a.max.x >= b.min.x and
            a.min.y <= b.max.y and a.max.y >= b.min.y and
            a.min.z <= b.max.z and a.max.z >= b.min.z;
    }

    pub fn intersection(a: AABB, b: AABB) ?AABB {
        const min_pt = Vec3.max(a.min, b.min);
        const max_pt = Vec3.min(a.max, b.max);
        if (min_pt.x > max_pt.x or min_pt.y > max_pt.y or min_pt.z > max_pt.z) return null;
        return new(min_pt, max_pt);
    }

    pub fn closestPoint(self: AABB, p: Vec3) Vec3 {
        return Vec3.clamp(p, self.min, self.max);
    }

    pub fn containsAABB(self: AABB, other: AABB) bool {
        return self.contains(other.min) and self.contains(other.max);
    }

    pub fn expand(self: AABB, point: Vec3) AABB {
        return .{
            .min = Vec3.min(self.min, point),
            .max = Vec3.max(self.max, point),
        };
    }

    pub fn merge(a: AABB, b: AABB) AABB {
        return .{
            .min = Vec3.min(a.min, b.min),
            .max = Vec3.max(a.max, b.max),
        };
    }

    pub fn pad(self: AABB, amount: f32) AABB {
        const v = Vec3.splat(amount);
        return .{ .min = Vec3.sub(self.min, v), .max = Vec3.add(self.max, v) };
    }

    /// Transform an AABB by a matrix, producing a new axis-aligned bounding box.
    pub fn transformed(self: AABB, mat: Mat4) AABB {
        const corners = [8]Vec3{
            Vec3.new(self.min.x, self.min.y, self.min.z),
            Vec3.new(self.max.x, self.min.y, self.min.z),
            Vec3.new(self.min.x, self.max.y, self.min.z),
            Vec3.new(self.max.x, self.max.y, self.min.z),
            Vec3.new(self.min.x, self.min.y, self.max.z),
            Vec3.new(self.max.x, self.min.y, self.max.z),
            Vec3.new(self.min.x, self.max.y, self.max.z),
            Vec3.new(self.max.x, self.max.y, self.max.z),
        };

        var transformed_corner = mat.mulVec(Vec4.fromVec3(corners[0], 1.0)).xyz();
        var result = AABB{ .min = transformed_corner, .max = transformed_corner };

        for (corners[1..]) |corner| {
            transformed_corner = mat.mulVec(Vec4.fromVec3(corner, 1.0)).xyz();
            result = result.expand(transformed_corner);
        }

        return result;
    }

    pub fn eql(a: AABB, b: AABB) bool {
        return a.min.eql(b.min) and a.max.eql(b.max);
    }

    pub fn approxEql(a: AABB, b: AABB, eps: f32) bool {
        return a.min.approxEql(b.min, eps) and a.max.approxEql(b.max, eps);
    }
};

test "rect contains" {
    const r = Rect.new(0, 0, 10, 10);
    try std.testing.expect(r.contains(Vec2.new(5, 5)));
    try std.testing.expect(!r.contains(Vec2.new(11, 5)));
}

test "rect overlap" {
    const a = Rect.new(0, 0, 10, 10);
    const b = Rect.new(5, 5, 10, 10);
    const c = Rect.new(20, 20, 5, 5);
    try std.testing.expect(a.overlaps(b));
    try std.testing.expect(!a.overlaps(c));
    try std.testing.expect(a.intersection(b).?.eql(Rect.fromMinMax(Vec2.new(5, 5), Vec2.new(10, 10))));
}

test "aabb contains" {
    const box = AABB.fromCenterExtents(Vec3.zero, Vec3.one);
    try std.testing.expect(box.contains(Vec3.zero));
    try std.testing.expect(!box.contains(Vec3.new(2, 0, 0)));
}

test "aabb merge" {
    const a = AABB.new(Vec3.new(0, 0, 0), Vec3.new(1, 1, 1));
    const b = AABB.new(Vec3.new(2, 2, 2), Vec3.new(3, 3, 3));
    const merged = AABB.merge(a, b);
    try std.testing.expect(merged.min.eql(Vec3.zero));
    try std.testing.expect(merged.max.eql(Vec3.new(3, 3, 3)));
}

test "aabb fromPoints" {
    const pts = [_]Vec3{
        Vec3.new(1, 2, 3),
        Vec3.new(-1, 0, 5),
        Vec3.new(4, -3, 1),
    };
    const box = AABB.fromPoints(&pts);
    try std.testing.expect(box.min.eql(Vec3.new(-1, -3, 1)));
    try std.testing.expect(box.max.eql(Vec3.new(4, 2, 5)));

    const empty = AABB.fromPoints(&[_]Vec3{});
    try std.testing.expect(!empty.contains(Vec3.zero));
}

test "aabb helpers" {
    const a = AABB.new(Vec3.zero, Vec3.new(2, 2, 2));
    const b = AABB.new(Vec3.one, Vec3.new(3, 3, 3));
    const i = a.intersection(b).?;
    try std.testing.expect(i.min.eql(Vec3.one));
    try std.testing.expect(i.max.eql(Vec3.new(2, 2, 2)));
    try std.testing.expect(a.closestPoint(Vec3.new(3, -1, 1)).eql(Vec3.new(2, 0, 1)));
    try std.testing.expectApproxEqAbs(@as(f32, 8), a.volume(), 1e-6);
}
