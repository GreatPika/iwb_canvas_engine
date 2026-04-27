# Change Contract

## 1. Change Mandate

Close `KI-2` by making validated snapshot fast-path public-object exposure
owner-correct: raw snapshot backing may remain a model-facing carrier, but no
generic validated fast-path may expose `SceneSnapshot` or `NodeSnapshot` objects
from raw backing without a model-owned value-validation proof.

## 2. Change Boundary

### Included in the Change

- retire generic raw-backing-to-public-snapshot materialization from the
  cross-layer `snapshot_fast_path.dart` bridge surface
- keep raw snapshot backing as an explicit internal carrier for model import,
  decode, validation, and runtime mapping paths
- materialize public snapshot objects from validated model-owned paths through
  typed validated node helpers and exact public aggregate constructors, not
  through generic raw backing materializers
- preserve `ScenePolicy.validateImportDraft(...)` as the only owner that mints
  `ValidatedSceneImportDraft`
- update the route expectation config plus the validated-materialization and
  bridge-surface audits so they distinguish explicit carrier flow from
  prohibited public-object materialization
- add separate failing reproducer proof for malformed node backing exposure and
  malformed scene backing exposure, plus guard proof for validated carrier and
  typed helper paths
- update `KNOWN_ISSUES.md`, `ARCHITECTURE.md`, architecture atlas family docs,
  guardrails, invariant references, and this plan step after the implementation
  proves `KI-2` is closed

### Not Included in the Change

- no public package API expansion, rename, or schema-version change
- no new unsafe raw snapshot materialization bridge for non-contract code
- no migration of full scene-value validation into the `contract` layer
- no duplicate copy of model/core value-range policy inside contract helper
  files
- no rewrite of import/build diagnostics beyond preserving the existing
  snapshot path surface
- no implementation for other active known issues

## 3. Surrounding Code Review

### Inspected Artifacts

- `KNOWN_ISSUES.md` - records `KI-2` as a confirmed `P2` defect where
  `nodeSnapshotFromValidatedBacking` and `sceneSnapshotFromValidatedBacking`
  can expose public snapshot objects from raw backing without full value
  validation.
- `docs/ARCHITECTURE_ATLAS.md` - identifies the atlas as the architecture
  navigation entrypoint and routes active confirmed defects to
  `KNOWN_ISSUES.md`.
- `docs/architecture/families/contract_document_model_and_validated_fast_paths.md`
  - marks validated fast-path materialization as a known issue and states that
  validated fast paths must not bypass full value validation unless the
  precondition is explicit and mechanically enforced.
- `docs/architecture/families/import_build_materialization.md` - marks the
  shared route audit failure as a known issue while keeping model import draft
  validation as the intended owner of import value validation.
- `ARCHITECTURE.md` - defines `contract` as the public boundary owner, `model`
  as the import/build canonicalization and validated import proof owner, and
  `snapshot_fast_path.dart` as an exceptional contract-internal bridge surface.
- `plan/step_8_validated_import_materialization_boundary.md` - established
  `ValidatedSceneImportDraft` and `ScenePolicy.validateImportDraft(...)` as the
  model-owned proof seam before runtime materialization.
- `plan/step_9_boundary_admission_canonicalization_and_unsafe_materialization_split.md`
  - established the intended safe-versus-unsafe materialization split and
  named `snapshot_fast_path.dart` as the only snapshot bridge surface, but
  left `KI-2` as an unresolved follow-up.
- `lib/src/contract/internal/snapshot_fast_path.dart` - currently exports raw
  backing types, raw backing builders, backing resolvers, typed validated
  helpers, and the generic `*FromValidatedBacking` materializers under one
  bridge surface.
- `lib/src/contract/internal/snapshot_materialization.dart` - currently routes
  `nodeSnapshotFromValidatedBacking(...)` directly to
  `materializeNodeSnapshotForInternalUse(...)`; `sceneSnapshotFromValidatedBacking(...)`
  validates structure and metadata but not the full model-owned scene value
  contract.
- `lib/src/contract/internal/unsafe_snapshot_materialization.dart` - already
  owns explicit unsafe raw snapshot materializers for contract-owned and
  test-owned negative scenarios.
- `lib/src/model/scene_policy.dart` - owns
  `ValidatedSceneImportDraft`, raw import validation, and the current
  `sceneSnapshotFromValidatedImportDraft(...)` projection from validated draft
  backing to public snapshot.
- `lib/src/model/scene_value_validation_scene.dart` - owns full import draft
  value validation, including snapshot path-surface propagation over raw
  `SceneSnapshotBacking` and `NodeSnapshotBacking`.
- `lib/src/model/scene_value_validation_node.dart` and
  `lib/src/model/scene_value_validation_node_*.dart` - already validate
  `NodeSnapshotBacking` directly for common fields, family fields, transform
  ranges, hit padding, text derived bounds, stroke point limits, and thickness
  limits.
