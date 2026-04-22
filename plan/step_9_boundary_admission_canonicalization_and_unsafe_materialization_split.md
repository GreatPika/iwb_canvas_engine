# Change Contract

## 1. Change Mandate

Establish one contract-owned boundary admission and canonicalization seam, one
model-owned validated import proof seam, and one symmetric safe-versus-unsafe
materialization model across snapshot, node-spec, and node-patch families so
boundary correctness no longer depends on late helper failures, mixed internal
barrels, or caller discipline.

## 2. Change Boundary

### Included in the Change

- eager admission canonicalization or rejection for nested public boundary
  graphs built through `SceneSnapshot`, layer snapshots, `NodeSpec`,
  `NodePatch`, and `CommonNodePatch`
- symmetric separation between validated helpers and explicit unsafe raw
  materializers for snapshot, node-spec, and node-patch contract families
- owner-file split, not just barrel split, between validated helper owners and
  unsafe raw materialization owners for those three families
- single-owner minting of `ValidatedSceneImportDraft` plus removal of raw
  public snapshot materialization from model-owned validated import and
  draft-validation paths
- canonical tri-state nullable `PatchField` semantics across constructors,
  schema validation, backings, apply paths, tests, and API docs
- guardrail, invariant, import-boundary, and smoke-test updates needed to make
  the new seam model mechanically enforceable

### Not Included in the Change

- public package entrypoint redesign or widening of exported symbols
- repository-wide phase-2 interaction, store, or render refactors from
  `docs/adr/0002_post_target_optimization_scope.md`
- sealing or finalizing the public boundary type family as a breaking API move
- adding a new contract bridge surface or widening friend-layer access so
  non-contract code can import unsafe raw materialization helpers
- unrelated cleanup of render, controller, or interactive owners

## 3. Surrounding Code Review

### Inspected Artifacts

- `docs/adr/0001_target_engine_architecture.md` — requires validation and
  canonicalization before a supported public result exists and prefers slice
  migration over opportunistic local fixes
- `docs/adr/0002_post_target_optimization_scope.md` — rules out opportunistic
  public API thinning as the default next wave
- `ARCHITECTURE.md` — states that validated import proof must precede supported
  document materialization and that runtime import materialization must cross
  `ValidatedSceneImportDraft`
- `PLAN.md` — confirms Step 8 already established the validated import
  materialization boundary and leaves this broader seam cleanup as new work
- `lib/src/model/scene_import_draft.dart` — defines `SceneImportDraft`,
  `ValidatedSceneImportDraft`, and the current proof carrier seam
- `lib/src/model/scene_policy.dart` — owns raw import validation and currently
  mints `ValidatedSceneImportDraft`
- `lib/src/model/scene_from_import_draft.dart` — still materializes raw public
  `NodeSnapshot` wrappers from raw backing inside the validated import path
- `lib/src/model/scene_value_validation_scene.dart` — still materializes raw
  public `NodeSnapshot` wrappers to validate draft node values
- `lib/src/model/scene_snapshot_from_scene.dart` and
  `lib/src/model/scene_node_boundary_mapping.dart` — show the current
  runtime-to-boundary and boundary-to-runtime mapping seams and where generic
  `materializeNodeSnapshot(...)` is used today
- `lib/src/contract/snapshot.dart` — aggregate snapshot constructors validate
  structure but currently retain nested boundary objects as supplied
- `lib/src/contract/node_spec.dart` — public spec constructors validate fields
  but today do not canonicalize nested boundary inputs at aggregate seams
- `lib/src/contract/node_patch.dart` — patch constructors validate fields but
  currently retain `common` as supplied
- `lib/src/contract/patch_field.dart` — documents and exposes patch-field state
  semantics
- `lib/src/contract/internal/node_boundary_schema_patch.dart` — currently
  preserves `PatchField<T?>.value(null)` as a distinct runtime form
- `lib/src/model/document_node_patch_common.dart` — currently preserves the
  explicit-null apply path at runtime because `txnPatchSetNullable(...)`
  collapses `PatchField.nullValue()` and `PatchField<T?>.value(null)` to the
  same write result while still accepting both encodings
- `lib/src/contract/internal/snapshot_fast_path.dart` — currently mixes
  validated helpers with raw snapshot materializers under one barrel and one
  vocabulary
- `lib/src/contract/internal/node_spec_fast_path.dart` — currently mixes
  validated spec helpers with raw `materializeNodeSpec(...)`
- `lib/src/contract/internal/node_patch_fast_path.dart` — currently mixes
  validated patch helpers with raw `materializeNodePatch(...)`
- `lib/src/contract/internal/snapshot_materialization.dart`,
  `lib/src/contract/internal/node_spec_materialization.dart`, and
  `lib/src/contract/internal/node_patch_materialization.dart` — each currently
  own both validated builders and raw `materialize*` helpers in the same file
- `lib/src/contract/internal/snapshot_boundary_impl.dart`,
  `lib/src/contract/internal/node_spec_boundary_impl.dart`, and
  `lib/src/contract/internal/node_patch_boundary_impl.dart` — rebuild seams
  require exact public runtime types while raw materializers return public
  subclasses over backing carriers
- `lib/src/contract/internal/snapshot_node_boundary_fallback.dart`,
  `lib/src/contract/internal/node_spec_boundary_fallback.dart`, and
  `lib/src/contract/internal/node_patch_boundary_fallback.dart` — strict
  exact-type fallback seams for the three families
- `tool/src/guardrails/rules/model/model_architecture_rules.dart` — already
  guards the validated import materialization boundary at the model layer
- `tool/src/guardrails/rules/contract/contract_architecture_rules.dart` —
  canonical contract internal surface allowlist owner
- `tool/src/import_boundaries/import_boundary_policy.dart` — bridge-surface
  inventory owner; today only `node_boundary_schema.dart` and
  `snapshot_fast_path.dart` are contract bridge surfaces
