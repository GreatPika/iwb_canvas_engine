# Change Contract

Contract Mode: FULL
Contract Profile: SOURCE_OF_TRUTH_DOCS
Contract Obligations: SEAM_MIGRATION

## 1. Mandate and Boundary

### Mandate

Convert `.design/2026-05-19-pointer-tool-cleanup-coordinator.md` into accepted
source-of-truth documentation for the future internal
`PointerToolCleanupCoordinator`.

This is a documentation-only roadmap step. It must lock the selected design
form, update durable architecture/contracts/diagrams/phase guidance, and record
future verification requirements. It must not implement production Dart,
production tests, guardrail runner code, or interaction tool machines.

### In Scope

- Document Candidate A from the design as the selected target form:
  an interaction-owned `PointerToolCleanupCoordinator` with typed cleanup
  requests and an effect-only `PointerCleanupOutcome`.
- Document that future typed cleanup requests carry both cleanup reason and
  ownership context so `interactive=false` can preserve non-owned pending line
  state while line-owned cleanup, mode/tool change, successful load, dispose,
  and terminal line decisions can clear owned pending line state.
- Document that `InteractionEngine` is the composition owner and the only caller
  of the coordinator; tool machines return typed cleanup requests to
  `InteractionEngine` and do not call the coordinator directly.
- Document the future coordinator placement under
  `lib/src/interaction/pointer_tool_cleanup_coordinator.dart` as an internal
  interaction package file.
- Document that the coordinator is a cleanup policy seam, not a state store,
  cache, public API type, resolver, edit owner, event dispatcher, text-request
  emitter, repaint notifier, Flutter adapter, or runtime publication owner.
- Document that the coordinator does not own final terminal normalization, hit
  testing, spatial candidate selection, exact eraser checks, commit-intent
  creation, or committed document/selection/resource mutation.
- Document cleanup reasons covered by the future seam: cancel, dispose, prepared
  load success, mode/tool change, active-session `interactive=false`, stale
  terminal, invalid terminal, no-op terminal, resolver cancel/error, edit
  failure, and post-successful-commit cleanup.
- Document cleanup outcome facts: previous preview kind, preview-changed flag,
  public-state need, repaint target, active token/session release fact, pending
  line cleared/preserved fact, pending text tap cleared fact, and load/dispose
  sequencing facts.
- Update active docs and diagrams so shared cleanup policy ownership points to
  the coordinator while tool-specific diagrams keep only gesture and terminal
  rules.
- Update implementation phase guidance so P10 introduces the documented seam,
  P11 draw/line work consumes it, and P12 eraser/text work consumes it.
- Update verification source-of-truth surfaces to require future behavioral and
  structural proof for cleanup ownership, pending line preservation, repaint
  target classification, no resolver on cleanup-only paths, no stale terminal
  commit, no user-action/text-request emission on cleanup, and no future bypass
  of the coordinator.
- Update registries, indexes, and generated documentation navigation only where
  required by repository documentation tooling.

### Out of Scope

- No production Dart implementation under `lib/**`.
- No Dart test implementation under `test/**`.
- No guardrail runner implementation under `tool/**`.
- No public API type, method, export, payload, event, error code, schema,
  compatibility promise, or public package barrel change.
- No runtime behavior change in this step.
- No implementation of `InteractionEngine`, pointer sessions, selected move,
  marquee, draw, line, eraser, text-request routing, resolver integration,
  `EditKernel` integration, repaint buses, or Flutter surface behavior.
- No migration of legacy package implementation files. The root package is the
  target architecture rebuild; legacy code is donor evidence only.
- No execution of `dart analyze`, `dcm analyze .`, `dcm calculate-metrics .`, or
  runtime `dart test`, because this step changes documentation only.

## 2. Evidence Map

### Baseline Evidence

These facts describe repository state before execution. They are evidence for
the documentation change, not target-state requirements.

- `.design/2026-05-19-pointer-tool-cleanup-coordinator.md` has disposition
  `READY_FOR_CONTRACT` and selects Candidate A: an interaction-owned cleanup
  coordinator with typed cleanup requests and an effect-only outcome.
- `.design/2026-05-19-pointer-tool-cleanup-coordinator.md` states that the
  coordinator must be composed inside `InteractionEngine`, placed under
  `lib/src/interaction/pointer_tool_cleanup_coordinator.dart`, and kept internal
  rather than public API.
- `.research/2026-05-19-pointer-tool-cleanup-coordinator.md:13` reports that
  cleanup-only inputs are documented across generic and tool-specific diagrams,
  but no durable `PointerToolCleanupCoordinator` symbol was found in inspected
  docs.
