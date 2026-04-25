# Change Contract

## 1. Change Mandate

Unify public-proof source-of-truth so the effective public namespace of
`lib/iwb_canvas_engine.dart` drives both public-surface evidence and public
signature hermeticity checks, while direct export-owner policy remains a
separate barrel-layout proof.

## 2. Change Boundary

### Included in the Change

- introduce one shared effective-public-namespace support seam for public proof
  tooling
- keep direct export-owner policy explicit, but stop using it as the full scan
  scope for public-signature hermeticity
- add one new guardrail runner artifact for effective exported public elements
  and owners
- switch the public-signature guardrail to scan real exported owners from the
  effective entrypoint namespace
- add transitive re-export regression tests for public-signature hermeticity,
  including `show` / `hide` behavior
- update proof inventory tooling, target-proof evidence, and target-proof map
  docs to reflect the landed shape
- add this step to `PLAN.md` and update both files together when the step
  closes

### Not Included in the Change

- no change to controller, interactive, model, or contract guardrail families
  outside the public-proof path
- no cleanup of unrelated guardrail rules, invariant ids, or verification-step
  definitions
- no change to the supported public API symbol set unless a regression test
  proves the current public-surface tool was wrong
- no analyzer plugin, quick-fix, or new generic hygiene-tool wave
- no change to `docs/target_architecture/**`

## 3. Surrounding Code Review

### Inspected Artifacts

- `docs/target_proof_architecture/overview.md` - the only provisional proof
  families are `Public entrypoint and signature proof` and
  `Guardrail runner and artifact model`, so the strongest remaining proof debt
  is local to the public-proof layer
- `docs/target_proof_architecture/families/public_entrypoint_and_signature_proof.md`
  - the target already states that effective public namespace, real owner
  resolution, and signature-proof scope must align
- `docs/target_proof_architecture/families/guardrail_runner_and_artifact_model.md`
  - the runner-family target already states that one shared artifact must not
  silently stand in for two different proof universes
- `docs/target_proof_architecture/evidence/public_export_namespace.md` -
  mechanically proves that `lib/iwb_canvas_engine.dart` currently has
  `13` transitively exported owner files and `16` transitively exported symbols
  under `snapshot.dart` and `validated.dart`
- `docs/target_proof_architecture/evidence/proof_inventory.md` - mechanically
  proves that `check_guardrails.dart` currently has `6` rules and one shared
  runner artifact, `exportedSurfaces`, written by `public-surface` and read by
  `public-signature`
- `tool/check_public_api_surface.dart` - already uses
  `result.element.exportNamespace.definedNames2.keys`, so it is the closest
  checked-in precedent for effective public namespace truth
- `tool/src/guardrails/rules/public/public_surface_rules.dart` - currently owns
  direct export-target collection, direct export policy, and the shared
  `exportedSurfaces` runner artifact
- `tool/src/guardrails/rules/public/public_signature_rules.dart` - currently
  uses `exportNamespace` only to derive visible type owners, but still scans
  local declarations of direct export-target libraries via `_collectExportedElements(...)`
- `tool/src/guardrails/core/guardrail_run_state.dart` - runner artifacts are
  explicit and contract-checked, so any new proof universe must land as a
  declared artifact rather than an implicit side path
- `test/tool/guardrails/guardrails_public_signature_hermeticity_tool_test.dart`
  - already proves direct-export signature hermeticity and raw collection leak
  behavior, but does not model transitive contract barrels such as
  `validated.dart -> validated/node_id_value.dart` or
  `snapshot.dart -> ids.dart`
- `test/tool/guardrails/guardrails_public_surface_tool_test.dart` - already
  proves direct export policy and ordered `show` / `hide` behavior at the
  public entrypoint
- `test/tool/public_api_surface_tool_test.dart` - already proves that the
  public-surface golden tool sees transitively re-exported symbols through
  `exportNamespace`
- `test/tool/guardrails/guardrails_rule_inventory_tool_test.dart` - already
  locks the public guardrail rule inventory, artifact handoff, and fail-fast
  runner behavior
- `tool/trace_export_namespace.dart` - already exposes the mechanical mismatch
  between direct export targets and effective owner files
