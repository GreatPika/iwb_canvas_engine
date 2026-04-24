# Change Contract

## 1. Change Mandate

Normalize `docs/target_architecture/**` into a short, code-backed, mechanically
checkable target map that stays aligned with ADR 0001, checked-in runtime
owners, and the repository-local LSP probe workflow.

## 2. Change Boundary

### Included in the Change

- rewrite `docs/target_architecture/README.md` so it defines the directory as a
  verification-first target map instead of a prose-heavy architecture note set
- slim `docs/target_architecture/overview.md` into a concise owner-family
  registry with stable status vocabulary and explicit verification status,
  without hand-drawn diagrams
- slim `docs/target_architecture/execution_flows.md` into a short runtime view
  registry that links only to mechanically generated flow artifacts and states
  the target boundary each artifact is used to check
- normalize every family document under `docs/target_architecture/families/`
  to one compact section format that records the family purpose, target rules,
  owner buckets, forbidden shapes, mechanical evidence, and current status
- correct target-doc claims that are stale against checked-in code where the
  accepted top-level architecture has already landed locally, especially the
  view/runtime render-read split
- add committed machine-generated evidence artifacts under
  `docs/target_architecture/evidence/` using only the checked-in LSP probes for
  every flow/path/diagram referenced by the target map
- add one lightweight structural tool test that fails when the target-map
  documents lose the required section shape, status vocabulary, or mechanical
  evidence blocks, and also fails if target-map docs reintroduce hand-written
  flow/diagram blocks
- update `PLAN.md` and this step document together when the step is executed

### Not Included in the Change

- no runtime-owner refactor in `lib/src/**`
- no change to the accepted top-level target in
  `docs/adr/0001_target_engine_architecture.md`
- no phase-2 optimization contract from
  `docs/adr/0002_post_target_optimization_scope.md`
- no rewrite of `ARCHITECTURE.md`; that document owns checked-in current
  architecture, while this step owns the target map only
- no new manifest, DSL, or standalone architecture product beyond the minimum
  structural test support needed to keep the target map checkable
- no target-map coverage for the current `Import And Build Flow` diagram from
  `execution_flows.md`; the checked-in LSP probes created in the previous step
  do not mechanically derive that model/import path, so this normalization step
  will remove it from the target runtime-view registry instead of inventing a
  hand-maintained successor
- no DCM-driven or hand-written flow diagram as canonical target-map content
- no raw metric dump, method-count inventory, or long mismatch narrative as
  canonical target-map body text

## 3. Surrounding Code Review

### Inspected Artifacts

- `PLAN.md` - the active plan index requires one dedicated step document per
  execution contract
- `docs/adr/0001_target_engine_architecture.md` - fixes the accepted top-level
  target owner map and boundary directions
- `docs/adr/0002_post_target_optimization_scope.md` - explicitly reserves
  phase-2 optimization contracts for later and does not authorize a new
  top-level target
- `docs/target_architecture/README.md` - already positions this directory as
  the working target map and now documents the new LSP probe workflow
- `docs/target_architecture/overview.md` - already owns the top-level target
  owner map, family registry, and action vocabulary
- `docs/target_architecture/execution_flows.md` - already owns the target
  control/data movement, but must stay short and boundary-focused
- `docs/target_architecture/families/composition_root_and_facade.md` - already
  locks the composition family target, but currently carries long mismatch
  narrative instead of a short contract plus machine evidence
- `docs/target_architecture/families/interaction_runtime.md` - already locks
  the interaction family target and local owner inventory, but is broader than
  needed for a working map
- `docs/target_architecture/families/mutation_gateway.md` - already locks the
  gateway family target, but does not yet express thin-wrapper debt as an
  explicit forbidden target shape
- `docs/target_architecture/families/store_and_commit_path.md` - already locks
  the store/commit family target, but the stable owner map is mixed with
  temporary mechanical detail
- `docs/target_architecture/families/view_runtime_and_render_seam.md` - still
  describes the render-read split as future work even though the checked-in
  runtime contract and implementation have already landed locally
- `docs/target_architecture/families/view_runtime_and_render_seam.md`,
  `lib/src/contract/scene_view_runtime.dart`,
  `lib/src/contract/scene_view_render_state.dart`, and
  `lib/src/interactive/internal/scene_controller_scene_view_runtime.dart` -
  together show that `SceneViewRuntime` already exposes `mainSceneRenderRead`
  and `overlayPreviewRead`, so the family doc is stale at the local-owner level
- `lib/src/view/scene_view_runtime_host.dart` - checked-in runtime host still
  consumes the `SceneViewRuntime` boundary and is part of the current
  runtime-view path that the new artifact set must document mechanically
- `lib/src/view/scene_view_render_surface.dart` - checked-in main-scene
  consumer proves the render-side consumer path that the runtime-view registry
  must reference through machine-generated evidence
- `lib/src/view/scene_view_interactive_overlay_painter.dart` - checked-in
  overlay consumer proves the overlay-side consumer path that the runtime-view
  registry must reference through machine-generated evidence
- `lib/src/interactive/internal/scene_controller_graph.dart` - checked-in code
  still supports the target claim that composition-root pressure is centered in
  one internal assembly owner
- `lib/src/interactive/internal/scene_controller_interaction_runtime.dart` and
  `lib/src/interactive/internal/interactive_runtime.dart` - checked-in code
  still supports the target claim that the main remaining interaction debt is
  bridge/core breadth, not another family split
