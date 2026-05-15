//! Small 2D/3D math utilities for rendering and game projects.
//!
//! Conventions:
//! - f32 scalar math
//! - column-major matrices with column vectors
//! - right-handed coordinates
//! - +X right, +Y up, -Z forward
//! - projection depth maps to [0, 1]
//! - quaternions are stored as x, y, z, w

pub const Vec2 = @import("vec2.zig").Vec2;
pub const Vec3 = @import("vec3.zig").Vec3;
pub const Vec4 = @import("vec4.zig").Vec4;
pub const Mat3 = @import("mat3.zig").Mat3;
pub const Mat4 = @import("mat4.zig").Mat4;
pub const Quat = @import("quat.zig").Quat;
pub const Transform = @import("transform.zig").Transform;
pub const Color = @import("color.zig").Color;
pub const Rect = @import("bounds.zig").Rect;
pub const AABB = @import("bounds.zig").AABB;
pub const Ray = @import("ray.zig").Ray;
pub const Frustum = @import("frustum.zig").Frustum;
pub const Plane = @import("frustum.zig").Plane;
pub const ease = @import("ease.zig");
pub const noise = @import("noise.zig");

pub const pi = @import("std").math.pi;
pub const tau = 2 * pi;

pub fn radians(deg: f32) f32 {
    return deg * (pi / 180.0);
}

pub fn degrees(rad: f32) f32 {
    return rad * (180.0 / pi);
}

pub fn clamp(val: f32, lo: f32, hi: f32) f32 {
    return @max(lo, @min(hi, val));
}

pub fn saturate(val: f32) f32 {
    return clamp(val, 0, 1);
}

pub fn remap(val: f32, in_lo: f32, in_hi: f32, out_lo: f32, out_hi: f32) f32 {
    const t = (val - in_lo) / (in_hi - in_lo);
    return out_lo + t * (out_hi - out_lo);
}

pub fn lerpf(a: f32, b: f32, t: f32) f32 {
    return a + (b - a) * t;
}

pub fn inverseLerp(a: f32, b: f32, v: f32) f32 {
    return (v - a) / (b - a);
}

pub fn step(edge: f32, x: f32) f32 {
    return if (x < edge) 0 else 1;
}

test {
    _ = @import("vec2.zig");
    _ = @import("vec3.zig");
    _ = @import("vec4.zig");
    _ = @import("mat3.zig");
    _ = @import("mat4.zig");
    _ = @import("quat.zig");
    _ = @import("transform.zig");
    _ = @import("color.zig");
    _ = @import("bounds.zig");
    _ = @import("ray.zig");
    _ = @import("frustum.zig");
    _ = @import("ease.zig");
    _ = @import("noise.zig");
}
