language: english

# Change Contract

## 1. Change Mandate
Restore one closed render-frame authority rule: whenever a frame exposes
`SceneViewRenderState.snapshot`, every paint candidate and every selected-node
supplement emitted for that frame must resolve against that same snapshot.

## 2. Locked Decisions

1. The active frame snapshot is the only node authority for a frame. The
   render path must not mix `renderState.snapshot` with node materialization
   from a different committed snapshot.
2. `enumeratePaintCandidates(...)` stays viewport-first. This step does not
   replace ordered viewport candidate acquisition with a full-frame public
   scan in the normal committed path.
3. The committed controller spatial-index fast path remains valid only when
   the active frame snapshot is identical to `SceneStoreController.snapshot`.
4. If the active frame snapshot diverges from the committed controller
   snapshot, `SceneControllerSceneViewRenderState` must fall back to
   snapshot-authoritative candidate enumeration for both ordinary viewport
   candidates and selected-node supplements.
5. Selected-node supplements continue to use `visibilityRect`, while ordinary
   candidates continue to use the raw `viewportRect`.
6. `ScenePainter` must capture one atomic frame read before shell/frame/node
   work begins, and background paint plus candidate enumeration plus resolved
   preview geometry must all consume that same captured frame read.
7. Snapshot-backed full-frame candidate enumeration for divergent snapshots
   must have one shared owner; this step must not leave a second parallel
   implementation of those semantics in production and test support.
8. This step must not widen the sealed committed read-side controller API from
   step 108. No new public or controller-owned helper contract is allowed.

## 3. Result Requirements

1. A frame never paints a node that is absent from the active frame snapshot.
2. A node that exists only in the active frame snapshot can still be painted
   when it overlaps the raw viewport or the selected-node visibility rect.
3. The normal committed path keeps controller-owned ordered viewport candidate
   acquisition when the active frame snapshot matches the controller
   snapshot.
4. Repository docs describe one non-contradictory rule: render output is
   frame-authoritative, while viewport-first/index-driven enumeration remains
   the normal execution strategy.
5. The render pipeline no longer performs independent live frame reads for
   background paint and candidate enumeration inside the same scene paint.

## 4. Vertical Slices

### Slice 1. [x] Close frame authority in controller-owned render-state enumeration

#### Change
- Update `SceneControllerSceneViewRenderState.enumeratePaintCandidates(...)`
  so the committed controller fast path is used only when
  `readSnapshot()` and `storeController.snapshot` are identical.
- Capture one atomic frame read through `SceneViewRenderState` before painter
  shell execution so background paint, visibility budget, candidate
  enumeration, and resolved preview geometry share one frame authority.
- Add a local snapshot-authoritative fallback for divergent frame snapshots
  that:
  - enumerates background and content nodes from the active frame snapshot
  - keeps ordinary candidates on `viewportRect`
  - keeps selected-node supplements on `visibilityRect`
  - preserves background/content ordering and de-duplication
  - reuses one shared snapshot enumeration owner instead of duplicating that
    logic in test support

#### Verification
- `flutter test test/render/scene_painter_frame_contract_test.dart`

### Slice 2. [x] Lock the frame-authoritative contract in render tests

#### Change
- Update render-frame contract tests so divergent frame snapshots prove:
  - ordinary content candidates come from the active frame snapshot
  - selected-node supplements come from the active frame snapshot
  - stale committed-only nodes are dropped when omitted by the active frame
    snapshot

#### Verification
- `flutter test test/render/scene_painter_frame_contract_test.dart`

### Slice 3. [x] Publish the frame-authoritative render rule

#### Change
- Update `README.md`, `API_GUIDE.md`, `ARCHITECTURE.md`, `CHANGELOG.md`, and
  the existing frame-resolution invariant wording so the repository states one
  rule: one frame snapshot authority, viewport-first/index-driven normal path,
  snapshot-authoritative fallback on divergence.

#### Verification
- `rg -n "frame-authoritative|active frame snapshot|viewport-first" README.md API_GUIDE.md ARCHITECTURE.md CHANGELOG.md tool/invariant_registry.dart`
