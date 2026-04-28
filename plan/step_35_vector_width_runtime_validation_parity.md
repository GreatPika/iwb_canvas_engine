# Change Contract

## 1. Change Mandate

Close `KI-4` by making vector width validation a shared model-owned runtime
value contract so stroke, line, and adjacent width-like node fields cannot drift
between runtime, snapshot, and backing validation paths.

## 2. Change Boundary

### Included in the Change

- reject oversized runtime `StrokeNode.thickness` values through the committed
  store invariant gate before a public `SceneController` mutation can commit
- keep line thickness, stroke thickness, rectangle `strokeWidth`, and path
  `strokeWidth` aligned on one model-owned width-range validation helper where
  the semantic contract is `finite`, valid sign, and `<= sceneThicknessMax`
- refactor stroke value validation so runtime, snapshot, and backing paths share
  the same stroke family field validator while preserving their caller-visible
  point path names
- add behavioral proof for public `addNode` and `patchNode` stroke mutations
  that currently escape the runtime invariant gate
- add guard proof for the already-correct line path and adjacent width-like
  node fields so the fix does not narrow or widen neighboring contracts
- add repository-local structural enforcement that makes future
  runtime/snapshot/backing vector-width validator drift mechanically visible
- remove `KI-4` only after the behavioral and structural proof passes
- update API/runtime behavior documentation, architecture-family status, and
  user-visible release notes only for the fixed validation behavior
- audit `README.md` under the landing-page sync rules and leave it unchanged
  when it remains accurate by delegating runtime validation details to
  `API_GUIDE.md`

### Not Included in the Change

- no public API rename, schema-version change, or new public import
- no migration of `sceneThicknessMax` into public constructor validation unless
  a separate contract explicitly changes the public admission model
- no replacement of all numeric validation with a new value-object hierarchy
- no rendering, hit-testing, or geometry policy change
- no change to point coordinate path aliases such as `localPoints`, `localA`,
  `localB`, `points`, `start`, or `end`
- no implementation for other active known issues

## 3. Surrounding Code Review

### Inspected Artifacts

- `KNOWN_ISSUES.md` - records `KI-4` as a confirmed `P2` defect where runtime
  stroke value diagnostics miss the same `sceneThicknessMax` upper bound that
  snapshot and backing stroke validators enforce.
- `docs/ARCHITECTURE_ATLAS.md` - routes active confirmed defects to
  `KNOWN_ISSUES.md` and makes family documents the local architecture maps.
- `docs/architecture/families/serialization_and_schema.md` - states that
  runtime, snapshot, and backing validators stay aligned where schema parity
  requires it, and currently marks `KI-4` as a known issue.
- `docs/architecture/families/model_document_mutation_and_topology.md` -
  names `lib/src/model/**` and `test/model/**` as the document topology and
  mutation-helper owner area and links `INV-ENG-RUNTIME-NODE-VALUE-OWNERS`.
- `docs/architecture/families/core_scene_graph_geometry_and_spatial_indexes.md`
  - names core geometry and runtime node owners but keeps value-owner proof
  linked through the model/runtime invariant rather than a rendering policy.
- `tool/invariant_registry.dart` - defines
  `INV-ENG-RUNTIME-NODE-VALUE-OWNERS` as the invariant for constrained runtime
  node fields and patch-based writes inheriting the same boundary contract.
- `lib/src/model/scene_value_validation_node_stroke.dart` - validates
  snapshot and backing stroke thickness with `sceneThicknessMax`, but runtime
  `sceneValidateStrokeNode` only checks positive finite thickness.
- `lib/src/model/scene_value_validation_node_line.dart` - uses
  `_sceneValidateLineNodeFields` for runtime, snapshot, and backing line
  validation, including the `sceneThicknessMax` check.
- `lib/src/model/scene_value_validation_node_rect.dart` - validates rectangle
  `strokeWidth` through one shared node-field helper for runtime, snapshot, and
  backing paths.
- `lib/src/model/scene_value_validation_node_path.dart` - validates path
  `strokeWidth` through one shared node-field helper for runtime, snapshot, and
  backing paths.
- `lib/src/model/scene_value_validation_primitives.dart` - owns primitive
  diagnostic adapters, including `sceneValidatePositiveDouble` and
  `sceneValidateDoubleInRange`, but has no vector-width semantic helper.
- `lib/src/core/vector_nodes.dart` - runtime `StrokeNode` and `LineNode`
  setters validate thickness as positive finite values only; they do not own
  `sceneThicknessMax` semantic range enforcement.
