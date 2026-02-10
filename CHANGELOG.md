## Unreleased

## 1.0.0 (2026-02-10)

- Breaking: finalized the v2 public API in `basic.dart`/`advanced.dart` around immutable snapshots, specs, and patch semantics.
- Breaking: removed legacy mutable public surface from package entrypoints.
- Added stable interactive runtime contracts through `SceneController` and `SceneView` aliases over v2 implementations.
- Added strict JSON v2 codec contracts (`schemaVersion = 2`) with canonical validation errors via `SceneJsonFormatException`.
- Hardened scene invariants: unique node ids, single canonical background layer, and explicit constructor/decoder canonicalization.
- Improved input transactional behavior for move/draw/eraser flows, including cancel safety and monotonic event timelines.
- Improved rendering consistency and parity for selection visuals, text line-height semantics, and thin-line snapping behavior.
- Added bounded render caches and spatial-index optimizations for interactive performance.
- Expanded automated validation with parity, regression, invariant coverage, and import-boundary checks.
- Updated package documentation (`README`, `API_GUIDE`, `ARCHITECTURE`) for 1.0 release baseline.
