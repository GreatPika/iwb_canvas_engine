# Change Contract

Contract Mode: FULL
Contract Profile: SOURCE_OF_TRUTH_DOCS
Contract Obligations: BUG_FIX, SEAM_MIGRATION, PUBLIC_API_CHANGE

## 1. Mandate and Boundary

### Mandate

Promote the text-edit stale guard into the active source of truth: request-originated
text commits must pass through an engine-owned guarded commit seam keyed by a
generic interaction request id, while the application continues to own the text
editor UI and while future contextual-action double-tap routing remains possible.

### In Scope

- Add a public `CanvasInteractionRequestId` identifier contract that follows the
  existing public id class policy and does not use Dart `extension type`.
- Add the `CanvasInteractionRequestId` validation limit and validator contract
  beside the existing public id limits.
- Extend `CanvasTextEditRequested` with `requestId`, `controllerEpoch`,
  `documentRevision`, and `elementRevision` while preserving the existing
  element id, timestamp, view/world positions, bounds, and immutable text
  snapshot facts.
- Add the guarded public commit seam
  `CanvasCommandPort.commitTextEdit(CanvasInteractionRequestId requestId, String newText, {int? timestampMs})`.
- Define stale rejection semantics for unknown or retired request ids, changed
  controller epoch, missing element, stale element generation, changed element
  revision, and non-text current element family.
- Define `documentRevision` as an emitted observation fact, not a stale-rejection
  guard, so unrelated document edits do not reject a still-current text edit.
- Define successful changed text commits as normal EditKernel-backed document
  edits with user-action notification semantics.
- Add a text-edit action notification shape that does not include raw text
  content.
- Align the interaction request lifecycle, sequence/state diagrams, operation
  matrix, verification mappings, phase guidance, and backlog/audit cleanup.
- Mark this plan step complete in `PLAN.md` and in this step document when the
  step is executed.

### Out of Scope

- No production Dart implementation under `lib/**`.
- No executable Dart tests under `test/**`.
- No full `CanvasContextActionRequested` or non-text contextual-action target
  API in this step.
- No engine-owned Flutter text editor overlay, IME, focus, accessibility, text
  selection, or app editor lifetime policy.
- No deprecation or removal of programmatic
  `CanvasEdit.updateElement(CanvasTextElementUpdate)` for non-request app sync.
- No hard stale rejection solely because `documentRevision` changed.
- No raw text values in action payloads, diagnostics, logs, or verification
  fixtures introduced by this step.

## 2. Evidence Map

### Baseline Evidence

These facts describe repository state before execution. They are evidence for
the change, not target-state requirements.

- `docs/contracts/public_api_v1.md` currently documents public id classes such
  as `CanvasElementId`, `CanvasLayerId`, `CanvasResourceId`, and
  `CanvasActionId`, and explicitly says no public `extension type` is used for
  ids.
- `docs/contracts/validation_limits.md` currently names max element, layer,
  resource, and action id lengths, but no interaction request id limit.
- `docs/contracts/public_api_v1.md` currently documents `CanvasRuntime` with
  `Stream<CanvasTextEditRequested> get textEditRequests`.
- `docs/contracts/public_api_v1.md` currently documents
  `CanvasCommandPort` with only `removeElement` and `clearContent`.
- `docs/contracts/public_api_v1.md` currently documents
  `CanvasTextEditRequested` with `elementId`, `timestampMs`, `viewPosition`,
  `worldPosition`, `boundsWorld`, and `textSnapshot`, but without request id,
  epoch, or revision facts.
- `docs/contracts/public_api_v1.md` currently says the application commits
  changed text through `updateElement(CanvasTextElementUpdate)` after receiving
  the text edit request.
- `docs/contracts/interaction_engine.md` says double-tap on a visible selectable
  text element emits `CanvasTextEditRequested` and does not mutate document or
  selection by itself.
- `docs/diagrams/state_pending_text_edit_request.mmd` already stores pending
  text tap `generation` and `controllerEpoch` before emission and revalidates
  the second tap against current committed facts.
- `docs/architecture/03_data_model.md` defines `ElementHandle.generation`,
  `elementRevision`, `structuralRevision`, and `boundsRevision`; it also defines
  `documentRevision` and `controllerEpoch`.