- `lib/src/model/scene_node_boundary_mapping.dart` and
  `lib/src/model/scene_node_boundary_mapping_*.dart` - provide the existing
  typed family mapping between backing/schema fields, runtime nodes, specs, and
  snapshots without needing generic public wrapper materialization.
- `lib/src/model/scene_snapshot_from_scene.dart` - exports runtime `Scene`
  values to `SceneSnapshotBacking` and currently finishes through
  `sceneSnapshotFromValidatedBacking(...)`.
- `tool/audit/route_expectations_boundary_audit.json` - currently expects the
  generic validated snapshot materializers to reach model-level validators,
  which is an ownership mismatch because `contract` must not depend on
  `model`.
- `tool/audit_route_expectations.dart` - reads
  `tool/audit/route_expectations_boundary_audit.json`; this change updates the
  route expectation config only and must not change route-audit tool behavior.
- `tool/audit_validated_materialization_paths.dart` - already detects the
  direct raw materialization in `nodeSnapshotFromValidatedBacking(...)`.
- `tool/audit_bridge_surfaces.dart` - currently flags raw backing and
  materialization-from-backing exports together; this change must refine that
  audit so explicit carrier exports are not confused with public-object
  materialization.
- `tool/src/import_boundaries/import_boundary_policy.dart` - registers
  `snapshot_fast_path.dart` as a bridge surface for model and serialization.
- `tool/src/guardrails/rules/model/model_architecture_rules.dart` - already
  forbids validated import and draft validation paths from reaching raw
  snapshot materializers, and must be extended to guard
  `scene_snapshot_projection.dart` plus model export paths against generic or
  unsafe raw snapshot materializer calls.
- `tool/src/guardrails/rules/contract/contract_architecture_rules.dart` -
  owns the allowed non-contract imports of contract-internal bridge surfaces.
- `test/contract/validated_fast_path_contract_test.dart` - already covers
  validated snapshot helpers, explicit unsafe materialization, carrier-backed
  admission, and some malformed backing cases.
- `test/tool/audit/audit_validated_materialization_paths_tool_test.dart` -
  locks detection of direct public validated functions that materialize raw
  backing without a validator or validated-helper hop.
- `test/tool/audit/audit_bridge_surfaces_tool_test.dart` - currently locks the
  broad raw-backing export finding and must be updated to the refined carrier
  versus materialization policy.
- `test/tool/guardrails/guardrails_model_architecture_tool_test.dart` - already
  proves model validated import paths must not use raw snapshot materializers.
- `test/tool/import_boundaries/import_boundaries_layer_dag_tool_test.dart` and
  `test/tool/import_boundaries/import_boundaries_controller_structure_tool_test.dart`
  - lock `snapshot_fast_path.dart` as a legal bridge only for configured friend
  layers.

### Current Entry Path

- current failing node path:
  `snapshot_fast_path.dart -> snapshot_materialization.dart ->
  nodeSnapshotFromValidatedBacking(...) ->
  materializeNodeSnapshotForInternalUse(...) -> NodeSnapshot`
- current failing scene path:
  `snapshot_fast_path.dart -> snapshot_materialization.dart ->
  sceneSnapshotFromValidatedBacking(...) ->
  materializeSceneSnapshotForInternalUse(...) -> lazy NodeSnapshot materialization`
- validated import snapshot path:
  `ScenePolicy.validateImportDraft(...) -> ValidatedSceneImportDraft ->
  sceneSnapshotFromValidatedImportDraft(...) ->
  sceneSnapshotFromValidatedBacking(...)`
- runtime export path:
  `sceneSnapshotFromScene(...) -> SceneSnapshotBacking ->
  sceneSnapshotFromValidatedBacking(...)`
- existing validation owner path:
  `ScenePolicy.validateImportDraft(...) ->
  sceneValidateSceneSnapshotBackingStructure(...) ->
  sceneValidateImportDraftValues(...)`

### Current Owner

- `contract` owns public boundary objects, backing carriers, boundary backing
  resolvers, typed validated snapshot helpers, and explicit unsafe internal
  snapshot materializers.
- `model` owns import/build canonicalization, raw backing value validation,
  validated import proof minting, and runtime/snapshot mapping.
- `tool/src/import_boundaries/import_boundary_policy.dart`,
  `tool/audit_validated_materialization_paths.dart`,
  `tool/audit_bridge_surfaces.dart`, and
  `tool/audit_route_expectations.dart` own mechanical detection of this defect
  family.

### Adjacent Abstractions

- `lib/src/contract/internal/node_boundary_schema.dart` - contract-owned typed
  schema validation and from-validated helpers used by model mapping code.
- `lib/src/contract/internal/snapshot_backing.dart` - raw immutable carrier
  definitions and validated backing builders.
- `lib/src/contract/internal/snapshot_boundary_impl.dart` - backing carrier
  resolvers and raw internal materialization classes.
