# Change Contract

## 1. Change Mandate

Establish one model-owned import diagnostic surface so public JSON
import/build entrypoints report alias-bearing line/stroke range diagnostics
through `localA`, `localB`, and `localPoints`, while typed snapshot surfaces
keep canonical `start`, `end`, and `points`, without storing JSON provenance in
canonical drafts or duplicating range checks in decode owners.

## 2. Change Boundary

### Included in the Change

- Add one internal model seam for caller-visible validation path surfaces on
  import/build boundaries.
- Move late import-draft range diagnostics out of `scene_policy.dart` into the
  existing value-validation owner family under `lib/src/model/scene_value_validation*.dart`.
- Preserve the current canonical `SceneImportDraft` / `SceneSnapshotBacking`
  data shape while making path selection explicit at the boundary call site.
- Add regression tests, invariant coverage, model-architecture guardrails, and
  release-ready documentation updates for the public diagnostic-path contract.

### Not Included in the Change

- Any public API rename, schema rename, or canonical snapshot-field rename.
- Any new provenance or source-path fields on `SceneImportDraft`,
  `SceneSnapshotBacking`, or node backing types.
- Any duplicate scene-range validation in `scene_builder_decode_line.dart`,
  `scene_builder_decode_stroke.dart`, or other JSON decode owners.
- Any runtime-center refactor from ADR 0001 or phase-2 follow-up work from
  ADR 0002.
- Any rewrite of `SceneDataException` wording beyond the path/details changes
  already implied by the existing public contract.

## 3. Surrounding Code Review

### Inspected Artifacts

- `lib/src/model/scene_builder.dart` — `sceneBuildFromSnapshot(...)` and
  `sceneBuildFromJsonMap(...)` are the import/build owners that currently enter
  `ScenePolicy.validateImportDraft(...)` without any explicit diagnostic
  surface.
- `lib/src/model/scene_builder_decode_line.dart` — JSON `localA` / `localB`
  decode already owns finite/object validation for line endpoints and keeps the
  public JSON field names at decode time.
- `lib/src/model/scene_builder_decode_stroke.dart` — JSON `localPoints` decode
  already owns list/max-points/finite-item validation and keeps the public JSON
  field name at decode time.
- `lib/src/model/scene_import_draft.dart` — the draft is a pure canonical
  carrier over `SceneSnapshotBacking` and currently has no provenance slot.
- `lib/src/model/scene_from_import_draft.dart` — `sceneImportFromDraft(...)`
  is the import owner that currently delegates to `ScenePolicy.validateImportDraft(...)`
  before runtime materialization.
- `lib/src/model/scene_policy.dart` — late import-draft range validation is
  still owned here through `_validateDraftRanges(...)` and direct
  `SceneDataException.outOfRange(...)` construction.
- `lib/src/model/scene_value_validation_scene.dart` — import-draft validation
  currently materializes canonical snapshots and therefore loses JSON spelling
  before alias-bearing range diagnostics are emitted.
- `lib/src/model/scene_value_validation_node.dart` — node-family validation is
  already centralized here and dispatches to family owners.
- `lib/src/model/scene_value_validation_node_line.dart` — this file already
  demonstrates the correct local pattern: one invariant owner with caller-chosen
  field spelling (`start/end` for snapshot, `localA/localB` for runtime).
- `lib/src/model/scene_value_validation_node_stroke.dart` — same local pattern
  already exists for `points` vs `localPoints`.
- `lib/src/model/scene_value_validation_palette_grid.dart` — scene metadata
  range helpers already take caller-provided field paths and do not hardcode
  entrypoint spelling internally.
- `lib/src/contract/scene_data_exception.dart` and
  `lib/src/contract/scene_validation_diagnostics.dart` — the public error
  contract is stable and path/details driven, so owner changes must preserve
  that contract rather than replace it.
- `test/public_api/validated_boundary_value_test.dart` — current proof locks
  neighboring JSON finite/type diagnostics such as non-finite `localA`, but not
  the alias-bearing out-of-range branch.