- `.research/2026-05-18-text-edit-stale-guard.md` records the stale-commit gap:
  the current accepted API has pre-emission stale guards but no guarded commit
  after the app-owned editor finishes.
- `redesign.md` contains an accepted direction note for adding text edit request
  identity, revision facts, and `commitTextEdit`, but its sketch uses
  `CanvasTextEditRequestId` as an `extension type`.

### Entry Paths

- The current text request entry path is double-tap routing through
  `CanvasSurface`, `CanvasToolPort`, `InteractionEngine`, narrow interaction
  read ports, `DocumentStoreKernel`, `SpatialKernel`, and `GeometryPolicy`,
  ending in the `CanvasTextEditRequested` stream.
- The current text commit entry path after request delivery is application code
  calling `CanvasEdit.updateElement(CanvasTextElementUpdate)` through the normal
  public edit path.
- The target guarded commit entry path is application code calling
  `CanvasCommandPort.commitTextEdit(...)` with the request id from the delivered
  request.

### Current Owners

- `docs/contracts/public_api_v1.md` owns public ids, command port signatures,
  action payload types, text request event shape, and the text editing model.
- `docs/_registry/public_api_v1.yaml` owns the machine-readable public export
  inventory.
- `InteractionEngine` owns double-tap request emission and text tap stale
  candidate facts through narrow read-only query ports.
- `EditKernel` owns atomic document mutation, rollback, touched-set compilation,
  and post-install publication for accepted edits.
- `RuntimeRoot` owns public runtime state publication and composition of the
  command, interaction, store, edit, and event boundaries.

### Existing Checks

- `docs/verification/tests.md` already names
  `test.interaction.no_stale_terminal_commit` for stale terminal commit safety.
- `docs/verification/tests.md` already names
  `test.interaction.commands_emit_user_actions` and
  `test.api.typed_action_payloads` for command/action event behavior.
- `docs/verification/guardrails.md` already maps
  `events.commands_emit_user_actions` to high-level commands and interaction
  commits owning user action events.
- `docs/verification/guardrails.md` already maps
  `interaction.no_stale_terminal_commit` to stale or epoch-mismatched terminal
  samples not creating commit intent.
- No inspected verification document currently names a proof for stale
  app-owned text commit after `CanvasTextEditRequested` has already been
  delivered.

### Valid Precedents

- Public id classes in `docs/contracts/public_api_v1.md` validate immediately
  through `CanvasIdValidators` and avoid public `extension type` wrappers.
- High-level commands in `CanvasCommandPort` use EditKernel for atomic mutation
  and own user-action event emission after install.
- Low-level `CanvasEdit.updateElement` remains programmatic and emits no user
  action event.
- Pending text tap state already treats generation and controller epoch as
  stale guards before request emission.
- Spatial and frame documentation already rejects stale handles by generation
  and structural revision before using candidate facts.

### Repository Rules

- `PLAN.md` is the active roadmap and every plan entry links to one dedicated
  step contract.
- Repository `docs/` are the durable source of truth for the new-engine target
  architecture.
- Public API declarations must compile as written, use explicit public type
  shapes, and keep exported names in `docs/_registry/public_api_v1.yaml`.
- Source-of-truth documentation changes must update related registries,
  indexes, guardrails, verification mappings, and phase guidance when contract
  meaning changes.
- Documentation-only changes do not require `dart analyze`,
  `dcm analyze .`, or `dcm calculate-metrics .`; documentation navigation and
  registry consistency are checked with the docs tools.

### Misleading Patterns

- The current phrase that the application commits request-originated text
  changes through `updateElement` is the stale-commit gap, not the target seam
  for app-owned text editing.
- The `redesign.md` `CanvasTextEditRequestId` `extension type` sketch is
  target-direction evidence only; it conflicts with the accepted public id
  policy.
- A hard `documentRevision` equality guard would reject unrelated edits to other
  elements and is too broad for this issue.
- A full contextual-action event for shapes, images, lines, or empty canvas is a
  future API direction, not required to close stale text commit safety now.
