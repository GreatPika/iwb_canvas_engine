# Change Contract

Contract Mode: FULL
Contract Profile: SOURCE_OF_TRUTH_DOCS
Contract Obligations: SEAM_MIGRATION, PUBLIC_API_CHANGE

## 1. Mandate and Boundary

### Mandate

Convert `.design/2026-05-19-double-tap-context-action.md` into accepted
source-of-truth documentation for double-tap context actions.

This is a documentation-only roadmap step. It must replace the active
text-only double-tap request contract with a general application-owned context
request contract for content targets and empty canvas, while preserving guarded
text editing as an application choice. It must not implement production Dart,
runtime tests, Flutter UI, analyzer rules, generated runtime code, or
behavioral test files.

### In Scope

- Document Candidate A from the design as the selected target form:
  `CanvasRuntime.contextActionRequests` emits `CanvasContextActionRequested`
  events for valid double-tap context targets.
- Document that the engine emits exactly one context request for each accepted
  valid double-tap target: either content element or empty canvas.
- Retire `CanvasRuntime.textEditRequests` and `CanvasTextEditRequested` from the
  target public API docs and registries instead of keeping a parallel text-only
  stream.
- Keep `CanvasToolPort.handleDoubleTap` as the public input boundary for the
  gesture.
- Document `CanvasContextActionTrigger.doubleTap` and a sealed
  `CanvasContextActionTarget` union with content-element and empty-canvas
  variants.
- Document that a content-element target carries an immutable public
  `CanvasElement` snapshot and `boundsWorld`.
- Document that text editing remains application-owned: the application may open
  a menu first or immediately show a text editor when the content target
  snapshot is a `CanvasTextElement`.
- Preserve `CanvasCommandPort.commitTextEdit(requestId, newText)` as the
  guarded text mutation seam for request-originated text edits.
- Document that `commitTextEdit` accepts only current, unretired context request
  ids whose target is a text content element, and rejects empty-canvas,
  non-text, stale, retired, missing, or family-mismatched request ids without
  document, repaint, or action effects.
- Document context-action target eligibility separately from selection hit
  eligibility: finite point, visible content element, finite invertible
  transform, exact geometry hit, and topmost in content paint order.
- Document that `element.isSelectable` does not gate context-action requests.
- Document that background elements never produce content-element context
  targets; a point covered only by background elements is an empty-canvas
  context target.
- Document first/second tap matching and revalidation rules for content targets
  and empty-canvas targets.
- Document that first and second taps must match the same target class; content
  targets must revalidate the same current element id, generation,
  elementRevision, family, controllerEpoch, visibility, and top-hit status, and
  empty-canvas targets must still have no qualifying content target within the
  configured double-tap constraints.
- Document that `InteractionRequestRegistry` stores context request guard facts:
  request id, request target kind, controllerEpoch, retired status, and, for
  content targets, target element id, generation, elementRevision, and family.
- Document that context request delivery has no document, selection, preview,
  repaint, spatial, projection, resource, or user-action effect.
- Update durable diagrams, registries, phase guidance, donor guidance,
  verification docs, indexes, and generated documentation navigation only where
  required to keep the source-of-truth map coherent.
- Update this step and `PLAN.md` checkboxes only when the documentation step is
  later executed.

### Out of Scope

- No production Dart implementation.
- No production Dart tests or fixtures.
- No Flutter overlay, context menu, text editor, IME, focus, accessibility, text
  selection, hide/show policy, or app-owned UI implementation.
- No document mutation, selection mutation, preview mutation, resource mutation,
  repaint publication, spatial/projection update, or action event from context
  request delivery.
- No change to selection hit eligibility or pointer selection semantics.
- No engine-owned context menu or text editor.
- No duplicate text request stream next to the context-action stream.
- No broad implementation-file naming decision beyond documentation of the
  future route ownership. The later implementation contract owns exact Dart file
  placement.
- No updates to historical research, design, or completed plan-step records
  except this active step file and `PLAN.md`.

## 2. Evidence Map

### Baseline Evidence

These facts describe repository state before execution. They are evidence for
the change, not target-state requirements.

- `.design/2026-05-19-double-tap-context-action.md` is
  `READY_FOR_CONTRACT` and classifies the next step as
  `SOURCE_OF_TRUTH_DOCS` with `PUBLIC_API_CHANGE` and `SEAM_MIGRATION`.
