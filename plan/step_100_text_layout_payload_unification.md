language: russian

# Шаг 100. Ввести canonical text-layout payload для geometry и paint

## 1. Change Mandate

Этот шаг вводит один canonical resolved text-layout payload на render read-side,
чтобы text geometry sizing и text paint использовали один и тот же
кешируемый результат layout вместо двух независимых `TextPainter.layout()`
путей.

## 2. Change Boundary

### Included in the Change

- Canonical text-layout payload owner in the shared text-layout support path.
- Render-local text-layout cache migration from cached `TextPainter` instances
  to cached resolved text-layout payloads.
- `ScenePainter` frame-resolution migration so text geometry and text paint
  consume the same resolved payload per paint candidate.
- Render/view/contract/invariant/documentation surfaces required to prove and
  publish the shared text-layout payload contract.

### Not Included in the Change

- Viewport candidate enumeration ownership, spatial query policy, or
  candidate-first frame selection semantics.
- Main-painter/overlay repaint-topology changes or marquee migration into the
  overlay path.
- Dynamic selection-halo cull-budget computation.
- Runtime `TextNodeLayoutState` owner changes outside the render read-side
  integration required by this step.
- Public model, snapshot, JSON, or write-side text contracts.

## 3. File Map and Analysis Areas

### Implementation Files

- `lib/src/core/text_layout.dart`
- `lib/src/render/cache/scene_text_layout_cache.dart`
- `lib/src/render/render_geometry_builder.dart`
- `lib/src/render/render_geometry_cache.dart`
- `lib/src/render/scene_painter.dart`
- `lib/src/render/scene_painter_contract.dart`
- `lib/src/render/scene_painter_frame.dart`
- `lib/src/render/scene_painter_node_renderer.dart`

### Test Files

- `test/render/scene_text_layout_cache_test.dart`
- `test/render/render_geometry_cache_test.dart`
- `test/render/scene_painter_bounds_contract_test.dart`
- `test/render/scene_painter_frame_contract_test.dart`
- `test/render/scene_painter_test.dart`
- `test/view/scene_view_test.dart`

### Fixture and Supporting Data Files

- `tool/invariant_registry.dart`
- `README.md`
- `API_GUIDE.md`
- `ARCHITECTURE.md`
- `CHANGELOG.md`
- `PLAN.md`
- `plan/step_100_text_layout_payload_unification.md`

### Analysis Area

- `lib/src/core/text_layout.dart`
- `lib/src/render/**`
- `test/render/**`
- `test/view/scene_view_test.dart`
- `tool/invariant_registry.dart`
- `README.md`
- `API_GUIDE.md`
- `ARCHITECTURE.md`
- `CHANGELOG.md`

### Outside the Change Boundary

- Any files outside the listed zones.
- An exception is allowed only for a targeted change without which a specific
  slice and its verification cannot be closed.

### File Change Rule

- Every modified implementation file must either introduce the canonical
  resolved text-layout payload, migrate one render owner to consume it, or
  remove the superseded duplicate text-layout path.
- Every modified test file must pin one closed seam of this step:
  canonical payload ownership,
  geometry reuse of resolved text size,
  frame-local handoff into text paint,
  or the absence of renderer-side text-layout cache re-entry.
- Every modified supporting or documentation file must publish or enforce the
  exact shared text-layout payload contract closed by this step.
- Every newly proposed file or directory name must comply with the global
  `AGENTS.md` section `### File naming`.
- Untied changes are considered out of scope for the change.

## 4. Locked Decisions

1. This step changes only text-layout payload ownership on the render
   read-side. It must not absorb viewport candidate enumeration changes,
   overlay repaint-topology changes, marquee ownership migration, or
   selection-halo cull-budget changes.
2. The canonical shared unit for render-side text layout is one resolved
   payload named `ResolvedTextLayout` that contains the laid-out `TextPainter`
   and the measured text size derived from that same layout.
3. `core/text_layout.dart` remains the shared owner for text-layout derivation;
   this step extends that owner instead of introducing a second text-layout
   payload owner under `render/`.
4. `SceneTextLayoutCache` remains the only render-local text-layout cache
   owner; this step must evolve it to cache the canonical resolved payload
   instead of creating a parallel cache or hidden builder path.
5. `ScenePainterResolvedNodePaintData` remains the handoff contract from frame
   resolution to painter-local consumers; text paint must consume the resolved
   layout payload from that handoff instead of re-entering cache/build code
   inside the node renderer.