- `test/public_api/scene_builder_test.dart` — current proof locks path-aware
  parity between `SceneBuilder.buildFromJson(...)` and `decodeScene(...)` for
  neighboring contracts, including `localPoints` max-points.
- `test/serialization/scene_codec_validation_test.dart` — current proof locks
  triple-entrypoint contract parity and several neighboring JSON range branches,
  but not alias-bearing line/stroke range drift.
- `test/model/scene_builder_test.dart` — current proof already covers
  `sceneCanonicalizeAndValidateSnapshot(...)` and
  `ScenePolicy.validateImportSnapshot(...)` as direct model-owned snapshot
  canonicalization/import-spine surfaces that this step must keep explicit.
- `test/model/scene_value_validation_primitives_test.dart` — current proof
  already locks snapshot-vs-runtime field naming on line finite diagnostics and
  path-derived `fieldName` behavior.
- `tool/invariant_registry.dart` — current serialization invariants cover JSON
  numeric validation and shared metadata contracts, but not alias-bearing import
  diagnostic surfaces.
- `tool/src/guardrails/rules/model/model_architecture_rules.dart` and
  `test/tool/guardrails/guardrails_model_architecture_tool_test.dart` — the
  repository already has a model-architecture guardrail seam that can carry the
  new owner restriction.
- `ARCHITECTURE.md` — the model layer owns import/build canonicalization and the
  stable scene boundary error contract.
- `docs/adr/0001_target_engine_architecture.md` — the accepted target keeps the
  existing public boundary and layer DAG stable and rejects new general-purpose
  logic buckets.
- `docs/adr/0002_post_target_optimization_scope.md` — the accepted follow-up
  scope explicitly avoids opportunistic broad redesign outside the targeted
  owner families.

### Current Entry Path

- JSON map/string path:
  `SceneBuilder.buildFromJson(...)` / `decodeScene(...)` /
  `decodeSceneFromJson(...)`
  -> `sceneBuildFromDynamicJsonMap(...)` / `_guardDecode(...)`
  -> `sceneBuildFromJsonMap(...)`
  -> `sceneBuilderDecodeImportDraftFromJson(...)`
  -> `ScenePolicy.validateImportDraft(...)`
  -> `sceneValidateImportDraftValues(...)`
  -> `_buildDraftSceneValueValidationAccessors()`
  -> `materializeNodeSnapshot(...)`
  -> `sceneValidateNodeSnapshot(...)`
  plus `scene_policy.dart` late `_validateDraftRanges(...)`.
- Typed snapshot path:
  `SceneBuilder.buildFromSnapshot(...)`
  -> `sceneBuildFromSnapshot(...)`
  -> `sceneImportDraftFromSnapshot(...)`
  -> `ScenePolicy.validateImportDraft(...)`.
- Internal snapshot-canonicalization path:
  `sceneCanonicalizeAndValidateSnapshot(...)` /
  `ScenePolicy.validateImportSnapshot(...)`
  -> `sceneImportDraftFromSnapshot(...)`
  -> `ScenePolicy.validateImportDraft(...)`.

### Current Owner

- The defect belongs to the model-layer import-boundary diagnostic naming
  contract.
- JSON decode owners know the caller-visible JSON field spelling, and
  validation owners know the invariants, but `scene_policy.dart` currently owns
  late range-path construction after canonicalization, which is why JSON
  alias-bearing diagnostics drift back to canonical snapshot names.

### Adjacent Abstractions

- `lib/src/model/scene_builder_decode_scene_metadata.dart` — valid early JSON
  metadata range owner for fields whose JSON spelling is already stable.
- `lib/src/model/scene_import_draft_from_snapshot.dart` — canonical snapshot
  import path that should keep snapshot spelling without adding extra metadata.
- `lib/src/model/scene_value_validation.dart` — internal facade over the
  validation owner family.
- `lib/src/model/scene_value_validation_support.dart` — stable conversion seam
  from validation diagnostics into `SceneDataException`.
- `lib/src/model/scene_builder_json_require.dart` — existing decode path helper
  seam that should remain decode-only and should not absorb late range logic.