- `todo.md:143` and `todo.md:177` name
  `PointerToolCleanupCoordinator` as backlog/product context, but `todo.md` is
  not the durable architecture source of truth.
- `docs/architecture/01_runtime_ownership.md:58` assigns pointer sessions,
  tools, preview state, terminal commit requests, and interaction request guard
  facts to `InteractionEngine`.
- `docs/architecture/01_runtime_ownership.md:89` through
  `docs/architecture/01_runtime_ownership.md:96` require interaction gesture
  decisions to use narrow read-only query boundaries and committed mutations to
  go through `EditKernel`.
- `docs/architecture/02_package_boundaries.md:82` through
  `docs/architecture/02_package_boundaries.md:91` list current target
  interaction package files without `pointer_tool_cleanup_coordinator.dart`.
- `docs/architecture/02_package_boundaries.md:221` and
  `docs/architecture/02_package_boundaries.md:231` through
  `docs/architecture/02_package_boundaries.md:235` forbid interaction code from
  importing concrete store or selection internals directly.
- `docs/contracts/interaction_engine.md:107` through
  `docs/contracts/interaction_engine.md:109` require terminal admission to use
  the active pointer token and current `controllerEpoch`; stale token or epoch
  mismatch may clean up only and cannot create a commit intent.
- `docs/contracts/interaction_engine.md:120` through
  `docs/contracts/interaction_engine.md:123` require preview changes to publish
  sealed `CanvasPreviewState` variants and `state.revisions.preview`, while
  already-empty cleanup publishes no new public state snapshot.
- `docs/contracts/interaction_engine.md:134` through
  `docs/contracts/interaction_engine.md:140` require `interactive=false` to
  cancel only an active routed pointer session, preserve non-owned pending line
  state, and publish preview revision only when active pointer-owned preview
  changed.
- `docs/contracts/interaction_engine.md:144` through
  `docs/contracts/interaction_engine.md:158` make `InteractionEngine` the only
  public preview producer and map selected move to main-scene repaint while
  other pointer previews map to overlay repaint.
- `docs/contracts/load_document.md:49` through
  `docs/contracts/load_document.md:53` allow prepared load success to request
  interaction interrupt/preview cleanup but forbid terminal resolver or commit
  paths.
- `docs/contracts/load_document.md:64` through
  `docs/contracts/load_document.md:76` place load success cleanup after
  successful preparation and before one post-install runtime state publication.
- `docs/diagrams/state_pointer_session.mmd:99` through
  `docs/diagrams/state_pointer_session.mmd:105` list cleanup-only paths and
  forbid selected-move resolver calls on cancel, load, mode,
  `interactive=false`, or dispose paths.
- `docs/diagrams/state_pointer_session.mmd:111` through
  `docs/diagrams/state_pointer_session.mmd:115` require preview/session cleanup
  and active token release before public state, action, or repaint effects.
- `docs/diagrams/state_pointer_session.mmd:118` through
  `docs/diagrams/state_pointer_session.mmd:123` classify cleanup target by the
  cleared preview kind.
- `docs/diagrams/state_pointer_session.mmd:151` through
  `docs/diagrams/state_pointer_session.mmd:158` name negative invariants:
  no direct store mutation, no multiple active pointer sessions, no stale
  terminal commit, no resolver on cancel/load/mode/interactive-false/dispose,
  and no cleanup of pending line state not owned by the active routed pointer.
- `docs/diagrams/state_selected_move.mmd:127` through
  `docs/diagrams/state_selected_move.mmd:132` describe selected move
  pre-resolver cleanup paths that emit no action and do not call the resolver or
  open an edit.
- `docs/diagrams/state_selected_move.mmd:164` through
  `docs/diagrams/state_selected_move.mmd:170` require selected-move cleanup to
  clear move preview/session, advance preview revision only when active preview
  existed, and queue main-scene cleanup repaint.
- `docs/diagrams/state_select_marquee.mmd:114` through
  `docs/diagrams/state_select_marquee.mmd:129` require marquee cleanup to clear
  overlay/session state only, request overlay repaint only, and avoid selected
  move resolver or main-scene preview cleanup.
- `docs/diagrams/state_pencil_marker_draw.mmd:117` through
  `docs/diagrams/state_pencil_marker_draw.mmd:148` require pencil/marker cleanup
  to clear only stroke preview/session and use overlay repaint only.
- `docs/diagrams/state_two_tap_line.mmd:26` through
  `docs/diagrams/state_two_tap_line.mmd:40` require pending line state to
  outlive unrelated pointer cleanup and `interactive=false` when no active
  routed pointer owns it.