- `tool/invariant_registry.dart` — already defines
  `INV-ENG-VALIDATED-IMPORT-MATERIALIZATION-BOUNDARY`,
  `INV-ENG-CONTRACT-ARCHITECTURE-BOUNDARY`, and
  `INV-ENG-BOUNDARY-HERMETIC-CONCRETE-TYPES`
- `API_GUIDE.md` — currently documents `PatchField<T>` as tri-state
- `test/contract/validated_fast_path_contract_test.dart` — proves raw internal
  bypasses, late seam-failure behavior for unsupported boundary subtypes, and
  current raw spec/patch/snapshot materialization semantics
- `test/contract/validated_internal_helpers_test.dart` — proves raw metadata
  materializers preserve malformed snapshot values
- `test/model/scene_builder_test.dart` — proves raw `SceneImportDraft` bypass
  remains explicit and locks supported snapshot import behavior
- `test/public_api/node_patch_semantics_test.dart`,
  `test/contract/patch_field_test.dart`, and
  `test/model/document_model_test.dart` — lock current patch-field semantics
- `test/tool/guardrails/guardrails_model_architecture_tool_test.dart` —
  structural proof for validated import materialization
- `test/tool/guardrails/guardrails_contract_architecture_tool_test.dart` —
  structural proof for canonical contract surfaces
- `test/tool/import_boundaries/import_boundaries_layer_dag_tool_test.dart` and
  `test/tool/import_boundaries/import_boundaries_controller_structure_tool_test.dart`
  — lock bridge-surface legality and friend-layer access for
  `snapshot_fast_path.dart`
- `test/contract/contract_layer_smoke_test.dart` — locks explicit contract
  surface inventory and part-free surface structure

### Current Entry Path

- typed snapshot import:
  `SceneBuilder.buildFromSnapshot(...) -> sceneBuildFromSnapshot(...) ->
  sceneImportFromDraft(...) -> ScenePolicy.validateImportDraft(...) ->
  sceneFromValidatedImportDraft(...)`
- public snapshot aggregation:
  `SceneSnapshot(...) / BackgroundLayerSnapshot(...) /
  ContentLayerSnapshot(...) -> later sceneSnapshotBackingOf(...) -> strict
  exact-type rebuild`
- public patch aggregation:
  `ImageNodePatch(...) / TextNodePatch(...) / ... -> later
  nodePatchBackingOf(...) -> strict exact-type rebuild`
- public spec aggregation:
  `ImageNodeSpec(...) / TextNodeSpec(...) / ... -> later nodeSpecBackingOf(...)
  -> strict exact-type rebuild`
- internal snapshot helper path:
  `snapshot_fast_path.dart -> snapshot_materialization.dart -> validated helpers
  plus raw materializers in one owner`
- internal spec helper path:
  `node_spec_fast_path.dart -> node_spec_materialization.dart -> validated
  helpers plus raw materializers in one owner`
- internal patch helper path:
  `node_patch_fast_path.dart -> node_patch_materialization.dart -> validated
  helpers plus raw materializers in one owner`

### Current Owner

- `contract` owns public boundary admission, schema validation helpers, backing
  carriers, and fast-path/barrel seams
- `model` owns raw import validation, import proof minting, and boundary-to-
  runtime mapping
- `tool/src/import_boundaries/import_boundary_policy.dart` owns cross-layer
  bridge-surface registration for contract/internal imports
- `tool/src/guardrails/rules/contract/contract_architecture_rules.dart` owns
  the canonical contract internal-surface allowlist for non-contract imports

### Current Consumer Inventory

- `snapshot_fast_path.dart` has non-test `lib/src/model/**` consumers for
  import draft conversion, runtime export, runtime-to-boundary mapping, and
  decode helpers, plus many tests across render, controller, serialization,
  view, public API, and contract coverage
- `node_spec_fast_path.dart` and `node_patch_fast_path.dart` have no `lib/**`
  production consumers; current consumers are contract tests, smoke coverage,
  and guardrail fixtures only

### Adjacent Abstractions

- `lib/src/contract/internal/node_boundary_schema_common.dart`
- `lib/src/contract/internal/node_boundary_schema_snapshot.dart`
- `lib/src/contract/internal/node_boundary_schema_spec.dart`
- `lib/src/contract/internal/node_boundary_schema_patch.dart`
- `lib/src/contract/internal/snapshot_backing.dart`
- `lib/src/contract/internal/node_spec_backing.dart`
- `lib/src/contract/internal/node_patch_backing.dart`
- `lib/src/model/scene_snapshot_from_scene.dart`
- `lib/src/model/scene_node_boundary_mapping_*.dart`
- `tool/check_guardrails.dart`
- `tool/check_import_boundaries.dart`

### Existing Tests

- `test/contract/validated_fast_path_contract_test.dart` — locks the current
  validated and raw helper behavior for snapshots, specs, and patches
- `test/contract/validated_internal_helpers_test.dart` — locks explicit unsafe
  raw snapshot materialization behavior
- `test/model/scene_builder_test.dart` — locks explicit raw
  `SceneImportDraft.fromBacking(...)` bypass behavior and supported snapshot
  import behavior
- `test/public_api/node_patch_semantics_test.dart` — locks public patch-field
  runtime behavior, including the current explicit-null path
- `test/contract/patch_field_test.dart` — locks baseline `PatchField` runtime
  state behavior
- `test/model/document_model_test.dart` — locks patch application semantics
- `test/tool/guardrails/guardrails_model_architecture_tool_test.dart` — locks
  the validated import materialization boundary structurally
- `test/tool/guardrails/guardrails_contract_architecture_tool_test.dart` —
  locks canonical contract internal surfaces and non-contract import rules
- `test/tool/import_boundaries/import_boundaries_layer_dag_tool_test.dart` and
  `test/tool/import_boundaries/import_boundaries_controller_structure_tool_test.dart`
  — lock bridge-surface legality and friend-layer access