- `lib/src/model/scene_import_draft.dart` - raw import carrier over
  `SceneSnapshotBacking`.
- `lib/src/model/scene_from_import_draft.dart` - validated draft to runtime
  scene materialization.
- `lib/src/model/scene_snapshot_from_scene.dart` - runtime scene to public
  snapshot projection.
- `lib/src/model/scene_node_boundary_mapping_common.dart` - shared typed
  family mapping from schema/backing/common fields.

### Existing Tests

- `test/contract/validated_fast_path_contract_test.dart` - proves the current
  validated helper surface and explicit unsafe materializer behavior.
- `test/contract/validated_internal_helpers_test.dart` - proves explicit unsafe
  raw metadata materializers preserve malformed values for negative tests.
- `test/model/scene_builder_test.dart` - proves supported snapshot import uses
  `ScenePolicy.validateImportDraft(...)` and keeps path-aware diagnostics.
- `test/model/document_model_test.dart` - proves transaction-facing model
  snapshot import routes through model-owned validation.
- `test/tool/audit/audit_validated_materialization_paths_tool_test.dart` -
  proves direct raw materialization in validated functions is detected.
- `test/tool/audit/audit_bridge_surfaces_tool_test.dart` - proves bridge
  surface classification.
- `test/tool/audit/audit_route_expectations_tool_test.dart` - exists for
  route-audit tool behavior, but this change intentionally does not include it
  because only `tool/audit/route_expectations_boundary_audit.json` is allowed
  to change for route expectations.
- `test/tool/guardrails/guardrails_model_architecture_tool_test.dart` - proves
  raw snapshot materializers cannot re-enter validated import and draft
  validation paths.
- `test/tool/import_boundaries/import_boundaries_layer_dag_tool_test.dart` and
  `test/tool/import_boundaries/import_boundaries_controller_structure_tool_test.dart`
  - prove bridge-surface legality and friend-layer restrictions.

### Analogous Implementation Path

- `lib/src/model/scene_from_import_draft.dart` - materializes runtime `Scene`
  only from `ValidatedSceneImportDraft`, preserving raw backing as input data
  while keeping materialization behind a model-owned proof seam.
- `lib/src/contract/internal/unsafe_snapshot_materialization.dart` - already
  separates explicit unsafe raw public-object materialization from validated
  helper vocabulary.
- `lib/src/model/scene_node_boundary_mapping_*.dart` - already map
  backing/schema fields by concrete node family without generic raw public
  wrapper materialization.

### Governing Repository Rules

- `AGENTS.md` - fixes must land at the owning seam, avoid duplicated sources of
  truth, and prefer mechanically enforced repository-local rules.
- `ARCHITECTURE.md` - `model` owns import/build canonicalization and
  `ValidatedSceneImportDraft` proof minting; `contract` must not depend upward
  on model.
- `docs/architecture/families/contract_document_model_and_validated_fast_paths.md`
  - validated fast paths must not bypass full value validation unless the
  precondition is explicit and mechanically enforced.
- `docs/architecture/families/import_build_materialization.md` - external
  input is validated at the import/build boundary and import diagnostics remain
  path-aware.
- `tool/invariant_registry.dart` - existing relevant invariants are
  `INV-ENG-VALIDATED-IMPORT-MATERIALIZATION-BOUNDARY`,
  `INV-ENG-CONTRACT-ARCHITECTURE-BOUNDARY`, and
  `INV-ENG-BOUNDARY-HERMETIC-CONCRETE-TYPES`.

### Rejected Misleading Local Patterns

- Adding `sceneValidateImportDraftValues(...)` calls inside `contract` - wrong
  dependency direction because full scene value validation is model-owned and
  depends on core/model validation policy.
- Copying model backing validators into `contract` - creates a second source
  of truth for range limits, text derived bounds, transform ranges, and
  diagnostic path behavior.
- Keeping `nodeSnapshotFromValidatedBacking(...)` as a bridge-visible generic
  helper with a stronger precondition comment - leaves the defect dependent on
  caller discipline rather than a mechanical seam.
- Moving non-contract code to `unsafe_snapshot_materialization.dart` - widens
  the unsafe seam and violates the existing safe-versus-unsafe split.
- Removing raw backing carriers from model access in the same change - expands
  `KI-2` into a broad import/decode/runtime mapping redesign that is not
  required to close public-object exposure.

## 4. Architecture

### 4A. Locked Architectural Form

#### Problem Ownership Level

- Cross-seam boundary admission between contract-owned snapshot carriers and
  model-owned validated import/export proof.

#### Selected Architectural Form

- Keep `SceneSnapshotBacking` and `NodeSnapshotBacking` as explicit raw
  immutable carriers available through the existing snapshot bridge for model
  and serialization friend layers.
- Remove generic `SceneSnapshotBacking -> SceneSnapshot` and
  `NodeSnapshotBacking -> NodeSnapshot` materialization from the
  bridge-visible validated fast-path surface.
