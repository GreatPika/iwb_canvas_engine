language: russian

# Шаг 71. Замкнуть shared scene model invariants для stroke, palette и `textDirection`

## 1. Change Mandate

This change fixes the absence of a single owner for scene model invariants by introducing one shared invariant path for stroke point count, palette item count, and text node layout inputs across typed construction, policy, import, serialization, and decode.

## 2. Change Boundary

### Included in the Change

* Unification of `kMaxStrokePointsPerNode` enforcement across typed, policy, import, serialization, and decode paths.
* Unification of `kMaxPaletteItems` enforcement across typed, policy, import, serialization, and decode paths.
* Completion of the text node contract by making `textDirection` explicit in model and serialized data.
* Normalization of legacy text payloads without `textDirection` at decode boundary.
* Removal of authoritative dependence on inbound serialized text `size`.
* Update of targeted tests and invariant protection for the changed rules.

### Not Included in the Change

* Any change to interactive, render, controller, or public API problems outside the listed model-invariant defect.
* Any broad refactor of unrelated node contracts.
* Any optimization work in text layout or rendering performance.
* Any change to semantics of other scene limits not confirmed in the current defect scope.

## 3. File Map and Analysis Areas

### Implementation Files

* `lib/src/model/scene_builder_decode_stroke.dart`
* `lib/src/model/scene_builder_decode_scene_metadata.dart`
* `lib/src/model/scene_policy.dart`
* `lib/src/model/scene_value_validation_palette_grid.dart`
* `lib/src/contract/snapshot.dart`
* `lib/src/core/text_layout.dart`
* `lib/src/core/scene_limits.dart`
* `lib/src/model/scene_node_boundary_mapping_text.dart`
* `lib/src/serialization/scene_codec.dart`
* `lib/src/contract/internal/node_boundary_schema_spec.dart`
* `lib/src/contract/internal/node_boundary_schema_snapshot.dart`

### Test Files

* `test/model/scene_builder_test.dart`
* `test/serialization/scene_codec_validation_test.dart`
* `test/serialization/scene_test.dart`

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
5. Legacy text payloads without `textDirection` must be normalized at decode boundary to `TextDirection.ltr`.
6. Inbound serialized text `size` is not authoritative model truth.
7. Silent truncation, clipping, or auto-repair of invalid stroke point lists and palette lists is forbidden.
8. The change is not closed until typed, decode, and serialization paths are covered by executable negative checks for the affected invariants.

## 5. Result Requirements

1. A stroke node that exceeds `kMaxStrokePointsPerNode` is rejected through one shared rule path in typed construction, policy validation, import, serialization, and decode.
2. A palette that exceeds `kMaxPaletteItems` is rejected through one shared rule path in typed construction, policy validation, import, serialization, and decode.
3. The package cannot create, serialize, or emit canonical scene data that its own decode path rejects for the affected stroke and palette invariants.
4. Text nodes carry explicit `textDirection` in model data and serialized scene data.
5. Legacy text payloads without `textDirection` decode into model data with explicit normalized direction.
6. Text layout correctness no longer depends on hidden semantic fallback outside model-owned `textDirection`.
7. Inbound serialized text `size` does not determine semantic correctness of text nodes.
8. Targeted tests and invariant protection prove model invariant consistency across typed, decode, and serialization paths.

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
* Text node mapping and derived text size recomputation path.
* Targeted model and serialization tests.
* Invariant protection tooling affected by the new rules.

### 6.3 Protected States, Data, or Structures

* Stroke point list cardinality.
* Palette list cardinality for scene palette data.
* Text node layout inputs.
* Text node serialized compatibility for legacy payloads.
* Canonical compatibility between typed construction, serialization, and decode.

### 6.4 Allowed Semantic Change Zones

* Ownership of stroke and palette invariant enforcement.
* Text node semantic contract fields.
* Legacy decode normalization for missing `textDirection`.
* Treatment of serialized text `size` as non-authoritative input.
* Targeted invariant proof coverage for the changed rules.

### 6.5 Allowed Forms That Do Not Count as Violations

* Legacy decode-time normalization of missing `textDirection` to `TextDirection.ltr`.
* Recomputed derived text `size` written by encoder only if the external schema still requires that field during migration.

### 6.6 Prohibited

* A decode-only owner for `kMaxStrokePointsPerNode`.
* A decode-only owner for `kMaxPaletteItems`.
* A typed path that accepts stroke or palette data rejected by decode for the same invariant.
* A serialization path that emits canonical scene data rejected by decode for the same invariant.
* Hidden semantic dependence on implicit `TextDirection.ltr` for `TextAlign.start` or `TextAlign.end`.
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

### Slice 1. [ ] Shared stroke invariant path

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

### Slice 2. [ ] Shared palette invariant path

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

### Slice 3. [ ] Explicit text direction contract

#### Slice Contract

Text nodes carry explicit `textDirection` in model data and serialized scene data, and legacy payloads without that field normalize to explicit direction at decode boundary.

#### Change

Extend the text node contract, mapping path, and codec path to carry explicit `textDirection`; add decode normalization for legacy payloads that omit `textDirection`.

#### Verification

* `flutter test test/model/scene_builder_test.dart`
* `flutter test test/serialization/scene_codec_validation_test.dart`
* `flutter test test/serialization/scene_test.dart`

#### Positive Scenarios

* A text node with explicit `textDirection` is accepted through typed construction, encode, and decode.
* A legacy text payload without `textDirection` decodes into model data with explicit normalized direction.

#### Negative Scenarios

* Text layout-relevant paths cannot rely on hidden semantic fallback outside model-owned `textDirection`.
* A serialized text payload missing required explicit `textDirection` in the new canonical path is not treated as already-canonical scene data.

#### Closure Evidence

* Green run of the listed verifications with explicit-direction and legacy-normalization scenarios implemented.
* Diagnostic proof that legacy decode normalization occurs at boundary rather than remaining implicit in layout code.

### Slice 4. [ ] Derived non-authoritative text size

#### Slice Contract

Inbound serialized text `size` is non-authoritative, and text size used by import and serialization is derived from current text node data including explicit `textDirection`.

#### Change

Route text import and serialization through derived-size computation that does not trust inbound serialized `size` as semantic truth, while preserving compatibility for legacy payload acceptance.

#### Verification

* `flutter test test/model/scene_builder_test.dart`
* `flutter test test/serialization/scene_codec_validation_test.dart`
* `flutter test test/serialization/scene_test.dart`

#### Positive Scenarios

* A text node with valid content, style, align, and explicit direction produces stable derived size through import and serialization.
* A legacy payload containing `size` remains decodable without using inbound `size` as semantic source of truth.

#### Negative Scenarios

* Altering inbound serialized `size` alone does not bypass text-node semantic validation.
* Canonical output does not depend on preserving inbound legacy `size` as authoritative state.

#### Closure Evidence

* Green run of the listed verifications with derived-size and inbound-size-negative scenarios implemented.
* Diagnostic proof that inbound `size` is ignored as semantic truth in the changed path.

### Slice 5. [ ] Invariant protection updated for the changed rules

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