- `test/contract/contract_layer_smoke_test.dart` — locks contract surface
  inventory and explicit non-part structure

### Analogous Implementation Path

- `lib/src/contract/internal/node_boundary_schema_*.dart` — already centralize
  raw-to-validated canonicalization by family and expose `...FromValidated(...)`
  seams without mixing them with public-admission ownership
- `lib/src/model/scene_import_draft.dart` plus
  `tool/invariant_registry.dart` — already establish
  `ValidatedSceneImportDraft` as a proof-before-materialization seam; the
  missing piece is minting ownership closure rather than a new proof model

### Governing Repository Rules

- `docs/adr/0001_target_engine_architecture.md` — validate and canonicalize
  before a supported public result, prefer owner-correct slices over local
  patches, and keep proof seams explicit
- `docs/adr/0002_post_target_optimization_scope.md` — do not default to public
  contract thinning or broad API redesign as opportunistic cleanup
- `ARCHITECTURE.md` — validated proof must precede supported document
  materialization and runtime import materialization must cross
  `ValidatedSceneImportDraft`
- `tool/invariant_registry.dart` — preserve and extend
  `INV-ENG-VALIDATED-IMPORT-MATERIALIZATION-BOUNDARY`,
  `INV-ENG-CONTRACT-ARCHITECTURE-BOUNDARY`, and
  `INV-ENG-BOUNDARY-HERMETIC-CONCRETE-TYPES`
- `tool/src/import_boundaries/import_boundary_policy.dart` — preserve the
  existing contract bridge inventory unless the architecture decision is
  explicitly reopened
- repository instructions in `AGENTS.md` — fix root causes at the owning seam
  and prefer repository-local enforcement over prose-only guidance

### Rejected Misleading Local Patterns

- raw `materialize*` helpers in the current family materialization owners —
  valid as explicit unsafe seams, but the wrong owner for admission guarantees
  or validated-path correctness
- mixed fast-path barrels that expose both `...FromValidated(...)` and raw
  `materialize*` helpers under one internal surface — wrong safety model even
  when the files stay contract-internal
- barrel-only split while keeping validated helpers and raw materializers in the
  same owner file — hides the problem cosmetically without repairing ownership
- strict fallback helpers such as `nodeSnapshotBackingOf(...)`,
  `nodeSpecBackingOf(...)`, and `nodePatchBackingOf(...)` — valid as exact-type
  rebuild seams, but the wrong place to be the first failure surface for
  admitted public graphs
- preserving `PatchField<T?>.value(null)` as a second null encoding — locally
  convenient, but it contradicts the documented tri-state public contract

## 4. Architecture

### 4A. Locked Architectural Form

#### Problem Ownership Level

- This is a cross-seam boundary correctness problem owned jointly by the
  `contract` admission layer and the `model` import proof seam, not by
  individual call sites.

#### Selected Architectural Form

- Public boundary values enter through one contract-owned admission seam that
  eagerly canonicalizes supported nested boundary values into exact built-in
  public boundary instances and eagerly rejects unsupported subtypes.
- Validated import proof is minted by one model owner only:
  `ScenePolicy.validateImportDraft(...)` and its file-owned helper seam remain
  the only place allowed to turn `SceneImportDraft` into
  `ValidatedSceneImportDraft`.
- Safe validated helpers and unsafe raw materializers are symmetric by family:
  snapshot, node-spec, and node-patch helpers each expose a validated-only
  helper owner and a separate unsafe raw materialization owner.
- `snapshot_fast_path.dart` remains the only cross-layer snapshot bridge
  surface, but it becomes validated-only.
- `node_spec_fast_path.dart` and `node_patch_fast_path.dart` remain
  contract-internal validated-only barrels and do not become bridge surfaces.
- Raw materializers move to explicit family-specific unsafe owners and use
  explicit unsafe naming rather than neutral validated-sounding names.
- Nullable `PatchField` values have one canonical null encoding in admitted
  public objects and in backings.

#### Owning Layer or Module

- `contract` owns boundary admission canonicalization, canonical nullable patch
  semantics, backing carriers, and the symmetric validated-versus-unsafe seam
  split for snapshot, spec, and patch families.
- `model` owns raw import validation, file-owned proof minting, and
  draft/runtime mapping without routing through raw public wrappers.

#### Dependency Direction

- raw public boundary input -> contract admission canonicalization -> strict
  exact-type backing seams and runtime/serialization owners
- raw import backing -> `ScenePolicy.validateImportDraft(...)` -> file-owned
  validated proof minting -> validated import materialization -> runtime `Scene`
- non-contract validated snapshot consumers -> `snapshot_fast_path.dart` ->
  validated snapshot helpers only
- validated node-spec and node-patch helpers remain contract-internal only; no
  cross-layer bridge expansion is allowed for those families
- raw backing -> family-specific explicit unsafe internal materialization seam
  only
- no validated owner may depend on unsafe raw materialization to recover
  validation semantics

#### State and Data Ownership

- caller-supplied public boundary instances are input only
- exact built-in immutable public boundary instances are the canonical admitted
  form retained inside aggregate public boundary graphs
- if an admitted nested value is already an exact built-in immutable boundary
  instance, admission preserves it by reference
- if an admitted nested value is a supported carrier-backed or internal
  materialized subtype, admission rebuilds it into an exact built-in immutable
  boundary instance before storing it
- `SceneImportDraft` remains the raw carrier for import data
- `ValidatedSceneImportDraft` remains the only proof type for validated import
  materialization
- `PatchField` state ownership belongs to the contract patch schema layer; once
  admitted, nullable patch fields expose only one null encoding

#### Entry and Exit Boundaries

- Entry boundaries:
  `SceneSnapshot`, layer snapshot constructors, `NodeSpec` constructors,
  `NodePatch` constructors, `CommonNodePatch`, typed snapshot import, JSON
  import, and any internal helper that accepts public boundary values