6. `RenderGeometryCache` remains the geometry cache owner for text nodes; this
   step must let it build text geometry from a provided resolved layout payload
   instead of bypassing the geometry cache for text.

## 5. Result Requirements

1. The production tree has one canonical resolved text-layout payload type that
   owns both the laid-out `TextPainter` and the measured size for a text node's
   layout inputs.
2. `SceneTextLayoutCache` returns that canonical resolved payload and no longer
   exposes cached `TextPainter`-only results as the render-side layout owner.
3. Text geometry resolution and text painting for a frame candidate consume the
   same resolved text-layout payload instance instead of triggering two
   independent text-layout computations.
4. `ScenePainterNodeRenderer` no longer calls
   `SceneTextLayoutCache.getOrBuild(...)` or `buildSceneTextPainter(...)` in
   the text paint path.
5. The invariant registry, proof surface, and release-ready docs describe the
   shared text-layout payload contract and do not describe parallel geometry and
   paint text-layout owners.

## 6. Implementation Specification

### 6.1 Analysis Scope

- `lib/src/core/text_layout.dart` currently owns `TextLayoutRequest`,
  `buildTextStyle()`, and `measure()`, but it has no canonical resolved
  layout-payload type.
- `lib/src/core/text_node_layout_state.dart` currently uses
  `TextLayoutRequest.measure()` for runtime-local derived size caching and is
  outside this step's semantic change boundary.
- `lib/src/render/cache/scene_text_layout_cache.dart` currently caches
  render-ready `TextPainter` objects and exposes `buildSceneTextPainter(...)`
  as a second builder path.
- `lib/src/render/render_geometry_builder.dart` currently calls
  `_textLayoutRequest(node).measure()` for text geometry bounds.
- `lib/src/render/render_geometry_cache.dart` currently builds text geometry
  without any way to consume a pre-resolved text layout payload.
- `lib/src/render/scene_painter_frame.dart` currently resolves only preview
  delta plus geometry per candidate.
- `lib/src/render/scene_painter_contract.dart` currently has no text-layout
  field on `ScenePainterResolvedNodePaintData`.
- `lib/src/render/scene_painter_node_renderer.dart` currently builds or loads a
  `TextPainter` during `drawTextNode(...)` instead of consuming frame-resolved
  text layout data.

### 6.2 Target Verification Units

- `dart format --output=none --set-exit-if-changed lib test example/lib example/test tool`
- `flutter analyze`
- `(cd example && flutter analyze lib test)`
- `dcm analyze .`
- `dcm calculate-metrics lib/src/core lib/src/render --report-all`
- `dart run tool/check_tool_test_trigger_surface.dart`
- `dart run tool/check_import_boundaries.dart`
- `dart run tool/check_public_api_surface.dart`
- `dart run tool/check_guardrails.dart`
- `dart run tool/check_invariant_coverage.dart`
- MCP test runner shard preset: `core`
- MCP test runner shard preset: `model_contract`
- MCP test runner shard preset: `controller_internal`
- MCP test runner shard preset: `controller`
- MCP test runner shard preset: `render_view`
- MCP test runner shard preset: `interactive`
- MCP test runner shard preset: `example`
- `flutter test --coverage --no-pub --exclude-tags=tool`
- `dart run tool/check_coverage.dart`
- `dart run tool/run_tool_tests.dart`

### 6.3 Protected States, Data, or Structures

- Existing text sizing semantics derived from text layout inputs and explicit
  `textDirection`.
- Existing render-cache lifecycle ownership and epoch invalidation semantics.
- Existing runtime `TextNodeLayoutState` ownership and its current derived-size
  semantics.
- Existing candidate-first `ScenePainter` frame path; this step must not reopen
  all-node scans or candidate ownership changes.
- Existing public `SceneViewRenderSurface` and `ScenePainter` cache-injection
  surface shape.
- Existing path, stroke, image, line, and rect render geometry behavior.

### 6.4 Allowed Semantic Change Zones

- Shared derivation of a canonical resolved text-layout payload from validated
  text layout inputs.
- Render-local text-layout cache return type and builder path.
- Geometry-cache consumption of a provided text-layout payload for text nodes.
- Frame-local handoff of resolved text layout from candidate resolution to text
  paint.
- Invariant and documentation wording for the shared text-layout payload
  contract.

### 6.7 Requirements for Resolution of Links and Structural Analysis

