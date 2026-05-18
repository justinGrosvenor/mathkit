const std = @import("std");
const Vec4 = @import("vec4.zig").Vec4;

/// Linear RGBA color, f32 per channel.
pub const Color = extern struct {
    r: f32 = 0,
    g: f32 = 0,
    b: f32 = 0,
    a: f32 = 1,

    pub const black = Color{};
    pub const white = Color{ .r = 1, .g = 1, .b = 1 };
    pub const red = Color{ .r = 1 };
    pub const green = Color{ .g = 1 };
    pub const blue = Color{ .b = 1 };
    pub const yellow = Color{ .r = 1, .g = 1 };
    pub const cyan = Color{ .g = 1, .b = 1 };
    pub const magenta = Color{ .r = 1, .b = 1 };
    pub const transparent = Color{ .a = 0 };

    pub fn new(r: f32, g: f32, b: f32, a: f32) Color {
        return .{ .r = r, .g = g, .b = b, .a = a };
    }

    pub fn rgb(r: f32, g: f32, b: f32) Color {
        return .{ .r = r, .g = g, .b = b, .a = 1 };
    }

    /// Build from 0xRRGGBB. Alpha defaults to 1.
    pub fn fromHex(hex: u32) Color {
        return .{
            .r = @as(f32, @floatFromInt((hex >> 16) & 0xFF)) / 255.0,
            .g = @as(f32, @floatFromInt((hex >> 8) & 0xFF)) / 255.0,
            .b = @as(f32, @floatFromInt(hex & 0xFF)) / 255.0,
            .a = 1,
        };
    }

    /// Build from 0xRRGGBBAA.
    pub fn fromHexAlpha(hex: u32) Color {
        return .{
            .r = @as(f32, @floatFromInt((hex >> 24) & 0xFF)) / 255.0,
            .g = @as(f32, @floatFromInt((hex >> 16) & 0xFF)) / 255.0,
            .b = @as(f32, @floatFromInt((hex >> 8) & 0xFF)) / 255.0,
            .a = @as(f32, @floatFromInt(hex & 0xFF)) / 255.0,
        };
    }

    /// Pack into a u32 as 0xRRGGBBAA (R in the high byte).
    /// On a little-endian machine the in-memory byte order is A, B, G, R.
    /// For an in-memory RGBA byte layout (matching WebGPU rgba8unorm), use `toBytes`.
    pub fn toRgba8(self: Color) u32 {
        const c = self.saturate();
        const r: u32 = @intFromFloat(c.r * 255.0 + 0.5);
        const g: u32 = @intFromFloat(c.g * 255.0 + 0.5);
        const b: u32 = @intFromFloat(c.b * 255.0 + 0.5);
        const a: u32 = @intFromFloat(c.a * 255.0 + 0.5);
        return (r << 24) | (g << 16) | (b << 8) | a;
    }

    /// Pack into a u32 as 0x00RRGGBB.
    pub fn toRgb8(self: Color) u32 {
        const c = self.saturate();
        const r: u32 = @intFromFloat(c.r * 255.0 + 0.5);
        const g: u32 = @intFromFloat(c.g * 255.0 + 0.5);
        const b: u32 = @intFromFloat(c.b * 255.0 + 0.5);
        return (r << 16) | (g << 8) | b;
    }

    /// Pack into a [4]u8 in R, G, B, A memory order. Matches WebGPU rgba8unorm.
    pub fn toBytes(self: Color) [4]u8 {
        const c = self.saturate();
        return .{
            @intFromFloat(c.r * 255.0 + 0.5),
            @intFromFloat(c.g * 255.0 + 0.5),
            @intFromFloat(c.b * 255.0 + 0.5),
            @intFromFloat(c.a * 255.0 + 0.5),
        };
    }

    pub fn toVec4(self: Color) Vec4 {
        return .{ .x = self.r, .y = self.g, .z = self.b, .w = self.a };
    }

    pub fn fromVec4(v: Vec4) Color {
        return .{ .r = v.x, .g = v.y, .b = v.z, .a = v.w };
    }

    pub fn lerp(a: Color, b: Color, t: f32) Color {
        return .{
            .r = a.r + (b.r - a.r) * t,
            .g = a.g + (b.g - a.g) * t,
            .b = a.b + (b.b - a.b) * t,
            .a = a.a + (b.a - a.a) * t,
        };
    }

    pub fn withAlpha(self: Color, a: f32) Color {
        return .{ .r = self.r, .g = self.g, .b = self.b, .a = a };
    }

    pub fn clamp(self: Color, lo: Color, hi: Color) Color {
        return .{
            .r = @max(lo.r, @min(hi.r, self.r)),
            .g = @max(lo.g, @min(hi.g, self.g)),
            .b = @max(lo.b, @min(hi.b, self.b)),
            .a = @max(lo.a, @min(hi.a, self.a)),
        };
    }

    pub fn saturate(self: Color) Color {
        return self.clamp(Color.transparent, Color.white);
    }

    /// Convert sRGB to linear. Apply to colors loaded from image files.
    pub fn srgbToLinear(self: Color) Color {
        return .{
            .r = srgbComponentToLinear(self.r),
            .g = srgbComponentToLinear(self.g),
            .b = srgbComponentToLinear(self.b),
            .a = self.a,
        };
    }

    /// Convert linear to sRGB. Apply before displaying.
    pub fn linearToSrgb(self: Color) Color {
        return .{
            .r = linearComponentToSrgb(self.r),
            .g = linearComponentToSrgb(self.g),
            .b = linearComponentToSrgb(self.b),
            .a = self.a,
        };
    }

    /// HSV to linear RGB. h: [0,360), s: [0,1], v: [0,1].
    pub fn fromHsv(h: f32, s: f32, v: f32) Color {
        const c = v * s;
        const hp = h / 60.0;
        const x = c * (1.0 - @abs(@mod(hp, 2.0) - 1.0));
        const m = v - c;

        var r: f32 = 0;
        var g: f32 = 0;
        var b: f32 = 0;

        if (hp < 1) {
            r = c;
            g = x;
        } else if (hp < 2) {
            r = x;
            g = c;
        } else if (hp < 3) {
            g = c;
            b = x;
        } else if (hp < 4) {
            g = x;
            b = c;
        } else if (hp < 5) {
            r = x;
            b = c;
        } else {
            r = c;
            b = x;
        }

        return .{ .r = r + m, .g = g + m, .b = b + m, .a = 1 };
    }

    pub fn mul(a: Color, b: Color) Color {
        return .{ .r = a.r * b.r, .g = a.g * b.g, .b = a.b * b.b, .a = a.a * b.a };
    }

    /// Multiply RGB channels by `s`, leaving alpha unchanged. Use for tinting.
    pub fn scale(self: Color, s: f32) Color {
        return .{ .r = self.r * s, .g = self.g * s, .b = self.b * s, .a = self.a };
    }

    /// Multiply all four channels by `s`, including alpha.
    pub fn scaleAll(self: Color, s: f32) Color {
        return .{ .r = self.r * s, .g = self.g * s, .b = self.b * s, .a = self.a * s };
    }

    pub fn add(a: Color, b: Color) Color {
        return .{ .r = a.r + b.r, .g = a.g + b.g, .b = a.b + b.b, .a = a.a + b.a };
    }

    pub fn eql(a: Color, b: Color) bool {
        return a.r == b.r and a.g == b.g and a.b == b.b and a.a == b.a;
    }

    pub fn approxEql(a: Color, b: Color, eps: f32) bool {
        return @abs(a.r - b.r) <= eps and @abs(a.g - b.g) <= eps and
            @abs(a.b - b.b) <= eps and @abs(a.a - b.a) <= eps;
    }
};