- Exit boundaries:
  canonical public `SceneSnapshot`, runtime `Scene`, validated backings for
  write and serialization seams, validated-only fast-path barrels, and explicit
  unsafe raw boundary wrappers for contract-internal and test-owned scenarios
- Cross-layer snapshot helper exit boundary:
  `snapshot_fast_path.dart` remains the only friend-layer bridge surface for
  model and serialization snapshot helper access

#### Permitted Extension Seam

- add contract-internal admission canonicalization helpers and private or
  internal constructors that rebuild exact built-in boundary instances from
  already validated schema or backing data
- add `unsafe_snapshot_materialization.dart`,
  `unsafe_node_spec_materialization.dart`, and
  `unsafe_node_patch_materialization.dart`
- shrink `snapshot_materialization.dart`, `node_spec_materialization.dart`, and
  `node_patch_materialization.dart` to validated-only owners
- add model-owned backing-native validation or mapping helpers where the current
  path still materializes raw public wrappers
- replace public proof minting with a file-owned private constructor, private
  top-level minting helper, or equivalent owner-guarded form that sibling files
  cannot call directly
- add guardrail, smoke-test, and import-boundary proof updates that lock the
  unchanged bridge inventory and the new family symmetry

#### Rejected Alternatives

- add more late validation inside raw `materialize*` helpers — keeps admission
  correctness at the wrong owner and leaves mixed safety seams intact
- barrel-only split while keeping validated helpers and raw materializers in the
  same owner file — repairs naming but not ownership
- register `unsafe_*_materialization.dart` files as new bridge surfaces —
  widens cross-layer privileges instead of quarantining the raw bypass
- relax strict fallback seams to accept arbitrary subclasses — weakens the
  hermetic exact-type contract instead of fixing admission
- document four-state nullable patch semantics — contradicts the current public
  API guide and preserves duplicate null encodings
- make the full public boundary family `sealed` or `final` now — stricter on
  paper, but too public-facing and costly for the accepted ADR scope

#### Why This Level Is Correct

- The same defect shape appears in snapshots, specs, patches, import proof, and
  nullable patch semantics, so a helper-local patch would not solve the class
  of failures.
- Snapshot is special only in bridge visibility, not in safety semantics; its
  validated-versus-unsafe split should therefore match the spec and patch
  families even if those remain contract-internal.
- The repository already distinguishes validated schema ownership from raw input
  ownership, and `ValidatedSceneImportDraft` already proves that the intended
  model is proof-before-materialization.
- The repository already codifies bridge-surface ownership separately from
  contract internals, so unsafe seams must be quarantined inside that existing
  import-boundary architecture rather than silently creating new privileged
  surfaces.
- There are no production `lib/**` consumers of `node_spec_fast_path.dart` or
  `node_patch_fast_path.dart`, so extending symmetry to those families now is
  low-cost and closes the class instead of leaving a known duplicate pattern.

## 5. Locked Decisions

1. Aggregate public boundary constructors must not retain unsupported nested
   boundary objects by reference as the long-lived canonical form.
2. Admission preserves exact built-in immutable boundary instances by reference
   when they are already the canonical exact runtime type.
3. Admission must canonicalize supported carrier-backed or internal materialized
   boundary instances into exact built-in immutable copies before storing them.
4. Unsupported boundary subtypes must fail at admission, not later at backing
   rebuild, debug encode, import, or write seams.
5. The strict exact-type `*BackingOf(...)` seams remain strict and are not
   broadened to structural acceptance of arbitrary subclasses.
6. `ScenePolicy.validateImportDraft(...)` and its file-owned private helper
   remain the only proof-minting path for `ValidatedSceneImportDraft`.
7. `scene_import_draft.dart` must not expose a proof-minting constructor or
   factory that sibling model files can call directly.
8. Model validated import and validation paths must validate and map node
   backing directly or through validated helpers instead of materializing raw
   public snapshot wrappers from raw backing as an intermediate step.
9. `snapshot_fast_path.dart` remains the only cross-layer snapshot bridge
   surface for model and serialization, and it must become validated-only.
10. `node_spec_fast_path.dart` and `node_patch_fast_path.dart` become
    validated-only internal barrels with no raw `materialize*` exports.
11. Raw snapshot, spec, and patch materializers move to separate
    `unsafe_*_materialization.dart` owners and use explicit unsafe naming.
12. No non-contract caller may migrate to any unsafe raw materialization file.
13. `PatchField<T?>.value(null)` must no longer remain a distinct admitted
    state; the canonical public null form is `PatchField.nullValue()`.

## 6. Result Requirements

1. `SceneSnapshot`, layer snapshots, `NodeSpec`, `CommonNodePatch`, and
   `NodePatch` either reject unsupported nested subtype inputs during
   construction or store them only after canonicalization into exact built-in
   immutable forms.
2. The first observable failure for unsupported boundary subtype graphs occurs
   at public boundary admission, not at `sceneSnapshotBackingOf(...)`,
   `nodeSpecBackingOf(...)`, `nodePatchBackingOf(...)`, or downstream encode and
   import helpers.
3. Validated import and scene-validation paths use `ValidatedSceneImportDraft`
   or validated backing data directly and do not rely on raw unsafe snapshot
   materialization for node-specific validation.
4. `ValidatedSceneImportDraft` can be minted only by the model validation owner
   rather than by arbitrary sibling files.
5. Snapshot, node-spec, and node-patch helper families expose validated-only
   helper owners and separate explicit unsafe raw materialization owners.
6. `snapshot_fast_path.dart` remains the only cross-layer snapshot bridge
   surface and exports validated-only helpers; the unsafe family files are
   contract-internal only.
7. Raw helper names make unsafety explicit rather than sounding equivalent to
   validated materialization.
8. Public and internal nullable patch-field semantics are canonical tri-state in
   constructors, schema validation, backings, apply paths, docs, and tests.
9. Guardrails, smoke tests, import-boundary checks, and invariants make future
   drift mechanically visible.

## 7. Execution Order and Gates