### Existing Tests

- `test/public_api/validated_boundary_value_test.dart` — covers neighboring
  JSON finite/type contracts such as non-finite `localA`.
- `test/public_api/scene_builder_test.dart` — covers builder-vs-codec
  path-aware diagnostic parity and current `localPoints` max-points behavior.
- `test/serialization/scene_codec_validation_test.dart` — covers triple-entrypoint
  diagnostic parity, neighboring JSON range cases, and current `localPoints`
  shape/type limits.
- `test/model/scene_builder_test.dart` — already covers
  `sceneCanonicalizeAndValidateSnapshot(...)` and
  `ScenePolicy.validateImportSnapshot(...)` as direct model-owned snapshot
  canonicalization/import-spine proofs.
- `test/model/scene_value_validation_primitives_test.dart` — covers line
  snapshot-vs-runtime field naming and `SceneDataDiagnosticDescriptor`
  path-derived `fieldName` behavior.
- `test/tool/guardrails/guardrails_model_architecture_tool_test.dart` —
  existing structural proof surface for model ownership rules.

### Analogous Implementation Path

- `lib/src/model/scene_value_validation_node_line.dart` and
  `lib/src/model/scene_value_validation_node_stroke.dart` already implement the
  dominant local form for this problem class: one invariant owner receives the
  semantic value plus caller-selected field spelling instead of reconstructing
  spelling later in a policy/orchestration file.

### Governing Repository Rules

- `AGENTS.md` — fix bugs at the owning layer, avoid sync glue, reuse existing
  abstractions, and add repository-local enforcement for stable constraints.
- `ARCHITECTURE.md` — the model layer owns import/build canonicalization,
  snapshot/runtime mapping, and stable boundary errors.
- `docs/adr/0001_target_engine_architecture.md` — keep the public boundary and
  layer DAG stable; do not solve local defects by adding a new general-purpose
  logic bucket.
- `docs/adr/0002_post_target_optimization_scope.md` — do not turn a local
  model-layer fix into an unrelated broad redesign or implicit public-contract
  review.
- `tool/invariant_registry.dart` —
  `INV-SER-JSON-NUMERIC-VALIDATION`,
  `INV-SER-JSON-GRID-PALETTE-CONTRACTS`,
  `INV-ENG-SHARED-SCENE-METADATA-CONTRACT`,
  `INV-ENG-MODEL-ARCHITECTURE-BOUNDARY`, and
  `INV-ENG-RUNTIME-NODE-VALUE-OWNERS` already constrain the surrounding owner
  surfaces.

### Rejected Misleading Local Patterns

- Storing source-path provenance on `SceneImportDraft` or snapshot backing
  types — wrong data owner and unnecessary transport metadata on canonical
  carriers.
- Copying scene-range checks into `scene_builder_decode_line.dart` or
  `scene_builder_decode_stroke.dart` — duplicates invariants across decode and
  validation owners.
- Patching only `_validateLineNodeRanges(...)` and `_validateStrokeNodeRanges(...)`
  string literals in `scene_policy.dart` — fixes the symptom locally while
  leaving late diagnostic ownership in the wrong file.
- Treating ADR 0001 / ADR 0002 as authorization for a broader runtime or public
  surface redesign — wrong owner family and wrong scope for this defect.

## 4. Architecture

### 4A. Locked Architectural Form

#### Problem Ownership Level

- Model-layer import-boundary diagnostic spelling for canonicalized drafts and
  snapshots.

#### Selected Architectural Form

- Add one internal path-surface seam in
  `lib/src/model/scene_validation_path_surface.dart` that represents the
  caller-visible field spelling for validation diagnostics.
- Import/build owners choose that surface explicitly at the entry path:
  JSON import/build selects the JSON surface, and typed snapshot import/build
  selects the canonical snapshot surface.
- `scene_value_validation_scene.dart` propagates the chosen surface into the
  existing validation owner family, and alias-bearing line/stroke validators
  emit diagnostics through that surface instead of reconstructing field names
  after canonicalization.