- `tool/trace_proof_inventory.dart` - already exposes the current runner
  artifact handoff for public guardrails
- `test/tool/trace_export_namespace_tool_test.dart`,
  `test/tool/trace_proof_inventory_tool_test.dart`, and
  `test/tool/target_proof_architecture_map_tool_test.dart` - already lock the
  new proof-map foundation and evidence generators

### Current Entry Path

- public-surface golden path:
  `tool/check_public_api_surface.dart` ->
  `ResolvedLibraryResult.element.exportNamespace.definedNames2`
- public guardrail path:
  `tool/check_guardrails.dart` ->
  `public-surface` rule ->
  `exportedSurfaces` artifact ->
  `public-signature` rule ->
  direct exported libraries only ->
  local declarations only

### Current Owner

- the defect is owned by the public-proof tooling layer under
  `tool/check_public_api_surface.dart` plus
  `tool/src/guardrails/rules/public/**`

### Adjacent Abstractions

- `tool/src/guardrails/rules/public/entrypoint_layout_rules.dart` - adjacent
  public-proof boundary that should stay focused on barrel-layout policy
- `test/tool/support/public_entrypoint_contract.dart` - canonical direct export
  scaffold for public-entrypoint tool tests
- `tool/src/guardrails/guardrail_rule_inventory.dart` - explicit rule-order
  owner that must stay consistent with any new artifact handoff
- `tool/invariant_registry.dart` - invariant reachability owner that already
  stays locked and should not absorb public-proof policy

### Existing Tests

- `test/tool/public_api_surface_tool_test.dart` - locks effective entrypoint
  export namespace behavior, including transitive re-exports and ordered
  `show` / `hide`
- `test/tool/guardrails/guardrails_public_signature_hermeticity_tool_test.dart`
  - locks direct-export signature hermeticity cases and neighboring callback
  leak paths
- `test/tool/guardrails/guardrails_public_surface_tool_test.dart` - locks
  public export policy and direct-entrypoint `show` / `hide` behavior
- `test/tool/guardrails/guardrails_rule_inventory_tool_test.dart` - locks
  public rule metadata plus current `exportedSurfaces` handoff
- `test/tool/trace_export_namespace_tool_test.dart` - locks the new mechanical
  export-namespace evidence generator
- `test/tool/trace_proof_inventory_tool_test.dart` - locks the new mechanical
  proof inventory generator
- `test/tool/target_proof_architecture_map_tool_test.dart` - locks the proof
  target-map directory structure and evidence links

### Analogous Implementation Path

- `tool/check_public_api_surface.dart` - closest valid precedent because it
  already uses `exportNamespace` as the effective public-symbol source of truth
  instead of direct export-owner local declarations

### Governing Repository Rules

- `AGENTS.md` - fix root causes at the owner of the invariant rather than
  patching individual call sites or tests
- `AGENTS.md` - recurring repository knowledge must be enforced mechanically in
  repository-local tooling or tests
- `AGENTS.md` / project verification instructions - code changes must run
  targeted checks and ultimately the required verification preset before close
- `/Users/blackpika/.codex/skills/change-contract/SKILL.md` - architecture,
  seam-retirement timing, and verification strategy must be locked before
  implementation starts

### Rejected Misleading Local Patterns

- keep `exportedSurfaces` as the only proof universe and add more negative
  tests only - wrong level because the source-of-truth mismatch would remain
- make `public-signature` compute its own independent export-namespace scan
  without a shared support seam - wrong because it would create a second
  duplicated truth next to `check_public_api_surface.dart`
- flatten contract barrels such as `validated.dart` or `snapshot.dart` just to
  satisfy the current guardrail - wrong owner because the defect is in proof
  tooling, not in the public API layout itself
- broaden this step into interactive/controller/model guardrail cleanup - wrong
  scope because current mechanical evidence isolates the strongest gap to the
  public-proof family

## 4. Architecture

### 4A. Locked Architectural Form

#### Problem Ownership Level

- one proof-layer cleanup across public-surface tooling, public guardrails, and
  proof-map evidence

#### Selected Architectural Form

- keep two explicit proof universes instead of one ambiguous one:
  - direct export-owner surfaces for public barrel-layout policy
  - effective public namespace elements and real owner paths for signature
    hermeticity and public-surface evidence