### Required Order

- First, implement contract-owned admission canonicalization for aggregate
  public boundary constructors with failing reproducers and guard tests first,
  while keeping strict fallback seams unchanged.
- Next, lock single-owner validated import proof minting and move model-owned
  validated import and validation paths off raw public snapshot materialization
  and onto backing-native validation or validated helper mapping, with failing
  reproducers and owner-side fixes in the same slice.
- After the model no longer depends on the mixed snapshot seam, split snapshot
  validated and unsafe helper ownership into separate owner files and retire raw
  exports from the snapshot bridge barrel in one closeable slice.
- Then, split node-spec and node-patch validated and unsafe helper ownership
  into separate owner files and retire raw exports from their validated barrels
  in one closeable slice.
- Finish by canonicalizing nullable patch-field semantics across constructors,
  schema validation, backings, and apply paths after the patch family seam split
  is already in place, with apply-path reproducers and fixes in the same slice.
- Update docs, invariants, guardrails, smoke tests, and import-boundary proof
  only as each successor seam becomes real; do not front-run retirement.

### Successor Seam and Retirement Gates

- validated import proof seam:
  `SceneImportDraft -> ScenePolicy.validateImportDraft(...) ->
  ValidatedSceneImportDraft -> sceneFromValidatedImportDraft(...)`
  remains the only import proof path
- proof minting gate:
  if implementation appears to require minting `ValidatedSceneImportDraft`
  outside `scene_policy.dart` and its file-owned helper, stop and amend the
  contract before coding
- validated snapshot bridge seam:
  `lib/src/contract/internal/snapshot_fast_path.dart` remains the only
  contract-owned friend-layer bridge surface for snapshot helpers; it may
  retire raw exports only after non-contract callers are removed from them
- unsafe raw snapshot seam:
  `lib/src/contract/internal/unsafe_snapshot_materialization.dart` becomes the
  only raw snapshot export site for contract-owned and test-owned internal use;
  non-contract callers must not migrate to it
- validated spec seam:
  `lib/src/contract/internal/node_spec_fast_path.dart` remains a
  contract-internal validated-only barrel; raw exports retire only after tests,
  smoke coverage, and guardrails move with them
- unsafe raw spec seam:
  `lib/src/contract/internal/unsafe_node_spec_materialization.dart` becomes the
  only raw spec export site for contract-owned and test-owned internal use
- validated patch seam:
  `lib/src/contract/internal/node_patch_fast_path.dart` remains a
  contract-internal validated-only barrel; raw exports retire only after tests,
  smoke coverage, and guardrails move with them
- unsafe raw patch seam:
  `lib/src/contract/internal/unsafe_node_patch_materialization.dart` becomes
  the only raw patch export site for contract-owned and test-owned internal use
- bridge inventory gate:
  `tool/src/import_boundaries/import_boundary_policy.dart` remains unchanged for
  contract bridge-surface registration in this step; if implementation appears
  to require a new bridge descriptor for any unsafe file, stop and amend the
  contract before coding
- structural retirement gate:
  raw exports may be removed from `snapshot_fast_path.dart`,
  `node_spec_fast_path.dart`, and `node_patch_fast_path.dart` only after
  `tool/src/guardrails/rules/contract/contract_architecture_rules.dart`,
  `test/tool/guardrails/guardrails_contract_architecture_tool_test.dart`,
  `test/tool/import_boundaries/import_boundaries_layer_dag_tool_test.dart`,
  `test/tool/import_boundaries/import_boundaries_controller_structure_tool_test.dart`,
  `test/contract/contract_layer_smoke_test.dart`,
  `dart run tool/check_guardrails.dart`, and
  `dart run tool/check_import_boundaries.dart` all prove the bridge inventory
  is unchanged and all unsafe seams are quarantined
- naming gate:
  neutral raw helper names may be retired only after every internal caller and
  test is migrated to explicit unsafe names
- nullable patch semantics gate:
  the distinct admitted state for `PatchField<T?>.value(null)` may be retired
  only after public semantics tests, contract tests, apply-path tests, and API
  docs all lock the canonical tri-state behavior

### Deferred Broad Verification

- `dart run tool/run_verification_preset.dart run --preset=required_code_change --changed-paths-file=<file>`
  remains the final gate after the successor seams are fully migrated
- any broad failures caused by transitional mixed seams are deferred only until
  the slice that retires that seam; they are not grounds to keep mixed seams
  permanently

## 8. File Map

### Implementation Files

- `lib/src/contract/snapshot.dart`
- `lib/src/contract/node_spec.dart`
- `lib/src/contract/node_patch.dart`
- `lib/src/contract/patch_field.dart`
- `lib/src/contract/internal/node_boundary_schema_patch.dart`
- `lib/src/contract/internal/snapshot_fast_path.dart`
- `lib/src/contract/internal/snapshot_materialization.dart`
- `lib/src/contract/internal/unsafe_snapshot_materialization.dart`
- `lib/src/contract/internal/node_spec_fast_path.dart`
- `lib/src/contract/internal/node_spec_materialization.dart`
- `lib/src/contract/internal/unsafe_node_spec_materialization.dart`
- `lib/src/contract/internal/node_patch_fast_path.dart`
- `lib/src/contract/internal/node_patch_materialization.dart`
- `lib/src/contract/internal/unsafe_node_patch_materialization.dart`
- `lib/src/contract/internal/snapshot_boundary_impl.dart`
- `lib/src/contract/internal/snapshot_node_boundary_fallback.dart`
- `lib/src/contract/internal/node_spec_boundary_impl.dart`
- `lib/src/contract/internal/node_spec_boundary_fallback.dart`
- `lib/src/contract/internal/node_patch_boundary_impl.dart`
- `lib/src/contract/internal/node_patch_boundary_fallback.dart`
- `lib/src/model/scene_import_draft.dart`
- `lib/src/model/scene_policy.dart`
- `lib/src/model/scene_from_import_draft.dart`
- `lib/src/model/scene_value_validation_scene.dart`
- `lib/src/model/scene_snapshot_from_scene.dart`
- `lib/src/model/scene_node_boundary_mapping.dart`
- `lib/src/model/document_node_patch.dart`
- `lib/src/model/document_node_patch_common.dart`
- `lib/src/model/document_node_patch_image.dart`
- `lib/src/model/document_node_patch_text.dart`
- `lib/src/model/document_node_patch_rect.dart`
- `lib/src/model/document_node_patch_path.dart`
- `tool/src/guardrails/rules/model/model_architecture_rules.dart`
- `tool/src/guardrails/rules/contract/contract_architecture_rules.dart`
- `tool/src/import_boundaries/import_boundary_policy.dart`