- `lib/src/interactive/internal/scene_controller_mutation_boundary.dart` and
  `lib/src/controller/scene_controller_committed_mutation_access.dart` -
  checked-in code still supports the target claim that one gateway and one
  committed-write adapter seam remain the stable write path
- `lib/src/controller/scene_store_controller.dart` - checked-in code still
  supports the target claim that the store facade stays broad and is the likely
  later slimming target
- `tool/lsp_find_symbols.dart`, `tool/lsp_trace_symbol.dart`,
  `tool/lsp_trace_flow.dart`, `tool/lsp_find_boundary_bypasses.dart`, and
  `tool/lsp_find_thin_wrappers.dart` - checked-in tools now provide the live
  code-first probes the target map can cite as its mechanical evidence surface
- `test/tool/lsp_find_symbols_tool_test.dart`,
  `test/tool/lsp_trace_symbol_tool_test.dart`,
  `test/tool/lsp_trace_flow_tool_test.dart`,
  `test/tool/lsp_find_boundary_bypasses_tool_test.dart`, and
  `test/tool/lsp_find_thin_wrappers_tool_test.dart` - existing tests already
  lock the new probe behavior and provide the closest executable precedent for
  architecture-map verification support

### Current Entry Path

- `docs/adr/0001_target_engine_architecture.md` ->
  `docs/target_architecture/overview.md` ->
  `docs/target_architecture/execution_flows.md` ->
  `docs/target_architecture/families/*.md` -> `PLAN.md`
- live architecture review now starts from
  `docs/target_architecture/README.md` ->
  `dart run tool/lsp_find_symbols.dart` /
  `dart run tool/lsp_trace_flow.dart` /
  `dart run tool/lsp_trace_symbol.dart` /
  `dart run tool/lsp_find_boundary_bypasses.dart` /
  `dart run tool/lsp_find_thin_wrappers.dart` before deciding whether drift is
  in the code or in the target map

### Current Owner

- target-state ownership: `docs/target_architecture/**`
- accepted-decision ownership: `docs/adr/0001_target_engine_architecture.md`
- execution-order ownership: `PLAN.md` and `plan/*.md`
- checked-in current-architecture ownership: `ARCHITECTURE.md`
- mechanical proof of the live code path and recorded artifacts:
  `tool/lsp_*`, committed evidence files, and tool tests

### Adjacent Abstractions

- `ARCHITECTURE.md` - current-state architecture contract; adjacent but not the
  target-map owner
- `docs/adr/0001_target_engine_architecture.md` - accepted top-level target
  that the target map must refine, not rewrite
- `docs/adr/0002_post_target_optimization_scope.md` - later optimization scope
  that must not be silently pulled into this normalization step
- `PLAN.md` and existing `plan/step_*.md` contracts - the repository precedent
  for short, locked, executable maps instead of open-ended prose
- `tool/invariant_registry.dart`, `tool/check_guardrails.dart`, and tool tests
  - the repository precedent that important architecture knowledge should have
  mechanical proof where possible

### Existing Tests

- no current tool test validates the structure or consistency of
  `docs/target_architecture/**`
- `test/tool/lsp_find_symbols_tool_test.dart` and
  `test/tool/lsp_trace_symbol_tool_test.dart` - lock symbol lookup and tree
  trace probes
- `test/tool/lsp_trace_flow_tool_test.dart` - locks the stitched primary-flow
  probe used to confirm likely owner-to-owner paths
- `test/tool/lsp_find_boundary_bypasses_tool_test.dart` - locks required-seam
  boundary checks
- `test/tool/lsp_find_thin_wrappers_tool_test.dart` - locks thin-wrapper
  candidate detection used to identify over-shimmed target areas

### Analogous Implementation Path

- `ARCHITECTURE.md` together with `tool/invariant_registry.dart` and
  guardrail/tool tests - the closest repository precedent for concise
  architecture prose backed by mechanical enforcement instead of commentary
- `PLAN.md` plus existing `plan/step_*.md` contracts - the closest repository
  precedent for short, locked maps that are meant to drive execution instead of
  explain everything

### Governing Repository Rules

- `AGENTS.md` - repository-specific decisions must prefer checked-in code and
  mechanically enforced local rules over prose-only reminders
- `AGENTS.md` - target/current-state documentation must stay in the repository
  source of truth instead of only in chat
- `AGENTS.md` - important stable constraints should become linting, structural
  tests, CI checks, or tooling where feasible
- `AGENTS.md` - `PLAN.md` requires each step to have a dedicated document and
  step completion must update both files together
- `docs/adr/0001_target_engine_architecture.md` - the accepted top-level target
  remains the authority for owner-family boundaries and flow direction
- `docs/target_architecture/README.md` - this directory is already the target
  owner map, while `PLAN.md` owns execution order and `ARCHITECTURE.md` owns
  current-state rules

### Rejected Misleading Local Patterns

- keeping long `Current Mismatch` sections or hand-written flow diagrams as the
  main body of the target map - wrong level because they go stale quickly and
  obscure the stable target contract
- rewriting ADR 0001 from family-doc drift - wrong owner because the accepted
  top-level target is already fixed separately from local target-map cleanup
- moving target-state prose into `ARCHITECTURE.md` - wrong document because it
  conflates checked-in current architecture with intended target form
- inventing a new manifest/DSL or analysis product as the new source of truth -
  wrong scope because the repository already has ADRs, target docs, PLAN, and
  live probes; this step only needs a short map plus a structural test
- relying on the new LSP probes without documenting the mechanical evidence
  surface in the target map - wrong seam because architectural drift would
  remain tribal knowledge instead of a repeatable workflow