- introduce one shared effective-public-namespace support seam that resolves
  exported public elements and their real owner files from
  `lib/iwb_canvas_engine.dart`
- keep `public-surface` as the rule that owns direct export-target policy and
  writes runner artifacts
- add one new runner artifact for effective exported public elements and owner
  paths
- switch `public-signature` to read the new effective namespace artifact for
  scan scope, while leaving direct export-target policy in `public-surface`
- keep `check_public_api_surface.dart` on the same effective-public-namespace
  seam so the golden public surface and public-signature proof share one source
  of truth

#### Owning Layer or Module

- `tool/check_public_api_surface.dart`
- `tool/src/guardrails/rules/public/**`
- one new shared support file in the public guardrail/tooling layer

#### Dependency Direction

- public entrypoint ->
  shared effective-public-namespace support ->
  `check_public_api_surface.dart`
- public entrypoint ->
  `public-surface` rule ->
  direct export-owner artifact plus effective namespace artifact ->
  `public-signature` rule
- trace tools and proof-map evidence may read the same shared support seam or
  the resulting artifacts, but they do not own policy

#### State and Data Ownership

- direct export-owner layout stays owned by `ExportedLibrarySurface` and the
  existing `exportedSurfaces` artifact
- effective exported public elements and real owner paths become a distinct
  data model with a distinct runner artifact
- invariant ownership remains in `tool/invariant_registry.dart`; this step
  does not move invariants or change their ids

#### Entry and Exit Boundaries

- entry boundaries:
  `tool/check_public_api_surface.dart` and `tool/check_guardrails.dart`
- exit boundaries:
  public-surface golden diagnostics,
  guardrail signature-hermeticity violations,
  proof inventory trace output,
  export-namespace trace output,
  target-proof evidence under `docs/target_proof_architecture/evidence`

#### Permitted Extension Seam

- one new shared support file for effective public namespace collection is
  allowed
- one new guardrail runner artifact is allowed
- test-only sandbox scaffolds may gain the minimum transitive re-export helper
  files needed to model the new regression cases

#### Rejected Alternatives

- keep one shared `exportedSurfaces` artifact for both direct layout and
  effective namespace proof - wrong because it is the confirmed root cause of
  the current proof gap
- move effective namespace collection into tests only - wrong because the
  source-of-truth must live in production tooling, not in regression fixtures
- fix only `check_public_api_surface.dart` or only `public-signature` -
  wrong because the contract requires one shared truth for both

#### Why This Level Is Correct

- the mismatch is between two checked-in proof paths in the same tooling layer
- the public API layout itself already works; the defect is in how proof scope
  is modeled
- one shared support seam and one explicit new artifact solve the mismatch once
  without forcing layout changes onto the public barrels

## 5. Locked Decisions

1. `public-surface` keeps `exportedSurfaces` for direct export-owner policy;
   that artifact is not retired in this step.
2. A second runner artifact is added for effective exported public elements and
   owner paths; `public-signature` reads that artifact instead of deriving scan
   scope from direct export-owner files.
3. `check_public_api_surface.dart` adopts the same shared effective-public-
   namespace seam instead of continuing as a separate ad hoc implementation.
4. The first regression reproducer is a transitive re-export hidden-helper leak
   in `guardrails_public_signature_hermeticity_tool_test.dart`; implementation
   changes do not start before that failing case is named in the slice.
5. This step is expected to close both currently provisional proof families;
   proof-map docs and evidence must be refreshed in the same change.

## 6. Result Requirements

1. Public-surface golden and public-signature hermeticity use one effective
   public namespace truth for exported symbol visibility and real owner
   resolution.
2. Direct export-owner policy remains explicit and independently enforced, but
   no longer defines the full public-signature scan scope.
3. A transitively re-exported public class, enum, typedef, or function is
   checked for hidden/internal signature leaks exactly like a directly exported
   declaration.
4. Ordered `show` / `hide` semantics remain preserved for both golden public
   surface and signature-proof coverage.
5. The guardrail runner artifact model becomes explicit enough that public
   barrel layout and effective public namespace no longer share one ambiguous
   artifact.