- `.research/2026-05-19-double-tap-docs-current-contract.md:13` records that
  current docs describe double-tap as a text-edit request only.
- `.research/2026-05-19-double-tap-docs-current-contract.md:17` records that
  current docs explicitly defer contextual-action events for shapes, images,
  lines, and empty canvas.
- `.research/2026-05-19-double-tap-docs-current-contract.md:127` records that
  current hit eligibility is narrower than the requested content-target policy
  because it requires `element.isSelectable`.
- `.research/2026-05-19-double-tap-docs-current-contract.md:140` records that
  broadening double-tap touches registries, phase docs, verification docs, and
  release gates.

### Entry Paths

- `docs/contracts/public_api_v1.md:1680` documents
  `CanvasToolPort.handleDoubleTap({required Offset position, int? timestampMs})`
  as the public double-tap input boundary.
- `docs/contracts/interaction_engine.md:215` starts the current primary
  `Text double-tap` contract section.
- `docs/contracts/public_api_v1.md:359` exposes
  `Stream<CanvasTextEditRequested> get textEditRequests`.
- `docs/contracts/public_api_v1.md:2212` declares the current public
  `CanvasTextEditRequested` payload.
- `docs/_registry/public_api_v1.yaml:86` lists `CanvasTextEditRequested` as a
  public export name.

### Current Owners

- `docs/README.md:3` says `docs/` is the durable source of truth for the
  new-engine transition and target architecture.
- `docs/contracts/interaction_engine.md:221` through
  `docs/contracts/interaction_engine.md:226` currently own text request
  registry facts and the emitted text request payload.
- `docs/contracts/interaction_engine.md:233` through
  `docs/contracts/interaction_engine.md:235` state that the registry is not an
  active text-input session or preview state and that the application owns the
  editor UI concerns.
- `docs/contracts/interaction_engine.md:237` through
  `docs/contracts/interaction_engine.md:244` own the guarded
  `commitTextEdit` text mutation path.
- `docs/architecture/01_runtime_ownership.md:153` through
  `docs/architecture/01_runtime_ownership.md:160` assign
  `InteractionRequestRegistry` to interaction-owned guard facts, not app
  overlay state.
- `docs/architecture/02_package_boundaries.md:247` through
  `docs/architecture/02_package_boundaries.md:252` state that the request
  registry stores only engine-issued request facts and that guarded mutations
  enter through command ports before `EditKernel`.

### Existing Checks

- `docs/README.md:75` through `docs/README.md:80` define
  `docs/tool/check_docs.dart` as the structural checker for documentation
  entrypoints, registries, ids, paths, diagram catalog membership, and phase
  navigation.
- `docs/README.md:82` through `docs/README.md:87` document the docs verification
  commands:
  `dart run docs/tool/generate_context_capsules.dart --check` and
  `dart run docs/tool/check_docs.dart`.
- `docs/verification/tests.md:261` through `docs/verification/tests.md:266`
  currently name text edit requests in the runtime-created timestamp contract.
- `docs/verification/tests.md:453` currently names pending text tap cleanup
  emitting no text request.
- `docs/verification/release_gates.md:200` currently requires text edit request
  and guarded stale text commit integration tests.

### Valid Precedents

- `plan/step_10_interaction_request_text_edit_stale_guard.md` is a prior
  `SOURCE_OF_TRUTH_DOCS` contract that changed the documented request id and
  stale guard seam before implementation.
- `plan/step_11_operation_matrix_field_effect_taxonomy.md` is a prior
  `SOURCE_OF_TRUTH_DOCS` contract that updated operation effects and release
  verification before implementation.
- `plan/step_18_pointer_tool_cleanup_coordinator.md` is a prior
  `SOURCE_OF_TRUTH_DOCS` contract for locking future interaction ownership in
  documentation only.
- `docs/contracts/public_api_v1.md:1409` through
  `docs/contracts/public_api_v1.md:1431` document runtime-created timestamp
  behavior as a public contract and currently name
  `CanvasTextEditRequested.timestampMs` as one covered timestamp.

### Repository Rules

- `PLAN.md:5` identifies the active roadmap as the plan index, with each step
  represented by a dedicated document.
- `PLAN.md:17` gives the step entry template for new roadmap steps.
- `PLAN.md:28` through `PLAN.md:29` require updating both the index and linked
  step document when a step is completed.
- `docs/README.md:35` through `docs/README.md:37` state that role-based files
  and `_registry/sections.yaml` are the current documentation owners.