- `docs/diagrams/state_two_tap_line.mmd:110` through
  `docs/diagrams/state_two_tap_line.mmd:114` require line cleanup-only paths to
  clear pending start and overlay preview without committed effects.
- `docs/diagrams/state_eraser.mmd:111` through
  `docs/diagrams/state_eraser.mmd:119` require eraser cleanup-only and
  empty/no-op cleanup to clear preview/session only and publish no erase action
  or document state.
- `docs/diagrams/state_pending_text_edit_request.mmd:120` through
  `docs/diagrams/state_pending_text_edit_request.mmd:125` require text-request
  cleanup to clear pending tap history only and publish no text request, action,
  document revision, selection change, preview update, spatial update,
  projection eviction, or repaint.
- `docs/diagrams/dfd_pointer_preview_commit.mmd:89` through
  `docs/diagrams/dfd_pointer_preview_commit.mmd:95` route terminal/cancel
  cleanup to `CanvasNoPreview`, preview revision if active, and cleanup repaint
  classification by active preview kind.
- `docs/implementation/p10_selection_and_move.md:16` through
  `docs/implementation/p10_selection_and_move.md:29` place pointer session
  lifecycle, terminal cleanup, selected move resolver safety, stale terminal
  rejection, and loadDocument ordering in P10.
- `docs/implementation/p11_draw_tools.md:10` through
  `docs/implementation/p11_draw_tools.md:21` place pencil, marker, line preview
  lifecycle, overlay repaint, commits, actions, terminal cleanup, and stale
  terminal rejection in P11.
- `docs/implementation/p12_eraser_and_text_request.md:11` through
  `docs/implementation/p12_eraser_and_text_request.md:24` place eraser preview,
  eraser cleanup/no-op, text double-tap request routing, and terminal cleanup in
  P12.
- `docs/verification/guardrails.md:180` through
  `docs/verification/guardrails.md:184` already list guardrails for selected
  move main repaint, concrete interaction import boundaries, no resolver on
  cancel paths, and no stale terminal commit.
- `docs/verification/guardrails.md:210` through
  `docs/verification/guardrails.md:211` require Flutter surface adapters to pass
  normalized finite pointer samples into runtime routing and preserve non-owned
  pending line state when `interactive=false`.
- `docs/verification/tests.md:167` through
  `docs/verification/tests.md:171` list planned interaction tests for preview
  public state, state machines, no resolver on cancel cleanup, and no stale
  terminal commit.
- `docs/verification/tests.md:439` through
  `docs/verification/tests.md:443` require preview-only pointer changes to
  publish only `state.revisions.preview` and cleanup against empty preview state
  to be public-state silent.

### Entry Paths

- This documentation step starts from
  `.design/2026-05-19-pointer-tool-cleanup-coordinator.md`.
- The roadmap entry is `PLAN.md`.
- Active source-of-truth surfaces are `docs/**`, `docs/_registry/**`,
  `docs/indexes/**`, and `docs/diagrams/**`.

### Current Owners

- `docs/architecture/01_runtime_ownership.md` owns runtime and interaction
  ownership prose.
- `docs/architecture/02_package_boundaries.md` owns package layout and import
  boundary expectations.
- `docs/contracts/interaction_engine.md` owns pointer session lifecycle,
  preview/repaint cleanup semantics, interaction query boundaries, and
  interaction-public-state rules.
- `docs/contracts/load_document.md` owns prepared load success/failure interrupt
  ordering.
- `docs/diagrams/**` owns Mermaid source diagrams for pointer cleanup states,
  preview/commit data flow, and interaction sequences.
- `docs/implementation/p10_selection_and_move.md`,
  `docs/implementation/p11_draw_tools.md`, and
  `docs/implementation/p12_eraser_and_text_request.md` own phase-specific
  implementation guidance.
- `docs/verification/guardrails.md` owns mandatory guardrail ids and rules.
- `docs/verification/tests.md` owns planned test inventory and test ownership
  descriptions.
- `docs/_registry/**` and `docs/indexes/**` own generated or maintained
  navigation and lookup surfaces.

### Existing Checks

- `dart run docs/tool/check_docs.dart` validates documentation entrypoints,
  registries, diagram catalog membership, and navigation.
- `dart run docs/tool/generate_context_capsules.dart --check` validates
  generated documentation context capsules.
- Targeted `rg` proof can validate selected terminology, ownership statements,
  future verification requirements, and negative proof for retired tool-local
  cleanup-policy ownership wording.