- `lib/src/contract/internal/node_boundary_schema_spec.dart` - public
  `StrokeNodeSpec` constructor admission validates thickness as positive finite
  only.
- `lib/src/contract/internal/node_boundary_schema_common.dart` - public
  `LineNodeSpec` and `LineNodeSnapshot` schema admission validates thickness as
  positive finite only.
- `lib/src/contract/internal/node_boundary_schema_patch.dart` - public
  `StrokeNodePatch` and `LineNodePatch` admission validates thickness as
  positive finite only, so semantic width range must be enforced by later model
  value validation.
- `lib/src/model/document_node_patch_stroke.dart` - applies stroke thickness
  patches through the runtime setter, then relies on the commit invariant gate
  to reject semantic runtime value violations.
- `lib/src/model/document_node_patch_line.dart` - applies line thickness
  patches through the runtime setter, then relies on the same commit invariant
  gate; this path currently rejects oversized line thickness because line
  runtime validation is aligned.
- `lib/src/controller/scene_invariants.dart` - the critical commit invariant
  gate validates added and updated tracked runtime nodes through
  `sceneCollectRuntimeNodeViolations`.
- `lib/src/controller/scene_controller_commit_execution.dart` - checks
  critical store invariants before applying a state commit to the store.
- `lib/src/interactive/scene_controller_interaction.dart` and
  `lib/src/interactive/internal/scene_controller_interaction_config.dart` -
  draw-tool thickness settings validate positive finite values, but are not
  the model-owned semantic document validation layer.
- `test/model/scene_value_validation_primitives_test.dart` - already covers
  runtime node validation paths and contains raw node subclasses used to
  exercise validator backstops.
- `test/controller/core/scene_controller_commit_failures_test.dart` - already
  proves the commit plan rejects invalid runtime node state before applying the
  committed store.
- `test/public_api/scene_builder_test.dart` and
  `test/model/scene_builder_test.dart` - already cover import/build diagnostic
  path surfaces and range validation for typed and JSON scene input.
- `test/tool/guardrails/guardrails_model_architecture_tool_test.dart` - locks
  model architecture guardrails and is the nearest existing home for negative
  structural scenarios tied to `INV-ENG-RUNTIME-NODE-VALUE-OWNERS`.
- `tool/src/guardrails/rules/model/model_architecture_rules.dart` - already
  enforces model-layer ownership and runtime node mutable field guardrails, but
  does not yet check runtime/snapshot/backing value-validator parity.
- `tool/run_repository_audits.dart` and
  `tool/audit_schema_family_parity.dart` - current audits pass while `KI-4`
  remains active, proving the existing audit contour does not catch this
  validator drift class.
- temp-package probes with `tool/run_temp_pkg_test.dart` - confirmed that
  public `LineNodeSpec` and `LineNodePatch` oversized thickness mutations fail,
  while public `StrokeNodeSpec` and `StrokeNodePatch` oversized thickness
  mutations currently commit and surface through `controller.snapshot`.

### Current Entry Path

- Public add path:
  `SceneController.scene.addNode(StrokeNodeSpec)` -> interactive mutation
  boundary -> controller write command -> `txnNodeFromSpec` ->
  `StrokeNode` runtime node -> critical commit invariant gate ->
  `sceneCollectRuntimeNodeViolations`.
- Public patch path:
  `SceneController.scene.patchNode(StrokeNodePatch)` -> controller write
  command -> `txnApplyStrokeNodePatch` -> `StrokeNode.thickness` setter ->
  critical commit invariant gate -> `sceneCollectRuntimeNodeViolations`.
- Import/build path:
  `SceneBuilder.buildFromSnapshot` or JSON decode -> model import draft
  value validation -> stroke snapshot/backing validators with
  `sceneThicknessMax`.

### Current Owner

- The owning layer is `lib/src/model/**`, specifically the
  `scene_value_validation_node_*.dart` family validators. The controller commit
  path consumes model-owned validation as the runtime backstop; `core` and
  `contract` remain shape/finite admission owners.

### Adjacent Abstractions

- `_sceneValidateLineNodeFields` is the closest adjacent validated form
  for shared runtime/snapshot/backing line field checks.
- `_sceneValidateRectNodeFields` and `_sceneValidatePathNodeFields`
  are adjacent width-like field validators already shared across the three
  validation surfaces.
- `sceneValidatePositiveDouble` and `sceneValidateDoubleInRange` are
  primitive building blocks, not the semantic vector-width owner.

### Existing Tests

