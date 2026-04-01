language: russian

# Шаг 71. Замкнуть shared scene model invariants для stroke, palette и `textDirection`

## 1. Change Mandate

This change fixes the absence of a single owner for scene model invariants by introducing one shared invariant path for stroke point count, palette item count, and text node layout inputs across typed construction, policy, import, serialization, decode, and the public runtime/write boundaries that expose those semantics.

## 2. Change Boundary

### Included in the Change

* Unification of `kMaxStrokePointsPerNode` enforcement across typed, policy, import, serialization, and decode paths.
* Unification of `kMaxPaletteItems` enforcement across typed, policy, import, serialization, and decode paths.
* Completion of the text node contract by making `textDirection` explicit in model and serialized data.
* Promotion of `textDirection` to a required serialized text field with an explicit breaking schema transition.
* Alignment of public runtime construction and write-side mutation APIs with a strict explicit `textDirection` contract so callers do not silently fall back to removed view-owned semantics.
* Removal of authoritative dependence on inbound serialized text `size`.
* Update of targeted tests and invariant protection for the changed rules.

### Not Included in the Change

* Any unrelated interactive, render, controller, or public API change outside the listed contract-alignment defect.
* Any broad refactor of unrelated node contracts.
* Any optimization work in text layout or rendering performance.
* Any change to semantics of other scene limits not confirmed in the current defect scope.

## 3. File Map and Analysis Areas

### Implementation Files

* `lib/src/model/scene_builder_decode_stroke.dart`
* `lib/src/model/scene_builder_decode_scene_metadata.dart`
* `lib/src/model/scene_policy.dart`
* `lib/src/model/scene_value_validation_palette_grid.dart`
* `lib/src/model/document_node_patch_text.dart`
* `lib/src/contract/node_spec.dart`
* `lib/src/contract/node_patch.dart`
* `lib/src/contract/snapshot.dart`
* `lib/src/contract/internal/node_boundary_schema_patch.dart`
* `lib/src/core/text_layout.dart`
* `lib/src/core/scene_limits.dart`
* `lib/src/model/scene_node_boundary_mapping_text.dart`
* `lib/src/render/cache/scene_text_layout_cache.dart`
* `lib/src/render/scene_painter.dart`
* `lib/src/render/scene_painter_node_renderer.dart`
* `lib/src/view/scene_view_render_surface.dart`
* `lib/src/serialization/scene_codec.dart`
* `lib/src/contract/internal/node_boundary_schema_spec.dart`
* `lib/src/contract/internal/node_boundary_schema_snapshot.dart`

### Test Files

* `test/model/scene_builder_test.dart`
* `test/model/document_model_test.dart`
* `test/public_api/node_patch_semantics_test.dart`
* `test/serialization/scene_codec_validation_test.dart`
* `test/serialization/scene_test.dart`
* `test/render/scene_painter_test.dart`

### Analysis Area

* `lib/src/contract/**`
* `lib/src/core/**`
* `lib/src/model/**`
* `lib/src/serialization/**`
* `test/model/**`
* `test/serialization/**`
* `tool/**`

### Outside the Change Boundary

* Any files outside the listed zones.
* An exception is allowed only for a targeted change without which a specific slice and its verification cannot be closed.

### File Change Rule

* Every modified implementation file must be tied to a specific slice.
* Every new or modified test must be tied to a specific verification.
* Every new or modified fixture must be tied to a specific verification.
* Untied changes are considered out of scope for the change.

## 4. Locked Decisions

1. One shared invariant layer must own the stroke point-count rule and the palette item-count rule; decode, policy, serialization, and typed constructor code must not remain independent owners of those same rules.
2. Numeric limits remain defined in `lib/src/core/scene_limits.dart`.
3. The shared invariant layer must be reachable from both `contract` and `model` without reversing the repository layer graph.
4. `textDirection` is part of the semantic text node contract and must exist in model data and serialized scene data.
5. Legacy text payloads without `textDirection` are outside the supported JSON schema and must be rejected explicitly at decode boundary.
6. Inbound serialized text `size` is not authoritative model truth.
7. Silent truncation, clipping, or auto-repair of invalid stroke point lists and palette lists is forbidden.
8. The change is not closed until typed, decode, and serialization paths are covered by executable negative checks for the affected invariants.
9. Removing a view-owned `textDirection` fallback is allowed only if public runtime creation and mutation boundaries are aligned with the model-owned direction contract and cannot silently drift to implicit `TextDirection.ltr`.
10. If `textDirection` is model-owned mutable text state, the public write boundary must expose a supported update path for existing text nodes.
11. The chosen migration policy for this step is strict explicit contract alignment: no compatibility bridge, no hidden runtime fallback, and no implicit `TextDirection.ltr` default on public text constructors that would preserve old call sites while changing semantics.