- An engine-owned Flutter editor session would move UI, IME, focus,
  accessibility, and lifetime policy into the wrong owner.

## 3. Architecture Decision

### Selected Form

Text edit requests receive a generic public `CanvasInteractionRequestId`.
`CanvasTextEditRequested` remains the emitted text-specific request event for
this step, but its identity is not text-specific so a later contextual-action
request API can reuse the same id family without renaming the stale-guard seam.

The public API contract must document this exact request id family and guarded
commit seam:

```dart
final class CanvasInteractionRequestId {
  CanvasInteractionRequestId._(this.value);
  factory CanvasInteractionRequestId(String value) {
    CanvasIdValidators.requireInteractionRequestId(
      value,
      name: 'interactionRequestId',
    );
    return CanvasInteractionRequestId._(value);
  }
  final String value;
}

final class CanvasTextEditRequested {
  CanvasTextEditRequested({
    required this.requestId,
    required this.elementId,
    required this.controllerEpoch,
    required this.documentRevision,
    required this.elementRevision,
    required this.timestampMs,
    required this.viewPosition,
    required this.worldPosition,
    required this.boundsWorld,
    required this.textSnapshot,
  });

  final CanvasInteractionRequestId requestId;
  final CanvasElementId elementId;
  final int controllerEpoch;
  final int documentRevision;
  final int elementRevision;
  final int timestampMs;
  final Offset viewPosition;
  final Offset worldPosition;
  final Rect boundsWorld;
  final CanvasTextElement textSnapshot;
}

abstract interface class CanvasCommandPort {
  bool commitTextEdit(
    CanvasInteractionRequestId requestId,
    String newText, {
    int? timestampMs,
  });
}
```

The validation limit contract must add
`CanvasInteractionRequestId -> non-empty trimmed string, length <= 256, no control characters`.
There is no public `CanvasRuntime.generateInteractionRequestId()`; the engine
generates request ids for emitted interaction requests and public consumers only
store or pass them back.

The command returns `false` and performs no mutation, state publication, repaint,
or action event when the request id is unknown or retired, the controller epoch
changed, the current element is missing, the current element generation no
longer matches the issued request, the current `elementRevision` changed, or
the current element is no longer a text element. A validation failure for
`newText` uses the existing text validation path before request retirement and
before draft mutation.

A successful commit retires the request id. If `newText` equals the current
text, the command returns `true`, retires the request, and emits no document
revision, repaint, or action event. If `newText` changes the current text, the
command applies the update inside the normal EditKernel transaction and emits a
text-edit user action after atomic install.

The action surface must add `CanvasActionType.editText` and
`CanvasTextEditActionPayload`. The payload must include `requestId`,
`previousTextLength`, and `nextTextLength`; it must not include raw previous or
next text content. The action `elementIds` list carries the edited element id.

`documentRevision` is emitted on the request as an observation and diagnostics
fact. It is not a stale guard for `commitTextEdit`; unrelated committed edits
between request emission and commit do not reject a text edit while the
requested text element generation and `elementRevision` remain current.

This step does not introduce a full contextual-action event. The only target
event remains `CanvasTextEditRequested`, with a generic request id that is
compatible with a later `CanvasContextActionRequested`-style API.

### Ownership

The public API contract owns the public id class, request event fields,
command signature, action type, action payload, validation and return-value
semantics, and compatibility note.

`InteractionEngine` owns issuing interaction request ids for text double-tap
requests and capturing immutable guard facts at emission time. It does not own
the Flutter text editor overlay or app editor lifetime.

`InteractionRequestRegistry` is an interaction-module component placed at
`lib/src/interaction/interaction_request_registry.dart`. `RuntimeRoot` owns the
registry instance lifetime, `InteractionEngine` issues request records through
it, and the command-port implementation consumes records through a narrow
registry boundary. Live records contain request id, element id, controller
epoch, element generation, element revision, element family, and retired status.
The registry is not public runtime state and is not `CanvasPreviewState`.

`CanvasCommandPort.commitTextEdit` owns the public commit entry point. It
validates the request record through the registry, validates `newText` through
the existing text limit rules, delegates changed text mutation to EditKernel,
and stages the text-edit action only after atomic install.