- `scene_policy.dart` stays an orchestration owner and no longer formats
  node-range diagnostic paths or constructs direct late `SceneDataException`
  range failures for import-draft node values.

#### Owning Layer or Module

- `lib/src/model/scene_validation_path_surface.dart` owns import diagnostic
  surface selection and field-path mapping helpers.
- `lib/src/model/scene_value_validation_scene.dart` owns surface propagation
  through scene, snapshot, and import-draft validation flows.
- `lib/src/model/scene_value_validation_node*.dart` owns invariant-specific
  application of that surface.
- `lib/src/model/scene_policy.dart` remains the structure/canonicalization
  owner only.

#### Dependency Direction

- `scene_builder.dart` and the import/build path select the diagnostic surface
  and pass it into model validation.
- Validation owners depend on the internal path-surface seam.
- Canonical data carriers (`SceneImportDraft`, snapshot backing types) remain
  dependency-neutral and do not depend on path-surface logic.
- Public entrypoint files and serialization facades continue to depend on model
  facades rather than internal owner modules.

#### State and Data Ownership

- `SceneImportDraft`, `SceneSnapshotBacking`, and node backing types remain
  canonical value carriers only.
- The chosen diagnostic surface is transient call-time configuration, not
  persisted state.
- `SceneDataException` remains the single public error type; this step changes
  only where its `path` and path-derived details come from.

#### Entry and Exit Boundaries

- Entry:
  `sceneBuildFromJsonMap(...)`, `sceneBuildFromSnapshot(...)`,
  `sceneCanonicalizeAndValidateSnapshot(...)`, and
  `ScenePolicy.validateImportSnapshot(...)` choose the surface before
  `ScenePolicy.validateImportDraft(...)`.
- Exit:
  `SceneDataException.path` and derived `details['fieldName']` reflect the
  selected caller-visible field surface on alias-bearing validation failures.

#### Permitted Extension Seam

- Only `scene_validation_path_surface.dart` and validation-owner helpers may
  define alias-bearing field-path mapping for import diagnostics.
- Future alias-bearing fields must extend that seam instead of adding direct
  path literals in `scene_policy.dart` or provenance metadata to canonical
  drafts.

#### Rejected Alternatives

- Add provenance/source-path storage to `SceneImportDraft` or snapshot backing
  types — wrong owner and unnecessary data-shape expansion.
- Duplicate late range checks in JSON decode owners — duplicates invariants and
  diverges from the dominant validation-owner pattern already present in
  `scene_value_validation_node_line.dart` and
  `scene_value_validation_node_stroke.dart`.
- Keep late range-path construction in `scene_policy.dart` and patch only the
  current line/stroke branches — local workaround that leaves the defect class
  in place.
- Fold this work into a broader ADR 0001 / ADR 0002 refactor — unnecessary
  scope and wrong owner family.

#### Why This Level Is Correct

- The drift happens only because canonicalization removes the caller-visible
  field spelling before the late validator emits the error. Passing the chosen
  surface explicitly into the validation owner fixes that shared cause once
  while keeping canonical data, public API, and layer boundaries stable.

## 5. Locked Decisions

1. Add `lib/src/model/scene_validation_path_surface.dart` as the only new owner
   for import diagnostic spelling.
2. Make surface selection explicit in the import/build call chain rather than
   implicit in `SceneImportDraft`.
3. Move late import-draft node/common/type-specific range validation out of
   `scene_policy.dart` and into the existing validation owner family so policy
   no longer owns value/range path formatting.
4. Keep decode-stage finite/type/max-points guards exactly where they already
   belong; this step only repairs late diagnostic drift and owner mismatch.
5. Add one serialization invariant and extend the model-architecture guardrail
   so future policy-owned import diagnostics and direct non-model imports of
   `scene_validation_path_surface.dart` become mechanically visible.

## 6. Result Requirements

1. `SceneBuilder.buildFromJson(...)`, `decodeScene(...)`, and
   `decodeSceneFromJson(...)` report out-of-range line/stroke coordinate
   diagnostics through `localA`, `localB`, and `localPoints`.
