# Change Contract

Contract Mode: FULL
Contract Profile: SOURCE_OF_TRUTH_DOCS
Contract Obligations: BUG_FIX, PUBLIC_API_CHANGE

## 1. Mandate and Boundary

### Mandate

Close HOLE-010 by making monotonic runtime-created timestamps an explicit
public compatibility contract with operation-matrix linkage, guardrail/test
mapping, release-gate coverage, and audit closure.

### In Scope

- Define `runtime_created_timestamps_monotonic` as the contract/test mapping id.
- Define what `timestampMs` means for runtime-created outputs.
- Define where runtime timestamps are resolved, which input values are hints,
  and which output surfaces receive resolved timestamps.
- Define the runtime-local time source, monotonicity scope, and behavior when a
  caller or host supplies a backwards timestamp hint.
- Link timestamp creation to action/text event surfaces and to related
  timestamped runtime outputs without relabeling previews or resolver requests
  as user-action events.
- Add operation matrix wording that maps timestamped rows and event-producing
  rows to the timestamp proof.
- Add `events.runtime_created_timestamps_monotonic` guardrail wording and
  `test.interaction.runtime_created_timestamps_monotonic` test inventory,
  index, section-registry, and release-gate linkage.
- Retire the HOLE-010 audit checklist after active source-of-truth documents
  own the contract and proof mapping.

### Out of Scope

- No production Dart implementation under `lib/**`.
- No Dart test implementation under `test/**`.
- No analyzer, guardrail runner, or docs-tool implementation under `tool/**` or
  `docs/tool/**`.
- No schema v1 persistence change; runtime-created timestamps remain event and
  runtime-output facts, not document data.
- No global, process-wide, cross-runtime, or wall-clock timestamp guarantee.
- No change to public constructor signatures or exported type names.
- No legacy package edits.
- No execution of `dart analyze`, `dcm analyze .`, or
  `dcm calculate-metrics .`, because this step is documentation-only.

## 2. Evidence Map

### Baseline Evidence

These facts describe repository state before execution. They are evidence for
the change, not target-state requirements.

- `.research/2026-05-19-monotonic-runtime-created-timestamps.md:13` through
  `.research/2026-05-19-monotonic-runtime-created-timestamps.md:24` record that
  legacy action/text events use `timestampMs` and that the allocator accepts
  forward hints while clamping null or backwards hints to the next cursor value.
- `.research/2026-05-19-monotonic-runtime-created-timestamps.md:108` through
  `.research/2026-05-19-monotonic-runtime-created-timestamps.md:119` record that
  observed legacy monotonicity is scoped to a dispatcher/runtime instance and
  that backwards input uses the same cursor comparison rather than a separate
  wall-clock branch.
- `.research/2026-05-19-monotonic-runtime-created-timestamps.md:154` through
  `.research/2026-05-19-monotonic-runtime-created-timestamps.md:176` record
  legacy tests for null hints and backwards hints preserving monotonic emitted
  action order.
- `docs/verification/legacy_capability_inventory.md:62` through
  `docs/verification/legacy_capability_inventory.md:63` record
  runtime-created timestamps as a monotonic legacy capability.
- `docs/verification/tests.md` currently names the neighboring action and
  context request proofs, but no separate proof names
  `runtime_created_timestamps_monotonic`.
- `docs/contracts/public_api_v1.md:1411`,
  `docs/contracts/public_api_v1.md:1415`,
  `docs/contracts/public_api_v1.md:1419`,
  `docs/contracts/public_api_v1.md:1460`, and
  `docs/contracts/public_api_v1.md:1644` expose nullable `timestampMs` inputs on
  command, selection, pointer, and double-tap APIs.
- `docs/contracts/public_api_v1.md:1922` through
  `docs/contracts/public_api_v1.md:1931` define
  `CanvasPendingLineStartPreview.timestampMs`.
- `docs/contracts/public_api_v1.md:2005` through
  `docs/contracts/public_api_v1.md:2017` define
  `CanvasActionCommitted.timestampMs`.
