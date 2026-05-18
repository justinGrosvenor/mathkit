# Changelog

All notable changes to `mathkit` are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/), and versions follow semver
with the relaxed pre-1.0 rule: minor bumps may be breaking.

## [Unreleased]

### Added

- Left-handed coordinate variants for engine interop (Mach, Unreal, D3D world conventions):
  `Vec3.forward_lh`, `Mat4.lookAtLH`, `Mat4.perspectiveLH`, `Mat4.orthoLH`, and
  `Transform.forwardLH`. The default API remains right-handed.
- `Quat.fromMat3(m)` / `Quat.fromMat4(m)` — Shoemake trace-based decomposition.
- `Quat.fromTo(from, to)` — shortest-arc rotation, with stable antiparallel handling.
- `Transform.fromMat4(m)` — TRS decomposition with reflection-safe sign assignment to X scale.
- `Mat4.transformNormal(n)` — correct normal transform via the normal matrix (returns null if singular).
- `Mat4.fromColumns(c0, c1, c2, c3)` and `AABB.fromPoints(slice)`.
- `Vec2.project`, `Vec2.reject`, `Vec2.reflect`, `Vec2.angleBetween` — parity with Vec3.
- `Color.scaleAll(s)` — like `Color.scale` but includes alpha.
- `Color.toBytes() [4]u8` — WebGPU `rgba8unorm` memory order.
- `Plane.ground` — XZ plane at y=0 (convenience for picking).

### Changed

- `Mat4.transformDirection` renamed to `Mat4.transformDirectionFast`; the new
  `Mat4.transformNormal` should be preferred whenever the matrix has
  non-uniform scale.
- `Mat4.lookAt` returns `?Mat4`; previously silently returned identity on
  degenerate input.
- `Mat4.scaling` renamed to `Mat4.scale`.
- `Ray.intersectPlane` now takes a `Plane` instead of separate `(normal, d)` args.
- `Ray.new` removed in favor of struct-literal construction. Callers normalize `dir` explicitly.
- `Quat.fromEuler` and `Quat.fromYawPitchRoll` removed; use `Quat.fromEulerXYZ`.
- `Transform.transformDir` alias removed.
- `Mat3/Mat4.inverse` epsilon threshold raised from `1e-12` to `1e-6` (correct for f32).
- `Color.scale` is now documented as RGB-only (alpha unchanged); use `scaleAll` for all four channels.

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