2. Typed snapshot import surfaces keep canonical `start`, `end`, and `points`
   for the same invariants.
3. Neighboring finite/type/max-points diagnostics remain stable.
4. `SceneImportDraft` and snapshot backing types remain provenance-free
   canonical carriers.
5. `scene_policy.dart` no longer directly owns late import-draft
   node/common/type-specific range path construction or direct range exception
   emission for those node values.
6. Public API signatures, JSON schema, and ADR 0001 / ADR 0002 owner targets
   remain unchanged.
7. `scene_validation_path_surface.dart` remains an internal model owner and is
   added to the same direct-import guardrail surface as other restricted
   `lib/src/model/**` owners.

## 7. Execution Order and Gates

### Required Order

- Slice 1 must add the failing public-boundary reproducers before any owner-side
  implementation edit.
- Slice 2 may introduce the explicit path-surface seam and retire policy-owned
  path assembly only after Slice 1 is in place.
- Slice 3 may register the new invariant, guardrail wording, and release-ready
  documentation only after Slice 2 has the reproduced cases green.

### Successor Seam and Retirement Gates

- Successor seam:
  `lib/src/model/scene_validation_path_surface.dart` becomes the only import
  diagnostic spelling seam.
- Consumer migration order:
  1. `scene_value_validation_scene.dart` and node-family validation owners adopt
     the new surface.
  2. `scene_builder.dart`, `scene_from_import_draft.dart`, and
     `scene_policy.dart` pass the surface explicitly through every import and
     snapshot-canonicalization path, including
     `sceneCanonicalizeAndValidateSnapshot(...)` and
     `ScenePolicy.validateImportSnapshot(...)`.
  3. Retire `_validateDraftRanges(...)`, `_validateNodeRanges(...)`,
     `_validateCommonNodeRanges(...)`, and the remaining direct type-specific
     range helpers from `scene_policy.dart` only after all import-draft range
     diagnostics flow through validation owners.
- Retirement gate:
  retire the direct policy-owned helpers only after
  `tool/invariant_registry.dart`,
  `tool/src/guardrails/rules/model/model_architecture_rules.dart`, and
  `test/tool/guardrails/guardrails_model_architecture_tool_test.dart`
  are updated to protect the new owner boundary.

### Deferred Broad Verification

- `dart run tool/run_verification_preset.dart run --preset=required_code_change --changed-paths-file=-`
  — reserve for the final gate after all slices land.

## 8. File Map

### Implementation Files

- `lib/src/model/scene_validation_path_surface.dart` (new)
- `lib/src/model/scene_builder.dart`
- `lib/src/model/scene_from_import_draft.dart`
- `lib/src/model/scene_policy.dart`
- `lib/src/model/scene_value_validation.dart`
- `lib/src/model/scene_value_validation_scene.dart`
- `lib/src/model/scene_value_validation_node.dart`
- `lib/src/model/scene_value_validation_node_image.dart`
- `lib/src/model/scene_value_validation_node_line.dart`
- `lib/src/model/scene_value_validation_node_path.dart`
- `lib/src/model/scene_value_validation_node_rect.dart`
- `lib/src/model/scene_value_validation_node_stroke.dart`
- `lib/src/model/scene_value_validation_node_text.dart`
- `lib/src/model/scene_value_validation_palette_grid.dart`

### Test Files

- `test/public_api/validated_boundary_value_test.dart`
- `test/public_api/scene_builder_test.dart`
- `test/serialization/scene_codec_validation_test.dart`
- `test/model/scene_builder_test.dart`
- `test/model/scene_value_validation_primitives_test.dart`
- `test/model/scene_validation_path_surface_contract_test.dart` (new)
- `test/tool/guardrails/guardrails_model_architecture_tool_test.dart`

### Fixtures and Supporting Data

- `test/support/scene_builder_json_fixtures.dart`

### Registry, Inventory, and Workflow Files