fn srgbComponentToLinear(c: f32) f32 {
    if (c <= 0.04045) return c / 12.92;
    return std.math.pow(f32, (c + 0.055) / 1.055, 2.4);
}

fn linearComponentToSrgb(c: f32) f32 {
    if (c <= 0.0031308) return c * 12.92;
    return 1.055 * std.math.pow(f32, c, 1.0 / 2.4) - 0.055;
}

test "color from hex" {
    const c = Color.fromHex(0xFF8000);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), c.r, 1e-2);
    try std.testing.expectApproxEqAbs(@as(f32, 0.502), c.g, 1e-2);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), c.b, 1e-2);
}

test "color pack rgba8" {
    const c = Color.fromHexAlpha(0xFF800040);
    try std.testing.expectEqual(@as(u32, 0xFF800040), c.toRgba8());
    try std.testing.expectEqual(@as(u32, 0xFF8000), c.toRgb8());
    try std.testing.expectEqualSlices(u8, &.{ 0xFF, 0x80, 0x00, 0x40 }, &c.toBytes());
}

test "color srgb roundtrip" {
    const original = Color.rgb(0.5, 0.3, 0.8);
    const linear = original.srgbToLinear();
    const back = linear.linearToSrgb();
    try std.testing.expectApproxEqAbs(original.r, back.r, 1e-5);
    try std.testing.expectApproxEqAbs(original.g, back.g, 1e-5);
    try std.testing.expectApproxEqAbs(original.b, back.b, 1e-5);
}