## 4. Architecture

### 4A. Locked Architectural Form

#### Problem Ownership Level

- target-architecture documentation and its minimal structural verification
  surface

#### Selected Architectural Form

- keep ADR 0001 and the accepted top-level owner map unchanged
- normalize `docs/target_architecture/**` into one explicit two-level target
  form plus two supporting layers:
  - Level 1: top-level owner map in `overview.md`
  - Level 2: family-form contracts in `families/*.md`
  - target runtime-view layer: the short runtime-view registry in
    `execution_flows.md`
  - evidence layer: mechanically generated current-state flow/path artifacts in
    `docs/target_architecture/evidence/`
- keep `README.md` as the directory contract and workflow entrypoint for the
  two target-form levels plus the runtime-view and evidence layers
- store all referenced flows, paths, and diagrams as committed evidence
  artifacts generated only by the checked-in LSP probes
- add one lightweight tool test that enforces the required target-map section
  shape, status vocabulary, mechanical evidence blocks, and the absence of
  hand-written flow/diagram blocks in the target-map docs

#### Owning Layer or Module

- documentation owner: `docs/target_architecture/**`
- structural-proof owner: `test/tool/**`

#### Dependency Direction

- target-map docs may depend on checked-in code evidence, ADR 0001, and
  checked-in LSP probe commands and committed evidence artifacts
- the structural test may read `docs/target_architecture/**`
- runtime code in `lib/src/**` must not depend on the target-map documents
- `PLAN.md` may link to the step contract and completed target-map artifacts,
  but does not redefine their content

#### State and Data Ownership

- ADR 0001 owns the accepted top-level target
- `ARCHITECTURE.md` owns checked-in current-state architecture
- `docs/target_architecture/overview.md` owns the normalized target family
  registry and target-status vocabulary for Level 1
- `docs/target_architecture/families/*.md` own local target rules, owner
  buckets, forbidden shapes, and mechanical evidence references for Level 2
- `docs/target_architecture/execution_flows.md` owns the short runtime-view
  registry for the target runtime-view layer and links to mechanically
  generated flow artifacts
- `docs/target_architecture/evidence/*.json` and `*.mmd` own the committed
  machine-generated flow/path/diagram artifacts referenced by the target map
- `PLAN.md` and `plan/*.md` own execution order and slice contracts, but are
  not part of the target-form hierarchy

#### Entry and Exit Boundaries

- entry:
  - ADR 0001 accepted target
  - checked-in runtime code and current family docs
  - live probe evidence from `tool/lsp_*`
- exit:
  - normalized short target-map documents
  - committed machine-generated evidence artifacts for every referenced
    flow/path/diagram
  - one structural tool test that keeps the map shape and mechanical evidence
    surface visible

#### Permitted Extension Seam

- new or updated family documents may extend the target map only by using the
  normalized family-doc section set, the shared status vocabulary, and
  repository-local LSP probe commands plus committed evidence artifacts
- new owner families still require a separate accepted owner-boundary decision
  before they are added to `overview.md`

#### Rejected Alternatives

- introduce a new target-manifest DSL or analysis database - too heavy for a
  documentation step and unnecessary given existing ADRs, docs, probes, and
  tests
- leave the current prose-heavy family docs in place and rely on live probes
  only during cleanup - too weak because the target map would stay verbose,
  stale-prone, and not mechanically checkable
- merge target docs into `ARCHITECTURE.md` - wrong owner because current-state
  and target-state contracts serve different purposes in this repository

#### Why This Level Is Correct

- the problem is not that the repository lacks a top-level target; ADR 0001 and
  the current overview already provide that
- the problem is that the target map is too verbose, partially stale, and not
  structurally enforced as a working execution guide
- fixing that once at the target-doc layer keeps future cleanup work aligned
  without opening runtime design decisions during every code slice

### 4B. Architecture Decision Gate

Not used. The architectural form is locked in 4A.

## 5. Locked Decisions

1. This step does not change ADR 0001, add a new owner family, or authorize a
   runtime refactor; it only normalizes the target map and its proof surface.
2. `overview.md` must become a concise family registry that includes a shared
   verification-status vocabulary:
   `locked`, `locked, needs slimming`, `provisional`, and `docs stale`.
3. The target form is exactly two levels:
   `overview.md` for Level 1 and `families/*.md` for Level 2; `PLAN.md` and
   `plan/*.md` are execution artifacts, not target-form levels.
4. `execution_flows.md` must stay limited to a short target runtime view of
   runtime-center flows that are mechanically supported by the checked-in LSP
   probes and the boundaries those flows must preserve; unsupported flows such
   as the current import/build map must not survive as hand-maintained
   diagrams.
5. Every family document must use the same compact section set:
   `Purpose`, `Target Rules`, `Owners`, `Forbidden Shapes`, `Mechanical
   Evidence`, and `Status`.
6. Any flow, path, or diagram referenced by the target map must come from a
   committed artifact generated by the checked-in LSP probes; hand-written flow
   lists and Mermaid diagrams are not an allowed target-map form.
7. The runtime-view artifact set used by `execution_flows.md` is fixed by this
   contract:
   `add_node_write_flow`, `pointer_input_flow`,
   `render_main_scene_read_flow`, and `render_overlay_preview_flow`.
   `execution_flows.md` may be rewritten only in the slice that generates and
   links that complete artifact set.
8. Raw metric numbers and long mismatch narration are not the
   canonical body of the target map; if a family still needs one short
   code-backed pressure note to justify a target cut, that note must stay
   compact and subordinate to the owner contract.