### Test Files

- `test/contract/validated_fast_path_contract_test.dart`
- `test/contract/validated_internal_helpers_test.dart`
- `test/contract/contract_layer_smoke_test.dart`
- `test/model/scene_builder_test.dart`
- `test/public_api/node_patch_semantics_test.dart`
- `test/contract/patch_field_test.dart`
- `test/model/document_model_test.dart`
- `test/tool/guardrails/guardrails_model_architecture_tool_test.dart`
- `test/tool/guardrails/guardrails_contract_architecture_tool_test.dart`
- `test/tool/import_boundaries/import_boundaries_layer_dag_tool_test.dart`
- `test/tool/import_boundaries/import_boundaries_controller_structure_tool_test.dart`

### Fixtures and Supporting Data

- none expected beyond test-local helpers and fixtures already in the named test
  files

### Registry, Inventory, and Workflow Files

- `PLAN.md`
- `tool/invariant_registry.dart`
- `tool/check_guardrails.dart`
- `tool/check_import_boundaries.dart`

### Analysis Area

- `README.md`
- `CHANGELOG.md`
- `ARCHITECTURE.md`
- `API_GUIDE.md`
- `docs/adr/0001_target_engine_architecture.md`
- `docs/adr/0002_post_target_optimization_scope.md`

## 9. Implementation Rules

### Protected Invariants

- `INV-ENG-VALIDATED-IMPORT-MATERIALIZATION-BOUNDARY` must remain true and must
  expand to cover single-owner proof minting plus the backing-native validated
  model path
- `INV-ENG-CONTRACT-ARCHITECTURE-BOUNDARY` must remain true; validated contract
  surfaces stay canonical while unsafe family files remain quarantined
- `INV-ENG-BOUNDARY-HERMETIC-CONCRETE-TYPES` must remain true; the fix moves
  the first failure surface to admission but does not relax the strict exact-
  type seam
- `INV-G-LAYER-DAG` must remain true; no new contract/internal bridge surface
  is introduced for unsafe raw materialization
- supported public document results must still be validated and canonicalized
  before they become supported boundary objects
- nullable patch semantics must remain tri-state in public docs and observable
  runtime state

### Required Proof

- behavioral proof:
  failing reproducers first in `test/contract/validated_fast_path_contract_test.dart`
  for eager admission failure or canonicalization, mixed safe/unsafe seam
  exposure, and explicit unsafe helper behavior
- behavioral proof:
  failing reproducers first in `test/public_api/node_patch_semantics_test.dart`,
  `test/contract/patch_field_test.dart`, and `test/model/document_model_test.dart`
  for canonical nullable patch semantics
- behavioral guard tests:
  `test/model/scene_builder_test.dart` and
  `test/contract/validated_internal_helpers_test.dart` must continue to prove
  the explicit raw bypass remains explicit and quarantined
- structural proof:
  `test/tool/guardrails/guardrails_model_architecture_tool_test.dart` and
  `tool/check_guardrails.dart` must prove that model-owned validated import
  paths do not regress to raw snapshot materialization and that proof minting
  remains owner-locked
- structural proof:
  `test/tool/guardrails/guardrails_contract_architecture_tool_test.dart`,
  `test/contract/contract_layer_smoke_test.dart`, and
  `tool/check_guardrails.dart` must prove that snapshot, spec, and patch
  families keep validated-only barrels, separate unsafe owners, and no barrel-
  only split regressions
- structural proof:
  `test/tool/import_boundaries/import_boundaries_layer_dag_tool_test.dart`,
  `test/tool/import_boundaries/import_boundaries_controller_structure_tool_test.dart`,
  and `dart run tool/check_import_boundaries.dart` must prove that
  `snapshot_fast_path.dart` remains the only cross-layer snapshot bridge
  surface and that unsafe family files stay unlisted internal modules for
  non-contract code
- for bug fixes, regressions, false positives, false negatives, and
  invariant-enforcement gaps: one failing reproducer first, plus 1 to 3 guard
  tests for neighboring branches of the same contract

### Allowed Change Surface

- the files named in section 8
- additional contract-internal helpers or private constructors only when they
  are required to implement the locked admission, proof-minting, or unsafe-seam
  form
- `README.md`, `API_GUIDE.md`, `ARCHITECTURE.md`, and `CHANGELOG.md` must all
  be updated in the implementation change to reflect the final implemented
  public behavior and architecture

### Forbidden Moves

- do not broaden the strict fallback seams to structural acceptance of arbitrary
  subclasses
- do not leave validated helpers and raw materializers in the same owner file
  under a cosmetic barrel split
- do not leave both a mixed fast-path barrel and a new unsafe barrel active as
  permanent parallel seams
- do not register any `unsafe_*_materialization.dart` file as a bridge surface
  or canonical non-contract contract surface
- do not reintroduce model-owned validation logic that depends on raw public
  snapshot wrappers created from raw backing
- do not expose a callable `ValidatedSceneImportDraft` proof-minting entrypoint
  outside the model validation owner
- do not keep neutral raw helper names that sound equivalent to validated
  materialization
- do not migrate model, serialization, controller, or other non-contract
  callers onto unsafe files