- Documentation-only changes do not require `dart analyze`, `dcm analyze .`, or
  `dcm calculate-metrics .`; this step's proof is docs structural checks and
  bounded semantic proof.

### Misleading Patterns

- `docs/contracts/interaction_engine.md:246` through
  `docs/contracts/interaction_engine.md:248` reserve
  `CanvasInteractionRequestId` for a future contextual-action request API, but
  still explicitly defer that API; this is baseline evidence, not target state.
- `docs/contracts/geometry.md:57` defines selection-oriented hit eligibility
  with `element.isSelectable`; the context-action target policy must be a
  separate documented policy and must not rewrite selection hit semantics.
- `docs/contracts/operation_matrix.md:84` currently names `text double-tap
  request`; this row should migrate to context-action request semantics, not
  remain as a parallel text-only row.
- `docs/architecture/02_package_boundaries.md:92` currently names
  `text_tap_router.dart`; this is a route ownership clue, not a final
  implementation filename for the later code step.
- `docs/diagrams/seq_text_edit_request.mmd` and
  `docs/diagrams/state_pending_text_edit_request.mmd` currently encode
  text-only no-hit and non-text cleanup paths; those diagrams should be replaced
  or renamed for context-action behavior rather than patched as text-only
  diagrams.
- Historical `.research/`, `.design/`, and completed `plan/step_*.md` files may
  continue to mention `CanvasTextEditRequested` and `textEditRequests` as
  historical evidence.

## 3. Architecture Decision

### Selected Form

Replace the text-specific double-tap request documentation with a general
context-action request seam.

The target public surface is:

```dart
final class CanvasRuntime {
  Stream<CanvasContextActionRequested> get contextActionRequests;
}

enum CanvasContextActionTrigger { doubleTap }

final class CanvasContextActionRequested {
  CanvasContextActionRequested({
    required this.requestId,
    required this.trigger,
    required this.target,
    required this.controllerEpoch,
    required this.documentRevision,
    required this.timestampMs,
    required this.viewPosition,
    required this.worldPosition,
  });

  final CanvasInteractionRequestId requestId;
  final CanvasContextActionTrigger trigger;
  final CanvasContextActionTarget target;
  final int controllerEpoch;
  final int documentRevision;
  final int timestampMs;
  final Offset viewPosition;
  final Offset worldPosition;
}

sealed class CanvasContextActionTarget {}

final class CanvasContentElementContextActionTarget
    extends CanvasContextActionTarget {
  CanvasContentElementContextActionTarget({
    required this.elementSnapshot,
    required this.boundsWorld,
  });

  final CanvasElement elementSnapshot;
  final Rect boundsWorld;
}

final class CanvasEmptyCanvasContextActionTarget
    extends CanvasContextActionTarget {
  const CanvasEmptyCanvasContextActionTarget();
}
```

The exact prose may refine names only if the final docs preserve these locked
semantics: one context request stream, exactly one emitted context request for
each accepted valid double-tap target, content-or-empty target union, app-owned
menu/editor decision, guarded text commit through `commitTextEdit`, no request
delivery effects, background exclusion, non-selectable content eligibility,
content target revalidation by current element id, generation, elementRevision,
family, controllerEpoch, visibility, and top-hit status, empty-canvas request
delivery when no qualifying content target exists, and request registry facts
for target kind plus content-target guard facts.

### Ownership

Interaction documentation owns double-tap target detection, request emission,
request guard facts, and cleanup/no-effect semantics. Public API documentation
owns the exported request stream and public payload shape. Geometry
documentation owns the context-action target eligibility policy. Operation
matrix documentation owns the effect row. Architecture documentation owns
registry and route ownership. The application owns context menus, text editor
overlays, IME, focus, accessibility, text selection, hide/show policy, and
menu/editor lifetime.

### Seam

The retired public request seam is
`CanvasRuntime.textEditRequests` plus `CanvasTextEditRequested`. The successor
public request seam is `CanvasRuntime.contextActionRequests` plus
`CanvasContextActionRequested`.

`CanvasInteractionRequestId` remains the request identity seam. The guarded text
mutation seam remains `CanvasCommandPort.commitTextEdit(requestId, newText)`,
but it now accepts only current, unretired context request ids whose target is a
text content element.