9. Where checked-in code already matches the intended local target shape, the
   family document must move to the landed local form instead of describing the
   split as future work.
10. The new structural test must fail when a family document loses the required
   section set, when the shared status vocabulary drifts, when a family omits
   repository-local probe commands and evidence links, or when target docs
   reintroduce hand-written flow/diagram blocks.

## 6. Result Requirements

1. A contributor can read `docs/target_architecture/README.md`,
   `overview.md`, `execution_flows.md`, and one family doc and answer four
   questions quickly: who owns this area, how the canonical path should move,
   what shapes are forbidden, and how to verify the rule.
2. The target map no longer contradicts checked-in local owner shapes that have
   already landed, especially the split `SceneViewRuntime` read surface.
3. Family docs express thin wrappers, over-shimmed helpers, and boundary
   bypasses as target-map debt where the repository evidence now supports that
   classification.
4. Stable target rules are separated cleanly from current-state architecture
   and from execution sequencing: ADR 0001 keeps the accepted top-level target,
   `docs/target_architecture/**` keeps the target map, `ARCHITECTURE.md` keeps
   checked-in current-state architecture, and `PLAN.md` keeps step order.
5. A contributor can distinguish target form, target runtime view, execution
   plan, and observed evidence without ambiguity: Level 1 is the owner map,
   Level 2 is the family form, `execution_flows.md` is a target runtime view,
   `PLAN.md` is execution planning, and observed flows live only in the
   evidence layer.
6. The repository contains executable proof that the target map keeps its
   normalized section structure, mechanical evidence surface, and status
   vocabulary, and that referenced flow/path artifacts exist.

## 7. Execution Order and Gates

### Required Order

- first add a failing structural tool test that locks the normalized target-map
  section shape, status vocabulary, mechanical-evidence-block requirements, and
  the absence of hand-written flow/diagram blocks
- then normalize `docs/target_architecture/README.md` and `overview.md` so the
  directory roles and top-level registry are fixed before any evidence-backed
  runtime-view or family rewrite
- the structural test expands progressively by slice:
  - Slice 1 covers only `docs/target_architecture/README.md` and
    `docs/target_architecture/overview.md`
  - Slice 2 extends coverage to `docs/target_architecture/execution_flows.md`
    and the runtime-view artifact set under
    `docs/target_architecture/evidence/`
  - Slices 3 through 7 extend coverage one family document at a time
  - only the final gate enforces the ban-on-inline-flow-content rule across the
    full `docs/target_architecture/**/*.md` tree
- then generate and commit the complete runtime-view artifact set used by
  `execution_flows.md` and rewrite `execution_flows.md` in the same slice
- then migrate the stale `view_runtime_and_render_seam.md` family doc to the
  landed local form and keep its mechanical evidence explicit
- then migrate the remaining family docs under the shared compact section set,
  one family doc per slice:
  composition root and facade, mutation gateway, store and commit path, and
  interaction runtime
- only after every family doc follows the new shape may the old long-form
  family sections be removed fully and the step be closed

### Successor Seam and Retirement Gates

- normalized family-doc seam:
  the shared compact family-doc section set replaces the current long-form
  `Target Shape` / `Current Mismatch`-heavy form;
  the old long-form sections may disappear only after all family docs migrate
  and the structural test enforces the new shape
- normalized status seam:
  ad hoc family-state language is replaced by the shared status vocabulary in
  `overview.md` and each family doc; the legacy prose may disappear only after
  all family docs expose one normalized status block
- normalized verification seam:
  undocumented or hand-drawn architecture review is replaced by
  repository-local LSP probe commands plus committed evidence artifacts; family
  docs may stop carrying raw narrative detail only after the new `Mechanical
  Evidence` blocks name the commands and artifacts that prove the rule

### Deferred Broad Verification

- the broad `required_code_change` preset is deferred to the final gate because
  this step should first lock the documentation shape and family migrations
  slice by slice before paying for the full repository run

## 8. File Map

### Implementation Files

- `docs/target_architecture/README.md`
- `docs/target_architecture/overview.md`
- `docs/target_architecture/execution_flows.md`
- `docs/target_architecture/families/composition_root_and_facade.md`
- `docs/target_architecture/families/interaction_runtime.md`
- `docs/target_architecture/families/mutation_gateway.md`
- `docs/target_architecture/families/store_and_commit_path.md`
- `docs/target_architecture/families/view_runtime_and_render_seam.md`
- `docs/target_architecture/evidence/composition_root_trace.json`
- `docs/target_architecture/evidence/composition_root_trace.mmd`
- `docs/target_architecture/evidence/add_node_write_flow.json`
- `docs/target_architecture/evidence/add_node_write_flow.mmd`
- `docs/target_architecture/evidence/render_main_scene_read_flow.json`
- `docs/target_architecture/evidence/render_main_scene_read_flow.mmd`
- `docs/target_architecture/evidence/render_overlay_preview_flow.json`
- `docs/target_architecture/evidence/render_overlay_preview_flow.mmd`
- `docs/target_architecture/evidence/replace_scene_write_flow.json`
- `docs/target_architecture/evidence/replace_scene_write_flow.mmd`
- `docs/target_architecture/evidence/commit_move_selection_flow.json`
- `docs/target_architecture/evidence/commit_move_selection_flow.mmd`
- `docs/target_architecture/evidence/pointer_input_flow.json`
- `docs/target_architecture/evidence/pointer_input_flow.mmd`
- `PLAN.md`
- `plan/step_16_target_architecture_map_normalization.md`