### Seam

The retired seam is request-originated text editing committed directly through
`CanvasEdit.updateElement(CanvasTextElementUpdate)`. That low-level edit API
continues to exist for programmatic app synchronization, but it is no longer the
documented commit seam for a delivered text edit request.

The successor seam is
`CanvasCommandPort.commitTextEdit(CanvasInteractionRequestId, String, {int? timestampMs})`.

### Public API Compatibility

This is a breaking draft-public-contract correction before the v1 public API
freeze and before root-package production implementation exists. The target v1
contract intentionally changes the documented `CanvasTextEditRequested` shape,
adds `CanvasInteractionRequestId`, adds `commitTextEdit`, and adds the
`editText` action notification shape.

Compatibility decision: no runtime compatibility shim is required in this
documentation step because there is no root-package public implementation to
migrate. The migration note for future consumers is: commits originating from
`CanvasTextEditRequested` must call `commitTextEdit` with the emitted
`requestId`; direct `CanvasEdit.updateElement(CanvasTextElementUpdate)` remains
available only for programmatic non-request synchronization.

### Dependency Direction

Interaction request issuance may read committed document facts only through the
existing narrow interaction read ports. `InteractionRequestRegistry` must not
expose store tables or mutation methods. `CanvasCommandPort` may ask the
registry for request guard facts and may ask the document/read boundary for the
current element facts needed to validate the guard, but the accepted mutation
still flows through EditKernel. Interaction and command owners must not import
concrete `DocumentStoreKernel` or Flutter widget/editor types.

### State and Data Ownership

The request registry stores only stale-guard facts and retired status. It does
not store application overlay state, text input controllers, selection ranges,
IME state, focus state, or accessibility state.

`CanvasTextEditRequested.textSnapshot` remains an immutable request-time
snapshot for the application editor. Current committed text remains owned by
the document store and changes only through accepted EditKernel mutation.

`controllerEpoch` invalidates requests across successful `loadDocument` or full
document replacement. `elementRevision` and element generation invalidate
requests across delete, same-id replacement, or any update to the target
element. `documentRevision` is not a guard.

### Entry and Exit Boundaries

Request entry starts when text double-tap routing emits `CanvasTextEditRequested`
with a generated `CanvasInteractionRequestId` and a registry record. Delivery
still has no document, selection, preview, spatial, projection, repaint, or
action effect.

Commit entry starts when application code calls `commitTextEdit` with the
request id. Stale rejection exits with `false` and no side effects. Accepted
no-op exits with `true`, retired request state, and no public state publication.
Accepted changed text exits after EditKernel atomic install with normal document
revision, invalidation, repaint, and text-edit action effects.

After runtime disposal, `commitTextEdit` follows the existing mutating public
operation rule and throws `StateError('CanvasRuntime is disposed.')` instead of
returning `false`.

### Verification Strategy

Verification is documentation-first. Prove the current accepted text editing
model lacks a post-emission guarded commit, then prove the public contract,
registry, interaction lifecycle, operation matrix, verification mappings, and
cleanup surfaces all name the successor seam and retired terms are gone from
active source-of-truth surfaces. Production Dart checks are deferred because
this step does not create `lib/**` or `test/**`.

### Decision Ledger

| ID | Decision | Owner | Proof |
|---|---|---|---|
| D1 | Request identity is `CanvasInteractionRequestId`, a public id class, not a text-specific id or extension type. | Public API contract and registry | P2, P5 |
| D2 | Request-originated text commits use `CanvasCommandPort.commitTextEdit` and retire the request after accepted no-op, accepted change, or stale rejection. | Public API contract, Interaction docs | P2, P3 |
| D3 | Stale commit rejection uses request id, controller epoch, element generation, element revision, and text family; `documentRevision` is observation-only. | Public API contract, Interaction docs, diagrams | P2, P3 |
| D4 | Changed text commits run through EditKernel and emit `editText` action notifications without raw text content. | Public API contract, operation matrix, verification docs | P2, P4 |
| D5 | The full contextual-action API is deferred; the text request event remains the only event changed by this step. | Public API contract, Interaction docs | P3, P5 |

### Rejected Alternatives