### Valid Precedents

- Step 17 is a `SOURCE_OF_TRUTH_DOCS` contract that updated architecture docs,
  package boundaries, contracts, implementation phase guidance, verification
  surfaces, diagrams, and registries without implementing production Dart.
- `docs/verification/tests.md` can document future tests and guardrail test
  ownership without creating those test files in the same documentation step.
- `docs/verification/guardrails.md` can document mandatory guardrail rules
  before their executable implementation arrives in a later code step.
- `docs/tool/check_docs.dart` is the correct structural tool for documentation
  navigation and diagram catalog validation.

### Repository Rules

- `PLAN.md` is the active roadmap index and each step has a dedicated contract
  file.
- Documentation is written in English.
- Documentation-only changes do not require `dart analyze`, `dcm analyze .`,
  `dcm calculate-metrics .`, or runtime `dart test`.
- Source-of-truth knowledge that changes future implementation, testing,
  debugging, operation, or architecture must be recorded in repository docs,
  tests, guardrails, or tooling rather than chat only.

### Misleading Patterns

- The backlog's coordinator name in `todo.md` is product context, not durable
  architecture source of truth.
- Keeping shared cleanup policy repeated across tool-specific diagrams is
  misleading once the coordinator is accepted; diagrams may keep tool-specific
  terminal rules but must point shared cleanup policy at the coordinator.
- A production implementation contract shape is misleading for this step; this
  step must not own `lib/**`, `test/**`, or `tool/**` implementation.
- Putting cleanup ownership in `PointerSession` is misleading because pointer
  session owns routing/token lifecycle, not selected move, marquee, draw, line,
  eraser, or text cleanup policy.
- Putting cleanup ownership in runtime/public signal aggregation is misleading
  because cleanup and active-token release must complete before public state,
  action, text-request, or repaint effects are published.

## 3. Architecture Decision

### Selected Form

Document Candidate A as the accepted future form:

```text
Tool machine -> InteractionEngine -> PointerToolCleanupCoordinator -> PointerCleanupOutcome
```

The future coordinator is an internal `InteractionEngine` collaborator with
typed cleanup requests and an effect-only outcome. Future typed cleanup requests
carry cleanup reason plus ownership context. Tool machines recognize gestures
and return terminal commit intents or typed cleanup requests to
`InteractionEngine`. `InteractionEngine` is the only caller of the coordinator
and remains responsible for sequencing resolver/edit paths and later public
effect publication.

The future coordinator owns cleanup policy and outcome calculation for these
cleanup reasons:

- cancel;
- dispose;
- prepared load success;
- mode/tool change;
- active-session `interactive=false`;
- stale terminal;
- invalid terminal;
- no-op terminal;
- resolver cancel/error after valid resolver entry;
- edit failure after a commit intent;
- post-successful-commit cleanup.

The future coordinator outcome records previous preview kind, preview-changed
flag, public-state need, repaint target, active token/session release fact,
pending line cleared/preserved fact, pending text tap cleared fact, and
load/dispose sequencing facts.

### Ownership

- This step owns documentation updates only.
- Future production implementation remains under `lib/src/interaction/**`.
- `InteractionEngine` remains the future composition owner and only caller of
  the coordinator.
- `PointerToolCleanupCoordinator` is documented as the future cleanup policy
  owner and outcome calculator.
- Tool machines remain documented as gesture recognizers and terminal
  decision/request builders.
- Active pointer token/session and `controllerEpoch` remain pointer-session
  facts.
- Public preview remains the interaction-owned sealed preview snapshot.
- Runtime/public signal aggregation remains owner of public state publication,
  repaint notifications, action events, text-request events, stream close, and
  load publication.

### Seam

This step migrates source-of-truth wording from duplicated tool-local cleanup
policy ownership to the documented future coordinator seam:

```text
Tool machine -> InteractionEngine -> PointerToolCleanupCoordinator -> PointerCleanupOutcome
```

No production seam is created, renamed, or retired in this documentation step.
The implementation seam is documented for a later code step.

### Dependency Direction

The documentation must state these future dependency expectations:

- `InteractionEngine` may depend on `PointerToolCleanupCoordinator`.
- Tool machines may construct typed cleanup requests and return them to
  `InteractionEngine`; they must not call the coordinator directly.
- The coordinator may depend on interaction state models and public preview
  value types needed to produce `CanvasNoPreview` outcomes.
- The coordinator must not depend on concrete store internals, concrete
  selection internals, selected-move resolver callbacks, `EditKernel`, action
  dispatchers, text-request streams, frame engine, repaint buses, Flutter
  widgets/adapters, resource resolver/session APIs, public runtime-state
  publication, or legacy package paths.