- do not document nullable patch semantics as four-state behavior
- do not solve this by adding repository prose alone without guardrail or test
  enforcement

## 10. Vertical Slices

### Slice 1. [x] Canonicalize Aggregate Public Boundary Admission

#### Slice Contract

Move the first failure or canonicalization surface for nested public boundary
graphs into boundary admission without relaxing strict fallback seams.

#### Change

- add failing tests that prove unsupported nested snapshot, spec, and patch
  subtype graphs fail or canonicalize at admission instead of failing only at
  later rebuild seams, plus neighboring guard cases for supported exact inputs
  and carrier-backed canonicalization
- update aggregate public constructors in `snapshot.dart`, `node_spec.dart`, and
  `node_patch.dart` to preserve exact built-in immutable inputs by reference,
  canonicalize supported carrier-backed inputs into exact built-in copies, and
  reject unsupported nested subtype values
- keep strict exact-type rebuild seams unchanged and rely on the new admission
  layer to feed them canonical values

#### Behavioral Verification

- `flutter test test/contract/validated_fast_path_contract_test.dart`
- `flutter test test/public_api/node_patch_semantics_test.dart`

#### Structural Verification

- `flutter test test/contract/contract_layer_smoke_test.dart`

#### Fixtures Used

- existing unsupported subtype fixtures in
  `test/contract/validated_fast_path_contract_test.dart`

#### Positive Scenarios

- exact built-in boundary inputs still construct and round-trip successfully
- carrier-backed values are admitted only after canonicalization to exact
  built-in forms

#### Negative Scenarios

- unsupported nested subtype graphs do not survive until `*BackingOf(...)`
  before failing
- downstream `debugEncodeCanonicalSnapshotForTest(...)` is no longer the first
  failure surface for admitted graphs

#### Closure Evidence

- late seam-failure tests move to eager admission failure or eager
  canonicalization expectations while strict fallback seam tests remain green

### Slice 2. [x] Lock Single-Owner Validated Import Proof and Backing-Native Model Path

#### Slice Contract

Validated import and draft validation must operate on proof-backed or
backing-native data without creating raw public wrappers from raw backing, and
validated proof minting must stay with one model owner.

#### Change

- add failing tests that prove validated import paths do not use raw public
  snapshot wrappers from raw backing and that sibling model files cannot mint
  `ValidatedSceneImportDraft`, plus neighboring guard cases for supported
  validated import behavior
- replace model-side uses of raw `materializeNodeSnapshot(...)` from raw backing
  in validated import and draft validation paths with backing-native validation
  or validated helper mapping
- remove or hide any callable proof-minting constructor or factory so only the
  model validation owner can mint `ValidatedSceneImportDraft`
- extend model guardrails so sibling files cannot regress to direct proof
  minting or unsafe raw snapshot materialization from validated paths

#### Behavioral Verification

- `flutter test test/model/scene_builder_test.dart`
- `flutter test test/contract/validated_fast_path_contract_test.dart`

#### Structural Verification

- `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_model_architecture_tool_test.dart`
- `dart run tool/check_guardrails.dart`

#### Fixtures Used

- draft and malformed backing fixtures already in
  `test/model/scene_builder_test.dart` and
  `test/contract/validated_fast_path_contract_test.dart`

#### Positive Scenarios

- validated typed snapshot import still canonicalizes through
  `ValidatedSceneImportDraft`
- malformed draft node values still fail with the correct import diagnostic
  surface

#### Negative Scenarios

- no model-owned validated path depends on raw public snapshot wrappers created
  from raw backing
- sibling model files cannot mint `ValidatedSceneImportDraft` directly

#### Closure Evidence

- model validated import paths compile and pass without depending on raw
  snapshot materialization and proof minting is structurally owner-locked

### Slice 3. [x] Split Snapshot Validated and Unsafe Helper Owners

#### Slice Contract

Snapshot validated helpers and unsafe raw materializers must no longer share one
owner file, one barrel, or one safety-signaling vocabulary.

#### Change

- add failing tests that prove snapshot validated barrels do not expose raw
  materializers and that explicit unsafe snapshot helpers remain the only raw
  bypass, plus neighboring guard cases for validated callers
- add `lib/src/contract/internal/unsafe_snapshot_materialization.dart`
- move raw snapshot `materialize*` ownership out of
  `snapshot_materialization.dart` into the new unsafe owner
- rename raw snapshot helpers to explicit unsafe names
- shrink `snapshot_materialization.dart` and `snapshot_fast_path.dart` to
  validated-only helper ownership while preserving `snapshot_fast_path.dart` as
  the sole cross-layer snapshot bridge surface
- migrate contract-owned and test-owned snapshot raw users to the unsafe owner
  and keep non-contract callers on validated helpers only

#### Behavioral Verification

- `flutter test test/contract/validated_internal_helpers_test.dart`
- `flutter test test/contract/validated_fast_path_contract_test.dart`

#### Structural Verification

- `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_contract_architecture_tool_test.dart test/tool/import_boundaries/import_boundaries_layer_dag_tool_test.dart test/tool/import_boundaries/import_boundaries_controller_structure_tool_test.dart`
- `flutter test test/contract/contract_layer_smoke_test.dart`
- `dart run tool/check_guardrails.dart`
- `dart run tool/check_import_boundaries.dart`

#### Fixtures Used

- raw malformed backing fixtures in
  `test/contract/validated_internal_helpers_test.dart`

#### Positive Scenarios

- validated snapshot helpers remain available to validated callers
- explicit unsafe snapshot helpers still support negative internal scenarios and
  tests
- model and serialization continue to import `snapshot_fast_path.dart` as the
  only snapshot helper bridge surface

#### Negative Scenarios

- safe validated imports cannot accidentally reach raw snapshot materializers
  through the validated barrel
- non-contract code cannot import the unsafe snapshot owner

#### Closure Evidence

- no mixed validated-plus-unsafe snapshot owner or barrel remains in the
  snapshot family and the bridge inventory remains unchanged