- `tool/invariant_registry.dart`
- `tool/src/guardrails/rules/model/model_architecture_rules.dart`
- `README.md`
- `API_GUIDE.md`
- `ARCHITECTURE.md`
- `CHANGELOG.md`
- `PLAN.md`
- `plan/step_7_import_boundary_diagnostic_surface.md`

## 9. Implementation Rules

### Protected Invariants

- `INV-SER-JSON-NUMERIC-VALIDATION`
- `INV-SER-JSON-GRID-PALETTE-CONTRACTS`
- `INV-ENG-SHARED-SCENE-METADATA-CONTRACT`
- `INV-ENG-MODEL-ARCHITECTURE-BOUNDARY`
- `INV-ENG-RUNTIME-NODE-VALUE-OWNERS`
- `INV-SER-IMPORT-DIAGNOSTIC-SURFACE` (new in this step)

### Required Proof

- behavioral proof:
  - one failing reproducer first for out-of-range `localA.x` on the public JSON
    boundary;
  - 1 to 3 guard tests for neighboring alias-bearing branches, covering
    `localB.y`, `localPoints[i].x/y`, and the typed snapshot surface that must
    keep canonical `start/end/points`;
  - public JSON entrypoints must compare `SceneDataException.code`,
    `SceneDataException.path`, and immutable `details`, not only message text.
- structural proof:
  - a dedicated model contract test must exercise the new path-surface seam so
    alias-bearing JSON and snapshot spellings are emitted by one owner path
    rather than by policy-specific string assembly;
  - the model-architecture guardrail must fail when non-model code imports
    `scene_validation_path_surface.dart` directly;
  - the model-architecture guardrail must fail when `scene_policy.dart`
    reintroduces direct import-range diagnostic ownership.
- for bug fixes, regressions, false positives, false negatives, and
  invariant-enforcement gaps: one failing reproducer first, plus 1 to 3 guard
  tests for neighboring branches of the same contract.

### Allowed Change Surface

- Only the files listed in section 8.
- Internal signature threading required to make surface selection explicit.
- Internal helper extraction required to retire direct policy-owned path
  assembly.

### Forbidden Moves

- Add provenance/source-path fields to canonical draft or backing types.
- Copy out-of-range node coordinate checks into JSON decode owners.
- Rename public JSON fields or canonical snapshot fields.
- Expand this step into a runtime-center ADR 0001 / ADR 0002 refactor.
- Replace path/detail assertions with message-only comparisons in the new proof
  surface.

### Optional: Allowed Forms That Are Not Violations

- The path-surface seam may be an internal enum plus top-level helper
  functions, or an internal record-style accessor family, as long as it lives
  in `scene_validation_path_surface.dart`.
- Fields whose spelling is identical across JSON and snapshot surfaces may use
  identity mapping through shared helpers rather than separate per-surface
  implementations.
- `sceneValidateSnapshotValues(...)` may absorb additional range coverage if
  that is the minimum coherent way to keep late value diagnostics inside the
  validation owner family.

### Optional: Resolution Rules

- If a field spelling is identical across surfaces, reuse the default identity
  path builder instead of adding a special-case mapping.
- If the only alias-bearing drift reproduced today is line/stroke-specific,
  still keep the new seam shared and reusable; do not encode a line/stroke-only
  patch directly inside `scene_policy.dart`.

## 10. Vertical Slices

### Slice 1. [x] Lock the alias-bearing boundary drift reproducers

#### Slice Contract

Make the current public-boundary path drift mechanically visible before any
owner-side implementation change.

#### Change

- Extend `test/public_api/scene_builder_test.dart` with failing builder-vs-codec
  reproducer cases for out-of-range `localA.x`, `localB.y`, and
  `localPoints[i].x/y`.
- Extend `test/serialization/scene_codec_validation_test.dart` with failing
  triple-entrypoint contract tests that compare `decodeSceneFromJson(...)`,
  `decodeScene(...)`, and `SceneBuilder.buildFromJson(...)` on those
  alias-bearing out-of-range branches.
- Extend `test/public_api/validated_boundary_value_test.dart` with precise
  `SceneDataException.code`, `path`, and `details` expectations for those JSON
  out-of-range cases.
