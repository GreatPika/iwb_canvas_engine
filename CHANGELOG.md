## Unreleased

### Performance

- Cache `PathNode` local paths to reduce selection rendering overhead.
- Avoid extra scene traversal when rendering selections.
- Simplify selection halo rendering to avoid expensive path unions/layers.

### Serialization (breaking)

- JSON import/export is now v2-only (`schemaVersion = 2`). v1 scenes are not supported.

### Selection transforms

- Add horizontal flip alongside vertical flip.
- Include flip axis in `ActionCommitted.payload`.

### Stage 1 — Public API split (basic vs advanced)

- Add `basic.dart` entrypoint with a minimal public surface.
- Add `advanced.dart` entrypoint that exports the full API.
- Document public API split and usage in README.

### Stage 2 — SceneController mutations

- Add `SceneController` mutation helpers (`addNode`, `removeNode`, `moveNode`).

### Stage 3 — notifySceneChanged invariants

- Enforce selection cleanup on `notifySceneChanged()` after external mutations.

### Stage 4 — NodeId generation

- Use per-controller NodeId seed; document `nodeIdGenerator`.

### Stage 5 — SceneView without external controller

- Allow `SceneView` without an external controller + `onControllerReady`.

### Stage 6 — Locked/transformable rules

- Define locked/transformable selection rules and document behavior.

### Stage 7 — Public API docs

- Add Dartdoc for `SceneController` public methods and streams.

### Stage 8 — Example app updates

- Update example app to use `basic.dart` and demonstrate JSON export/import.

### Selection rendering

- Draw selection outlines using each node's geometry instead of the combined AABB.
- Render selection as a halo around the node geometry.

### Backlog item delivered

- Add viewport culling in `ScenePainter` to skip offscreen nodes.

## 0.0.3

- Publish web demo (Flutter Web) to GitHub Pages.
- Improve README links for pub.dev.

## 0.0.2

- Declare supported platforms on pub.dev.
- Add documentation link to GitHub Pages.

## 0.0.1

Initial release.

- Scene model (layers, nodes, background, camera)
- Rendering via `ScenePainter` and `SceneView`
- Input handling via `SceneController` (move/draw modes)
- JSON v1 import/export with validation
- Example app and unit tests