- `test/model/scene_value_validation_primitives_test.dart` - verifies runtime
  and snapshot node value validation behavior and path surfaces.
- `test/controller/core/scene_controller_commit_failures_test.dart` - verifies
  invalid runtime node state is rejected before the committed store is applied.
- `test/model/scene_builder_test.dart` - verifies model import/build range and
  diagnostic behavior.
- `test/public_api/scene_builder_test.dart` - verifies public builder
  diagnostic alignment.
- `test/tool/guardrails/guardrails_model_architecture_tool_test.dart` -
  verifies model architecture guardrail failures.

### Analogous Implementation Path

- `lib/src/model/scene_value_validation_node_line.dart` - line validation is
  the closest valid precedent because runtime, snapshot, and backing validators
  all delegate to one family-field helper that enforces both coordinate ranges
  and thickness range.

### Governing Repository Rules

- `AGENTS.md` - recurring constraints should be mechanically enforced through
  repository-local tests, guardrails, or tooling rather than prose reminders.
- `AGENTS.md` - bugs must be fixed at the shared abstraction, invariant,
  contract, or boundary guard that owns the weakness.
- `ARCHITECTURE.md` - the model layer owns mapping, validation, and
  canonicalization between public immutable documents and mutable runtime
  documents.
- `tool/invariant_registry.dart` - `INV-ENG-RUNTIME-NODE-VALUE-OWNERS`
  requires constrained runtime node fields and patch-based writes to inherit
  the same validated boundary contract.
- `KNOWN_ISSUES.md` - active issue entries must be removed in the same change
  that fixes them and adds regression proof.

### Rejected Misleading Local Patterns

- `StrokeNode.thickness` and `LineNode.thickness` setters in
  `lib/src/core/vector_nodes.dart` - these setters guard positive finite
  runtime storage, but moving `sceneThicknessMax` there would change the
  current constructor/mutation error surface and duplicate model-owned semantic
  range policy.
- `validatePositiveFiniteDoubleValue` in `lib/src/contract/internal/**` -
  this admits public boundary values as shape-valid positive finite numbers,
  but import/build and commit semantics add the scene range policy later.
- `SceneControllerInteractionConfig.requireFinitePositive` - this protects
  UI draw configuration values, not persisted document validity or model import
  semantics.
- render and hit-test clamps such as `clampNonNegativeFinite` - these keep
  rendering robust around malformed runtime values, but they must not become
  document validity policy.

## 4. Architecture

### 4A. Locked Architectural Form

#### Problem Ownership Level

- The defect is an invariant-enforcement gap at the model runtime value
  validation level. It is not a rendering issue, a core storage issue, or a
  public constructor admission issue.

#### Selected Architectural Form

- Introduce one model-owned vector-width semantic validation helper that
  composes the existing primitive checks for finite/sign and
  `sceneThicknessMax`.
- Route stroke runtime, stroke snapshot, stroke backing, line runtime, line
  snapshot, line backing, rectangle `strokeWidth`, and path `strokeWidth`
  validation through family-field helpers that call the shared width helper, so
  the semantic range rule has one owner.
- Extend model architecture guardrails with a structural check that detects
  direct width primitive validation in vector node-family validators when the
  shared width helper must be used.

#### Owning Layer or Module

- Runtime value semantics live in `lib/src/model/scene_value_validation_*`.
- Structural enforcement lives in
  `tool/src/guardrails/rules/model/model_architecture_rules.dart`.
- Runtime commit rejection proof lives under `test/controller/core/**` because
  the controller commit gate is the backstop that applies model validation to
  public mutations.

#### Dependency Direction

- `controller` continues to depend on `model` validation through
  `sceneCollectRuntimeNodeViolations`.
- `model` may depend on `core` limits and node types.
- `core` and `contract` must not depend on `model` to enforce this semantic
  range.
- Guardrail code may inspect source text/AST but must not create runtime
  package dependencies.

#### State and Data Ownership

- Runtime nodes continue to store positive finite numeric fields.
- The model validation layer owns whether a stored width-like value is valid
  for a scene document.
- The committed store owns rejection timing by refusing a state commit before
  applying an invalid runtime scene candidate.

#### Entry and Exit Boundaries

- Entry boundaries are typed public scene mutations, typed snapshot import,
  JSON import/decode, and internal runtime invariant sweeps.
- Exit boundaries are successful committed store state, public snapshots,
  encoded scene data, and `SceneDataException` or `StateError` failure before
  store mutation depending on the caller path.