- The coordinator must not own final terminal normalization, hit testing,
  spatial candidate selection, exact eraser checks, commit-intent creation, or
  committed document/selection/resource mutation.
- Runtime/public signal aggregation may consume `PointerCleanupOutcome` after
  cleanup, but must not re-read stale active session state to decide cleanup
  effects.

### State and Data Ownership

The documentation must state that the coordinator is not a second state store or
cache. It mutates or clears only authoritative interaction-owned state supplied
to it by `InteractionEngine` and does not mirror pointer, preview, selected
move, marquee, draw, line, eraser, or text state into a duplicate model.

The documentation must also preserve these state facts:

- previous preview kind is captured before changing preview to
  `CanvasNoPreview`;
- selected move cleanup maps to main-scene repaint;
- overlay preview cleanup maps to overlay repaint;
- no-preview cleanup requests no repaint and is public-state silent;
- active preview cleanup advances preview revision only when preview state
  changed;
- non-owned pending line state is preserved on `interactive=false`;
- pending line is cleared only by line-owned cleanup, mode/tool change,
  successful load, dispose, or terminal line decision;
- the cleanup request shape carries ownership context so pending line
  preservation and clearing rules are enforceable by the future coordinator
  seam;
- pending text tap cleanup clears tap history without preview, repaint, action,
  text-request, document, selection, spatial, or projection effects.

### Entry and Exit Boundaries

Documentation entry boundaries:

- `.design/2026-05-19-pointer-tool-cleanup-coordinator.md`;
- `PLAN.md`;
- active docs, diagrams, registries, indexes, and verification inventories.

Future implementation entry boundaries to document:

- pointer cancel;
- invalid or stale terminal cleanup;
- no-op terminal cleanup;
- mode/tool change;
- active-session `interactive=false`;
- prepared load success interrupt;
- dispose;
- selected-move resolver cancel/error after valid terminal entry;
- edit failure after a commit intent;
- post-successful-commit cleanup.

Future implementation exit boundary to document:

- `PointerCleanupOutcome` consumed by `InteractionEngine` and runtime/public
  signal aggregation after cleanup is complete.

### Verification Strategy

Use documentation structural checks plus targeted semantic searches.

Semantic proof must show that active source-of-truth docs name the coordinator,
lock `InteractionEngine` as the only caller, keep the coordinator internal and
effect-only, preserve pending line/text cleanup rules, and record future
behavioral and structural proof requirements. Negative proof must show active
source-of-truth surfaces no longer assign shared cleanup policy ownership,
preview/session cleanup ownership, or cleanup-effect publication ownership to
individual tool machines.

### Decision Ledger

| ID | Decision | Owner | Proof |
|---|---|---|---|
| D1 | Document `PointerToolCleanupCoordinator` as the future internal cleanup policy seam with typed cleanup requests carrying reason plus ownership context and with an effect-only outcome. | `docs/contracts/interaction_engine.md` | P1, P2 |
| D2 | Document `InteractionEngine` as the future composition owner and only caller of the coordinator. | `docs/architecture/01_runtime_ownership.md`, `docs/contracts/interaction_engine.md` | P1, P2 |
| D3 | Document the coordinator as internal to `lib/src/interaction/**` and absent from public API/export surfaces. | `docs/architecture/02_package_boundaries.md` | P1, P2 |
| D4 | Document cleanup outcome semantics for previous preview kind, repaint target, preview revision/no-op behavior, token/session release, pending line, and pending text cleanup. | `docs/contracts/interaction_engine.md`, `docs/diagrams/**` | P1, P2 |
| D5 | Document P10/P11/P12 migration order so future tool machines consume the same cleanup seam. | `docs/implementation/p10_selection_and_move.md`, `docs/implementation/p11_draw_tools.md`, `docs/implementation/p12_eraser_and_text_request.md` | P1, P2 |
| D6 | Document future behavioral and structural verification requirements for cleanup ownership and bypass prevention. | `docs/verification/guardrails.md`, `docs/verification/tests.md` | P1, P2 |

### Rejected Alternatives

- `PointerSession` as cleanup owner: rejected because it would give a
  routing/token object knowledge of selected move, marquee, draw, line, eraser,
  and text cleanup policy.
- Per-tool cleanup plus shared tests: rejected because it preserves duplicated
  cleanup policy and relies on sampled test coverage rather than one documented
  owner.