This is a breaking target public API documentation migration. No compatibility
alias, duplicate stream, or versioned transition window is documented because
the repository is still rebuilding unreleased target architecture docs. The
later implementation contract must migrate the public API atomically to the
successor context-action seam.

### Dependency Direction

The documented direction remains interaction-owned request detection through
narrow read-only document/selection/runtime facts and
`InteractionRequestRegistry` guard facts. Request delivery exits through the
runtime stream to application UI. Later text mutation re-enters through the
public command port, consumes registry facts through a narrow boundary, and
delegates accepted text changes to `EditKernel`.

The docs step must not document app UI state, Flutter state, or menu/editor
lifetime as engine-owned data, and must not make context request delivery depend
on document mutation or repaint publication.

### State and Data Ownership

Pending double-tap target history is interaction state. Context request guard
facts are registry state: request id, request target kind, controllerEpoch,
retired status, and, for content targets, target element id, generation,
elementRevision, and family. The emitted content target snapshot is immutable
public DTO data. Empty-canvas targets carry no element snapshot. App
menu/editor state is application state. `documentRevision` on the emitted
request is observation and diagnostics only, not a stale guard.

### Entry and Exit Boundaries

The entry boundary remains `CanvasToolPort.handleDoubleTap({required Offset
position, int? timestampMs})` with normalized finite tap samples from the
surface/tool boundary.

The exit boundary becomes `CanvasRuntime.contextActionRequests`. The only later
mutation boundary for request-originated text editing remains
`CanvasCommandPort.commitTextEdit(requestId, newText)`.

### Verification Strategy

Use documentation structural checks plus bounded semantic proof. Structural
proof must cover generated docs navigation, registries, diagram references, and
phase navigation. Semantic proof must show the successor context-action terms
are present in active source-of-truth surfaces and that active source-of-truth
surfaces no longer define the text-only request seam or the contextual-action
deferral as the target contract.

Do not add production tests to this documentation-only step. Instead, update
verification docs to require later implementation tests for content targets,
non-selectable content targets, empty canvas, background-only points, text
commit guard acceptance/rejection, timestamp monotonicity, operation effects,
and pending context tap cleanup.

### Decision Ledger

| ID | Decision | Owner | Proof |
|---|---|---|---|
| D1 | Double-tap emits one application-owned context request stream for content-element or empty-canvas targets; the text-only request stream is retired from target docs. | `docs/contracts/public_api_v1.md`, `docs/contracts/interaction_engine.md`, `docs/_registry/public_api_v1.yaml` | P1, P2, P3 |
| D2 | Context-action target eligibility is distinct from selection hit eligibility, excludes background content targets, and does not require `element.isSelectable`. | `docs/contracts/geometry.md`, `docs/contracts/interaction_engine.md` | P1, P3 |
| D3 | Request delivery remains effect-only; guarded text mutation remains a later `commitTextEdit` command accepted only for current text content-target request ids. | `docs/contracts/operation_matrix.md`, `docs/contracts/interaction_engine.md`, `docs/contracts/public_api_v1.md` | P1, P3 |
| D4 | Diagrams, registries, implementation phase guidance, donor guidance, verification docs, and indexes migrate from text-request naming to context-action request naming where they are active source-of-truth surfaces. | `docs/diagrams/`, `docs/_registry/`, `docs/implementation/`, `docs/donors/`, `docs/verification/`, `docs/indexes/` | P1, P4, P5 |

### Rejected Alternatives

- Keep both `textEditRequests` and `contextActionRequests`. Rejected because it
  creates two public request seams for one double-tap gesture and forces
  applications to merge text and non-text context behavior.
- Keep `CanvasTextEditRequested` and only add menu wording around it. Rejected
  because the current text payload cannot represent non-text content targets or
  empty canvas.
- Treat double-tap context as a committed user action or command callback.
  Rejected because a context request is application-owned UI intent, not a
  document mutation, selection mutation, preview mutation, repaint, or action
  effect.
- Change selection hit eligibility to satisfy context-action targeting.
  Rejected because selection and context-action target eligibility are separate
  policies.

## 4. Execution Guardrails

### Required Order

1. Update the core public API and interaction contracts before downstream
   registries, diagrams, phase docs, and verification docs.
2. Update geometry and operation matrix semantics before verification docs that
   name expected target eligibility or effect rows.
3. Update diagrams and their registry/catalog entries in the same slice.
4. Update phase, donor, verification, and index surfaces after the public API
   terms and diagram ids are stable.