- Delete `nodeSnapshotFromValidatedBacking(...)` and
  `sceneSnapshotFromValidatedBacking(...)` from
  `snapshot_materialization.dart`; do not replace them with another generic
  backing-to-public materializer.
- Public snapshot projection from model-owned validated paths must be performed
  through `lib/src/model/scene_snapshot_projection.dart`, which consumes either
  a `ValidatedSceneImportDraft` or validated runtime/export fields and builds
  exact public aggregate snapshot objects through exact public constructors and
  exact public node snapshots through typed validated node helpers.
- Explicit unsafe raw materializers remain only in
  `unsafe_snapshot_materialization.dart` and stay unavailable to non-contract
  production code.
- The audit model changes from "raw backing export is always a violation" to
  "raw backing carrier export is allowed only when generic public-object
  materialization from backing is absent and validated callers are mechanically
  forced through owner-correct projection."

#### Owning Layer or Module

- `contract` owns snapshot carriers, typed validated snapshot helpers, backing
  resolvers, explicit unsafe raw snapshot materializers, and the narrowed
  bridge surface.
- `model` owns validated raw backing value checks and public snapshot
  projection from validated import/runtime paths.
- `tool/audit_*`, `tool/check_guardrails.dart`, and
  `tool/check_import_boundaries.dart` own mechanical proof for the seam.

#### Dependency Direction

- raw external data -> model decode/import draft carrier ->
  `ScenePolicy.validateImportDraft(...)` -> `ValidatedSceneImportDraft` ->
  model-owned runtime or public snapshot projection
- runtime `Scene` -> model-owned snapshot backing export -> typed validated
  public snapshot projection
- model/serialization -> `snapshot_fast_path.dart` for explicit carriers and
  typed validated helpers only
- contract/test negative scenarios -> `unsafe_snapshot_materialization.dart`
  for explicit unsafe public-object materialization
- no `contract -> model` dependency is allowed

#### State and Data Ownership

- Raw backing objects are data carriers, not proof objects.
- `ValidatedSceneImportDraft` is the only proof that raw import backing has
  crossed model-owned structure and value validation.
- Public `SceneSnapshot` and `NodeSnapshot` objects exposed from model-owned
  import/export paths must be exact validated public boundary objects or
  carrier-backed objects built only after the owning proof seam.
- Unsafe materialized public snapshot wrappers are test/internal negative
  fixtures and never become model-facing proof.

#### Entry and Exit Boundaries

- Entry boundary for external/import data:
  `ScenePolicy.validateImportDraft(...)`.
- Entry boundary for runtime export:
  `sceneSnapshotFromScene(...)` and `sceneNodeSnapshotFromScene(...)`.
- Exit boundary for public snapshot exposure:
  model-owned typed projection to `SceneSnapshot` or `NodeSnapshot`.
- Exit boundary for explicit negative tests:
  `unsafe_snapshot_materialization.dart`.

#### Permitted Extension Seam

- New node families may extend typed backing-to-public projection only by adding
  family-specific mapping beside the existing `scene_node_boundary_mapping_*`
  family owners and typed validated snapshot helper coverage.
- Audit allowlists may describe carrier exports only by explicit symbol shape;
  they must not allow generic `*FromValidatedBacking` public-object
  materializers back into a bridge surface.

#### Rejected Alternatives

- Move full scene value validation into `contract` - rejected because it
  duplicates model/core policy and violates the current layer ownership.
- Add a new unsafe bridge surface for raw materializers - rejected because it
  expands friend-layer access to the seam that should stay contract/test-only.
- Remove all raw backing carrier access from model - rejected as a broader
  import/decode redesign outside `KI-2`.
- Treat existing failing route expectations as the target shape - rejected
  because they encode an impossible `contract -> model` validation route rather
  than the owner-correct seam.

#### Why This Level Is Correct

- The defect is not raw backing as a carrier; the defect is bridge-visible
  generic public-object materialization from raw backing.
- Model already owns full value validation for backing graphs, so repairing the
  public-object projection seam avoids duplicated validators and preserves the
  architecture DAG.
- Contract already has explicit unsafe materializers, so the repository has a
  valid precedent for keeping raw public-wrapper construction available only
  where it is intentionally unsafe.

### 4B. Architecture Decision Gate

Not used. The architectural form is locked in 4A.

## 5. Locked Decisions

1. `snapshot_fast_path.dart` remains the single snapshot bridge surface, but
   its supported friend-layer role is carrier access plus typed validated
   helpers, not generic public-object materialization from backing.
2. Existing raw backing carriers stay available to model and serialization
   through the bridge until a separate future contract explicitly replaces the
   import/decode carrier model.
3. Generic `nodeSnapshotFromValidatedBacking(...)` and
   `sceneSnapshotFromValidatedBacking(...)` are deleted from
   `snapshot_materialization.dart`; any remaining raw public-object
   materialization uses the existing explicit `unsafeMaterialize*` helpers in
   `unsafe_snapshot_materialization.dart`.