- `docs/contracts/public_api_v1.md:2176` through
  `docs/contracts/public_api_v1.md:2195` define
  `CanvasTextEditRequested.timestampMs`.
- `docs/contracts/public_api_v1.md:2237` through
  `docs/contracts/public_api_v1.md:2250` define
  `CanvasMoveCommitRequest.timestampMs`.
- `docs/_registry/public_api_v1.yaml:1` through
  `docs/_registry/public_api_v1.yaml:2` state that the public API registry is
  the machine-readable exported-name contract while semantic rules and
  signatures remain owned by `docs/contracts/public_api_v1.md`.
- `docs/_registry/public_api_v1.yaml:74` through
  `docs/_registry/public_api_v1.yaml:88` already list
  `CanvasActionCommitted`, `CanvasTextEditRequested`, and
  `CanvasMoveCommitRequest`, so the timestamp work changes semantics and proof
  mapping, not exported-name inventory.
- `docs/contracts/operation_matrix.md:46` through
  `docs/contracts/operation_matrix.md:88` list operation rows and event cells,
  including `deleteElements`, `selectMarquee`, `moveSelection`,
  `transformSelection`, `clearContent`, `drawPencil/drawMarker`, `drawLine`,
  `erase`, `textEditRequested`, and `editText`.
- `docs/contracts/operation_matrix.md:157` through
  `docs/contracts/operation_matrix.md:170` define the expanded row dimensions,
  including user-action notification and rollback behavior, but they do not
  define timestamp proof linkage.
- `docs/verification/guardrails.md:163` defines
  `edit.operation_matrix_complete`; `docs/verification/guardrails.md:167`
  defines `events.commands_emit_user_actions`; neither rule names monotonic
  runtime timestamps.
- `docs/verification/tests.md:223` through
  `docs/verification/tests.md:225` list action payload and user-action command
  tests, and `docs/verification/tests.md:251` through
  `docs/verification/tests.md:254` describe operation matrix coverage, but no
  required monotonic timestamp test is listed.
- `docs/verification/release_gates.md:184` through
  `docs/verification/release_gates.md:197` require operation matrix,
  text-edit, and action payload tests, but no release gate names monotonic
  runtime-created timestamp ordering.
- `audit.md:31` through `audit.md:51` track HOLE-010 and require a mapping id,
  timestamp definition, creation site, time source, scope, rollback behavior,
  event coverage, operation-matrix linkage, release-gate linkage, and a
  monotonic-order test.

### Entry Paths

- Roadmap entry path: root `PLAN.md` links this step file.
- Contract entry path: `docs/contracts/public_api_v1.md` owns public timestamp
  semantics and timestamp-bearing public shapes.
- Operation entry path: `docs/contracts/operation_matrix.md` owns operation and
  event linkage.
- Verification entry path: `docs/verification/guardrails.md`,
  `docs/verification/tests.md`,
  `docs/indexes/by_guardrail.md`, `docs/indexes/by_test_area.md`,
  `docs/_registry/sections.yaml`, and `docs/verification/release_gates.md` own
  the proof mapping.
- Audit entry path: `audit.md` owns the temporary HOLE-010 problem checklist
  until active source-of-truth documents close it.

### Current Owners

- `docs/contracts/public_api_v1.md` owns the public meaning of `timestampMs`,
  public input hints, public event shapes, and runtime-output shapes.
- `docs/contracts/operation_matrix.md` owns operation rows, user-action event
  cells, and operation-level proof linkage.
- `docs/verification/guardrails.md` owns mandatory guardrail ids and rules.
- `docs/verification/tests.md` owns required test ids and paths.
- `docs/indexes/**` and `docs/_registry/sections.yaml` own generated or
  registry-style navigation between sections, tests, and guardrails.
- `docs/verification/release_gates.md` owns final release proof requirements.
- `audit.md` is a temporary problem tracker, not the accepted owner for the
  timestamp contract after this step is implemented.

### Existing Checks

- `dart run docs/tool/check_docs.dart` is the available structural check for
  documentation entrypoints, registries, ids, paths, and diagram catalog
  consistency.