5. Run semantic proof before final docs structural checks so stale wording is
   caught before registry/navigation verification.
6. Mark this step complete in `PLAN.md` and in this step document only after all
   documentation proof passes.

### Cross-Slice Constraints

- Keep the step documentation-only. Do not edit `lib/`, `test/`, `example/`, or
  runtime analyzer/guardrail source files.
- Keep `CanvasToolPort.handleDoubleTap` as the public input boundary.
- Keep `CanvasInteractionRequestId` generic and shared by context requests and
  guarded text commit.
- Keep `CanvasCommandPort.commitTextEdit` as the request-originated text commit
  seam.
- Do not document `documentRevision` as a stale guard for context requests.
- Do not make background elements context content targets.
- Do not add app UI ownership to `InteractionRequestRegistry` or any runtime
  state owner.
- Do not update historical `.research/`, `.design/`, or completed `plan/`
  records to satisfy negative proof.

### Seam Migration

| Consumer group | Retired or changed seam | Successor seam | Migration order | Retirement gate |
|---|---|---|---|---|
| Public runtime docs and API registry | `CanvasRuntime.textEditRequests`, `CanvasTextEditRequested` | `CanvasRuntime.contextActionRequests`, `CanvasContextActionRequested`, `CanvasContextActionTrigger`, `CanvasContextActionTarget` variants | Public API prose and registry first, then downstream references | P2 proves successor terms exist and retired public request stream/type are absent from active public source-of-truth surfaces. |
| Interaction contract and request registry prose | Text double-tap emits `CanvasTextEditRequested` for visible selectable text only | Double-tap emits a context request for content-element or empty-canvas targets | Interaction contract after public API shape is stable | P3 proves target semantics and no-effect request delivery are documented and the contextual-action deferral is gone from active contracts. |
| Geometry targeting docs | Selection hit eligibility reused implicitly for text request targeting | Separate context-action target policy | Geometry contract before phase/test docs | P3 proves non-selectable content eligibility and background exclusion are documented. |
| Operation effects docs | `text double-tap request` row and `textEditRequested` proof naming | Context-action request row and context request timestamp proof naming | Operation matrix before verification/release gates | P3 proves request delivery remains effect-only and text-only effect naming is retired from active effect docs. |
| Diagram and section registry ids | `seq_text_edit_request`, `state_pending_text_edit_request` as durable active ids | Context-action sequence and pending context target state diagram ids | Diagram files and registry/catalog together | P4 proves diagram ids, paths, and section registry references agree and retired active diagram ids are absent. |
| Phase, donor, verification, and index guidance | P12 text double-tap router/request wording and text-request verification rows | P12 context-action double-tap routing and implementation verification requirements | Downstream guidance after contracts/diagrams | P5 proves active phase, donor, verification, and index surfaces name context-action requirements and no longer treat contextual action as deferred. |

### Forbidden Moves

- Do not implement the context-action stream, target classes, registry changes,
  hit policy, router, or tests in code.
- Do not add runtime compatibility shims, aliases, adapters, or synchronizers
  for `textEditRequests`.
- Do not document a compatibility window where both public request streams are
  active.
- Do not weaken text stale guards to use `documentRevision`.
- Do not move text editing UI ownership into the engine.
- Do not satisfy semantic proof by editing historical evidence files.
- Do not rename unrelated diagrams or phase files.

### Deferred Broad Verification

The later implementation contract owns runtime behavior tests for request
emission, hit policy, registry facts, stream delivery, text commit acceptance
and rejection, timestamp monotonicity, operation effects, cleanup behavior, and
public API code shape. This docs-only step only updates the source-of-truth docs
that define those future checks.

## 5. Proof Plan

### P1. Documentation Structure

This proves generated documentation navigation, registries, diagram membership,
ids, paths, and phase navigation are structurally coherent after the docs-only
source-of-truth change.

```sh
dart run docs/tool/generate_context_capsules.dart --check
dart run docs/tool/check_docs.dart
```

Expected signal: both commands exit successfully.

### P2. Public Request Seam Migration

This proves the active public source-of-truth surfaces expose the successor
context-action request seam and no longer expose the retired text request stream
or event as the target public API.