### Slice 4. [x] Split NodeSpec and NodePatch Validated and Unsafe Helper Owners

#### Slice Contract

Node-spec and node-patch validated helpers and unsafe raw materializers must no
longer share one owner file, one barrel, or one safety-signaling vocabulary.

#### Change

- add failing tests that prove validated spec and patch barrels do not expose
  raw materializers and that explicit unsafe helpers remain the only raw spec
  and patch bypasses, plus neighboring guard cases for validated helpers
- add `lib/src/contract/internal/unsafe_node_spec_materialization.dart`
- add `lib/src/contract/internal/unsafe_node_patch_materialization.dart`
- move raw spec and patch `materialize*` ownership out of
  `node_spec_materialization.dart` and `node_patch_materialization.dart` into
  their new unsafe owners
- rename raw spec and patch helpers to explicit unsafe names
- shrink `node_spec_fast_path.dart`, `node_spec_materialization.dart`,
  `node_patch_fast_path.dart`, and `node_patch_materialization.dart` to
  validated-only helper ownership
- migrate contract-owned and test-owned raw users to the new unsafe owners

#### Behavioral Verification

- `flutter test test/contract/validated_fast_path_contract_test.dart`

#### Structural Verification

- `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_contract_architecture_tool_test.dart`
- `flutter test test/contract/contract_layer_smoke_test.dart`
- `dart run tool/check_guardrails.dart`
- `dart run tool/check_import_boundaries.dart`

#### Fixtures Used

- raw spec and patch backing fixtures already in
  `test/contract/validated_fast_path_contract_test.dart`

#### Positive Scenarios

- validated spec and patch helpers remain available to contract-owned callers
  and tests
- explicit unsafe spec and patch helpers still support negative internal
  scenarios and tests

#### Negative Scenarios

- validated spec and patch barrels do not expose raw materializers
- unsafe spec and patch owners are not imported cross-layer

#### Closure Evidence

- no mixed validated-plus-unsafe spec or patch owner or barrel remains in the
  contract layer

### Slice 5. [x] Canonicalize Nullable PatchField Semantics End-to-End

#### Slice Contract

Nullable patch fields must expose one canonical null state across constructors,
schema validation, backings, apply paths, docs, and tests.

#### Change

- add failing tests that prove admitted nullable patch fields expose only one
  null encoding across constructors and transactional apply paths, plus
  neighboring guard cases for absent and concrete-value states
- canonicalize nullable `PatchField` null writes at the public constructor and
  schema-validation layer
- remove the distinct admitted-state behavior for `PatchField<T?>.value(null)`
- update patch backings, transactional apply paths in
  `document_node_patch_common.dart`, `document_node_patch.dart`,
  `document_node_patch_image.dart`, `document_node_patch_text.dart`,
  `document_node_patch_rect.dart`, and `document_node_patch_path.dart`, plus
  docs and tests, to the canonical tri-state contract

#### Behavioral Verification

- `flutter test test/public_api/node_patch_semantics_test.dart`
- `flutter test test/contract/patch_field_test.dart`
- `flutter test test/model/document_model_test.dart`

#### Structural Verification

- `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_contract_architecture_tool_test.dart`

#### Fixtures Used

- existing patch-field and node-patch fixtures in the named test files

#### Positive Scenarios

- absent, concrete value, and explicit null remain the only observable patch
  states
- nullable patch application still writes `null` correctly

#### Negative Scenarios

- `PatchField<T?>.value(null)` is not observable as a fourth effective state

#### Closure Evidence

- docs and tests both describe and prove one tri-state nullable patch contract

## 11. Final Verification

- `flutter test test/contract/validated_fast_path_contract_test.dart`
- `flutter test test/contract/validated_internal_helpers_test.dart`
- `flutter test test/contract/contract_layer_smoke_test.dart`
- `flutter test test/model/scene_builder_test.dart`
- `flutter test test/public_api/node_patch_semantics_test.dart`
- `flutter test test/contract/patch_field_test.dart`
- `flutter test test/model/document_model_test.dart`
- `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_model_architecture_tool_test.dart test/tool/guardrails/guardrails_contract_architecture_tool_test.dart test/tool/import_boundaries/import_boundaries_layer_dag_tool_test.dart test/tool/import_boundaries/import_boundaries_controller_structure_tool_test.dart`
- `dart run tool/check_guardrails.dart`
- `dart run tool/check_import_boundaries.dart`
- `dart run tool/run_verification_preset.dart run --preset=required_code_change --changed-paths-file=<file>`
- `dcm calculate-metrics <new-lib-files>` if the implementation introduces new
  production files under `lib/**`
- confirm that `README.md`, `API_GUIDE.md`, `ARCHITECTURE.md`, and
  `CHANGELOG.md` are updated in the same change

## 12. Acceptance Criteria

- admitted public boundary graphs no longer depend on late strict seam helpers
  as the first correctness surface
- exact built-in immutable inputs are preserved when already canonical and
  supported carrier-backed inputs are rebuilt to exact built-in forms at
  admission
- validated import and draft-validation paths use the validated proof seam and
  backing-native validation rather than raw public wrappers created from raw
  backing
- `ValidatedSceneImportDraft` proof minting is owned by one model validation
  owner only
- snapshot, node-spec, and node-patch families all expose validated-only helper
  owners and separate explicit unsafe raw materialization owners
- `snapshot_fast_path.dart` remains the only cross-layer snapshot bridge
  surface and all unsafe family files remain non-bridge
- strict exact-type seam helpers remain strict and still enforce hermetic
  concrete boundary types
- nullable patch fields expose one canonical tri-state null contract in code,
  tests, and docs
- `README.md`, `API_GUIDE.md`, `ARCHITECTURE.md`, and `CHANGELOG.md` are all
  updated to match the implemented public behavior and architecture
- invariant, guardrail, smoke-test, and import-boundary coverage make
  regressions in these seams mechanically visible