test "color srgb small-value linear segment" {
    // Below the 0.04045 threshold, sRGB->linear is just division by 12.92.
    const dark = Color.rgb(0.02, 0.04, 0.001);
    const linear = dark.srgbToLinear();
    try std.testing.expectApproxEqAbs(dark.r / 12.92, linear.r, 1e-7);
    try std.testing.expectApproxEqAbs(dark.g / 12.92, linear.g, 1e-7);
    try std.testing.expectApproxEqAbs(dark.b / 12.92, linear.b, 1e-7);
}

test "color hsv red" {
    const c = Color.fromHsv(0, 1, 1);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), c.r, 1e-5);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), c.g, 1e-5);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), c.b, 1e-5);
}

test "color lerp" {
    const mid = Color.lerp(Color.black, Color.white, 0.5);
    try std.testing.expectApproxEqAbs(@as(f32, 0.5), mid.r, 1e-5);
    try std.testing.expectApproxEqAbs(@as(f32, 0.5), mid.g, 1e-5);
    try std.testing.expectApproxEqAbs(@as(f32, 0.5), mid.b, 1e-5);
}

test "color scale vs scaleAll" {
    const c = Color.new(0.4, 0.4, 0.4, 0.8);
    const s = c.scale(0.5);
    try std.testing.expectApproxEqAbs(@as(f32, 0.2), s.r, 1e-6);
    try std.testing.expectApproxEqAbs(@as(f32, 0.8), s.a, 1e-6);
    const sa = c.scaleAll(0.5);
    try std.testing.expectApproxEqAbs(@as(f32, 0.2), sa.r, 1e-6);
    try std.testing.expectApproxEqAbs(@as(f32, 0.4), sa.a, 1e-6);
}

test "color hsv green blue and gray" {
    try std.testing.expect(Color.fromHsv(120, 1, 1).approxEql(Color.green, 1e-5));
    try std.testing.expect(Color.fromHsv(240, 1, 1).approxEql(Color.blue, 1e-5));
    try std.testing.expect(Color.fromHsv(0, 0, 0.5).approxEql(Color.new(0.5, 0.5, 0.5, 1), 1e-5));
}

test "color vec4 roundtrip and withAlpha" {
    const c = Color.new(0.1, 0.2, 0.3, 0.4);
    try std.testing.expect(Color.fromVec4(c.toVec4()).eql(c));
    try std.testing.expect(c.withAlpha(1).eql(Color.new(0.1, 0.2, 0.3, 1)));
}