### Test Files

- `test/tool/target_architecture_map_tool_test.dart`

### Fixtures and Supporting Data

- the committed evidence artifacts listed above under
  `docs/target_architecture/evidence/`

### Registry, Inventory, and Workflow Files

- `PLAN.md` - step index must link to this contract and later close with it
- `docs/target_architecture/README.md` - workflow owner for the target map and
  its verification-first usage

### Analysis Area

- `docs/adr/0001_target_engine_architecture.md`
- `docs/adr/0002_post_target_optimization_scope.md`
- `ARCHITECTURE.md`
- `lib/src/contract/scene_view_runtime.dart`
- `lib/src/contract/scene_view_render_state.dart`
- `lib/src/interactive/internal/scene_controller_scene_view_runtime.dart`
- `lib/src/interactive/internal/scene_controller_graph.dart`
- `lib/src/interactive/internal/scene_controller_interaction_runtime.dart`
- `lib/src/interactive/internal/interactive_runtime.dart`
- `lib/src/interactive/internal/scene_controller_mutation_boundary.dart`
- `lib/src/controller/scene_controller_committed_mutation_access.dart`
- `lib/src/controller/scene_store_controller.dart`
- `tool/lsp_find_symbols.dart`
- `tool/lsp_trace_symbol.dart`
- `tool/lsp_trace_flow.dart`
- `tool/lsp_find_boundary_bypasses.dart`
- `tool/lsp_find_thin_wrappers.dart`

## 9. Implementation Rules

### Protected Invariants

- ADR 0001 remains the accepted top-level target and must not be silently
  rewritten by this step
- `ARCHITECTURE.md` continues to describe checked-in current architecture, not
  target-state intent
- target-map documents must stay code-backed: when local checked-in code and
  the family doc disagree, the family doc may only be updated to the code-backed
  form if the top-level ADR rule still holds
- target-map docs must not contain hand-written flow/path/diagram content; they
  may only reference committed machine-generated evidence artifacts
- the target map must remain short and normative; explanatory pressure evidence
  is secondary and must not dominate the document body
- every family target rule kept in the map must have a repository-local LSP
  probe command and a committed evidence reference

### Required Proof

- behavioral proof: `dart run tool/run_tool_tests.dart test/tool/target_architecture_map_tool_test.dart`
- structural proof: `dart run tool/run_tool_tests.dart test/tool/target_architecture_map_tool_test.dart`
- progressive structural-test scope:
  - Slice 1: the test may assert normalized shape and no hand-written
    flow/diagram content only for `README.md` and `overview.md`
  - Slice 2: the same test extends to `execution_flows.md` and validates that
    the complete runtime-view artifact set exists before the runtime-view
    registry is accepted
  - Slices 3 through 7: the same test extends to exactly one family document
    per slice, matching that slice's family rewrite
  - final gate: the same test enforces normalized shape, evidence links, and
    ban-on-inline-flow-content across the full
    `docs/target_architecture/**/*.md` tree
- for refactors: existing locking tests must be named or missing
  characterization tests must be added before structural edits, plus 1 to 3
  guard tests for neighboring branches when needed

### Allowed Change Surface

- the files listed in section 8 only
- one lightweight parser/helper local to
  `test/tool/target_architecture_map_tool_test.dart` if needed to keep the test
  readable

### Forbidden Moves

- no runtime behavior change in `lib/src/**`
- no ADR rewrite
- no expansion of the target map into a long analytical report
- no family-specific custom format that deviates from the shared compact
  section set
- no references to commands, probes, or files that are not
  checked into the repository
- no new hand-written Mermaid blocks or hand-written flow/path enumerations may
  be introduced anywhere inside `docs/target_architecture/**/*.md` during the
  migration; full removal of legacy inline flow content is enforced at the
  slice-local scopes above and across the full tree at the final gate

### Optional: Recognition Forms That Must Be Supported

- normalized family statuses:
  `locked`, `locked, needs slimming`, `provisional`, `docs stale`
- repository-local verification references that use checked-in commands such as
  `dart run tool/lsp_trace_flow.dart ...`,
  `dart run tool/lsp_trace_symbol.dart ...`,
  `dart run tool/lsp_find_boundary_bypasses.dart ...`,
  `dart run tool/lsp_find_thin_wrappers.dart ...`,
  `dart run tool/run_tool_tests.dart ...`

### Optional: Allowed Forms That Are Not Violations

- one short observed-pressure note in a family doc when it is still needed to
  justify the owner cut, as long as it does not replace the normalized owner
  contract
- a family may stay `locked, needs slimming` without inventing a new owner
  family when the live code shows breadth inside an already accepted boundary

### Optional: Resolution Rules

- if a family doc disagrees with checked-in code but the top-level ADR rule
  still holds, update the family doc to the code-backed local form
- if checked-in code appears to contradict ADR 0001 at the owner-family level,
  stop and escalate instead of rewriting the ADR or target map silently

## 10. Vertical Slices

### Slice 1. [ ] Lock The Normalized Target-Map Skeleton

#### Slice Contract

Add a failing structural tool test that locks the normalized target-map section
shape, status vocabulary, mechanical evidence blocks, and the ban on
hand-written flow/diagram content, then update the target-map directory
contract plus the top-level overview to that shape without yet rewriting
`execution_flows.md`.

#### Change

- add `test/tool/target_architecture_map_tool_test.dart` with one failing test
  for the required target-map structure and 1 to 3 guard tests around status
  vocabulary, mechanical-evidence-block presence, and rejection of hand-written
  flow/diagram blocks