4. `lib/src/model/scene_snapshot_projection.dart` owns public snapshot
   projection from validated backing carriers in import/export paths.
5. `tool/audit/route_expectations_boundary_audit.json` must be updated to
   follow owner-correct model projection and bridge-surface rules instead of
   requiring contract helpers to reach model validators; route-audit tool
   behavior is unchanged in this contract.

## 6. Result Requirements

1. `KI-2` is removed only after the route, validated-materialization, and
   bridge-surface audits no longer report the defect.
2. Malformed raw backing can still be represented as raw carrier data for
   validation and negative tests, but it cannot be exposed through a
   bridge-visible validated snapshot materialization helper.
3. Validated import snapshot projection and runtime scene export continue to
   return public snapshot objects with the same supported field values and
   diagnostic path behavior.
4. Explicit unsafe raw materialization remains available for contract-owned and
   test-owned negative scenarios only.
5. Architecture docs and atlas family statuses no longer classify validated
   snapshot fast-path materialization as an active known issue.

## 7. Execution Order and Gates

### Required Order

- First add or identify the failing reproducer: current audit failures plus a
  contract/model regression that demonstrates malformed raw backing exposure
  through the generic helper.
- Add neighboring guard tests for validated carrier import, runtime export, and
  explicit unsafe negative materialization before changing production code.
- Introduce the model-owned typed projection seam and migrate model callers off
  generic backing materialization.
- Narrow `snapshot_fast_path.dart` only after all model production callers no
  longer require the generic materializers.
- Update validated-materialization and bridge-surface audits, model/contract
  guardrails, import-boundary tests, and the route expectation config after the
  new seam is in place.
- Remove `KI-2` and change atlas family statuses only after all mechanical
  detections are green.

### Successor Seam and Retirement Gates

- successor seam: `lib/src/model/scene_snapshot_projection.dart` projects from
  `ValidatedSceneImportDraft` and runtime-export backing to exact public
  snapshots
- retirement gate for generic materializers: no non-contract production call
  sites remain for `nodeSnapshotFromValidatedBacking(...)` or
  `sceneSnapshotFromValidatedBacking(...)`
- bridge gate: `snapshot_fast_path.dart` exports no generic
  `*FromValidatedBacking` public-object materializer
- validated-materialization audit gate: no public top-level
  `*FromValidatedBacking` function directly reaches raw snapshot
  materialization without a validator or typed validated helper hop
- materializer retirement gate: `snapshot_materialization.dart` contains only
  typed validated snapshot helpers and no generic backing-to-public snapshot
  materializer
- unsafe gate: non-contract production code imports no
  `unsafe_snapshot_materialization.dart` symbols
- documentation gate: `KNOWN_ISSUES.md` removes `KI-2` only in the same change
  that adds regression proof and makes all listed detections pass

### Deferred Broad Verification

- `dart run tool/run_repository_audits.dart` is a final gate because it may
  still include other active known issues during slice work.
- `dart run tool/run_verification_preset.dart run --preset=required_code_change`
  is reserved for the final implementation change with the complete changed
  path list.

## 8. File Map

### Implementation Files

- `lib/src/contract/internal/snapshot_fast_path.dart`
- `lib/src/contract/internal/snapshot_materialization.dart`
- `lib/src/contract/internal/unsafe_snapshot_materialization.dart`
- `lib/src/model/scene_policy.dart`
- `lib/src/model/scene_snapshot_projection.dart`
- `lib/src/model/scene_snapshot_from_scene.dart`
- `lib/src/model/scene_node_boundary_mapping.dart`
- `lib/src/model/scene_node_boundary_mapping_common.dart`
- `lib/src/model/scene_node_boundary_mapping_image.dart`
- `lib/src/model/scene_node_boundary_mapping_text.dart`
- `lib/src/model/scene_node_boundary_mapping_stroke.dart`
- `lib/src/model/scene_node_boundary_mapping_line.dart`
- `lib/src/model/scene_node_boundary_mapping_rect.dart`
- `lib/src/model/scene_node_boundary_mapping_path.dart`

### Test Files

- `test/contract/validated_fast_path_contract_test.dart`
- `test/contract/validated_internal_helpers_test.dart`
- `test/model/scene_builder_test.dart`
- `test/model/document_model_test.dart`
- `test/tool/audit/audit_validated_materialization_paths_tool_test.dart`
- `test/tool/audit/audit_bridge_surfaces_tool_test.dart`
- `test/tool/guardrails/guardrails_model_architecture_tool_test.dart`
- `test/tool/guardrails/guardrails_contract_architecture_tool_test.dart`
- `test/tool/import_boundaries/import_boundaries_layer_dag_tool_test.dart`
- `test/tool/import_boundaries/import_boundaries_controller_structure_tool_test.dart`
- `test/contract/contract_layer_smoke_test.dart`