- Keep direct `updateElement` as the documented request commit path and tell
  applications to compare revisions. Rejected because stale safety belongs at
  the engine boundary and application-side checks have a time-of-check/time-of-use
  gap.
- Introduce `CanvasTextEditRequestId`. Rejected because the id would hard-code
  text editing into a seam that is intended to support future contextual
  requests.
- Use a public `extension type` for request ids. Rejected because accepted
  public id policy uses validating final classes.
- Reject any commit when `documentRevision` changed. Rejected because unrelated
  document edits should not invalidate an unchanged target text element.
- Move to an engine-owned Flutter editor session now. Rejected because UI, IME,
  focus, accessibility, text selection, and editor lifetime are application
  responsibilities.
- Add the full contextual-action target hierarchy now. Rejected because the
  stale text commit gap can be closed without broadening the double-tap API to
  shapes, images, lines, or empty canvas in this step.

## 4. Execution Guardrails

### Required Order

1. Run the BUG_FIX baseline reproducer before editing source-of-truth files:
   `rg -n "application commits changed text through updateElement|final class CanvasTextEditRequested|abstract interface class CanvasCommandPort|CanvasTextEditRequestId|commitTextEdit" docs/contracts/public_api_v1.md docs/_registry/public_api_v1.yaml redesign.md`.
2. Run the neighboring guard proof before owner-side edits:
   `rg -n "test\\.interaction\\.no_stale_terminal_commit|test\\.interaction\\.commands_emit_user_actions|test\\.api\\.typed_action_payloads|interaction\\.no_stale_terminal_commit|events\\.commands_emit_user_actions" docs/verification docs/indexes docs/_registry/sections.yaml`.
3. Update the public API contract and public export registry before downstream
   interaction, diagram, operation-matrix, verification, or cleanup documents.
4. Align interaction ownership and text request diagrams after the public
   request id and guarded commit seam are present.
5. Add verification, guardrail, release-gate, phase, and index mappings after
   the successor seam is named in public and interaction contracts.
6. Retire the accepted text stale-guard block from `redesign.md` and update the
   relevant `audit.md` text-edit request coverage only after successor docs and
   verification mappings exist.
7. After Slices 1 through 3 and P1 through P6 pass, complete Slice 4 by marking
   `PLAN.md` and this step document, then run P7 and the final gate.

### Cross-Slice Constraints

- Do not add production Dart files, executable tests, or tooling in this step.
- Keep application ownership of editor UI, IME, focus, accessibility, text
  selection, hide/show policy, and overlay lifetime.
- Do not treat `documentRevision` mismatch alone as stale.
- Do not expose internal element generation or request registry records as
  public API fields.
- Do not put text input session state into `CanvasPreviewState`,
  `DocumentStoreKernel`, or public runtime state.
- Do not include raw text content in action payloads, diagnostics, or logs.
- Preserve direct `CanvasEdit.updateElement(CanvasTextElementUpdate)` for
  programmatic non-request synchronization.

### Seam Migration

| Retired seam | Successor seam | Consumer migration order | Retirement gate |
|---|---|---|---|
| Request-originated text editing committed directly through `CanvasEdit.updateElement(CanvasTextElementUpdate)`. | `CanvasCommandPort.commitTextEdit(CanvasInteractionRequestId requestId, String newText, {int? timestampMs})`. | Public API contract and registry first; interaction lifecycle and diagrams second; operation matrix and verification mappings third; phase docs and backlog/audit cleanup last. | P2 and P5 prove the old request commit wording, text-specific request id proposal, and extension-type sketch are absent from active source-of-truth surfaces, while `commitTextEdit` and `CanvasInteractionRequestId` are present. |

This is a pre-freeze public-contract correction. Migration guidance is: use
`commitTextEdit` for commits that originate from `CanvasTextEditRequested`;
keep `CanvasEdit.updateElement` for programmatic synchronization that did not
originate from an engine-issued text request.

### Forbidden Moves

- Do not satisfy stale safety by adding app-side prose guidance without an
  engine-owned commit guard.
- Do not add background synchronizers or bridges between app overlay state and
  engine request state.
- Do not let request-retirement rules silently consume invalid `newText` before
  validation.