- rewrite `docs/target_architecture/README.md` so it defines the normalized
  directory roles and verification-first workflow
- rewrite `docs/target_architecture/overview.md` into the concise family
  registry with normalized status vocabulary

#### Behavioral Verification

- `dart run tool/run_tool_tests.dart test/tool/target_architecture_map_tool_test.dart`

#### Structural Verification

- `dart run tool/run_tool_tests.dart test/tool/target_architecture_map_tool_test.dart`

#### Fixtures Used

- none

#### Positive Scenarios

- the top-level target map exposes normalized roles, statuses, and mechanical
  evidence expectations

#### Negative Scenarios

- the tool test fails if a required top-level section, status term, or
  mechanical-evidence block is missing, or if hand-written flow/diagram content
  appears in `README.md` or `overview.md`

#### Closure Evidence

- `README.md` and `overview.md` follow the normalized shape and the new
  structural test is green for these two files only

### Slice 2. [ ] Generate The Runtime-View Artifact Set And Rewrite Execution Flows

#### Slice Contract

Generate the complete mechanically supported runtime-view artifact set, commit
those artifacts, and rewrite `execution_flows.md` in the same slice so every
listed flow has a concrete evidence link and unsupported legacy flow diagrams
are removed.

#### Change

- generate and commit `docs/target_architecture/evidence/add_node_write_flow.json`
  and `docs/target_architecture/evidence/add_node_write_flow.mmd`
- generate and commit `docs/target_architecture/evidence/pointer_input_flow.json`
  and `docs/target_architecture/evidence/pointer_input_flow.mmd`
- generate and commit
  `docs/target_architecture/evidence/render_main_scene_read_flow.json` and
  `docs/target_architecture/evidence/render_main_scene_read_flow.mmd`
- generate and commit
  `docs/target_architecture/evidence/render_overlay_preview_flow.json` and
  `docs/target_architecture/evidence/render_overlay_preview_flow.mmd`
- rewrite `docs/target_architecture/execution_flows.md` into the short
  runtime-view registry that links only to this complete artifact set
- remove the unsupported hand-maintained import/build flow from
  `docs/target_architecture/execution_flows.md`
- extend `test/tool/target_architecture_map_tool_test.dart` with expectations
  that the runtime-view registry links only to the committed runtime-view
  artifact set and does not contain inline Mermaid blocks

#### Behavioral Verification

- `dart run tool/run_tool_tests.dart test/tool/target_architecture_map_tool_test.dart`
- `dart run tool/lsp_trace_symbol.dart lib/src/interactive/scene_controller_scene.dart SceneControllerSceneOwner.addNode --direction=outgoing --depth=5 --json-out=docs/target_architecture/evidence/add_node_write_flow.json --mermaid-out=docs/target_architecture/evidence/add_node_write_flow.mmd`
- `dart run tool/lsp_trace_symbol.dart lib/src/view/scene_view_interactive_pointer_host.dart SceneViewInteractivePointerHost.handlePointerEvent --direction=outgoing --depth=3 --json-out=docs/target_architecture/evidence/pointer_input_flow.json --mermaid-out=docs/target_architecture/evidence/pointer_input_flow.mmd`
- `dart run tool/lsp_trace_symbol.dart lib/src/contract/scene_view_runtime.dart SceneViewRuntime.mainSceneRenderRead --direction=both --depth=2 --json-out=docs/target_architecture/evidence/render_main_scene_read_flow.json --mermaid-out=docs/target_architecture/evidence/render_main_scene_read_flow.mmd`
- `dart run tool/lsp_trace_symbol.dart lib/src/contract/scene_view_runtime.dart SceneViewRuntime.overlayPreviewRead --direction=both --depth=2 --json-out=docs/target_architecture/evidence/render_overlay_preview_flow.json --mermaid-out=docs/target_architecture/evidence/render_overlay_preview_flow.mmd`

#### Structural Verification

- `dart run tool/run_tool_tests.dart test/tool/target_architecture_map_tool_test.dart`
- `dart run tool/lsp_find_symbols.dart mainSceneRenderRead --path-contains=lib/src/contract`
- `dart run tool/lsp_find_symbols.dart overlayPreviewRead --path-contains=lib/src/contract`

#### Fixtures Used

- none

#### Positive Scenarios

- every runtime-view flow listed in `execution_flows.md` has a committed
  evidence artifact
- `execution_flows.md` no longer contains inline flow diagrams

#### Negative Scenarios

- `execution_flows.md` must not list a flow that lacks a committed artifact
- the unsupported import/build flow must not survive as a hand-maintained
  diagram

#### Closure Evidence

- `execution_flows.md` links only to the committed runtime-view artifact set
  and the structural test plus probe commands are green for the runtime-view
  layer

### Slice 3. [ ] Sync The View Runtime Family To The Landed Local Form

#### Slice Contract

Move the view/runtime family document from a future-split narrative to the
landed local owner form while keeping the accepted top-level boundary and the
mechanical evidence explicit.

#### Change

- rewrite `docs/target_architecture/families/view_runtime_and_render_seam.md`
  under the normalized family-doc section set
- record the family status against checked-in code instead of describing the
  render-read split as future work
- keep the mechanical evidence block focused on `SceneViewRuntime`,
  `mainSceneRenderRead`, and `overlayPreviewRead`
- extend `test/tool/target_architecture_map_tool_test.dart` with expectations
  that catch regression to the stale mixed-seam wording or missing mechanical
  evidence blocks for this family

#### Behavioral Verification