### Fixtures and Supporting Data

- malformed raw `SceneSnapshotBacking` and `NodeSnapshotBacking` fixtures in
  `test/contract/validated_fast_path_contract_test.dart`
- existing guardrail sandboxes under `test/tool/support/**`

### Registry, Inventory, and Workflow Files

- `KNOWN_ISSUES.md`
- `PLAN.md`
- `plan/step_31_validated_snapshot_fast_path_admission.md`
- `ARCHITECTURE.md`
- `docs/architecture/families/contract_document_model_and_validated_fast_paths.md`
- `docs/architecture/families/import_build_materialization.md`
- `tool/invariant_registry.dart`
- `tool/audit/route_expectations_boundary_audit.json`
- `tool/src/import_boundaries/import_boundary_policy.dart`
- `tool/src/guardrails/rules/contract/contract_architecture_rules.dart`
- `tool/src/guardrails/rules/model/model_architecture_rules.dart`

### Analysis Area

- `tool/audit_validated_materialization_paths.dart`
- `tool/audit_bridge_surfaces.dart`
- `tool/audit_route_expectations.dart`
- `tool/run_repository_audits.dart`

## 9. Implementation Rules

### Protected Invariants

- `INV-ENG-VALIDATED-IMPORT-MATERIALIZATION-BOUNDARY`
- `INV-ENG-CONTRACT-ARCHITECTURE-BOUNDARY`
- `INV-ENG-BOUNDARY-HERMETIC-CONCRETE-TYPES`

### Required Proof

- behavioral proof: malformed `NodeSnapshotBacking` and malformed
  `SceneSnapshotBacking` cannot be exposed through the validated snapshot
  bridge, while supported validated import/export flows keep their public
  snapshot behavior
- structural proof: audits and guardrails reject generic backing-to-public
  materialization from the snapshot bridge, reject generic or unsafe raw
  materializer calls from `scene_snapshot_projection.dart` and model export
  paths, and reject unsafe raw materializer imports from non-contract
  production code
- for this bug fix: establish two failing reproducers before the owner-side
  fixes: one node-level reproducer in Slice 1 and one scene-level reproducer in
  Slice 2, plus one to three guard tests for neighboring validated carrier,
  typed helper, and unsafe materialization paths

### Allowed Change Surface

- `lib/src/model/scene_snapshot_projection.dart` is the model-owned successor
  seam for public snapshot projection from validated backing carriers
- model-owned typed projection helpers may be added only inside
  `lib/src/model/scene_snapshot_projection.dart` or existing
  `scene_node_boundary_mapping_*` family owners
- audit logic may be refined to allow explicit carrier exports while forbidding
  generic public-object materialization exports
- contract smoke and guardrail tests may be updated to reflect the narrowed
  snapshot bridge surface

### Forbidden Moves

- do not make `contract` import `model` or `core`
- do not duplicate model backing value validators inside contract
- do not expose `unsafe_snapshot_materialization.dart` to non-contract
  production code
- do not call `unsafeMaterialize*`, `nodeSnapshotFromValidatedBacking(...)`, or
  `sceneSnapshotFromValidatedBacking(...)` from
  `scene_snapshot_projection.dart`, `scene_snapshot_from_scene.dart`, or
  validated import/export model paths
- do not remove raw backing carrier access from model import/decode paths in
  this change
- do not remove `KI-2` before every detection listed in `KNOWN_ISSUES.md`
  passes

### Optional: Recognition Forms That Must Be Supported

- Direct export or import of `nodeSnapshotFromValidatedBacking` or
  `sceneSnapshotFromValidatedBacking` from `snapshot_fast_path.dart` must be
  recognized as a bridge violation.
- Direct calls from guarded validated import paths to any raw snapshot
  materializer must remain recognized as a model architecture violation.
- Direct calls from `scene_snapshot_projection.dart` or
  `scene_snapshot_from_scene.dart` to generic `*FromValidatedBacking`
  materializers or unsafe raw snapshot materializers must be recognized as a
  model architecture violation.
- Explicit raw backing type and backing builder exports are recognized as
  carrier exports only when no generic `*FromValidatedBacking` materializer is
  exported from the same bridge surface.

### Optional: Allowed Forms That Are Not Violations

- Model and serialization may continue to import `snapshot_fast_path.dart` for
  raw backing carriers, backing resolvers, and typed validated helpers.
- Contract and tests may import `unsafe_snapshot_materialization.dart` for
  explicit negative scenarios.
- Model projection may reuse `scene_node_boundary_mapping_*` typed family
  extractors and typed validated snapshot helpers.

### Optional: Resolution Rules

- Route expectations should target model-owned validated projection and
  bridge-surface narrowing rather than requiring contract helpers to call
  model validators.