#### Permitted Extension Seam

- The only permitted new reusable seam is a small model validation helper for
  vector-width semantics and guardrail recognition of that helper in node
  value validators.

#### Rejected Alternatives

- Put `sceneThicknessMax` into `StrokeNode.thickness` and `LineNode.thickness`
  setters - rejected because it changes the current two-stage public admission
  model and can turn model diagnostic failures into `ArgumentError` at a lower
  layer.
- Add the missing `sceneValidateDoubleInRange` call only to
  `sceneValidateStrokeNode` - rejected because it closes the immediate
  symptom while preserving duplicated width policy and allowing the same drift
  class to recur.
- Add a special controller-side check for stroke patches or stroke inserts -
  rejected because the defect belongs to the shared model runtime value
  validator consumed by all commit paths.

#### Why This Level Is Correct

- Import/build already rejects oversized stroke snapshots through model value
  validation, while public add/patch can escape only because the runtime stroke
  validator diverges. The shared owner is therefore the model value-validation
  family, and the controller commit gate should remain a consumer of that owner.

## 5. Locked Decisions

1. The first implementation slice must add a failing behavioral reproducer for
   oversized public stroke insertion or patching before changing validation
   logic.
2. Stroke family validation must be reshaped to use one shared internal
   field-validator path for runtime, snapshot, and backing variants while
   preserving point path aliases.
3. Width semantic validation must be expressed through one model helper rather
   than repeated adjacent calls at each node family validator.
4. The guardrail must fail when a width-like node-family validator bypasses the
   shared width semantic helper.
5. `KI-4` removal and architecture-family status updates happen only after
   behavioral and structural proof is green.

## 6. Result Requirements

1. A public oversized stroke insert cannot commit and cannot change the
   controller snapshot.
2. A public oversized stroke patch cannot commit and cannot change the
   controller snapshot.
3. Runtime, snapshot, and backing stroke validators report the same
   `sceneThicknessMax` upper-bound violation for `thickness`.
4. Line thickness keeps its existing rejection behavior.
5. Rectangle and path `strokeWidth` keep their existing non-negative upper-bound
   behavior.
6. Repository guardrails make future width-validation drift visible without
   relying on `KNOWN_ISSUES.md` prose.
7. `KNOWN_ISSUES.md` no longer lists `KI-4` after the fix and proof land.

## 7. Execution Order and Gates

### Required Order

- Add the failing public mutation reproducer and adjacent guard tests first,
  then introduce the shared model width helper, migrate the in-scope validators,
  and add structural guardrail recognition in the same slice so the locked
  architecture is protected before the slice closes.
- Remove `KI-4` and update documentation only after the behavior and guardrail
  tests pass.
- Update this step document's slice checkboxes as slices close, and update the
  `PLAN.md` step checkbox only after final verification passes.

### Successor Seam and Retirement Gates

- Successor seam: the model-owned vector-width semantic validation helper.
- Retirement gate: no node value validator may directly spell the paired
  positive/non-negative primitive plus `sceneThicknessMax` range logic for an
  in-scope width field when the shared helper applies.
- Documentation gate: `KNOWN_ISSUES.md`, `API_GUIDE.md`, `README.md`,
  `ARCHITECTURE.md`, `CHANGELOG.md`, and
  `docs/architecture/families/serialization_and_schema.md` may be updated or
  audited only after the behavioral and structural verification for this
  contract is green.

### Deferred Broad Verification

- The repository `required_code_change` verification preset is reserved for the
  final gate after all slices and documentation updates are complete.
- Targeted model, controller, public API, and tool tests run slice-locally
  before the final preset.

## 8. File Map

### Implementation Files

- `lib/src/model/scene_value_validation_primitives.dart`
- `lib/src/model/scene_value_validation_node_stroke.dart`
- `lib/src/model/scene_value_validation_node_line.dart`
- `lib/src/model/scene_value_validation_node_rect.dart`
- `lib/src/model/scene_value_validation_node_path.dart`
- `lib/src/model/scene_value_validation_vector_width.dart`
- `tool/src/guardrails/rules/model/model_architecture_rules.dart`

### Test Files

- `test/model/scene_value_validation_primitives_test.dart`
- `test/controller/core/scene_controller_commit_failures_test.dart`
- `test/public_api/scene_builder_test.dart`
- `test/model/scene_builder_test.dart`
- `test/tool/guardrails/guardrails_model_architecture_tool_test.dart`

### Fixtures and Supporting Data

- No new fixture files are required.

### Registry, Inventory, and Workflow Files