- `dart run tool/run_tool_tests.dart test/tool/target_architecture_map_tool_test.dart`
- `dart run tool/lsp_trace_flow.dart lib/src/view/scene_view_interactive_pointer_host.dart SceneViewInteractivePointerHost.handlePointerEvent --depth=5`
- `dart run tool/lsp_trace_symbol.dart lib/src/view/scene_view_interactive_pointer_host.dart SceneViewInteractivePointerHost.handlePointerEvent --direction=outgoing --depth=3 --json-out=docs/target_architecture/evidence/pointer_input_flow.json --mermaid-out=docs/target_architecture/evidence/pointer_input_flow.mmd`

#### Structural Verification

- `dart run tool/run_tool_tests.dart test/tool/target_architecture_map_tool_test.dart`
- `dart run tool/lsp_find_symbols.dart mainSceneRenderRead --path-contains=lib/src/contract`
- `dart run tool/lsp_find_symbols.dart overlayPreviewRead --path-contains=lib/src/contract`

#### Fixtures Used

- none

#### Positive Scenarios

- the family doc describes the split read surface as the checked-in local form
- the family doc names the runtime boundary and its mechanical evidence surface

#### Negative Scenarios

- the family doc must not describe one permanently mixed render-state seam as
  the still-current local target

#### Closure Evidence

- the view/runtime family doc matches the landed local form and the structural
  test plus live probes still succeed

### Slice 4. [ ] Normalize The Composition Root Family

#### Slice Contract

Normalize the composition-root family doc under the shared compact contract so
it describes stable owners, forbidden shapes, and mechanical evidence without
raw analytical narrative.

#### Change

- rewrite `docs/target_architecture/families/composition_root_and_facade.md`
  under the normalized family-doc section set
- generate and commit
  `docs/target_architecture/evidence/composition_root_trace.json` and
  `docs/target_architecture/evidence/composition_root_trace.mmd`
- extend `test/tool/target_architecture_map_tool_test.dart` with family-level
  expectations for the normalized section set, status block, and mechanical
  evidence references in this doc

#### Behavioral Verification

- `dart run tool/run_tool_tests.dart test/tool/target_architecture_map_tool_test.dart`
- `dart run tool/lsp_trace_symbol.dart lib/src/interactive/internal/scene_controller_graph.dart createSceneControllerGraph --direction=outgoing --depth=3 --json-out=docs/target_architecture/evidence/composition_root_trace.json --mermaid-out=docs/target_architecture/evidence/composition_root_trace.mmd`

#### Structural Verification

- `dart run tool/run_tool_tests.dart test/tool/target_architecture_map_tool_test.dart`

#### Fixtures Used

- none

#### Positive Scenarios

- the composition family doc exposes concise owner buckets and forbidden shapes
- the composition-root family references one committed composition trace

#### Negative Scenarios

- the composition family doc must not depend on long mismatch prose or raw
  metric tables as its main contract

#### Closure Evidence

- the composition family doc follows the normalized shape and the structural
  test plus composition trace remain green

### Slice 5. [ ] Normalize The Mutation Gateway Family

#### Slice Contract

Normalize the mutation-gateway family doc under the shared compact contract so
it describes the stable write boundary, forbidden shapes, and thin-wrapper debt
without raw analytical narrative.

#### Change

- rewrite `docs/target_architecture/families/mutation_gateway.md` under the
  normalized family-doc section set
- keep the mechanical evidence block explicitly anchored to the committed
  `add_node_write_flow` artifact pair from Slice 2
- extend `test/tool/target_architecture_map_tool_test.dart` with family-level
  expectations for the normalized section set, status block, and mechanical
  evidence references in this doc

#### Behavioral Verification

- `dart run tool/run_tool_tests.dart test/tool/target_architecture_map_tool_test.dart`
- `dart run tool/lsp_find_thin_wrappers.dart lib/src/interactive --classification=pure-forwarder`

#### Structural Verification

- `dart run tool/run_tool_tests.dart test/tool/target_architecture_map_tool_test.dart`
- `dart run tool/lsp_find_boundary_bypasses.dart lib/src/interactive/scene_controller_scene.dart SceneControllerSceneOwner --must-pass=SceneControllerMutationBoundary --depth=5`

#### Fixtures Used

- none

#### Positive Scenarios

- the gateway family doc exposes one stable write boundary and explicit
  thin-wrapper debt

#### Negative Scenarios

- the gateway family doc must not depend on long mismatch prose or raw metric
  tables as its main contract

#### Closure Evidence

- the gateway family doc follows the normalized shape and the structural test
  plus gateway probes remain green

### Slice 6. [ ] Normalize The Store And Commit Family

#### Slice Contract

Normalize the store/commit family doc under the shared compact contract so it
describes stable owners, forbidden shapes, and mechanical evidence without raw
analytical narrative.

#### Change

- rewrite `docs/target_architecture/families/store_and_commit_path.md` under
  the normalized family-doc section set
- generate and commit
  `docs/target_architecture/evidence/replace_scene_write_flow.json` and
  `docs/target_architecture/evidence/replace_scene_write_flow.mmd`
- extend `test/tool/target_architecture_map_tool_test.dart` with family-level
  expectations for the normalized section set, status block, and mechanical
  evidence references in this doc

#### Behavioral Verification

- `dart run tool/run_tool_tests.dart test/tool/target_architecture_map_tool_test.dart`
- `dart run tool/lsp_trace_symbol.dart lib/src/interactive/internal/scene_controller_scene_mutations.dart SceneControllerSceneMutations.replaceScene --direction=outgoing --depth=5 --json-out=docs/target_architecture/evidence/replace_scene_write_flow.json --mermaid-out=docs/target_architecture/evidence/replace_scene_write_flow.mmd`