- `dart run docs/tool/generate_context_capsules.dart --check` is the available
  consistency check for generated context capsules.
- Targeted `rg` searches are the available semantic proof for the new mapping
  id, guardrail id, test id, rejected clock terminology, and audit retirement.
- No existing active-source check names
  `runtime_created_timestamps_monotonic` outside the audit/research context.

### Valid Precedents

- `docs/contracts/operation_matrix.md:126` through
  `docs/contracts/operation_matrix.md:178` use a compact expanded-dimensions
  section plus row-detail blocks for machine-checkable operation semantics.
- `docs/indexes/by_guardrail.md:161` through
  `docs/indexes/by_guardrail.md:166` map an event guardrail to sections and
  tests.
- `docs/indexes/by_test_area.md:163` through
  `docs/indexes/by_test_area.md:170` map an interaction test id to its path,
  phases, sections, guardrails, and focus.
- `docs/_registry/sections.yaml:454` through
  `docs/_registry/sections.yaml:464` map operation-matrix guardrails and tests
  to section 13.
- `docs/_registry/sections.yaml:508` through
  `docs/_registry/sections.yaml:523` map interaction guardrails and tests to
  section 14.

### Repository Rules

- Root `PLAN.md` is the active roadmap and every step must have a linked step
  document.
- Completed step contracts are historical records; active source-of-truth
  documents and active step contracts govern current navigation.
- When completing a plan step, update both the root `PLAN.md` checkbox and the
  linked step document in the same change.
- Documentation is written in English.
- Documentation-only changes do not require `dart analyze`,
  `dcm analyze .`, or `dcm calculate-metrics .`.

### Misleading Patterns

- The presence of `timestampMs` fields in public DTO snippets looks like enough
  contract coverage, but it does not define monotonicity, hint normalization,
  time source, scope, or wall-clock rollback behavior.
- The operation matrix `Events` column looks like it covers all event proof, but
  it only names user-action notification effects and does not prove timestamp
  order.
- Per-stream timestamp ordering looks simpler, but it would fail to define the
  order between action and text request streams that share the runtime.
- Using wall-clock time looks natural from the word "timestamp", but legacy
  evidence supports runtime ordering tokens, not global created-at time.
- Making `CanvasActionCommitted` constructors validate monotonic order would
  put runtime state inside DTO construction, which is the wrong owner for a
  per-runtime cursor.

## 3. Architecture Decision

### Selected Form

Create a documentation-only source-of-truth alignment that defines
`runtime_created_timestamps_monotonic` as the proof mapping for runtime-created
timestamps. The public contract must define `timestampMs` on runtime-created
outputs as a millisecond integer ordering token resolved by the runtime, not a
wall-clock creation time.

The selected timestamp resolver is runtime-local:

- each `CanvasRuntime` owns one monotonic timestamp cursor for timestamped
  runtime outputs;
- nullable public `timestampMs` values are hints at input boundaries;
- when the runtime creates a timestamped output, it computes
  `next = lastResolvedTimestampMs + 1`;
- a non-null hint greater than or equal to `next` resolves to the hint value;
- a null hint or a hint less than `next` resolves to `next`;
- the resolved value becomes the next cursor value;
- no global, process-wide, cross-runtime, or wall-clock monotonicity is
  promised;
- wall-clock rollback and stale host timestamps are represented as backwards
  hints and resolve to `next`.

The primary compatibility proof covers `CanvasActionCommitted.timestampMs` and
`CanvasTextEditRequested.timestampMs`. The same runtime-local resolver also
applies to `CanvasPendingLineStartPreview.timestampMs` and
`CanvasMoveCommitRequest.timestampMs` because those are timestamped runtime
outputs, but they must not be relabeled as user-action events.

The operation matrix must link every row that creates a timestamped runtime
output to `runtime_created_timestamps_monotonic`. Rows that emit a
`CanvasActionCommitted` action, rows that emit `textEditRequested`, the
`line first tap` pending preview row, and selected-move resolver request wording
must all point to the timestamp proof. No-op, stale rejection, rollback, cancel,
and dispose stream-close paths must not create a timestamped action or text
request.