```sh
rg -n "contextActionRequests|CanvasContextActionRequested|CanvasContextActionTrigger|CanvasContextActionTarget|CanvasContentElementContextActionTarget|CanvasEmptyCanvasContextActionTarget" docs/contracts/public_api_v1.md docs/_registry/public_api_v1.yaml docs/contracts/interaction_engine.md
! rg -n "Stream<CanvasTextEditRequested> get textEditRequests|final class CanvasTextEditRequested|CanvasRuntime\\.textEditRequests|CanvasTextEditRequested is the current public request payload" docs/contracts/public_api_v1.md docs/_registry/public_api_v1.yaml docs/contracts/interaction_engine.md
```

Expected signal: the first command finds the successor public request names in
the active contract and registry; the second command finds no retired public
text request stream/type definition in those active public source-of-truth
surfaces.

### P3. Context Target Semantics and No-Effect Delivery

This proves the active contracts document context-action target semantics,
background exclusion, non-selectable content eligibility, app-owned text
editing, guarded text commit, and no-effect request delivery while removing the
old contextual-action deferral.

```sh
rg -n "empty-canvas|empty canvas|background|isSelectable|context-action target|context action target|CanvasTextElement|commitTextEdit|no document, selection, preview, repaint, spatial, projection, resource, or action effect" docs/contracts/interaction_engine.md docs/contracts/public_api_v1.md docs/contracts/geometry.md docs/contracts/operation_matrix.md docs/architecture/01_runtime_ownership.md docs/architecture/02_package_boundaries.md
! rg -n "does not introduce a full contextual-action event|contextual-action event API remains deferred|text double-tap request|text edit request stream only|textEditRequested" docs/contracts/interaction_engine.md docs/contracts/public_api_v1.md docs/contracts/geometry.md docs/contracts/operation_matrix.md docs/architecture/01_runtime_ownership.md docs/architecture/02_package_boundaries.md
```

Expected signal: the first command finds the successor semantics in active
contract/architecture surfaces; the second command finds no active text-only
double-tap seam or contextual-action deferral in those same surfaces.

### P4. Diagram and Registry Migration

This proves durable diagram ids and section registry references have moved from
text-edit request diagrams to context-action request diagrams.

```sh
rg -n "seq_.*context.*action|state_.*context|context-action request|context action request|pending context" docs/diagrams docs/_registry/sections.yaml docs/contracts/interaction_engine.md docs/implementation/p12_eraser_and_text_request.md
! rg -n "seq_text_edit_request|state_pending_text_edit_request|Text double-tap edit request|Pending text edit request" docs/diagrams docs/_registry/sections.yaml docs/contracts/interaction_engine.md docs/implementation/p12_eraser_and_text_request.md docs/implementation/p13_flutter_surface.md docs/implementation/p14_benchmarks_diagrams_and_release_readiness.md
```

Expected signal: the first command finds the successor diagram ids/prose; the
second command finds no active durable references to retired text-edit request
diagram ids in diagram catalogs, section registry, or phase navigation.

### P5. Phase, Donor, Verification, and Index Migration

This proves downstream active planning and verification surfaces require the
future context-action implementation behavior and no longer treat the full
contextual-action API as deferred.

```sh
rg -n "contextActionRequests|CanvasContextActionRequested|context-action|context action|empty-canvas|empty canvas|background-only|non-selectable|commitTextEdit" docs/implementation docs/donors docs/verification docs/indexes
! rg -n "CanvasTextEditRequested|textEditRequests|text double-tap on selectable text emits|contextual-action event API remains deferred|text edit request and guarded stale text commit integration tests" docs/implementation docs/donors docs/verification docs/indexes
```

Expected signal: the first command finds successor phase/donor/verification
requirements; the second command finds no active downstream requirement that
keeps the retired text-only request seam or contextual-action deferral.

### P6. Roadmap Completion

This proves the roadmap index and the linked step document are completed
together only after all docs proof passes.

```sh
rg -n "^- \\[x\\] \\[Step 19\\. Double-tap context action documentation\\]\\(plan/step_19_double_tap_context_action_documentation\\.md\\)$" PLAN.md
! rg -n "^### Slice [0-9]+\\. \\[ \\]" plan/step_19_double_tap_context_action_documentation.md
```

Expected signal: after execution, the first command finds the completed Step 19
entry in the roadmap index and the second command finds no incomplete slice
checkbox headings in the linked step document.

## 6. Vertical Slices

### Slice 1. [x] Public Context Request Seam

#### Implements

D1 and D3.

#### Obligations Covered

SEAM_MIGRATION, PUBLIC_API_CHANGE

#### Files