#### Structural Verification

- `dart run tool/run_tool_tests.dart test/tool/target_architecture_map_tool_test.dart`

#### Fixtures Used

- none

#### Positive Scenarios

- the store/commit family doc exposes concise owner buckets and one committed
  write-path artifact

#### Negative Scenarios

- the store/commit family doc must not depend on long mismatch prose or raw
  metric tables as its main contract

#### Closure Evidence

- the store/commit family doc follows the normalized shape and the structural
  test plus replace-scene write trace remain green

### Slice 7. [ ] Normalize The Interaction Family And Close The Map

#### Slice Contract

Normalize the interaction family doc, close the target-map migration, and prove
that the directory now stays in the normalized short and checkable form.

#### Change

- rewrite `docs/target_architecture/families/interaction_runtime.md` under the
  normalized family-doc section set
- generate and commit
  `docs/target_architecture/evidence/commit_move_selection_flow.json` and
  `docs/target_architecture/evidence/commit_move_selection_flow.mmd`
- extend `test/tool/target_architecture_map_tool_test.dart` with final
  expectations that every family doc follows the normalized section shape and
  carries one status plus one mechanical evidence block
- update `PLAN.md` and this step document when the full migration is complete

#### Behavioral Verification

- `dart run tool/run_tool_tests.dart test/tool/target_architecture_map_tool_test.dart`
- `dart run tool/lsp_find_thin_wrappers.dart lib/src/interactive --classification=pure-forwarder`
- `dart run tool/lsp_trace_flow.dart lib/src/interactive/internal/interactive_selection_actions.dart InteractiveSelectionActions.commitMoveSelection --depth=5`
- `dart run tool/lsp_trace_symbol.dart lib/src/interactive/internal/interactive_selection_actions.dart InteractiveSelectionActions.commitMoveSelection --direction=outgoing --depth=5 --json-out=docs/target_architecture/evidence/commit_move_selection_flow.json --mermaid-out=docs/target_architecture/evidence/commit_move_selection_flow.mmd`

#### Structural Verification

- `dart run tool/run_tool_tests.dart test/tool/target_architecture_map_tool_test.dart`
- `dart run tool/lsp_find_boundary_bypasses.dart lib/src/interactive/scene_controller_interaction.dart SceneControllerInteractionOwner --must-pass=SceneControllerMutationBoundary --depth=4`

#### Fixtures Used

- none

#### Positive Scenarios

- every target-map family doc follows the same compact contract
- interaction-family breadth is described as debt inside an accepted family
  boundary rather than as an implied new family split

#### Negative Scenarios

- the normalized target map must not leave family status or verification
  expectations implicit or reintroduce hand-written flow/diagram content

#### Closure Evidence

- all target-map docs follow the normalized shape, the structural test is
  complete, and the plan index links the step correctly

## 11. Final Verification

- `dart run tool/run_tool_tests.dart test/tool/target_architecture_map_tool_test.dart`
- `dart run tool/run_tool_tests.dart test/tool/lsp_find_symbols_tool_test.dart test/tool/lsp_trace_symbol_tool_test.dart test/tool/lsp_trace_flow_tool_test.dart test/tool/lsp_find_boundary_bypasses_tool_test.dart test/tool/lsp_find_thin_wrappers_tool_test.dart`
- `printf '%s\n' docs/target_architecture/README.md docs/target_architecture/overview.md docs/target_architecture/execution_flows.md docs/target_architecture/families/composition_root_and_facade.md docs/target_architecture/families/interaction_runtime.md docs/target_architecture/families/mutation_gateway.md docs/target_architecture/families/store_and_commit_path.md docs/target_architecture/families/view_runtime_and_render_seam.md docs/target_architecture/evidence/composition_root_trace.json docs/target_architecture/evidence/composition_root_trace.mmd docs/target_architecture/evidence/add_node_write_flow.json docs/target_architecture/evidence/add_node_write_flow.mmd docs/target_architecture/evidence/render_main_scene_read_flow.json docs/target_architecture/evidence/render_main_scene_read_flow.mmd docs/target_architecture/evidence/render_overlay_preview_flow.json docs/target_architecture/evidence/render_overlay_preview_flow.mmd docs/target_architecture/evidence/replace_scene_write_flow.json docs/target_architecture/evidence/replace_scene_write_flow.mmd docs/target_architecture/evidence/commit_move_selection_flow.json docs/target_architecture/evidence/commit_move_selection_flow.mmd docs/target_architecture/evidence/pointer_input_flow.json docs/target_architecture/evidence/pointer_input_flow.mmd PLAN.md plan/step_16_target_architecture_map_normalization.md test/tool/target_architecture_map_tool_test.dart | dart run tool/run_verification_preset.dart run --preset=required_code_change --changed-paths-file=-`

## 12. Acceptance Criteria

- `docs/target_architecture/**` is a short, role-segregated, verification-first
  target map rather than a prose-heavy analysis dump
- every family doc uses the shared compact section set and one normalized
  status block
- `overview.md` and `execution_flows.md` expose only the stable top-level map
  and runtime-view registry needed to guide cleanup work
- the target map no longer contains stale local target claims where the
  checked-in code already landed the accepted owner split
- one structural tool test fails if the target-map documents drift away from
  the normalized, checkable form or if target docs reintroduce hand-written
  flow/path/diagram content