- Extend `test/model/scene_builder_test.dart` with a typed-snapshot guard that
  exercises `sceneCanonicalizeAndValidateSnapshot(...)` and
  `ScenePolicy.validateImportSnapshot(...)`, so canonical `start/end/points`
  spelling stays locked on the direct snapshot-canonicalization/import-spine
  paths.
- Keep one neighboring typed field-name guard in
  `test/model/scene_value_validation_primitives_test.dart` so the lower-level
  validation seam remains locked independently of the entry-path proofs.

#### Behavioral Verification

- `flutter test test/public_api/scene_builder_test.dart`
  — expected to fail on the new reproduced cases before Slice 2.
- `flutter test test/serialization/scene_codec_validation_test.dart`
  — expected to fail on the new reproduced cases before Slice 2.
- `flutter test test/public_api/validated_boundary_value_test.dart`
  — expected to fail on the new reproduced cases before Slice 2.
- `flutter test test/model/scene_builder_test.dart`
  — expected to fail on the new snapshot-canonicalization guard before Slice 2.

#### Structural Verification

- `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_model_architecture_tool_test.dart`
  — must stay green while the behavioral reproducers are added.

#### Positive Scenarios

- JSON line import with out-of-range `localA.x`.
- JSON line import with out-of-range `localB.y`.
- JSON stroke import with out-of-range `localPoints[i].x` or `localPoints[i].y`.
- Typed snapshot validation that keeps canonical `start/end/points` spelling.

#### Negative Scenarios

- Existing finite `localA` diagnostics remain owned by the current early JSON
  guard path.
- Existing `localPoints` max-points diagnostics remain owned by the current
  decode path and keep their current spelling.
- Same-name range branches such as `opacity` stay unchanged.

#### Closure Evidence

- The new public-boundary reproducer cases fail against the current drift while
  neighboring finite/max-points and model-architecture proofs stay green.

### Slice 2. [x] Introduce the import diagnostic surface and retire policy-owned path assembly

#### Slice Contract

One explicit import diagnostic surface controls caller-visible validation path
spelling, and `scene_policy.dart` stops owning late import-range path
construction.

#### Change

- Add `lib/src/model/scene_validation_path_surface.dart`.
- Thread explicit surface selection through
  `sceneBuildFromJsonMap(...)`, `sceneBuildFromSnapshot(...)`,
  `sceneCanonicalizeAndValidateSnapshot(...)`, `sceneImportFromDraft(...)`,
  `ScenePolicy.validateImportDraft(...)`, and
  `ScenePolicy.validateImportSnapshot(...)`.
- Move late import-draft node/common/type-specific range validation out of
  `scene_policy.dart` into the validation owner family under
  `scene_value_validation*.dart`, including the image/text/rect/path owners in
  addition to line/stroke and shared node-base helpers.
- Add `test/model/scene_validation_path_surface_contract_test.dart` to lock the
  new shared seam for alias-bearing and identity-mapped fields.
- Extend `tool/src/guardrails/rules/model/model_architecture_rules.dart` and
  `test/tool/guardrails/guardrails_model_architecture_tool_test.dart` so
  `scene_policy.dart` cannot reintroduce direct import-range diagnostic
  ownership and non-model code cannot import
  `scene_validation_path_surface.dart` directly.

#### Behavioral Verification

- `flutter test test/public_api/scene_builder_test.dart`
- `flutter test test/serialization/scene_codec_validation_test.dart`
- `flutter test test/public_api/validated_boundary_value_test.dart`
- `flutter test test/model/scene_builder_test.dart`
- `flutter test test/model/scene_value_validation_primitives_test.dart`
- `flutter test test/model/scene_validation_path_surface_contract_test.dart`

#### Structural Verification

- `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_model_architecture_tool_test.dart`
  — must prove that `scene_policy.dart` no longer owns direct import-range
  diagnostics and that `scene_validation_path_surface.dart` stays model-internal.
- `dart run tool/check_guardrails.dart`
  — must stay green once the new rule and consumer migration are complete.