- `lib/src/core/text_layout.dart` must introduce one concrete resolved
  text-layout payload type named `ResolvedTextLayout`. It must expose:
  `TextPainter textPainter`,
  `Size measuredSize`,
  and one canonical construction path from `TextLayoutRequest`.
- The shared owner in `core/text_layout.dart` must provide one canonical
  resolution entrypoint that lays out the `TextPainter` once and derives
  `measuredSize` from that same instance.
- Render-owned code in this step must stop depending on
  `TextLayoutRequest.measure()`.
  `TextLayoutRequest.measure()` itself is not the migration target of this step
  and must not require `TextNodeLayoutState` ownership or semantics changes to
  close the render-side contract.
- `SceneTextLayoutCache.getOrBuild(...)` must return `ResolvedTextLayout`.
  The cache key must stay scoped to text layout plus paint-affecting semantics
  already used by the current render path, and the cache must not keep a second
  uncached `TextPainter` builder entrypoint in parallel.
- `RenderGeometryCache.get(...)` must accept a named
  `ResolvedTextLayout? resolvedTextLayout` input.
  For non-text nodes this input must stay `null` and unused.
  For `TextNodeSnapshot` this input is mandatory; passing `null` is a contract
  error and must not reopen an internal fallback layout path.
- `buildRenderGeometryEntry(...)` must accept the resolved text-layout payload
  needed for text nodes and must derive text local bounds from
  `resolvedTextLayout.measuredSize` instead of calling `_measureTextNodeSnapshot`
  or any equivalent second layout function.
- `ScenePainterFrameOwner` must become the only render-read-side point that
  resolves the canonical text-layout payload for a text candidate. It must use
  the injected `SceneTextLayoutCache` when available and the canonical
  uncached resolver in `core/text_layout.dart` otherwise.
- `ScenePainterResolvedNodePaintData` must carry the optional
  `ResolvedTextLayout? textLayout` field. It must be non-null for
  `TextNodeSnapshot` and `null` for every non-text node subtype.
- `SceneRichNodeRenderer.drawTextNode(...)` must accept the resolved text-layout
  payload from `ScenePainterResolvedNodePaintData` and must not read
  `SceneTextLayoutCache`, call `buildSceneTextPainter(...)`, or allocate a new
  `TextPainter` in the renderer path.
- `ScenePainterNodeRenderer` must stop owning `SceneTextLayoutCache`; cache
  ownership must move to `ScenePainterFrameOwner` so text layout is resolved
  before geometry and paint consume frame data.

### 6.8 Prohibited

- Leaving two independent text-layout compute paths alive for geometry sizing
  and text paint after the step is complete.
- Making `RenderGeometryCache` reach into `SceneTextLayoutCache` internally or
  introducing hidden cache chaining between the two owners.
- Bypassing `ScenePainterResolvedNodePaintData` and reintroducing text-layout
  cache access directly inside painter-local renderers.
- Keeping `buildSceneTextPainter(...)` or any equivalent uncached text-layout
  helper as a parallel render-side entrypoint after the canonical payload owner
  exists.
- Changing viewport candidate enumeration, repaint topology, marquee ownership,
  or selection cull padding in this step.
- Widening public model, snapshot, JSON, or write-side text surfaces.

## 7. Execution Rules

1. One slice closes one new verifiable change contract.
2. Every slice must have its own verification.
3. A slice is considered closed only in the change where its verification
   exists and its run is green.
4. Preparatory changes alone do not count as a closed slice.
5. The next slice is forbidden until the previous slice is closed.
6. If a slice closes a failure scenario, diagnostic output confirming the
   trigger point must be attached.
7. If a slice changes an analysis rule, negative and positive scenarios must be
   covered where applicable to the subject of the change.
8. Scope expansion is forbidden until the mandatory slices are closed.
9. The plan must be detailed enough that the implementing agent has no material
   branch in how to execute a slice.
10. Every newly proposed file or directory name must comply with the global
    `AGENTS.md` section `### File naming` before the slice is considered valid.
11. If a slice depends on an unconfirmed architectural decision, planning must
    stop and that decision must be explicitly confirmed by the user before the
    slice can be written or expanded.

## 8. Vertical Slices

### Slice 1. [x] Canonical resolved text-layout payload owner exists

#### Slice Contract