- Route expectation work is limited to
  `tool/audit/route_expectations_boundary_audit.json`. If implementation
  requires changing `tool/audit_route_expectations.dart`, stop and amend this
  contract to add `test/tool/audit/audit_route_expectations_tool_test.dart` to
  the file map and slice-local verification.
- Bridge-surface audit output should name materialization leaks separately from
  carrier exports so future findings point to the actual unsafe seam.

## 10. Vertical Slices

### Slice 1. [x] Node Snapshot Projection

#### Slice Contract

Close node-level public snapshot exposure from raw backing behind the
model-owned projection seam.

#### Change

- First add a failing reproducer showing malformed `NodeSnapshotBacking` can be
  exposed as a public `NodeSnapshot` through the current generic helper.
- Extend `tool/src/guardrails/rules/model/model_architecture_rules.dart` and
  `test/tool/guardrails/guardrails_model_architecture_tool_test.dart` so
  `scene_snapshot_projection.dart` and model export paths cannot call generic
  `*FromValidatedBacking` materializers or `unsafeMaterialize*` snapshot
  materializers.
- Add `lib/src/model/scene_snapshot_projection.dart` with node-level typed
  projection from validated backing carriers to exact public node snapshots.
- Migrate node-level model production callers away from
  `nodeSnapshotFromValidatedBacking(...)`.
- Add guard coverage that explicit unsafe node materialization still exists for
  negative tests.

#### Behavioral Verification

- `flutter test test/contract/validated_fast_path_contract_test.dart`
- `flutter test test/model/document_model_test.dart`

#### Structural Verification

- `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_model_architecture_tool_test.dart`
- `dart run tool/check_guardrails.dart`

#### Fixtures Used

- malformed `NodeSnapshotBacking` common and family-field fixtures

#### Positive Scenarios

- explicit unsafe materializers still preserve malformed backing for negative
  tests
- model node snapshot export returns supported public node fields

#### Negative Scenarios

- model node-level projection does not call generic or unsafe raw snapshot
  materializers
- model architecture guardrails reject a sandbox
  `scene_snapshot_projection.dart` that calls generic or unsafe raw snapshot
  materializers

#### Closure Evidence

- The node-level reproducer fails before the owner-side fix and passes through
  the model-owned typed projection seam, and the new model guardrail negative
  fixture fails before any future regression can reintroduce the unsafe call.

### Slice 2. [x] Scene Snapshot Projection

#### Slice Contract

Close scene-level public snapshot exposure from validated import/runtime paths
behind the model-owned projection seam.

#### Change

- First add a failing reproducer showing malformed `SceneSnapshotBacking` can be
  exposed as a public `SceneSnapshot` through the current generic helper.
- Extend `lib/src/model/scene_snapshot_projection.dart` with scene-level
  projection from `ValidatedSceneImportDraft` and runtime-export backing to
  exact public aggregate snapshots.
- Migrate `scene_policy.dart` and `scene_snapshot_from_scene.dart` away from
  `sceneSnapshotFromValidatedBacking(...)`.
- Preserve supported public snapshot field values and import diagnostic paths.

#### Behavioral Verification

- `flutter test test/model/scene_builder_test.dart`
- `flutter test test/model/document_model_test.dart`
- `flutter test test/contract/validated_fast_path_contract_test.dart`

#### Structural Verification

- `dart run tool/check_guardrails.dart`
- `dart run tool/audit_route_expectations.dart`

#### Fixtures Used

- valid import draft backing fixture
- runtime scene export fixture
- malformed `SceneSnapshotBacking` graph fixture

#### Positive Scenarios

- validated import snapshot projection returns the same supported public
  snapshot graph
- runtime scene export returns public snapshots without generic backing
  materialization

#### Negative Scenarios

- guarded model validated paths do not call unsafe or generic raw snapshot
  materializers
- scene-level projection rejects return to generic backing-to-public
  materialization through the model guardrail added in Slice 1

#### Closure Evidence

- The scene-level reproducer fails before the owner-side fix and passes through
  `scene_snapshot_projection.dart`; model production callers no longer require
  bridge-visible generic backing-to-public scene materialization.

### Slice 3. [x] Narrow Snapshot Bridge And Audits

#### Slice Contract

Remove generic public-object materialization from the snapshot bridge and make
the structural detectors enforce the narrowed seam.

#### Change

- Remove `nodeSnapshotFromValidatedBacking` and
  `sceneSnapshotFromValidatedBacking` from `snapshot_fast_path.dart`.
- Delete `nodeSnapshotFromValidatedBacking(...)` and
  `sceneSnapshotFromValidatedBacking(...)` from
  `snapshot_materialization.dart`; do not add replacement generic
  backing-to-public materializers.
- Keep raw public-object construction only behind the existing
  `unsafeMaterialize*` helpers in `unsafe_snapshot_materialization.dart`.
- Refine `audit_bridge_surfaces` and
  `audit_validated_materialization_paths`, and update
  `tool/audit/route_expectations_boundary_audit.json`, to enforce carrier-only
  bridge exports and owner-correct public snapshot projection.