- `KNOWN_ISSUES.md`
- `CHANGELOG.md`
- `API_GUIDE.md`
- `ARCHITECTURE.md`
- `README.md` for audit-only landing-page sync under `$readme-sync`
- `docs/architecture/families/serialization_and_schema.md`
- `PLAN.md`
- `plan/step_35_vector_width_runtime_validation_parity.md`

### Analysis Area

- Model value validators for width-like fields:
  `thickness`, `strokeWidth`, and draw-vector width semantics.
- Model architecture guardrail recognition for shared width helper usage.

## 9. Implementation Rules

### Protected Invariants

- `INV-ENG-RUNTIME-NODE-VALUE-OWNERS` - constrained runtime node fields and
  patch-based writes inherit the same validated boundary contract.
- `INV-SER-JSON-NUMERIC-VALIDATION` - JSON numeric fields remain finite and
  validated.
- `INV-SER-IMPORT-DIAGNOSTIC-SURFACE` - caller-visible line/stroke diagnostic
  path names stay stable across JSON and typed snapshot entrypoints.

### Required Proof

- behavioral proof: public stroke insert and patch oversized thickness
  reproducer must fail before implementation and pass after the model owner is
  fixed
- behavioral proof: line, rect, and path neighboring width cases remain aligned
  with their current contracts
- structural proof: model guardrails reject node-family width validation that
  bypasses the shared width helper
- for this bug fix and invariant-enforcement gap: one failing reproducer first,
  plus 1 to 3 neighboring guard tests before the minimum owner-side fix

### Allowed Change Surface

- Add one focused model validation helper for vector width semantics.
- Refactor in-scope node value validators only enough to use that helper and
  remove duplicated width checks.
- Extend model architecture guardrails and guardrail tests only for this
  validator drift class.
- Update public API behavior documentation, release notes, issue inventory,
  architecture documentation, and audit-only README sync only to reflect the
  proven closure.

### Forbidden Moves

- Do not move `sceneThicknessMax` enforcement into `core` runtime setters in
  this step.
- Do not change public constructor admission behavior for specs, snapshots, or
  patches in this step.
- Do not change JSON field names, typed snapshot field names, or diagnostic
  path aliases.
- Do not add controller-special-case validation for stroke thickness.
- Do not broaden the guardrail into a generic text grep that flags unrelated
  numeric range validation.

### Optional: Recognition Forms That Must Be Supported

- Shared helper calls in model node-family validators for:
  - positive width fields such as `thickness`
  - non-negative width fields such as `strokeWidth`
- Family-field helper delegation from runtime, snapshot, and backing validators.

### Optional: Allowed Forms That Are Not Violations

- Coordinate range checks may remain separate because their field names differ
  across line and stroke geometry paths.
- Text derived-bounds range validation may remain in text-specific snapshot and
  backing helpers because it is not a vector-width field.
- Public constructor/schema positive-finite validation may remain separate
  because it is boundary admission, not model semantic scene validity.

### Optional: Resolution Rules

- If a width-like field has a different sign contract, the shared helper must
  expose that sign contract explicitly rather than duplicating primitive calls.
- If guardrail recognition cannot reliably infer a field from AST shape, it
  must use an explicit allowlist of validator function names and field labels
  rather than scanning unrelated Dart files.

## 10. Vertical Slices

### Slice 1. [x] Shared Width Validation And Drift Guardrail

#### Slice Contract

Prove and close the public oversized stroke runtime mutation gap, migrate all
in-scope width validators to one shared model helper, and make future
width-validator drift mechanically visible before the slice closes.

#### Change

Add failing tests before implementation edits for public `StrokeNodeSpec` insert
and `StrokeNodePatch` update with `thickness > sceneThicknessMax`. Add one
neighboring guard for the already-correct line mutation path. Then introduce
the shared model width helper; wire stroke runtime, snapshot, and backing
validation through a shared stroke family-field helper; route line, rect, and
path width validation through the same helper without changing their
geometry-specific validation or caller-visible diagnostic paths. Extend
`model_architecture_rules.dart` to reject in-scope node-family validators that
spell width primitive validation directly instead of using the shared width
helper. Add negative and allowed-form tests in
`guardrails_model_architecture_tool_test.dart`.

#### Behavioral Verification

- `flutter test --no-pub test/model/scene_value_validation_primitives_test.dart`
- `flutter test --no-pub test/controller/core/scene_controller_commit_failures_test.dart`
- `flutter test --no-pub test/model/scene_builder_test.dart`
- `flutter test --no-pub test/public_api/scene_builder_test.dart`
- `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_model_architecture_tool_test.dart`