- Runtime/public signal aggregation as cleanup owner: rejected because it mixes
  transient interaction cleanup with public publication and risks violating the
  documented order that cleanup and token release happen before public effects.
- Production implementation in this step: rejected because the user requested a
  documentation contract and the step is scoped to source-of-truth updates only.

## 4. Execution Guardrails

### Required Order

1. Update architecture, package-boundary, and interaction contract docs to lock
   ownership, placement, dependency direction, and outcome semantics.
2. Update pointer cleanup diagrams and data-flow diagrams so shared cleanup
   policy routes through the coordinator while tool-specific terminal rules
   remain visible.
3. Update P10/P11/P12 implementation phase docs so future implementation order
   follows the documented seam migration.
4. Update verification docs and registry/index surfaces so future proof
   requirements and navigation match the selected form.
5. Run documentation structural checks and targeted semantic/negative searches.

### Cross-Slice Constraints

- Do not edit `lib/**`, `test/**`, or `tool/**` in this step.
- Do not document any public API/export/schema/event change.
- Do not turn `PointerToolCleanupCoordinator` into a runtime owner, state cache,
  public API type, resolver, edit owner, action/text dispatcher, repaint
  notifier, Flutter adapter, resource owner, or store/selection reader.
- Do not leave source-of-truth wording that makes individual tool machines the
  owner of shared cleanup policy.
- Keep tool-specific gesture and terminal rules in diagrams where useful, but
  route shared cleanup policy ownership through the coordinator.
- Do not run implementation checks (`dart analyze`, `dcm analyze .`,
  `dcm calculate-metrics .`, or runtime `dart test`) for this docs-only step.

### Seam Migration

| Consumer group | Retired wording seam | Successor wording seam | Migration order | Retirement gate |
|---|---|---|---|---|
| Architecture and interaction contracts | `InteractionEngine` and tool diagrams imply cleanup policy without naming a shared coordinator | `InteractionEngine` owns composition; `PointerToolCleanupCoordinator` owns cleanup policy and effect-only outcome | First | P2 proves coordinator ownership, internal placement, only-caller rule, and effect-only semantics appear in active docs. |
| Pointer cleanup diagrams | Tool-local states describe shared preview/session cleanup and cleanup target classification as local policy | Diagrams route shared cleanup close/classification through the coordinator while keeping tool-specific terminal states | Second | P2 proves diagrams name the coordinator or describe coordinator-owned outcomes for shared cleanup policy. |
| P10/P11/P12 phase guidance | Later tool phases can independently interpret terminal cleanup | P10 introduces the seam, P11 and P12 consume the existing seam | Third | P2 proves phase docs record the migration order. |
| Verification docs | Existing guardrails cover individual cleanup risks but not future coordinator ownership/bypass prevention | Verification docs require behavior proof plus structural proof that cleanup-capable tool machines use the coordinator | Fourth | P2 proves future guardrail/test requirements are present. |
| Active source-of-truth wording | Duplicated tool-local cleanup policy ownership, preview/session cleanup ownership, or cleanup-effect publication ownership | Shared cleanup policy ownership assigned to `PointerToolCleanupCoordinator` | Final | P3 proves no active source-of-truth hit assigns shared cleanup policy ownership to individual tool machines. |

### Forbidden Moves

- Do not add production Dart, runtime tests, or guardrail runner code.
- Do not create a public API change.
- Do not document direct tool-machine calls to the coordinator.
- Do not document resolver, edit, action, text-request, repaint, Flutter,
  resource, store, selection, or legacy dependencies on the coordinator.
- Do not document final terminal normalization, hit testing, spatial candidate
  selection, exact eraser checks, or commit-intent creation as coordinator
  responsibilities.
- Do not leave future verification as prose-only when the constraint requires a
  future behavioral or structural proof entry.

### Deferred Broad Verification

`dart analyze`, `dcm analyze .`, `dcm calculate-metrics .`, runtime `dart test`,
and any executable interaction guardrail are deferred to the later production
implementation step because this step changes documentation only.

## 5. Proof Plan

### P1. Documentation Structure

This proves documentation entrypoints, registries, diagram catalog membership,
and generated context capsules remain structurally valid.

```sh
dart run docs/tool/check_docs.dart
dart run docs/tool/generate_context_capsules.dart --check
```

Expected signal: both commands exit 0.

### P2. Selected Coordinator Semantics

This proves the active source of truth records the selected coordinator form,
ownership, internal placement, only-caller rule, effect-only outcome, migration
order, and future proof requirements.

