# mathkit

Small 2D/3D math utilities for Zig rendering and game projects.

`mathkit` is intentionally compact: vectors, matrices, quaternions, transforms,
colors, bounds, rays, frustum tests, easing, and deterministic Perlin/fBm noise.
It is developed alongside `droids`, so the API favors direct data types that are
easy to upload to graphics APIs and simple enough to audit.

## Status

Early package. The public API is still allowed to tighten before a `1.0.0`
release. While on `0.x`, treat any minor version bump as potentially breaking
and patch bumps as additive or bug-fix only.

Targets the Zig `0.16` build API.

## Install

Fetch the package and save it to `build.zig.zon`:

```sh
zig fetch --save git+https://github.com/<user>/mathkit
```

Then wire the module in `build.zig`:

```zig
const mathkit_dep = b.dependency("mathkit", .{
    .target = target,
    .optimize = optimize,
});

exe.root_module.addImport("mathkit", mathkit_dep.module("mathkit"));
```

Use it from Zig source:

```zig
const math = @import("mathkit");

const model = math.Mat4.mul(
    math.Mat4.translate(math.Vec3.new(0, 1, 0)),
    math.Mat4.rotateY(math.radians(45)),
);
```

## Conventions

- Floating-point math uses `f32`.
- Matrices are column-major and columns are stored contiguously.
- Vectors are treated as column vectors: `Mat4.mul(a, b)` composes `a * b`.
- Coordinates are right-handed.
- `Vec3.forward` is `-Z`, `Vec3.up` is `+Y`, and `Vec3.right` is `+X`.
- Perspective and orthographic projection map clip-space Z to `[0, 1]`, matching WebGPU and D3D-style depth.
- Quaternions are stored as `(x, y, z, w)`, with `w` as the scalar component.
- `Quat.fromEulerXYZ(x, y, z)` applies X, then Y, then Z rotation and is equivalent to `rotateZ(z) * rotateY(y) * rotateX(x)`. X is pitch, Y is yaw, Z is roll.

## GPU Upload

`Vec2`, `Vec3`, `Vec4`, `Quat`, `Mat3`, `Mat4`, and `Color` are `extern struct`s
with tightly-packed `f32` fields. They can be copied straight into vertex
buffers, uniform buffers, or storage buffers without reshaping.

**Caveat for uniform buffers (std140 / std430):** `Mat3` is 9 × `f32` = 36
bytes. WGSL / GLSL uniform layouts pad `mat3` to 3 × `vec4` = 48 bytes. If you
upload a `Mat3` directly into a uniform slot you will get garbage; either use
`Mat4` for uniforms or expand the columns to `Vec4` before upload.

## Transform Notes

`Transform` stores translation, rotation, and scale separately. It is convenient
for scene nodes, animation channels, and simple hierarchy data.

`Transform.mul(parent, child)` composes back into another TRS value. That cannot
represent shear created by rotated non-uniform scale. For exact composition, use:

```zig
const world = math.Mat4.mul(parent.toMat4(), child.toMat4());
```

For vectors:

- `transformPoint` applies scale, rotation, and translation.
- `transformVector` applies scale and rotation.
- `transformDirection` applies rotation only.

## API Shape

Core types:

- `Vec2`, `Vec3`, `Vec4`
- `Mat3`, `Mat4`
- `Quat`
- `Transform`
- `Color`
- `Rect`, `AABB`
- `Ray`
- `Plane`, `Frustum`

Modules:

- `ease` — standard easing curves (quad/cubic/quart/sine/expo/circ/back/elastic/bounce) plus `smoothstep` and `smootherstep`.
- `noise` — deterministic 1D/2D/3D Perlin noise with a fixed permutation table, and 2D/3D fBm.

Common helpers include vector projection/rejection, distances and squared
distances, ray intersections, AABB/Rect intersection, matrix point/vector
transforms, quaternion slerp/nlerp, color conversion, and scalar
`radians`/`degrees`/`clamp`/`saturate`/`remap`.

## Scope

This package is a pragmatic rendering/game math toolkit, not a full numerical
linear algebra library. It is meant to be boring, predictable, dependency-free,
and easy to keep in sync with graphics code.

`f32` is suitable for rendering and most local-scale game work (GPUs are `f32`
anyway). It is **not** suitable for large-world coordinates (precision degrades
to ~0.06 m at 10⁶ units), long-running physics integration where error
accumulates, or ill-conditioned linear algebra. If you need that, reach for a
different library.

## License

Zlib. See [LICENSE](LICENSE).