- Do not broaden this step into context menus or general double-tap target
  events.
- Do not delete unrelated `redesign.md` section 9 action-event notes or
  unrelated `audit.md` HOLE-002 checklist items.

### Deferred Broad Verification

Production Dart checks and executable runtime tests are deferred until a later
implementation step creates `lib/**` and `test/**`. This step proves the
source-of-truth contract, registry, diagrams, verification mappings, and
documentation structure only.

## 5. Proof Plan

### P0. BUG_FIX baseline and neighboring guards

Run before source-of-truth edits:

```sh
rg -n "application commits changed text through updateElement|final class CanvasTextEditRequested|abstract interface class CanvasCommandPort|CanvasTextEditRequestId|commitTextEdit" docs/contracts/public_api_v1.md docs/_registry/public_api_v1.yaml redesign.md
rg -n "test\\.interaction\\.no_stale_terminal_commit|test\\.interaction\\.commands_emit_user_actions|test\\.api\\.typed_action_payloads|interaction\\.no_stale_terminal_commit|events\\.commands_emit_user_actions" docs/verification docs/indexes docs/_registry/sections.yaml
```

Expected signal: the first command shows the current accepted text request
commit gap and the redesign-only stale-guard proposal; the second command shows
nearby stale terminal and command/action guard coverage that must remain.

### P1. Documentation structure

```sh
dart run docs/tool/generate_context_capsules.dart --check
dart run docs/tool/check_docs.dart
```

Expected signal: both documentation structure checks pass.

### P2. Public API guarded text commit seam

```sh
rg -n "final class CanvasInteractionRequestId|requireInteractionRequestId|final CanvasInteractionRequestId requestId|final int controllerEpoch|final int documentRevision|final int elementRevision|bool commitTextEdit\\(|CanvasActionType|editText|CanvasTextEditActionPayload|previousTextLength|nextTextLength|interaction request id length|CanvasInteractionRequestId -> non-empty trimmed string" docs/contracts/public_api_v1.md docs/contracts/validation_limits.md docs/_registry/public_api_v1.yaml docs/contracts/operation_matrix.md
! rg -n "extension type Canvas(TextEditRequestId|InteractionRequestId|ContextRequestId)|CanvasTextEditRequestId" docs/contracts/public_api_v1.md docs/_registry/public_api_v1.yaml
! awk '/Text editing model:/{flag=1} /### 4\\.20/{flag=0} flag' docs/contracts/public_api_v1.md | rg -n "application commits changed text through updateElement|loadDocument/dispose/tool change while editing is application responsibility"
rg -n "documentRevision.*observation|documentRevision.*not.*stale|unrelated document edits" docs/contracts/public_api_v1.md docs/contracts/interaction_engine.md
```

Expected signal: the first command finds the new public id, request facts,
commit seam, action type/payload, and operation-matrix coverage. The second and
third commands find no retired public id style or old text editing model. The
fourth command proves `documentRevision` is documented as observation-only.

### P3. Interaction request lifecycle

```sh
rg -n "CanvasInteractionRequestId|InteractionRequestRegistry|interaction_request_registry\\.dart|issued request|retired request|controllerEpoch|elementRevision|generation|not.*active text-input session|not.*CanvasPreviewState|contextual-action" docs/architecture/01_runtime_ownership.md docs/architecture/02_package_boundaries.md docs/contracts/interaction_engine.md docs/diagrams/seq_text_edit_request.mmd docs/diagrams/state_pending_text_edit_request.mmd
! rg -n "CanvasTextEditRequestId|extension type Canvas.*RequestId" docs/architecture/01_runtime_ownership.md docs/architecture/02_package_boundaries.md docs/contracts/interaction_engine.md docs/diagrams/seq_text_edit_request.mmd docs/diagrams/state_pending_text_edit_request.mmd
```

Expected signal: the first command finds request identity, registry ownership,
stale guard facts, app-owned editor boundary, and future contextual-action
compatibility language. The second command finds no text-specific or extension
type request id in these active surfaces.

### P4. Verification mapping