- Public API contract edit: `docs/contracts/public_api_v1.md` -- replace the
  public runtime request stream and public request payload model with the
  context-action request seam, update timestamp public contract wording, and
  preserve `CanvasToolPort.handleDoubleTap` plus `commitTextEdit`.
- Public API registry sync: `docs/_registry/public_api_v1.yaml` -- replace the
  retired public request event export with the successor context-action request
  names.
- Interaction contract alignment: `docs/contracts/interaction_engine.md` --
  replace the `Text double-tap` section with context-action request behavior,
  registry facts, text commit guard rules, and app-owned menu/editor ownership.

#### Change

The active public docs expose one context-action request stream and target
payload instead of the text-only request stream. Text editing remains possible
only as an application choice after receiving a text content-target context
request, and request-originated mutation still flows through
`commitTextEdit`.

#### Proof

Run P2 for public seam migration.

Run the interaction/API portion of P3 to prove request delivery semantics,
app-owned text editing, and guarded text commit wording are present and the old
contextual-action deferral is gone from active public/interaction contracts.

#### Closure

Slice 1 is complete when active public API and interaction docs define the
successor context-action seam, the public API registry names the successor
types, and no active public source-of-truth surface still defines
`textEditRequests` or `CanvasTextEditRequested` as the target double-tap seam.

### Slice 2. [x] Target Eligibility and Effect Semantics

#### Implements

D2 and D3.

#### Obligations Covered

SEAM_MIGRATION

#### Files

- Geometry contract edit: `docs/contracts/geometry.md` -- add context-action
  target eligibility separate from selection hit eligibility, including
  non-selectable content eligibility and background exclusion.
- Operation matrix edit: `docs/contracts/operation_matrix.md` -- replace the
  text double-tap request row with a context-action request row and preserve
  no-effect request delivery.
- Runtime ownership edit: `docs/architecture/01_runtime_ownership.md` -- align
  request registry facts with context target kind and content-target guard
  facts while keeping app UI state outside the registry.
- Package-boundary edit: `docs/architecture/02_package_boundaries.md` -- rename
  future route ownership from text tap routing to context-action double-tap
  routing without locking a production implementation file beyond documented
  ownership.
- Data model verify-only evidence: `docs/architecture/03_data_model.md` -- use
  existing `locationKind: background | content` documentation as evidence for
  background exclusion; edit only if cross-reference wording is required by the
  final source-of-truth docs.

#### Change

The active contracts separate context-action targeting from selection
targeting, document that background is never a content context target, and keep
context request delivery effect-free until a later accepted command.

#### Proof

Run P3 for target semantics and no-effect delivery.

Run P1 if this slice changes registered sections, generated navigation, or
context capsules.

#### Closure

Slice 2 is complete when geometry, operation matrix, and architecture docs agree
that context-action requests use their own target policy, do not require
selectability, exclude background content targets, and do not mutate document,
selection, preview, spatial, projection, resource, repaint, or action state.

### Slice 3. [x] Context Request Diagrams and Registries

#### Implements

D4.

#### Obligations Covered

SEAM_MIGRATION

#### Files

- Sequence diagram replacement: `docs/diagrams/seq_text_edit_request.mmd` --
  replace or retire this durable text-request diagram in favor of a context
  action request sequence diagram.
- State diagram replacement: `docs/diagrams/state_pending_text_edit_request.mmd`
  -- replace or retire this durable pending-text diagram in favor of a pending
  context target state diagram.
- Diagram index sync: `docs/diagrams/README.md` -- align diagram ids, titles,
  paths, related phases, and related sections with the successor diagrams.
- Section registry sync: `docs/_registry/sections.yaml` -- replace retired
  diagram ids and text-request mappings with context-action request mappings.
- Contract diagram reference sync: `docs/contracts/interaction_engine.md` --
  align the diagram list with the successor diagram ids.
- Phase diagram navigation sync: `docs/implementation/p12_eraser_and_text_request.md`,
  `docs/implementation/p13_flutter_surface.md`, and
  `docs/implementation/p14_benchmarks_diagrams_and_release_readiness.md` --
  replace active durable diagram references to retired text-request diagrams.

#### Change

The durable diagram set describes context-action request flow and pending
context target state rather than text-only edit request flow.

#### Proof

Run P4 for diagram and registry migration.

Run P1 for structural diagram/catalog/registry verification.

#### Closure