`core/text_layout.dart` and `SceneTextLayoutCache` expose one canonical
`ResolvedTextLayout` payload for render-side text layout, and the old
`TextPainter`-only render cache surface is gone.

#### Change

- Add `ResolvedTextLayout` to `lib/src/core/text_layout.dart` and move the
  canonical text-layout resolution flow there so one resolution call builds the
  laid-out `TextPainter` and captures `measuredSize`.
- Replace `TextLayoutRequest.measure()` usage in render-owned code with the new
  canonical resolution flow.
- Migrate `SceneTextLayoutCache` to cache and return `ResolvedTextLayout` while
  preserving the current key semantics, LRU behavior, and debug counters.
- Remove `buildSceneTextPainter(...)` after the canonical uncached resolution
  path exists in `core/text_layout.dart`.

#### Verification

- `dart run tool/check_import_boundaries.dart`
- MCP test runner shard preset: `core`
- MCP test runner shard preset: `render_view`

#### Positive Scenarios

- Repeated `SceneTextLayoutCache.getOrBuild(...)` calls for the same text inputs
  return the same `ResolvedTextLayout` instance and keep current hit/build
  semantics.
- The canonical uncached text-layout path returns a `ResolvedTextLayout` whose
  `measuredSize` matches the dimensions of its `textPainter`.

#### Negative Scenarios

- No render-owned source file may keep a `TextPainter`-only layout builder
  entrypoint in parallel with `ResolvedTextLayout`.
- `SceneTextLayoutCache` must not regress to value-key omissions for
  `textDirection`, `maxWidth`, `lineHeight`, color, or opacity.

#### Closure Evidence

- Green run of the listed verifications.
- `test/render/scene_text_layout_cache_test.dart` proves cache reuse and key
  behavior for `ResolvedTextLayout`.
- Source-level assertions prove the superseded `buildSceneTextPainter(...)`
  render path is removed.

### Slice 2. [x] Text geometry consumes provided resolved layout payload

#### Slice Contract

`RenderGeometryCache` and `render_geometry_builder.dart` use a provided
`ResolvedTextLayout` to build text geometry bounds, so text geometry no longer
triggers its own independent layout computation.

#### Change

- Extend `RenderGeometryCache.get(...)` and `buildRenderGeometryEntry(...)`
  with the exact `ResolvedTextLayout? resolvedTextLayout` input.
  This input stays `null` for non-text nodes and is mandatory for
  `TextNodeSnapshot`; a text-node call with `null` must fail fast instead of
  reopening a fallback layout path.
- Make `_textEntry(...)` derive bounds from `resolvedTextLayout.measuredSize`
  and remove `_measureTextNodeSnapshot(...)` plus the render-owned
  `TextLayoutRequest.measure()` path.
- Keep non-text geometry behavior and existing geometry-cache invalidation
  semantics unchanged.

#### Verification

- `dcm calculate-metrics lib/src/core lib/src/render --report-all`
- MCP test runner shard preset: `render_view`

#### Positive Scenarios

- A text geometry cache miss with a provided `ResolvedTextLayout` produces the
  same local/world bounds as the previous render contract.
- Non-text nodes keep their existing geometry build and cache behavior.

#### Negative Scenarios

- `render_geometry_builder.dart` must not call `TextLayoutRequest.measure()`,
  `_measureTextNodeSnapshot(...)`, or any second text-layout helper after this
  slice.
- `RenderGeometryCache.get(...)` must reject `TextNodeSnapshot` calls that omit
  `resolvedTextLayout`.
- `RenderGeometryCache` must not create or own its own `SceneTextLayoutCache`.

#### Closure Evidence

- Green run of the listed verifications.
- Structural tests prove text geometry derives bounds from the provided
  `ResolvedTextLayout` instead of a second layout path.
- Runtime cache tests show non-text geometry cache semantics remain unchanged.

### Slice 3. [x] Frame resolution hands one text layout payload to geometry and paint

#### Slice Contract

`ScenePainterFrameOwner` resolves text layout once per text paint candidate and
hands that same `ResolvedTextLayout` instance to both geometry resolution and
text paint through `ScenePainterResolvedNodePaintData`.

#### Change

- Move `SceneTextLayoutCache` ownership from `ScenePainterNodeRenderer` to
  `ScenePainterFrameOwner` through `ScenePainter` construction wiring while
  keeping the external cache-injection surface unchanged.
- Extend `ScenePainterResolvedNodePaintData` with the optional text-layout
  field and populate it only for `TextNodeSnapshot`.