6. `docs/target_proof_architecture/**` reflects the landed form and committed
   evidence for the public-proof layer.

## 7. Execution Order and Gates

### Required Order

- add the transitive re-export failing reproducer and 1 to 3 neighboring guard
  tests before any shared-seam or runner-artifact implementation edits
- land the shared effective-public-namespace support seam only after the new
  failing public-signature cases are checked in
- switch the public-signature guardrail to the new artifact only after the
  reproducer exists and the shared support seam is in place
- refresh proof evidence and target-proof docs only after code, runner
  artifacts, and regression tests are green

### Successor Seam and Retirement Gates

- successor seam:
  the shared effective-public-namespace support plus the new effective
  namespace runner artifact
- consumer migration order:
  1. public-signature regression fixtures and tests
  2. `check_public_api_surface.dart`
  3. `public-surface` rule writer path
  4. `public-signature` rule reader path
  5. proof inventory / proof-map evidence
- retirement gate:
  `public-signature` may stop depending on `exportedSurfaces` for scan scope
  only after:
  `guardrails_public_signature_hermeticity_tool_test.dart`,
  `guardrails_rule_inventory_tool_test.dart`,
  `trace_proof_inventory_tool_test.dart`, and
  `trace_export_namespace_tool_test.dart`
  all reflect the new artifact handoff and transitive regression cases

### Deferred Broad Verification

- `dart run tool/check_public_api_surface.dart` - reserve for slice gates after
  the shared support seam lands and for the final gate
- `dart run tool/check_guardrails.dart` - reserve for slice gates after the new
  artifact handoff lands and for the final gate
- `dart run tool/check_invariant_coverage.dart` - reserve for the final gate
- `dart run tool/run_verification_preset.dart run --preset=required_code_change --changed-paths-file=-`
  - reserve for the final gate only

## 8. File Map

### Implementation Files

- `PLAN.md`
- `plan/step_23_effective_public_namespace_and_signature_proof_unification.md`
- `tool/check_public_api_surface.dart`
- `tool/src/guardrails/core/guardrail_run_state.dart`
- `tool/src/guardrails/rules/public/public_surface_rules.dart`
- `tool/src/guardrails/rules/public/public_signature_rules.dart`
- `tool/src/guardrails/rules/public/public_export_namespace_support.dart`
- `tool/trace_export_namespace.dart`
- `tool/trace_proof_inventory.dart`

### Test Files

- `test/tool/public_api_surface_tool_test.dart`
- `test/tool/guardrails/guardrails_public_signature_hermeticity_tool_test.dart`
- `test/tool/guardrails/guardrails_public_surface_tool_test.dart`
- `test/tool/guardrails/guardrails_rule_inventory_tool_test.dart`
- `test/tool/trace_export_namespace_tool_test.dart`
- `test/tool/trace_proof_inventory_tool_test.dart`
- `test/tool/target_proof_architecture_map_tool_test.dart`

### Fixtures and Supporting Data

- `test/tool/support/public_entrypoint_contract.dart`
- `test/tool/support/guardrails_sandbox_support.dart`

### Registry, Inventory, and Workflow Files

- `docs/target_proof_architecture/overview.md`
- `docs/target_proof_architecture/families/public_entrypoint_and_signature_proof.md`
- `docs/target_proof_architecture/families/guardrail_runner_and_artifact_model.md`
- `docs/target_proof_architecture/evidence/public_export_namespace.json`
- `docs/target_proof_architecture/evidence/public_export_namespace.md`
- `docs/target_proof_architecture/evidence/proof_inventory.json`
- `docs/target_proof_architecture/evidence/proof_inventory.md`

### Analysis Area

- `tool/check_public_api_surface.dart`
- `tool/src/guardrails/rules/public/**`
- `tool/src/guardrails/core/guardrail_run_state.dart`
- `test/tool/public_api_surface_tool_test.dart`
- `test/tool/guardrails/guardrails_public*_tool_test.dart`
- `test/tool/guardrails/guardrails_rule_inventory_tool_test.dart`
- `docs/target_proof_architecture/**`

## 9. Implementation Rules

### Protected Invariants