```sh
rg -n "test\\.interaction\\.text_edit_stale_commit_guard|test\\.interaction\\.commands_emit_user_actions|test\\.api\\.typed_action_payloads|interaction\\.text_edit_stale_commit_guard|events\\.commands_emit_user_actions|functional\\.text_edit_request|editText|commitTextEdit" docs/verification docs/indexes docs/_registry/sections.yaml docs/implementation/p12_eraser_and_text_request.md
```

Expected signal: verification, generated-style indexes, registry section
metadata, and P12 phase guidance name the future stale text commit proof,
command/action proof, and guarded commit seam.

### P5. Backlog and audit retirement

```sh
! rg -n "CanvasTextEditRequestId|Text edit request снабжаем stale guard|application commits changed text through updateElement\\(CanvasTextElementUpdate\\)" docs/contracts docs/architecture docs/diagrams docs/implementation docs/verification docs/_registry redesign.md audit.md
```

Expected signal: active source-of-truth docs, `redesign.md`, and `audit.md`
contain no retired text-specific request id sketch, accepted redesign block, or
old request commit wording.

### P6. Whitespace validation

```sh
git diff --check
```

Expected signal: no whitespace errors are reported.

### P7. Roadmap completion marking

```sh
rg -n "^- \\[x\\] \\[Step 10\\. Interaction request text edit stale guard\\]\\(plan/step_10_interaction_request_text_edit_stale_guard\\.md\\)$" PLAN.md
rg -n "^### Slice 1\\. \\[x\\]|^### Slice 2\\. \\[x\\]|^### Slice 3\\. \\[x\\]|^### Slice 4\\. \\[x\\]" plan/step_10_interaction_request_text_edit_stale_guard.md
! rg -n "^### Slice [1-4]\\. \\[ \\]" plan/step_10_interaction_request_text_edit_stale_guard.md
```

Expected signal: root `PLAN.md` marks Step 10 complete, all four slice
headings in this step document are marked complete, and no Slice 1 through 4
heading remains unchecked.

## 6. Vertical Slices

### Slice 1. [x] Public Guarded Text Commit Seam

#### Implements

D1, D2, D3, D4

#### Obligations Covered

BUG_FIX, SEAM_MIGRATION, PUBLIC_API_CHANGE

#### Files

- Primary public API contract: `docs/contracts/public_api_v1.md` — define
  `CanvasInteractionRequestId`, extend `CanvasTextEditRequested`, add
  `commitTextEdit`, add `editText` action notification, document stale/no-op
  semantics, and replace the old request commit model.
- Validation limit contract: `docs/contracts/validation_limits.md` — add the
  interaction request id length and validation boundary beside the existing
  public id limits.
- Public export inventory: `docs/_registry/public_api_v1.yaml` — export
  `CanvasInteractionRequestId` and `CanvasTextEditActionPayload`.
- Operation matrix owner: `docs/contracts/operation_matrix.md` — add or align
  rows for text double-tap request and guarded text commit effects, including
  stale rejection, no-op, changed commit, document revision, projection/spatial
  invalidation, repaint, and action event behavior.

#### Change

The public contract names the generic interaction request id and the guarded
text commit command. Request-originated text editing no longer documents direct
`updateElement` as the commit seam. Changed commits become normal EditKernel
document edits with `editText` user-action notification; stale and no-op paths
have explicit side-effect rules.

#### Proof

Run P0 before editing. After the slice edit, run P2.

#### Closure

The public API contract, export registry, and operation matrix agree on the
successor seam and no longer expose the retired text-specific id or direct
request commit wording.

### Slice 2. [x] Interaction Request Lifecycle And Ownership

#### Implements

D1, D2, D3, D5

#### Obligations Covered

BUG_FIX, SEAM_MIGRATION

#### Files

- Runtime ownership contract: `docs/architecture/01_runtime_ownership.md` —
  assign interaction request registry ownership to the interaction/runtime
  boundary without moving editor UI or store tables into InteractionEngine.
- Package layout contract: `docs/architecture/02_package_boundaries.md` —
  add the interaction-owned registry placement
  `lib/src/interaction/interaction_request_registry.dart` without adding code.
- Interaction contract: `docs/contracts/interaction_engine.md` — define request
  issuance, stored guard facts, retirement, app-owned editor boundary, and
  contextual-action compatibility.
