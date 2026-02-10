## 1.0.0 (2026-02-10)

### Breaking

- Finalized the v2 public API in `basic.dart`/`advanced.dart` around immutable snapshots, specs, and patch semantics.
- Removed the legacy mutable public surface from package entrypoints.

### Added

- Stable interactive runtime aliases: `SceneController` and `SceneView` over v2 implementations.
- Strict JSON v2 codec contracts (`schemaVersion = 2`) with canonical validation errors via `SceneJsonFormatException`.
- Bounded render caches and spatial-index optimizations for interactive performance.
- Expanded automated validation with parity, regression, invariant coverage, and import-boundary checks.

### Changed

- Hardened scene invariants: unique node ids, single canonical background layer, explicit constructor/decoder canonicalization.
- Improved input transactional behavior for move/draw/eraser flows, including cancel safety and monotonic event timelines.
- Improved rendering consistency and parity for selection visuals, text line-height semantics, and thin-line snapping behavior.
- Refreshed package documentation (`README`, `API_GUIDE`, `ARCHITECTURE`) for the `1.0.0` release baseline.