```sh
rg -n "PointerToolCleanupCoordinator|PointerCleanupOutcome|only caller|typed cleanup request|ownership context|effect-only|pointer_tool_cleanup_coordinator\\.dart|cleanup-capable tool machines" docs/architecture docs/contracts docs/diagrams docs/implementation docs/verification docs/_registry docs/indexes
```

Expected signal: hits appear only in active source-of-truth surfaces that
document the selected coordinator form, internal placement, caller rule,
effect-only outcome, or future verification requirements.

### P3. Retired Tool-Local Cleanup Ownership

This proves active source-of-truth docs no longer present individual tool
machines as the owner of shared cleanup policy, preview/session cleanup
ownership, or cleanup-effect publication ownership after the coordinator is
accepted.

```sh
rg -n "tool-local cleanup|owns cleanup|shared cleanup|preview/session cleanup|cleanup-effect|cleanup effect|cleanup policy owner|TerminalCleanup|OverlayCleanup|MainSceneCleanup|NoPreviewCleanup" docs/architecture docs/contracts docs/diagrams docs/implementation docs/verification docs/_registry docs/indexes
```

Expected signal: every hit either names `PointerToolCleanupCoordinator` as the
shared policy owner, describes a tool-specific gesture/terminal transition
without assigning shared policy ownership, or describes a coordinator-owned
outcome.

### P4. No Production Scope Drift

This proves the documentation-only step did not edit production implementation,
runtime tests, or guardrail runner code.

```sh
git diff --name-only -- lib test tool
```

Expected signal: no paths are printed.

## 6. Vertical Slices

### Slice 1. [x] Architecture And Contract Source Of Truth

#### Implements

D1, D2, D3, and D4.

#### Obligations Covered

SEAM_MIGRATION

#### Files

- Primary documentation edit: `docs/architecture/01_runtime_ownership.md` —
  document the coordinator as an internal `InteractionEngine` cleanup policy
  seam and document `InteractionEngine` as the only caller.
- Primary documentation edit: `docs/architecture/02_package_boundaries.md` —
  add `pointer_tool_cleanup_coordinator.dart` under `lib/src/interaction/**`
  and keep it internal/unexported.
- Primary contract edit: `docs/contracts/interaction_engine.md` — document the
  coordinator, cleanup reasons, typed request ownership context, effect-only
  outcome, previous-preview repaint classification, pending line/text cleanup
  semantics, and forbidden dependencies.
- Alignment contract edit: `docs/contracts/load_document.md` — ensure prepared
  load success references the coordinator-owned cleanup boundary without
  changing load success/failure ordering.

#### Change

The core source of truth records the future coordinator seam, internal
placement, caller rule, state ownership, and cleanup outcome semantics.

#### Proof

Run P1 and the architecture/contract-relevant subset of P2:

```sh
rg -n "PointerToolCleanupCoordinator|PointerCleanupOutcome|only caller|typed cleanup request|ownership context|effect-only|pointer_tool_cleanup_coordinator\\.dart" docs/architecture docs/contracts
```

Expected signal: hits document D1 through D4 without public API or production
implementation scope.

#### Closure

Slice is complete when architecture and contract docs lock D1 through D4 and
documentation structure still passes.

### Slice 2. [x] Diagram Cleanup Routing

#### Implements

D1, D2, and D4.

#### Obligations Covered

SEAM_MIGRATION

#### Files

- Data-flow diagram edit: `docs/diagrams/dfd_pointer_preview_commit.mmd` —
  route cleanup-only, terminal failure, and post-edit cleanup through the
  coordinator before public effects.
- State diagram edit: `docs/diagrams/state_pointer_session.mmd` — delegate
  preview/session close, token release, and cleanup-target classification to the
  coordinator.
- State diagram edit: `docs/diagrams/state_selected_move.mmd` — preserve
  selected move terminal/resolver rules while pointing shared cleanup policy at
  the coordinator.
- State diagram edit: `docs/diagrams/state_select_marquee.mmd` — preserve
  marquee terminal rules while pointing shared cleanup policy at the
  coordinator.
- State diagram edit: `docs/diagrams/state_pencil_marker_draw.mmd` — preserve
  draw terminal rules while pointing shared cleanup policy at the coordinator.
- State diagram edit: `docs/diagrams/state_two_tap_line.mmd` — preserve pending
  line ownership rules while pointing shared cleanup policy at the coordinator.
- State diagram edit: `docs/diagrams/state_eraser.mmd` — preserve eraser
  terminal rules while pointing shared cleanup policy at the coordinator.
- State diagram edit: `docs/diagrams/state_pending_text_edit_request.mmd` —
  preserve text-request cleanup silence while pointing shared cleanup policy at
  the coordinator.