- Text request sequence diagram: `docs/diagrams/seq_text_edit_request.mmd` —
  emit `CanvasTextEditRequested` with the new request id and revision facts,
  keep request delivery mutation-free, and show later guarded commit through
  `commitTextEdit`.
- Pending text request state diagram:
  `docs/diagrams/state_pending_text_edit_request.mmd` — include issued request
  registry state, retirement, epoch/generation/elementRevision stale rejection,
  and non-preview ownership.

#### Change

Interaction docs and diagrams distinguish pre-emission tap stale guards from
post-emission commit stale guards. They record that the engine stores only
request guard facts, not an active text input session, and that full contextual
double-tap actions remain deferred.

#### Proof

Run P3.

#### Closure

The interaction ownership documents and text request diagrams agree that request
delivery stays stream-only while later text commit safety is guarded by the
engine-owned request registry and command seam.

### Slice 3. [x] Verification, Phase Guidance, And Backlog Retirement

#### Implements

D1, D2, D3, D4, D5

#### Obligations Covered

BUG_FIX, SEAM_MIGRATION, PUBLIC_API_CHANGE

#### Files

- Test registry owner: `docs/verification/tests.md` — add the future
  `test.interaction.text_edit_stale_commit_guard` proof and update neighboring
  command/action proof focus where needed.
- Guardrail registry owner: `docs/verification/guardrails.md` — add
  `interaction.text_edit_stale_commit_guard` and align command/action guardrail
  wording for `editText`.
- Release gate owner: `docs/verification/release_gates.md` — include stale text
  commit and guarded command/action proof in the interaction/action gates.
- Generated-style test index owner: `docs/indexes/by_test_area.md` — map the
  new stale text commit proof to the public API, interaction, edit, and
  guardrail sections.
- Generated-style guardrail index owner: `docs/indexes/by_guardrail.md` — map
  the new stale text commit guardrail to its sections and tests.
- Section registry owner: `docs/_registry/sections.yaml` — wire the new proof
  and guardrail to public API and interaction sections.
- Phase guidance owner:
  `docs/implementation/p12_eraser_and_text_request.md` — require guarded text
  commit semantics in the text request phase without broadening to the full
  contextual-action API.
- Accepted redesign backlog owner: `redesign.md` — remove the accepted text
  edit stale-guard block after active source-of-truth docs own the design.
- Audit owner: `audit.md` — update only the text double-tap/text edit request
  coverage item related to this step while preserving unrelated HOLE-002 items.

#### Change

Verification and phase guidance name the future executable stale text commit
proof, the public API proof, and the command/action proof. The accepted
`redesign.md` note is retired only after active docs and mappings own the
decision. The audit entry is narrowed without falsely closing unrelated
operation-matrix coverage. This slice does not mark roadmap or step checkboxes;
that finalization is owned by Slice 4.

#### Proof

Run P4 and P5.

#### Closure

Verification, phase, index, registry, backlog, and audit surfaces agree that
guarded text commit is the active source-of-truth design and the old
redesign-only proposal is retired.

### Slice 4. [x] Roadmap Completion Finalization

#### Implements

D1, D2, D3, D4, D5

#### Files

- Roadmap index owner: `PLAN.md` — mark Step 10 complete after Slices 1 through
  3 and P1 through P6 have passed.
- Step contract owner:
  `plan/step_10_interaction_request_text_edit_stale_guard.md` — mark Slice 1
  through Slice 4 complete after their closure conditions have been satisfied.

#### Change

Finalize only roadmap and contract checkboxes. No architecture, public API,
verification, phase, audit, or backlog content may change in this slice.

#### Proof

Run P7.

#### Closure

`PLAN.md` and this step contract show Step 10 and all four slices as complete.

## 7. Final Gate

### Run Proof Set

Run P1, P2, P3, P4, P5, P6, and P7.

### Done When

- D1 through D5 have passing proof through P1 through P7;
- all Contract Obligations are satisfied;
- all retired seams have negative proof through P2 and P5;
- P7 proves roadmap and step-contract completion marking;
- no out-of-scope files were changed;
- P6 passes.