- `INV-G-PUBLIC-ENTRYPOINTS`
- `INV-ENG-SAFE-TXN-API`
- `INV-ENG-PUBLIC-SURFACE-NO-MUTABLE-TYPES`
- `INV-ENG-PUBLIC-SIGNATURE-HERMETICITY`

### Required Proof

- behavioral proof:
  transitive re-export signature leaks must fail in
  `guardrails_public_signature_hermeticity_tool_test.dart`,
  direct-export `show` / `hide` policy must stay green in
  `guardrails_public_surface_tool_test.dart`, and the public-surface golden
  tool must stay green in `public_api_surface_tool_test.dart`
- structural proof:
  `guardrails_rule_inventory_tool_test.dart`,
  `trace_proof_inventory_tool_test.dart`, and
  `target_proof_architecture_map_tool_test.dart`
  must make the new artifact split and locked proof-map shape mechanically
  visible
- for bug fixes, regressions, false positives, false negatives, and
  invariant-enforcement gaps: one failing reproducer first, plus 1 to 3 guard
  tests for neighboring branches of the same contract

### Allowed Change Surface

- only the files listed in section 8
- one new public-proof support file is allowed
- sandbox fixture helpers may change only as needed to express the transitive
  re-export regression cases

### Forbidden Moves

- do not change non-public guardrail families in this step
- do not flatten or delete public contract barrels such as `validated.dart` or
  `snapshot.dart` to work around the proof gap
- do not broaden this step into public API redesign, symbol renaming, or
  package export-surface cleanup
- do not change invariant ids or required proof step ids in this step
- do not change `tool/goldens/public_api_symbols.txt` unless a regression test
  proves the current effective public namespace golden is wrong

### Optional: Recognition Forms That Must Be Supported

- direct export of a public declaration
- transitive re-export through one barrel
- transitive re-export through ordered `show` / `hide` combinators
- transitively exported type aliases, enums, classes, and top-level functions

### Optional: Allowed Forms That Are Not Violations

- direct export-owner layout policy remains separate from effective namespace
  proof
- transitively exported public symbols that use only SDK or publicly visible
  types remain valid

### Optional: Resolution Rules

- resolve public symbol visibility from the effective entrypoint namespace first
- resolve the real owner file of the exported element second
- apply signature-leak traversal to that resolved exported element and its
  public members third

## 10. Vertical Slices

### Slice 1. [ ] Transitive Proof Reproducer Lock

#### Slice Contract

Lock the public-signature proof gap with one failing transitive re-export
reproducer and 1 to 3 neighboring guard tests before any implementation-side
seam or artifact changes begin.

#### Change

- add one failing reproducer in
  `guardrails_public_signature_hermeticity_tool_test.dart` for a hidden helper
  leak on a transitively re-exported public owner
- add 1 to 3 neighboring guard tests for:
  transitive positive pass,
  transitive `show` / `hide`, and
  contract-barrel owner resolution
- update `guardrails_public_surface_tool_test.dart` only if one neighboring
  direct-export policy guard is needed to keep barrel-layout proof separate
- update test-only sandbox support only as needed to model the transitive
  re-export cases

#### Behavioral Verification

- `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_public_signature_hermeticity_tool_test.dart test/tool/guardrails/guardrails_public_surface_tool_test.dart`

#### Structural Verification

- `dart run tool/run_tool_tests.dart test/tool/public_api_surface_tool_test.dart`
  This locks that transitive visibility through the public entrypoint remains
  mechanically visible before the owner-side proof fix lands.

#### Fixtures Used

- `test/tool/support/public_entrypoint_contract.dart`
- `test/tool/support/guardrails_sandbox_support.dart`

#### Positive Scenarios

- a transitively re-exported public owner with only SDK or publicly visible
  types is modeled as a valid neighboring case
- ordered `show` / `hide` still separates visible and hidden transitive owners
  in the regression suite

#### Negative Scenarios

- a transitively re-exported public owner that exposes a hidden helper type
  fails with `public signature hermeticity violation`

#### Closure Evidence

- the regression suite contains a failing transitive proof-gap reproducer
  before any owner-side implementation edit starts

### Slice 2. [ ] Shared Effective Namespace Support

#### Slice Contract