## 5. Result Requirements

1. A stroke node that exceeds `kMaxStrokePointsPerNode` is rejected through one shared rule path in typed construction, policy validation, import, serialization, and decode.
2. A palette that exceeds `kMaxPaletteItems` is rejected through one shared rule path in typed construction, policy validation, import, serialization, and decode.
3. The package cannot create, serialize, or emit canonical scene data that its own decode path rejects for the affected stroke and palette invariants.
4. Text nodes carry explicit `textDirection` in model data and serialized scene data.
5. Legacy text payloads without `textDirection` are rejected by the decode boundary of the current schema.
6. Text layout correctness no longer depends on hidden semantic fallback outside model-owned `textDirection`.
7. Inbound serialized text `size` does not determine semantic correctness of text nodes.
8. Targeted tests and invariant protection prove model invariant consistency across typed, decode, and serialization paths.
9. Public runtime construction paths do not silently change caller-visible RTL/LTR semantics when the view-level fallback is removed.
10. Existing text nodes can be moved between LTR and RTL through the supported public write contract if `textDirection` remains mutable model state.
11. Public text constructors require explicit `textDirection` at call sites, and `TextNodePatch` exposes explicit direction mutation for existing text nodes.

## 6. Implementation Specification

### 6.1 Analysis Scope

* Inspect every path that can create, validate, import, encode, or decode stroke nodes.
* Inspect every path that can create, validate, import, encode, or decode palette data.
* Inspect every path that constructs, imports, recalculates, encodes, or decodes text node layout-relevant fields.
* Inspect existing invariant protection to ensure these rules are not left as decode-only or comment-only guarantees.

### 6.2 Target Verification Units

* Shared invariant helpers for stroke point count and palette item count.
* Snapshot and schema validation for stroke nodes and palette data.
* `ScenePolicy` and model validation entrypoints that currently validate imported scene data.
* JSON decode entrypoints for stroke nodes, scene metadata, and text fields.
* Serialization entrypoints that emit canonical scene data.
* Public runtime constructors and patch entrypoints for text nodes.
* Text-node mutation application paths that recompute derived size after semantic layout changes.
* Text node mapping and derived text size recomputation path.
* Targeted model and serialization tests.
* Invariant protection tooling affected by the new rules.

### 6.3 Protected States, Data, or Structures

* Stroke point list cardinality.
* Palette list cardinality for scene palette data.
* Text node layout inputs.
* Text node serialized compatibility for the current explicit-direction schema.
* Public runtime creation and mutation semantics for text direction.
* Canonical compatibility between typed construction, serialization, and decode.

### 6.4 Allowed Semantic Change Zones

* Ownership of stroke and palette invariant enforcement.
* Text node semantic contract fields.
* Breaking decode enforcement for missing `textDirection`.
* Public runtime/write-side alignment for the explicit text-direction contract.
* Treatment of serialized text `size` as non-authoritative input.
* Targeted invariant proof coverage for the changed rules.

### 6.5 Allowed Forms That Do Not Count as Violations

* Recomputed derived text `size` written by encoder only if the external schema still requires that field during migration.
* Public patch semantics may keep `textDirection` optional per patch object because `NodePatch` is partial by design; the strictness requirement applies to text creation boundaries and to the existence of an explicit write path, not to forcing unrelated patches to resend current direction.

### 6.6 Prohibited