Compatibility decision: this is a non-breaking public API contract
clarification. It strengthens the documented compatibility promise for existing
`timestampMs` fields and nullable input hints without adding exported names,
removing exported names, or changing public signatures. No migration is required
for applications that already treat `timestampMs` as ordering data. Applications
that assumed wall-clock created-at semantics must treat that assumption as
unsupported; no versioned schema or API migration is needed because the
contracted field shape is unchanged.

Public export registry handling: `docs/_registry/public_api_v1.yaml` is a
verify-only artifact for this step. It must not change unless implementation
discovers an exported-name contradiction, because the selected form does not add
or remove public exports and does not alter public signature shapes.

### Ownership

- `docs/contracts/public_api_v1.md` owns timestamp semantics, timestamp-bearing
  public output shapes, and input-hint wording.
- `docs/contracts/operation_matrix.md` owns operation-row linkage between
  timestamped outputs and the timestamp proof.
- The future runtime output/event boundary owns the runtime-local cursor; DTO
  constructors and applications do not own monotonicity.
- `docs/verification/**`, `docs/indexes/**`, and
  `docs/_registry/sections.yaml` own proof inventory, guardrail, test, index,
  and release-gate linkage.
- `audit.md` owns only temporary HOLE tracking until this step closes it.

### Seam

The seam is the public `timestampMs` compatibility contract on runtime-created
outputs. Inputs with nullable `timestampMs` cross into the runtime as hints;
observers receive resolved non-null `timestampMs` values on timestamped runtime
outputs.

### Dependency Direction

Public API timestamp semantics feed operation-matrix row linkage. Operation
matrix and event/text contracts feed guardrail, test, index, and release-gate
mapping. Future implementation must depend on the public runtime timestamp
contract through the runtime output/event owner, not on audit prose, research
notes, or per-call-site timestamp normalization.

### State and Data Ownership

The runtime timestamp cursor is internal mutable runtime state. It is scoped to
one `CanvasRuntime`, is not stored in `CanvasDocument`, is not encoded in schema
v1, is not part of resource, selection, preview revision, or document revision
state, and is not reconstructed from wall-clock time.

### Entry and Exit Boundaries

Entry boundaries are nullable `timestampMs` inputs on command, selection,
pointer, and double-tap APIs. Exit boundaries are `CanvasActionCommitted`,
`CanvasTextEditRequested`, `CanvasPendingLineStartPreview`, and
`CanvasMoveCommitRequest`. Successful timestamped output creation resolves the
hint once before publishing the output; no-op and rejected paths exit without a
timestamped action or text request.

### Verification Strategy

Use source-of-truth semantic proof plus documentation structural proof. The
semantic proof must find the mapping id, guardrail id, test id, operation
linkage, public timestamp semantics, release gate, and audit retirement in the
expected active documents. The structural proof must run the docs checker and
context-capsule check. Negative proof must show active source-of-truth surfaces
do not promise global or wall-clock timestamp semantics.

### Decision Ledger

| ID | Decision | Owner | Proof |
|---|---|---|---|
| D1 | Runtime-created `timestampMs` is a runtime-local ordering token, not wall-clock created-at time. | `docs/contracts/public_api_v1.md` | P2, P4 |
| D2 | One runtime-local resolver is shared by timestamped runtime outputs in a `CanvasRuntime`. | `docs/contracts/public_api_v1.md` and future runtime output/event owner | P2 |
| D3 | `CanvasActionCommitted` and `CanvasTextEditRequested` are the primary event/request compatibility proof; pending line preview and move resolver request are related timestamped runtime outputs, not user-action events. | `docs/contracts/public_api_v1.md`, `docs/contracts/operation_matrix.md` | P2, P3 |
| D4 | `runtime_created_timestamps_monotonic`, `events.runtime_created_timestamps_monotonic`, and `test.interaction.runtime_created_timestamps_monotonic` are the stable mapping ids. | `docs/verification/**`, `docs/indexes/**`, `docs/_registry/sections.yaml` | P3, P5, P6 |