- Update `ScenePainterNodeRenderer` and `SceneRichNodeRenderer.drawTextNode(...)`
  to consume the resolved text-layout payload from frame data and remove any
  direct text cache access from the renderer path.
- Update proof tests so one cold paint on a text node demonstrates one
  text-layout build path feeding both geometry and paint.

#### Verification

- `dart run tool/check_public_api_surface.dart`
- MCP test runner shard preset: `render_view`

#### Positive Scenarios

- A cold paint of a visible text node resolves one `ResolvedTextLayout`,
  geometry uses its `measuredSize`, and paint uses its `textPainter`.
- Repainting the same text node with an injected `SceneTextLayoutCache`
  reuses the cached `ResolvedTextLayout` instead of relaying out text in the
  renderer.

#### Negative Scenarios

- `ScenePainterNodeRenderer` must not call
  `SceneTextLayoutCache.getOrBuild(...)`, `buildSceneTextPainter(...)`, or
  allocate a new `TextPainter`.
- `ScenePainterFrameOwner` must not skip geometry cache usage for text nodes.

#### Closure Evidence

- Green run of the listed verifications.
- Frame/painter contract tests prove the same resolved text-layout payload is
  handed to geometry and paint.
- Integration paint tests prove the renderer path no longer re-enters text
  layout ownership.

### Slice 4. [x] Invariant and docs publish shared text-layout payload ownership

#### Slice Contract

The invariant registry, proof surface, and release-ready docs describe one
shared resolved text-layout payload for geometry and text paint on the render
read-side.

#### Change

- Add or update the render invariant in `tool/invariant_registry.dart` so it
  states that text geometry sizing and text paint consume one canonical
  `ResolvedTextLayout` payload on the render read-side.
- Update the proof wording in
  `test/render/scene_text_layout_cache_test.dart`,
  `test/render/scene_painter_bounds_contract_test.dart`, and
  `test/render/scene_painter_frame_contract_test.dart` so the proof surface
  matches the new invariant exactly.
- Update `README.md`, `API_GUIDE.md`, `ARCHITECTURE.md`, `CHANGELOG.md`,
  `PLAN.md`, and this step document so they publish the same internal
  architecture:
  one canonical resolved text-layout payload,
  `SceneTextLayoutCache` as its render-local cache owner,
  `ScenePainterFrameOwner` as the frame-local resolver,
  and no renderer-side text-layout cache re-entry.

#### Verification

- `dart run tool/check_guardrails.dart`
- `dart run tool/check_invariant_coverage.dart`
- `dart run tool/run_tool_tests.dart`
- MCP test runner shard preset: `render_view`

#### Positive Scenarios

- The invariant text and proof files describe the same shared payload contract.
- The release-ready docs describe one render-side text-layout owner path for
  geometry and paint.

#### Negative Scenarios

- No invariant or documentation text may continue to describe independent
  geometry and paint text-layout owners on the render read-side.

#### Closure Evidence

- Green run of the listed verifications.
- `tool/invariant_registry.dart` and the proof files contain aligned wording
  with exact `// INV:<id>` coverage.
- Release-ready docs no longer describe the superseded dual-layout path.

## 9. Final Verification

- `dart format --output=none --set-exit-if-changed lib test example/lib example/test tool`
- `flutter analyze`
- `(cd example && flutter analyze lib test)`
- `dcm analyze .`
- `dcm calculate-metrics lib/src/core lib/src/render --report-all`
- `dart run tool/check_tool_test_trigger_surface.dart`
- `dart run tool/check_import_boundaries.dart`
- `dart run tool/check_public_api_surface.dart`
- `dart run tool/check_guardrails.dart`
- `dart run tool/check_invariant_coverage.dart`
- MCP test runner shard preset: `core`
- MCP test runner shard preset: `model_contract`
- MCP test runner shard preset: `controller_internal`
- MCP test runner shard preset: `controller`
- MCP test runner shard preset: `render_view`
- MCP test runner shard preset: `interactive`
- MCP test runner shard preset: `example`
- `flutter test --coverage --no-pub --exclude-tags=tool`
- `dart run tool/check_coverage.dart`
- `dart run tool/run_tool_tests.dart`

## 10. Acceptance Criteria

- Result requirements are satisfied.
- Implementation specification is satisfied.
- Execution rules are satisfied.
- Mandatory slices are closed.
- Final verification has passed.