* A decode-only owner for `kMaxStrokePointsPerNode`.
* A decode-only owner for `kMaxPaletteItems`.
* A typed path that accepts stroke or palette data rejected by decode for the same invariant.
* A serialization path that emits canonical scene data rejected by decode for the same invariant.
* Hidden semantic dependence on implicit `TextDirection.ltr` for `TextAlign.start` or `TextAlign.end`.
* Public runtime construction paths that silently substitute `TextDirection.ltr` after the view fallback has been removed without an explicit migration policy and proof coverage.
* A model-owned `textDirection` contract that cannot be updated through the supported public write boundary for existing text nodes.
* A compatibility bridge that keeps old runtime constructor call sites compiling by silently defaulting missing `textDirection` while the canonical contract has already moved to explicit direction.
* Treating inbound serialized text `size` as authoritative model truth.
* Silent truncation or silent repair of invalid stroke point lists or palette lists.
* Closing the change without executable negative tests for typed, decode, and serialization paths.

## 7. Execution Rules

1. One slice closes one new verifiable change contract.
2. Every slice must have its own verification.
3. A slice is considered closed only in the change where its verification exists and its run is green.
4. Preparatory changes alone do not count as a closed slice.
5. The next slice is forbidden until the previous slice is closed.
6. If a slice closes a failure scenario, diagnostic output confirming the trigger point must be attached.
7. If a slice changes an analysis rule, negative and positive scenarios must be covered where applicable to the subject of the change.
8. Scope expansion is forbidden until the mandatory slices are closed.

## 8. Vertical Slices

### Slice 1. [x] Shared stroke invariant path

#### Slice Contract

A stroke node above `kMaxStrokePointsPerNode` is rejected by one shared invariant path in typed construction, policy/import validation, serialization, and decode.

#### Change

Introduce one shared stroke point-count invariant helper in the shared lower layer reachable from `contract` and `model`, then route all stroke creation, validation, import, serialization, and decode entrypoints through that helper.

#### Verification

* `flutter test test/model/scene_builder_test.dart`
* `flutter test test/serialization/scene_codec_validation_test.dart`
* `flutter test test/serialization/scene_test.dart`

#### Positive Scenarios

* A stroke node at the limit is accepted through typed construction.
* A scene containing a valid stroke round-trips through encode and decode without invariant failure.

#### Negative Scenarios

* Typed construction rejects a stroke above `kMaxStrokePointsPerNode`.
* Decode rejects a stroke above `kMaxStrokePointsPerNode`.
* Serialization rejects canonical emission of a stroke above `kMaxStrokePointsPerNode`.

#### Closure Evidence

* Green run of the listed verifications with targeted positive and negative stroke scenarios implemented.
* Failure output showing the trigger point for the invalid stroke cardinality path before the slice is fixed.

### Slice 2. [x] Shared palette invariant path

#### Slice Contract

A palette above `kMaxPaletteItems` is rejected by one shared invariant path in typed construction, policy/import validation, serialization, and decode.

#### Change

Introduce one shared palette item-count invariant helper in the shared lower layer reachable from `contract` and `model`, then route palette construction, validation, import, serialization, and decode entrypoints through that helper.

#### Verification

* `flutter test test/model/scene_builder_test.dart`
* `flutter test test/serialization/scene_codec_validation_test.dart`
* `flutter test test/serialization/scene_test.dart`

#### Positive Scenarios

* A palette at the limit is accepted through typed construction.
* A valid palette round-trips through encode and decode without invariant failure.

#### Negative Scenarios

* Typed construction rejects a palette above `kMaxPaletteItems`.
* Decode rejects a palette above `kMaxPaletteItems`.
* Serialization rejects canonical emission of a palette above `kMaxPaletteItems`.

#### Closure Evidence

* Green run of the listed verifications with targeted positive and negative palette scenarios implemented.
* Failure output showing the trigger point for the invalid palette cardinality path before the slice is fixed.

### Slice 3. [x] Explicit text direction contract

#### Slice Contract

Text nodes carry explicit `textDirection` in model data and serialized scene data, payloads without that field are rejected by the current schema boundary, public runtime constructors require explicit direction, and the public write API exposes explicit direction mutation for existing text nodes.

#### Change

Extend the text node contract, mapping path, codec path, and public runtime/write boundaries to carry explicit `textDirection`; reject payloads that omit `textDirection`, remove view-level direction fallback from the canonical text contract, require explicit direction on public text constructors, and expose `textDirection` through the public patch/write path for existing text nodes.

#### Verification

* `flutter test test/model/scene_builder_test.dart`
* `flutter test test/model/document_model_test.dart`
* `flutter test test/public_api/node_patch_semantics_test.dart`
* `flutter test test/render/scene_painter_test.dart`
* `flutter test test/serialization/scene_codec_validation_test.dart`
* `flutter test test/serialization/scene_test.dart`