### Rejected Alternatives

- Global or process-wide monotonic timestamps are rejected because legacy
  evidence supports dispatcher/runtime-local ordering and no public contract
  requires cross-runtime ordering.
- Wall-clock `DateTime.now()`-style creation time is rejected because rollback
  and stale host timestamps must not break emitted output ordering.
- Per-stream allocators are rejected because action and text request outputs
  need a single runtime ordering source.
- DTO-constructor monotonic validation is rejected because constructors cannot
  own per-runtime mutable cursor state.
- Operation-matrix-only wording is rejected because HOLE-010 requires linkage
  to public contract, tests, and release gates as well as matrix rows.

## 4. Execution Guardrails

### Required Order

1. Run P0 before edits to reproduce the HOLE-010 gap: the mapping id,
   guardrail id, and test id are absent from active source-of-truth surfaces.
2. Run P1 before edits as the neighboring guard check for the existing action,
   command-event, and operation-matrix proof mapping that this step extends.
3. Update public API timestamp semantics first so operation and verification
   docs can reference the accepted public contract.
4. Add operation-matrix linkage for timestamped runtime outputs.
5. Add guardrail, test, index, section-registry, and release-gate linkage.
6. Remove the open HOLE-010 entry from `audit.md` only after the active
   source-of-truth documents own the contract and proof mapping.
7. Run final semantic and structural documentation proof.

### Cross-Slice Constraints

- Do not add production runtime code or Dart tests in this documentation-only
  step.
- Do not define timestamp semantics separately in guardrail or index files;
  those files must point back to the public contract and operation matrix.
- Do not broaden the promise beyond one `CanvasRuntime`.
- Do not describe `timestampMs` as a persisted document fact, schema fact, or
  wall-clock creation time.
- Keep preview and resolver-request timestamp wording distinct from user-action
  event wording.

### Seam Migration

No seam migration is required. The work creates an explicit proof mapping for
an existing public timestamp seam and does not rename or retire a shared API
surface.

### Forbidden Moves

- Do not edit legacy package files.
- Do not remove `timestampMs` from any public shape.
- Do not add new exported public names.
- Do not add `DateTime`, `Stopwatch`, host clock, or global clock wording as the
  source of the compatibility guarantee.
- Do not mark HOLE-010 closed while `runtime_created_timestamps_monotonic` is
  present only in `audit.md`, research notes, or this plan step.

### Deferred Broad Verification

Runtime behavior proof is deferred to the future implementation phase that
creates the runtime output/event owner and
`test/interaction/runtime_created_timestamps_monotonic_test.dart`. This step
adds the required source-of-truth mapping so that later runtime work cannot
ship without the monotonic-order executable test.

## 5. Proof Plan

### P0. Pre-Fix HOLE-010 Reproducer

This proves the accepted gap before implementation: the runtime timestamp
mapping id, guardrail id, and test id are absent from active source-of-truth
surfaces even though the audit and research identify the hole.

```sh
rg -n "runtime_created_timestamps_monotonic|events\\.runtime_created_timestamps_monotonic|test\\.interaction\\.runtime_created_timestamps_monotonic" docs/contracts docs/verification docs/indexes docs/_registry
```

Expected signal before the fix: no matches and non-zero `rg` exit.

### P1. Neighboring Event Proof Mapping Exists

This proves the adjacent event and operation-matrix proof surfaces exist before
the fix, so the new timestamp proof extends the established mapping rather than
creating an orphan contract.

```sh
rg -n "events\\.commands_emit_user_actions|test\\.interaction\\.commands_emit_user_actions|test\\.edit\\.operation_matrix_effects|edit\\.operation_matrix_complete" docs/contracts/operation_matrix.md docs/verification docs/indexes docs/_registry
```