Slice 3 is complete when active diagram files, diagram README entries, section
registry entries, contract references, and phase navigation all use successor
context-action diagram ids and no active durable reference still points to the
retired text-edit request diagrams.

### Slice 4. [x] Phase, Donor, Verification, and Index Guidance

#### Implements

D4.

#### Obligations Covered

SEAM_MIGRATION, PUBLIC_API_CHANGE

#### Files

- P12 phase guidance edit: `docs/implementation/p12_eraser_and_text_request.md`
  -- replace text double-tap router/request scope and exit gates with
  context-action double-tap routing, context request emission, and guarded text
  commit requirements.
- Later phase navigation edits: `docs/implementation/p13_flutter_surface.md`
  and `docs/implementation/p14_benchmarks_diagrams_and_release_readiness.md` --
  align future phase references to context-action request diagrams and public
  stream behavior.
- Donor guidance edit: `docs/donors/06_interaction_edit_event_staged_load.md`
  -- rename donor use from text double-tap edit-request routing to
  context-action double-tap routing where the donor remains relevant.
- Donor registry sync: `docs/_registry/donors.yaml` -- align donor names,
  allowed use, or target phase wording with successor context-action routing.
- Tests verification edit: `docs/verification/tests.md` -- replace text request
  test requirements with future context request requirements for selectable
  content, non-selectable content, empty canvas, background-only points, guarded
  text commit, timestamp monotonicity, no-effect delivery, and cleanup.
- Functional ledger edit: `docs/verification/functional_ledger.md` -- replace
  text edit request row and timestamp wording with context-action request
  function/proof names.
- Release gates edit: `docs/verification/release_gates.md` -- replace text edit
  request gates with context-action request and guarded text commit gates.
- Guardrail/index sync: `docs/verification/guardrails.md`,
  `docs/indexes/by_test_area.md`, `docs/indexes/by_guardrail.md`, and any
  generated docs index touched by the docs tools -- align active references
  where the structural checks require it.

#### Change

Downstream source-of-truth guidance now tells the later implementation step to
build and verify context-action double-tap behavior, not the retired text-only
request behavior.

#### Proof

Run P5 for downstream phase, donor, verification, and index migration.

Run P1 for generated navigation and registry consistency.

#### Closure

Slice 4 is complete when phase, donor, verification, release gate, guardrail,
and index surfaces consistently describe context-action request behavior and no
active downstream source-of-truth surface still treats the full contextual
action API as deferred.

### Slice 5. [x] Final Documentation Closure

#### Implements

D1, D2, D3, and D4.

#### Obligations Covered

SEAM_MIGRATION, PUBLIC_API_CHANGE

#### Files

- Roadmap index finalization: `PLAN.md` -- mark Step 19 complete only after all
  proof passes.
- Step contract finalization:
  `plan/step_19_double_tap_context_action_documentation.md` -- mark completed
  slice checkboxes only after their closure conditions pass.
- Explicit exclusions: `lib/`, `test/`, `example/`, `.research/`, `.design/`,
  and completed historical `plan/step_*.md` files other than this step -- do not
  edit these files for this docs-only step.

#### Change

The roadmap records the documentation step as complete only after all successor
docs, registries, diagrams, phase guidance, verification guidance, and negative
proof are coherent.

#### Proof

Run P6.

Also inspect the final diff to confirm no out-of-scope production code, tests,
research artifacts, design artifacts, or historical completed plan steps were
modified.

#### Closure

Slice 5 is complete when every slice checkbox is marked done, `PLAN.md` marks
Step 19 done, all proof commands pass, and the diff contains only in-scope
documentation changes.

## 7. Final Gate

### Run Proof Set

P1, P2, P3, P4, P5, and P6 must pass before closure.

### Done When

- D1, D2, D3, and D4 have passing proof.
- P1, P2, P3, P4, P5, and P6 have the expected signal.
- `SEAM_MIGRATION` is satisfied by the migration table in section 4 and by P2,
  P3, P4, and P5 negative proof.
- `PUBLIC_API_CHANGE` is satisfied by the public API contract owner,
  breaking target-docs compatibility decision, no-alias/no-window versioning
  note, registry update, migration note, and P2 public contract proof.
- No out-of-scope production code, production tests, analyzer code, generated
  runtime code, research artifact, design artifact, or completed historical
  plan-step record was edited.
- `PLAN.md` and this step file are marked complete in the same final change.
- Whitespace validation passes.