#### Positive Scenarios

- Alias-bearing JSON line/stroke range failures use `localA`, `localB`, and
  `localPoints`.
- Typed snapshot surfaces keep canonical `start`, `end`, and `points`.
- Identity-mapped fields continue to use their unchanged names through the same
  seam.

#### Negative Scenarios

- No provenance/source-path fields are added to canonical draft or backing
  types.
- Decode-owner finite/type/max-points logic does not move.
- `scene_policy.dart` remains an orchestration owner rather than a second
  validation owner.

#### Closure Evidence

- All Slice 1 reproducers turn green, the dedicated path-surface contract test
  turns green, and the new guardrail fails on both policy-owned and direct
  `scene_validation_path_surface.dart` import regression fixtures.

### Slice 3. [x] Register the import diagnostic surface contract and publish it

#### Slice Contract

The repository records the new public diagnostic-path contract and keeps the
owner boundary mechanically visible after implementation.

#### Change

- Add `INV-SER-IMPORT-DIAGNOSTIC-SURFACE` to `tool/invariant_registry.dart`.
- Update `API_GUIDE.md` for the public path-aware diagnostic contract on import
  entrypoints.
- Update `ARCHITECTURE.md` to record that import diagnostic spelling is selected
  at the boundary and owned by the model validation seam, not by policy.
- Update `README.md` and `CHANGELOG.md` to keep public behavior documentation
  release-ready.
- Update `PLAN.md` and `plan/step_7_import_boundary_diagnostic_surface.md`
  checkboxes when the step is completed.

#### Behavioral Verification

- `flutter test test/public_api/scene_builder_test.dart`
- `flutter test test/serialization/scene_codec_validation_test.dart`
- `flutter test test/public_api/validated_boundary_value_test.dart`
- `flutter test test/model/scene_builder_test.dart`

#### Structural Verification

- `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_model_architecture_tool_test.dart`
- `dart run tool/check_guardrails.dart`

#### Positive Scenarios

- Public documentation states that entrypoints compare diagnostics by `code`,
  `path`, and `details`.
- Architecture documentation records the validation-surface owner explicitly.
- The new invariant points to executable proof surfaces that lock the contract.

#### Negative Scenarios

- Documentation updates do not broaden the supported public API or rename
  existing fields.
- The invariant does not rely on prose-only evidence; it points to executable
  proof surfaces.

#### Closure Evidence

- The invariant, guardrails, and release-ready docs all describe the same
  boundary contract, and the plan step can be marked complete in the same
  change that lands the implementation.

## 11. Final Verification

- `flutter test test/public_api/scene_builder_test.dart`
- `flutter test test/public_api/validated_boundary_value_test.dart`
- `flutter test test/serialization/scene_codec_validation_test.dart`
- `flutter test test/model/scene_builder_test.dart`
- `flutter test test/model/scene_value_validation_primitives_test.dart`
- `flutter test test/model/scene_validation_path_surface_contract_test.dart`
- `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_model_architecture_tool_test.dart`
- `dart run tool/check_guardrails.dart`
- `dcm calculate-metrics lib/src/model/scene_validation_path_surface.dart`
- `dcm calculate-metrics lib/src/model/scene_policy.dart lib/src/model/scene_value_validation_scene.dart`
- `dart run tool/run_verification_preset.dart run --preset=required_code_change --changed-paths-file=-`

## 12. Acceptance Criteria

- Public JSON import/build entrypoints report alias-bearing line/stroke
  out-of-range diagnostics through `localA`, `localB`, and `localPoints`.
- Typed snapshot import surfaces keep canonical `start`, `end`, and `points`
  for the same invariants.
- `SceneImportDraft` and snapshot backing types remain provenance-free
  canonical carriers.
- `scene_policy.dart` no longer owns late import-range path construction, and
  the model-architecture guardrail makes that drift visible.
- `INV-SER-IMPORT-DIAGNOSTIC-SURFACE` and the release-ready docs are updated in
  the same implementation change.
- All targeted tests, guardrails, metrics, and the required verification preset
  are green.