Expected signal before and after the fix: matches include
`docs/contracts/operation_matrix.md`, `docs/verification/guardrails.md`,
`docs/verification/tests.md`, `docs/indexes/by_guardrail.md`,
`docs/indexes/by_test_area.md`, and `docs/_registry/sections.yaml`.

### P2. Public Timestamp Contract Is Present

This proves the public timestamp contract exists after Slice 1 without
requiring operation-matrix, guardrail, index, registry, or release-gate edits
that belong to Slice 2.

```sh
rg -n "Runtime timestamp contract|runtime-local|timestampMs.*hint|CanvasActionCommitted\\.timestampMs|CanvasTextEditRequested\\.timestampMs" docs/contracts/public_api_v1.md
```

Expected signal after Slice 1: matches include
`docs/contracts/public_api_v1.md`.

### P3. Full Runtime Timestamp Mapping Is Present

This proves the stable mapping id, guardrail id, test id, and active public
contract wording are present in active source-of-truth documents.

```sh
rg -n "runtime_created_timestamps_monotonic|events\\.runtime_created_timestamps_monotonic|test\\.interaction\\.runtime_created_timestamps_monotonic|Runtime timestamp contract|runtime-local" docs/contracts docs/verification docs/indexes docs/_registry
```

Expected signal: matches include `docs/contracts/public_api_v1.md`,
`docs/contracts/operation_matrix.md`, `docs/verification/guardrails.md`,
`docs/verification/tests.md`,
`docs/indexes/by_guardrail.md`, `docs/indexes/by_test_area.md`,
`docs/_registry/sections.yaml`, and `docs/verification/release_gates.md`.

### P4. Rejected Clock Semantics Stay Absent

This proves active source-of-truth surfaces do not make positive promises of
global, cross-runtime, or wall-clock timestamp semantics. Explicit negative
phrases such as "no global guarantee" or "not wall-clock" are allowed and are
not part of this search.

```sh
rg -n "guarantees global timestamp|globally monotonic timestamp|process-wide timestamp source|cross-runtime timestamp order|DateTime\\.now\\(\\).*timestamp|wall-clock created-at timestamp|timestampMs is createdAt" docs/contracts docs/verification docs/indexes docs/_registry
```

Expected signal: no matches.

### P5. Documentation Structure Is Valid

This proves documentation entrypoints, registries, ids, paths, and diagram
catalog consistency remain valid.

```sh
dart run docs/tool/check_docs.dart
```

Expected signal: command exits 0.

### P6. Context Capsules Are Current

This proves generated context capsules remain synchronized with registry and
source-of-truth documents.

```sh
dart run docs/tool/generate_context_capsules.dart --check
```

Expected signal: command exits 0.

### P7. HOLE-010 Is Removed From Audit

This proves the temporary audit hole entry is removed after active
source-of-truth documents own the timestamp contract. The selected retirement
mode is removal, not a closed-but-still-present checklist entry.

```sh
rg -n "HOLE-010|Monotonic runtime-created timestamps|runtime-created timestamps не имеют" audit.md
```

Expected signal: no matches.

## 6. Vertical Slices

### Slice 1. [x] Public Runtime Timestamp Contract

#### Implements

D1, D2

#### Obligations Covered

BUG_FIX, PUBLIC_API_CHANGE

#### Files

- Primary contract edit: `docs/contracts/public_api_v1.md` — define the
  runtime timestamp contract, input-hint semantics, runtime-local resolver
  algorithm, scope, wall-clock rollback behavior, and timestamped output
  coverage.
- Verify-only evidence: `docs/verification/legacy_capability_inventory.md` —
  remains the legacy capability source and must not be rewritten unless the
  wording becomes contradictory.
- Verify-only export registry: `docs/_registry/public_api_v1.yaml` — remains
  unchanged because exported names and signatures are unchanged.

#### Change

Public API v1 must state that runtime-created `timestampMs` values are
runtime-local millisecond ordering tokens. Nullable input timestamps are hints;
resolved output timestamps are non-null and monotonic within one runtime by the
selected resolver algorithm. Required tests and guardrails must expose the
dedicated proof id instead of relying only on the broader action event row.