#### Positive Scenarios

* A text node with explicit `textDirection` is accepted through typed construction, encode, and decode.
* A text payload with explicit `textDirection` remains round-trippable through the current schema version.
* Public runtime construction and mutation entrypoints preserve the chosen explicit-direction semantics without relying on a removed view fallback.
* Public text constructor call sites that omit `textDirection` fail at compile time rather than silently receiving implicit LTR semantics.

#### Negative Scenarios

* Text layout-relevant paths cannot rely on hidden semantic fallback outside model-owned `textDirection`.
* A serialized text payload missing required explicit `textDirection` in the new canonical path is not treated as already-canonical scene data.
* An existing text node cannot become stuck with an unchangeable `textDirection` if the contract treats direction as mutable node state.
* Public runtime text creation cannot silently change `TextAlign.start` / `TextAlign.end` behavior to implicit LTR after the fallback removal.
* The package must not preserve pre-change runtime call-site compatibility by keeping an implicit default direction once the canonical contract has moved to strict explicit semantics.

#### Closure Evidence

* Green run of the listed verifications with explicit-direction, missing-field rejection, public-construction, and write-side mutation scenarios implemented.
* Diagnostic proof that decode rejects payloads that omit `textDirection` instead of silently normalizing them.
* Diagnostic proof that the chosen public runtime/write-side direction policy does not rely on the removed view fallback.
* Diagnostic proof that strict explicit runtime construction is enforced at the public boundary and that direction can still be changed through the public write path.

### Slice 4. [x] Derived non-authoritative text size

#### Slice Contract

Inbound serialized text `size` is non-authoritative, and text size used by import and serialization is derived from current text node data including explicit `textDirection`.

#### Change

Route text import and serialization through derived-size computation that does not trust inbound serialized `size` as semantic truth, while preserving compatibility for the current schema shape that still carries serialized `size`.

#### Verification

* `flutter test test/model/scene_builder_test.dart`
* `flutter test test/serialization/scene_codec_validation_test.dart`
* `flutter test test/serialization/scene_test.dart`

#### Positive Scenarios

* A text node with valid content, style, align, and explicit direction produces stable derived size through import and serialization.
* A current-schema payload containing serialized `size` remains decodable without using inbound `size` as semantic source of truth.

#### Negative Scenarios

* Altering inbound serialized `size` alone does not bypass text-node semantic validation.
* Canonical output does not depend on preserving inbound legacy `size` as authoritative state.

#### Closure Evidence

* Green run of the listed verifications with derived-size and inbound-size-negative scenarios implemented.
* Diagnostic proof that inbound `size` is ignored as semantic truth in the changed path.

### Slice 5. [x] Invariant protection updated for the changed rules

#### Slice Contract

The changed model invariants are mechanically protected by executable invariant coverage and are not left as decode-only guarantees.

#### Change

Update the invariant protection surface so the shared stroke rule, shared palette rule, and text contract change are represented by executable checks tied to the changed paths.

#### Verification

* `dart run tool/check_invariant_coverage.dart`
* `dart run tool/check_guardrails.dart`

#### Positive Scenarios

* The changed invariant proofs are registered and pass invariant coverage checks.
* The changed code paths remain inside the intended architectural boundary.

#### Negative Scenarios

* Removing proof registration for one of the changed rules fails invariant coverage.
* Leaving one of the changed rules as a decode-only guarantee fails targeted protection expectations.

#### Closure Evidence

* Green run of the listed tooling checks after proof registration is updated.
* Failure output from invariant protection before the slice is fixed.

## 9. Final Verification

* `flutter test test/model/scene_builder_test.dart`
* `flutter test test/model/document_model_test.dart`
* `flutter test test/public_api/node_patch_semantics_test.dart`
* `flutter test test/render/scene_painter_test.dart`
* `flutter test test/serialization/scene_codec_validation_test.dart`
* `flutter test test/serialization/scene_test.dart`
* `dart run tool/check_invariant_coverage.dart`
* `dart run tool/check_guardrails.dart`

## 10. Acceptance Criteria

* Result requirements are satisfied.
* Implementation specification is satisfied.
* Execution rules are satisfied.
* Mandatory slices are closed.
* Final verification has passed.