- Update guardrail/import-boundary/smoke tests for the narrowed surface.

#### Behavioral Verification

- `flutter test test/contract/validated_fast_path_contract_test.dart`
- `flutter test test/contract/validated_internal_helpers_test.dart`
- `flutter test test/contract/contract_layer_smoke_test.dart`

#### Structural Verification

- `dart run tool/run_tool_tests.dart test/tool/audit/audit_validated_materialization_paths_tool_test.dart test/tool/audit/audit_bridge_surfaces_tool_test.dart test/tool/guardrails/guardrails_contract_architecture_tool_test.dart test/tool/guardrails/guardrails_model_architecture_tool_test.dart test/tool/import_boundaries/import_boundaries_layer_dag_tool_test.dart test/tool/import_boundaries/import_boundaries_controller_structure_tool_test.dart`
- `dart run tool/audit_validated_materialization_paths.dart`
- `dart run tool/audit_bridge_surfaces.dart`
- `dart run tool/audit_route_expectations.dart`

#### Fixtures Used

- audit sandbox fixtures for bridge surfaces
- guardrail sandbox fixtures for unsafe materializer imports

#### Positive Scenarios

- model and serialization can still import explicit carrier and typed validated
  helper symbols from the snapshot bridge
- contract/test code can still use explicit unsafe materializers

#### Negative Scenarios

- `snapshot_fast_path.dart` cannot export generic `*FromValidatedBacking`
  public-object materializers
- `snapshot_materialization.dart` cannot declare generic
  `*FromValidatedBacking` public-object materializers
- non-contract production code cannot import unsafe raw materializers

#### Closure Evidence

- All `KI-2` audit detections pass for the narrowed bridge.

### Slice 4. [x] Close Documentation And Known Issue

#### Slice Contract

Update repository sources of truth only after mechanical proof shows the defect
is closed.

#### Change

- Remove `KI-2` from `KNOWN_ISSUES.md`.
- Update `ARCHITECTURE.md` and the two architecture atlas family docs from
  known-issue status to the repaired target rule.
- Update `tool/invariant_registry.dart` only if proof paths or invariant
  markers changed.
- Mark this plan step complete in `PLAN.md` and this file.

#### Behavioral Verification

- `flutter test test/contract/validated_fast_path_contract_test.dart`
- `flutter test test/model/scene_builder_test.dart`

#### Structural Verification

- `dart run tool/run_repository_audits.dart`
- `dart run tool/check_guardrails.dart`
- `dart run tool/check_import_boundaries.dart`
- `dart run tool/check_invariant_coverage.dart`

#### Fixtures Used

- existing repository audit fixtures

#### Positive Scenarios

- atlas families no longer link `KI-2` as an active defect
- documentation describes carrier access separately from public-object
  materialization

#### Negative Scenarios

- no active `KI-2` entry remains after the regression proof is present

#### Closure Evidence

- `KNOWN_ISSUES.md` no longer contains `KI-2`, and every detection listed in
  the removed entry passes.

## 11. Final Verification

- `flutter test test/contract/validated_fast_path_contract_test.dart`
- `flutter test test/contract/validated_internal_helpers_test.dart`
- `flutter test test/model/scene_builder_test.dart`
- `flutter test test/model/document_model_test.dart`
- `dart run tool/run_tool_tests.dart test/tool/audit/audit_validated_materialization_paths_tool_test.dart test/tool/audit/audit_bridge_surfaces_tool_test.dart test/tool/guardrails/guardrails_contract_architecture_tool_test.dart test/tool/guardrails/guardrails_model_architecture_tool_test.dart test/tool/import_boundaries/import_boundaries_layer_dag_tool_test.dart test/tool/import_boundaries/import_boundaries_controller_structure_tool_test.dart`
- `dart run tool/run_repository_audits.dart`
- `dart run tool/check_guardrails.dart`
- `dart run tool/check_import_boundaries.dart`
- `dart run tool/check_invariant_coverage.dart`
- `dart run tool/run_verification_preset.dart run --preset=required_code_change --changed-paths-file=-`
  with the final changed repository-relative path list supplied on stdin

## 12. Acceptance Criteria

- `snapshot_fast_path.dart` exposes no generic validated backing-to-public
  snapshot materializer.
- Model validated import/export paths expose public snapshots only through the
  model-owned typed projection seam.
- Raw backing carrier access remains explicit and mechanically distinct from
  public-object materialization.
- Explicit unsafe snapshot materializers remain contract/test-only.
- `dart run tool/audit_route_expectations.dart`,
  `dart run tool/audit_validated_materialization_paths.dart`, and
  `dart run tool/audit_bridge_surfaces.dart` no longer report `KI-2`.
- `KNOWN_ISSUES.md` removes `KI-2` in the same implementation change that adds
  regression proof.