#### Structural Verification

- `dart run tool/check_guardrails.dart`
- `dart run tool/check_invariant_coverage.dart`

#### Fixtures Used

- Existing controller test fixtures and inline snapshots only.
- Existing raw node subclasses in model tests and existing builder test payloads.
- Existing guardrails sandbox helpers.

#### Positive Scenarios

- Valid stroke insert and patch still commit.
- Valid stroke, line, rect, and path widths remain accepted.
- Typed and JSON diagnostic paths remain caller-visible.
- Current node-family validators using the shared helper pass guardrails.
- Public constructor/schema positive-finite validation is not flagged.

#### Negative Scenarios

- Oversized stroke insert and patch must fail after the fix and leave the store
  unchanged.
- Oversized line insert or patch remains rejected.
- Oversized stroke runtime, snapshot, and backing thickness are rejected.
- Oversized line thickness remains rejected.
- Oversized rect/path `strokeWidth` remains rejected.
- A sandboxed stroke runtime validator that validates `thickness` with
  positive-only or duplicated primitive-plus-range calls fails guardrails.

#### Closure Evidence

- The new stroke tests fail before the model validation fix, pass after the
  slice implementation, and the neighboring line guard remains green.
- All slice-local behavioral tests pass and the line/stroke public mutation
  behavior is aligned.
- Guardrail negative tests fail before the guardrail change and pass after it;
  `check_guardrails` remains green on the repository.

### Slice 2. [x] Issue and Documentation Closure

#### Slice Contract

Retire `KI-4` only after runtime behavior and structural enforcement are proven.

#### Change

Remove `KI-4` from `KNOWN_ISSUES.md`, update `API_GUIDE.md` for the public
runtime validation/error behavior, update
`docs/architecture/families/serialization_and_schema.md` status away from this
known issue, audit `ARCHITECTURE.md` for whether the existing model-validation
ownership text already covers the enforced helper, and add a concise
`CHANGELOG.md` unreleased entry for the user-visible validation fix. Audit
`README.md` under `$readme-sync`; leave it unchanged when it remains a concise
landing page that points runtime behavior detail to `API_GUIDE.md` and does not
state stale thickness-limit behavior. Update the Step 35 plan checkboxes after
the required proof for this step is green.

#### Behavioral Verification

- `dart run tool/run_repository_audits.dart`

#### Structural Verification

- `dart run tool/check_guardrails.dart`
- `dart run tool/check_invariant_coverage.dart`

#### Fixtures Used

- No fixtures.

#### Positive Scenarios

- Architecture docs no longer describe `KI-4` as active.
- `API_GUIDE.md` describes the public runtime validation/error behavior for
  oversized vector widths.
- `README.md` remains accurate as a landing page or receives only the smallest
  landing-page wording update required by `$readme-sync`.

#### Negative Scenarios

- No active known issue entry remains for a defect that has regression proof.

#### Closure Evidence

- `KNOWN_ISSUES.md` no longer contains `KI-4`, and repository audits remain
  green.
- Documentation sync is complete for `API_GUIDE.md`, `README.md`,
  `ARCHITECTURE.md`, `CHANGELOG.md`, and the architecture-family document.

## 11. Final Verification

- Generate an untracked newline-delimited changed-paths file at
  `/tmp/iwb_step_35_changed_paths.txt` for the final preset.
- `dart run tool/run_verification_preset.dart run --preset=required_code_change --changed-paths-file=/tmp/iwb_step_35_changed_paths.txt`
- `dcm calculate-metrics lib/src/model/scene_value_validation_primitives.dart lib/src/model/scene_value_validation_vector_width.dart lib/src/model/scene_value_validation_node_stroke.dart lib/src/model/scene_value_validation_node_line.dart lib/src/model/scene_value_validation_node_rect.dart lib/src/model/scene_value_validation_node_path.dart`
- `dart run tool/run_repository_audits.dart`

## 12. Acceptance Criteria

- Oversized public stroke insert and patch attempts fail before committed state
  changes.
- Valid stroke, line, rect, and path width values continue to work.
- Runtime, snapshot, and backing stroke validation all enforce
  `sceneThicknessMax`.
- Line, rect, and path width validation keep their existing contracts.
- The model architecture guardrail prevents reintroducing direct drift-prone
  width validation in node-family validators.
- `KI-4` is removed from `KNOWN_ISSUES.md` only with passing regression proof.