Introduce one shared effective-public-namespace support seam that both the
public-surface golden tool and the export-namespace trace tool can use, while
the new transitive reproducer remains the behavioral lock for the later fix.

#### Change

- add `public_export_namespace_support.dart` with the effective entrypoint
  namespace collection logic
- migrate `tool/check_public_api_surface.dart` to the shared support seam
- migrate `tool/trace_export_namespace.dart` to the shared support seam
- update `public_api_surface_tool_test.dart` and
  `trace_export_namespace_tool_test.dart` only as needed to lock the shared
  support behavior

#### Behavioral Verification

- `dart run tool/run_tool_tests.dart test/tool/public_api_surface_tool_test.dart test/tool/trace_export_namespace_tool_test.dart`
- `dart run tool/check_public_api_surface.dart`

#### Structural Verification

- `dart run tool/trace_export_namespace.dart lib/iwb_canvas_engine.dart --json-out=docs/target_proof_architecture/evidence/public_export_namespace.json --md-out=docs/target_proof_architecture/evidence/public_export_namespace.md`

#### Fixtures Used

- `test/tool/public_api_surface_tool_test.dart`

#### Positive Scenarios

- the public-surface golden tool still sees transitive re-exports and ordered
  `show` / `hide`
- the export-namespace trace still shows the transitive owner files behind
  `snapshot.dart` and `validated.dart`

#### Negative Scenarios

- no independent ad hoc effective-namespace collection remains in
  `check_public_api_surface.dart`

#### Closure Evidence

- `public_export_namespace.json|md` is regenerated from the shared support seam

### Slice 3. [ ] Effective Namespace Guardrail Handoff

#### Slice Contract

Split the public guardrail runner state so direct export-owner policy and
effective exported public namespace become distinct artifacts, then make the
previously failing transitive public-signature reproducer pass through the new
artifact handoff.

#### Change

- add one new runner artifact id in `guardrail_run_state.dart`
- update `public_surface_rules.dart` to keep writing `exportedSurfaces` and to
  additionally write the new effective namespace artifact
- update `public_signature_rules.dart` to read the new artifact and scan real
  exported owner files instead of local declarations of direct export targets
- update `guardrails_rule_inventory_tool_test.dart` and
  `trace_proof_inventory_tool_test.dart` for the new artifact handoff

#### Behavioral Verification

- `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_public_signature_hermeticity_tool_test.dart test/tool/guardrails/guardrails_rule_inventory_tool_test.dart test/tool/trace_proof_inventory_tool_test.dart`
- `dart run tool/check_guardrails.dart`

#### Structural Verification

- `dart run tool/trace_proof_inventory.dart --json-out=docs/target_proof_architecture/evidence/proof_inventory.json --md-out=docs/target_proof_architecture/evidence/proof_inventory.md`

#### Fixtures Used

- none

#### Positive Scenarios

- direct export-owner policy still remains available to `public-surface`
- the previously failing transitive hidden-helper reproducer is now the live
  behavioral proof that `public-signature` reads the effective namespace
  artifact on a real transitive export scenario
- proof inventory now shows a distinct effective namespace artifact instead of
  one ambiguous handoff

#### Negative Scenarios

- `public-signature` no longer reads only `exportedSurfaces` for scan scope
- one shared artifact no longer stands in for both direct layout and effective
  namespace proof

#### Closure Evidence

- `proof_inventory.json|md` is regenerated and shows the split artifact model

### Slice 4. [ ] Proof Map Lock And Evidence Refresh

#### Slice Contract

Refresh the proof target map and committed evidence after the new effective
namespace truth and runner artifact handoff are already green.

#### Change

- refresh `docs/target_proof_architecture/overview.md`,
  `families/public_entrypoint_and_signature_proof.md`,
  `families/guardrail_runner_and_artifact_model.md`,
  `evidence/public_export_namespace.*`, and
  `evidence/proof_inventory.*`
- update `target_proof_architecture_map_tool_test.dart` if the locked-proof
  family statuses need stronger assertions

#### Behavioral Verification

- `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_public_signature_hermeticity_tool_test.dart test/tool/guardrails/guardrails_public_surface_tool_test.dart test/tool/public_api_surface_tool_test.dart`
- `dart run tool/check_guardrails.dart`
- `dart run tool/check_public_api_surface.dart`