#### Change

Cleanup diagrams show the coordinator as the shared policy owner and
classification point while retaining tool-specific terminal/gesture semantics.

#### Proof

Run P1 and the diagram-relevant subset of P2 and P3:

```sh
rg -n "PointerToolCleanupCoordinator|PointerCleanupOutcome|coordinator-owned|cleanup coordinator|TerminalCleanup|OverlayCleanup|MainSceneCleanup|NoPreviewCleanup" docs/diagrams
```

Expected signal: diagram hits route shared cleanup through the coordinator or
describe tool-specific terminal states without assigning shared policy ownership
to the tool state.

#### Closure

Slice is complete when diagrams route shared cleanup ownership through the
coordinator and documentation structure still passes.

### Slice 3. [ ] Phase Guidance And Verification Inventory

#### Implements

D5 and D6.

#### Obligations Covered

SEAM_MIGRATION

#### Files

- Phase guidance edit: `docs/implementation/p10_selection_and_move.md` — require
  P10 to introduce the coordinator and migrate selected move/marquee cleanup
  wording.
- Phase guidance edit: `docs/implementation/p11_draw_tools.md` — require P11
  draw/line work to consume the existing coordinator.
- Phase guidance edit: `docs/implementation/p12_eraser_and_text_request.md` —
  require P12 eraser/text work to consume the existing coordinator.
- Verification inventory edit: `docs/verification/guardrails.md` — add or map
  the future cleanup-coordinator structural guardrail requirement.
- Verification inventory edit: `docs/verification/tests.md` — add or map future
  behavioral tests for cleanup outcome semantics and coordinator consumers.
- Registry alignment: `docs/_registry/sections.yaml` — align affected sections
  with updated guardrail, test, and diagram references.
- Index alignment: `docs/indexes/**` — update generated or maintained indexes
  only if docs tooling requires it.

#### Change

Future implementation guidance and verification inventories require P10/P11/P12
to converge on the same cleanup seam and require behavior plus structural proof
before implementation closure.

#### Proof

Run P1 and the phase/verification subset of P2:

```sh
rg -n "PointerToolCleanupCoordinator|cleanup coordinator|cleanup-capable tool machines|P10|P11|P12|no resolver|stale terminal|interactive=false|pending line" docs/implementation docs/verification docs/_registry docs/indexes
```

Expected signal: hits document the migration order and future proof
requirements without adding executable test or guardrail implementation.

#### Closure

Slice is complete when phase guidance and verification docs record D5 and D6,
and documentation structure still passes.

### Slice 4. [ ] Roadmap Closure And Negative Proof

#### Implements

D1 through D6.

#### Obligations Covered

SEAM_MIGRATION

#### Files

- Roadmap index file: `PLAN.md` — keep Step 18 unchecked until the
  documentation step is actually executed; mark it complete only in the later
  execution change after all proof passes.
- Step contract file: `plan/step_18_pointer_tool_cleanup_coordinator.md` —
  mark completed slice checkboxes only after corresponding slice proof passes.
- Verify-only documentation surfaces: `docs/architecture/**`,
  `docs/contracts/**`, `docs/diagrams/**`, `docs/implementation/**`,
  `docs/verification/**`, `docs/_registry/**`, and `docs/indexes/**` — provide
  the bounded active source-of-truth search surface for P2 and P3.
- Explicit production implementation exclusion: `lib/**` — must not be changed
  by this documentation-only step.
- Explicit runtime test exclusion: `test/**` — must not be changed by this
  documentation-only step.
- Explicit guardrail runner exclusion: `tool/**` — must not be changed by this
  documentation-only step.

#### Change

The roadmap and step contract remain aligned, and the docs-only step has
negative proof that it did not drift into production implementation or leave
retired cleanup ownership wording active.

#### Proof

Run P1, P2, P3, and P4.

#### Closure

Slice is complete when all documentation checks and targeted searches pass,
`PLAN.md` and this step contract have matching completion state, and no
production/test/tool paths were changed.

## 7. Final Gate

### Run Proof Set

- P1. Documentation Structure
- P2. Selected Coordinator Semantics
- P3. Retired Tool-Local Cleanup Ownership
- P4. No Production Scope Drift

### Done When

- D1 through D6 each have the proof named in the Decision Ledger;
- `SEAM_MIGRATION` is satisfied by the migration table in section 4;
- every retirement gate in the `Seam Migration` table is closed;
- P1 through P4 pass;
- no out-of-scope files were changed;
- `PLAN.md` and this step contract have matching completion state;
- whitespace validation passes.