#### Proof

- Run P0 before the slice as the required failing reproducer for the accepted
  missing mapping.
- Run P1 before the slice as the neighboring event proof mapping guard.
- Run P2 after the slice to verify public contract presence.
- Run P4 after the slice to verify rejected positive clock promises are absent.

#### Closure

The slice is complete when public contract wording answers the HOLE-010
definition, creation site, time source, scope, rollback behavior, and output
coverage questions.

### Slice 2. [x] Operation And Verification Linkage

#### Implements

D3, D4

#### Obligations Covered

BUG_FIX, PUBLIC_API_CHANGE

#### Files

- Operation matrix edit: `docs/contracts/operation_matrix.md` — link
  timestamped runtime output rows and event-producing rows to
  `runtime_created_timestamps_monotonic`.
- Guardrail edit: `docs/verification/guardrails.md` — add
  `events.runtime_created_timestamps_monotonic` with the runtime-local
  monotonicity rule.
- Test inventory edit: `docs/verification/tests.md` — add
  `test.interaction.runtime_created_timestamps_monotonic` and the planned path
  `test/interaction/runtime_created_timestamps_monotonic_test.dart`.
- Release gate edit: `docs/verification/release_gates.md` — require the
  monotonic timestamp test before release.
- Guardrail index edit: `docs/indexes/by_guardrail.md` — map the new guardrail
  to sections and tests.
- Test-area index edit: `docs/indexes/by_test_area.md` — map the new test id to
  path, phases, sections, guardrails, and focus.
- Section registry edit: `docs/_registry/sections.yaml` — add the new guardrail
  and test id to the operation and interaction sections that own timestamped
  event/output behavior.

#### Change

The operation matrix and verification docs must make monotonic runtime-created
timestamps a first-class release proof. The mapping must cover action events,
text edit requests, pending line start timestamp creation, selected move
resolver request timestamp creation, and changed text edit action emission
without converting previews or resolver requests into user-action events.

#### Proof

- Run P3 after the slice to verify mapping, guardrail, test, index, section
  registry, and release-gate presence.
- Run P4 after the slice to verify no rejected positive global or wall-clock
  guarantee leaked into active source-of-truth docs.
- Run P5 after the slice to verify documentation structure after index and
  registry edits.
- Run P6 after the slice to verify context capsules after section-registry
  edits.

#### Closure

The slice is complete when future executable coverage is named by one stable
test id, the new guardrail is mandatory, operation rows link to the proof, and
release gates block on the monotonic timestamp test.

### Slice 3. [x] Audit Retirement And Documentation Proof

#### Implements

D4

#### Obligations Covered

BUG_FIX

#### Files

- Audit finalization edit: `audit.md` — remove the open HOLE-010 checklist only
  after active source-of-truth surfaces own every checklist item.
- Roadmap finalization edit: `PLAN.md` — mark Step 15 complete when the step is
  implemented.
- Step finalization edit: `plan/step_15_runtime_created_timestamp_monotonic_proof_mapping.md` —
  mark completed slice checkboxes when the implementation change completes.

#### Change

The temporary HOLE-010 problem note must stop being the only place that names
the timestamp mapping. After slices 1 and 2 land, the audit entry is retired and
the documentation proof set is run.

#### Proof

- Run P3 to verify active mapping coverage.
- Run P4 to verify rejected positive clock promises remain absent.
- Run P5 to verify documentation structure.
- Run P6 to verify context capsules.
- Run P7 to verify HOLE-010 audit retirement.

#### Closure

The slice is complete when HOLE-010 is no longer open in `audit.md`, all proof
commands pass, and the roadmap and step checkboxes are updated in the same
implementation change.

## 7. Final Gate

### Run Proof Set

P1, P2, P3, P4, P5, P6, P7

### Done When

- all referenced Decision Ledger decisions have passing proof;
- all Contract Obligations are satisfied;
- no retired seams have remaining active references;
- HOLE-010 is no longer open in `audit.md`;
- no out-of-scope files were changed;
- whitespace validation passes.