#### Structural Verification

- `dart run tool/run_tool_tests.dart test/tool/target_proof_architecture_map_tool_test.dart`
- `dart run tool/trace_export_namespace.dart lib/iwb_canvas_engine.dart --json-out=docs/target_proof_architecture/evidence/public_export_namespace.json --md-out=docs/target_proof_architecture/evidence/public_export_namespace.md`
- `dart run tool/trace_proof_inventory.dart --json-out=docs/target_proof_architecture/evidence/proof_inventory.json --md-out=docs/target_proof_architecture/evidence/proof_inventory.md`

#### Fixtures Used

- `test/tool/support/public_entrypoint_contract.dart`
- `test/tool/support/guardrails_sandbox_support.dart`

#### Positive Scenarios

- a transitively re-exported public owner with only SDK or publicly visible
  types passes hermeticity
- ordered `show` / `hide` still preserves correct visibility for transitive
  proof coverage

#### Negative Scenarios

- transitively hidden owners do not trigger false positives when they are not
  effectively visible through the public entrypoint

#### Closure Evidence

- both provisional proof families in `docs/target_proof_architecture/overview.md`
  are updated to `locked`
- committed proof evidence matches the landed code and runner-artifact model

## 11. Final Verification

- `dart run tool/run_tool_tests.dart test/tool/public_api_surface_tool_test.dart test/tool/guardrails/guardrails_public_surface_tool_test.dart test/tool/guardrails/guardrails_public_signature_hermeticity_tool_test.dart test/tool/guardrails/guardrails_rule_inventory_tool_test.dart test/tool/trace_export_namespace_tool_test.dart test/tool/trace_proof_inventory_tool_test.dart test/tool/target_proof_architecture_map_tool_test.dart`
- `dart run tool/check_public_api_surface.dart`
- `dart run tool/check_guardrails.dart`
- `dart run tool/check_invariant_coverage.dart`
- `printf '%s\n' 'PLAN.md' 'plan/step_23_effective_public_namespace_and_signature_proof_unification.md' 'tool/check_public_api_surface.dart' 'tool/src/guardrails/core/guardrail_run_state.dart' 'tool/src/guardrails/rules/public/public_surface_rules.dart' 'tool/src/guardrails/rules/public/public_signature_rules.dart' 'tool/src/guardrails/rules/public/public_export_namespace_support.dart' 'tool/trace_export_namespace.dart' 'tool/trace_proof_inventory.dart' 'test/tool/public_api_surface_tool_test.dart' 'test/tool/guardrails/guardrails_public_signature_hermeticity_tool_test.dart' 'test/tool/guardrails/guardrails_public_surface_tool_test.dart' 'test/tool/guardrails/guardrails_rule_inventory_tool_test.dart' 'test/tool/trace_export_namespace_tool_test.dart' 'test/tool/trace_proof_inventory_tool_test.dart' 'test/tool/target_proof_architecture_map_tool_test.dart' 'test/tool/support/public_entrypoint_contract.dart' 'test/tool/support/guardrails_sandbox_support.dart' 'docs/target_proof_architecture/overview.md' 'docs/target_proof_architecture/families/public_entrypoint_and_signature_proof.md' 'docs/target_proof_architecture/families/guardrail_runner_and_artifact_model.md' 'docs/target_proof_architecture/evidence/public_export_namespace.json' 'docs/target_proof_architecture/evidence/public_export_namespace.md' 'docs/target_proof_architecture/evidence/proof_inventory.json' 'docs/target_proof_architecture/evidence/proof_inventory.md' | dart run tool/run_verification_preset.dart run --preset=required_code_change --changed-paths-file=-`

## 12. Acceptance Criteria

- the effective public namespace and real owner files are the shared source of
  truth for both public-surface golden evidence and public-signature
  hermeticity
- direct export-owner policy remains explicit and independent
- transitive re-export leaks are caught mechanically by public-signature
  regression tests and `check_guardrails.dart`
- the public-proof runner artifact model is explicit enough that one artifact
  no longer stands in for two proof universes
- `docs/target_proof_architecture/overview.md` shows no remaining provisional
  proof families for the current proof-wave scope
