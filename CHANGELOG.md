# Changelog

All notable changes to `math3d` are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/), and versions follow semver
with the relaxed pre-1.0 rule: minor bumps may be breaking.

## [Unreleased]

## [0.1.0] - 2026-05-14

Initial release.

### Types

- `Vec2`, `Vec3`, `Vec4`, `Quat`, `Mat3`, `Mat4`, `Color` as `extern struct`s
  suitable for GPU upload.
- `Transform` (TRS), `Rect`, `AABB`, `Ray`, `Plane`, `Frustum`.

### Modules

- `ease` — easing curves plus `smoothstep` / `smootherstep`.
- `noise` — deterministic 1D/2D/3D Perlin and 2D/3D fBm.

### Conventions

- Right-handed, column-major matrices with column-vector composition.
- `+X` right, `+Y` up, `-Z` forward.
- Projection clip-space depth is `[0, 1]` (WebGPU / D3D-style).
- Quaternions are `(x, y, z, w)` with `w` scalar.
- All floating-point math is `f32`.
