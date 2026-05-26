---
date: 2026-05-26
researcher: Codex
commit: 65fb2038
branch: new-architecture
research_question: "Why did the P6 loadDocument contract/review workflow allow a post-install interaction cleanup gap after multiple skill-based reviews?"
---

# Research: LoadDocument Contract Review Gap

## Summary

The repository-visible workflow for P6 includes a design artifact marked
`READY_FOR_CONTRACT`, a completed Step 36 Change Contract, blocking guardrail
inventory entries, executable load ordering tests, and runtime implementation.
The observable source chain repeatedly describes `loadDocument` as staged,
validated, atomic replacement, but it also records pointer-normalization and
pending-tap cleanup as a post-install interaction step in the design, contract,
phase guide, and durable diagrams (`.design/2026-05-26-p6-load-document.md:443`,
`.design/2026-05-26-p6-load-document.md:449`;
`docs/contracts/load_document.md:75`;
`docs/diagrams/seq_load_document_success.mmd:63`;
`docs/diagrams/dfd_load_document_success_failure.mmd:81`).

The guardrail and test proof surface visible in this snapshot proves preparation
failure before interruption, successful interrupt before install, one success
publication, and no side effects for validation/materialization failure. It does
not contain a throwing post-install interaction boundary case. The successful
ordering fixture explicitly accepts the order `interrupt`,
`post-install-cleanup`, `state`, `observer`, and asserts that post-install cleanup
observes the replacement document already installed
(`test/runtime/fixtures/load_document_ordering_fixture.dart:55`,
`test/runtime/fixtures/load_document_ordering_fixture.dart:68`).

The runtime implementation follows that accepted shape: `_loadDocument` prepares,
interrupts, consumes the prepared load into the store, clears selection, updates
camera and epoch facts, calls `clearPostInstallFacts()`, and only then enters
`_deliverLoadResult(...)` for state/effect publication
(`lib/src/runtime/runtime_root.dart:373`,
`lib/src/runtime/runtime_root.dart:383`). The current seam is two imperative
`void` methods on `LoadInteractionBoundary`, with `clearPostInstallFacts()` as a
separate call after the store consume path (`lib/src/runtime/runtime_root.dart:487`,
`lib/src/runtime/runtime_root.dart:489`).

## Detailed Findings

### 1. Skill Workflows Require Review, But The Saved Outputs Are The Design And Contract

- **Location**: primary `.agents/skills/architecture-design-workflow/SKILL.md:24`;
  additional `.agents/skills/plan-step-contract/SKILL.md:27`,
  `.agents/skills/plan-step-contract/SKILL.md:65`.
- **Description**: The architecture design workflow requires a fresh reviewer
  after the design artifact exists and repeats fresh review after repair
  (`.agents/skills/architecture-design-workflow/SKILL.md:24`,
  `.agents/skills/architecture-design-workflow/SKILL.md:38`). The plan step
  contract workflow requires a fresh primary `contract_reviewer`, repair/review
  loops, and a fresh second reviewer after primary acceptance
  (`.agents/skills/plan-step-contract/SKILL.md:27`,
  `.agents/skills/plan-step-contract/SKILL.md:65`,
  `.agents/skills/plan-step-contract/SKILL.md:98`).
- **Dependencies**: `contract_reviewer` is configured to use
  `change-contract-check`, run read-only, and re-read the target Change Contract
  from scratch for every request (`.codex/agents/contract_reviewer.toml:1`,
  `.codex/agents/contract_reviewer.toml:9`,
  `.codex/agents/contract_reviewer.toml:17`). `code_reviewer` uses `code-review`
  and reviews the current uncommitted changes unless another target is named
  (`.codex/agents/code_reviewer.toml:1`,
  `.codex/agents/code_reviewer.toml:9`,
  `.codex/agents/code_reviewer.toml:13`).
- **Data flow**: design workflow creates one `.design/...` artifact and returns
  a review verdict in chat (`.agents/skills/architecture-design-workflow/SKILL.md:31`,
  `.agents/skills/architecture-design-workflow/SKILL.md:33`); plan-step workflow
  creates or updates `PLAN.md` and the linked step contract file
  (`.agents/skills/plan-step-contract/SKILL.md:17`,
  `.agents/skills/plan-step-contract/SKILL.md:25`).

### 2. Review Criteria Cover Ordering And Contradictions

- **Location**: primary `.agents/skills/architecture-design-review/SKILL.md:156`;
  additional `.agents/skills/change-contract-check/SKILL.md:145`,
  `.agents/skills/change-contract-check/SKILL.md:150`.
- **Description**: The design-review skill says a provisional diagram that
  contradicts, reorders, omits, or overstates architecture-relevant facts about
  ordering, effects, rollback/no-op behavior, or public observation blocks the
  design; if durable docs or diagrams disagree, the review should mark
  `BLOCKED` with `CONTRADICTS_REPO` unless routed to source-of-truth repair
  (`.agents/skills/architecture-design-review/SKILL.md:156`,
  `.agents/skills/architecture-design-review/SKILL.md:161`). The
  contract-check skill blocks unsafe order, inadequate completion checks, missing
  temporal/callback proof, unresolved fixture strategy, and weakened source-input
  obligations (`.agents/skills/change-contract-check/SKILL.md:145`,
  `.agents/skills/change-contract-check/SKILL.md:168`).
- **Dependencies**: Design review requires reading the design artifact, cited
  research, repository evidence, nearby docs/code/tests/plans/diagrams, and the
  paired authoring skill/template (`.agents/skills/architecture-design-review/SKILL.md:19`,
  `.agents/skills/architecture-design-review/SKILL.md:29`). Contract check
  validates the contract, not the code change, and re-checks repository evidence
  instead of trusting the contract's evidence at face value
  (`.agents/skills/change-contract-check/SKILL.md:8`,
  `.agents/skills/change-contract-check/SKILL.md:97`).
- **Data flow**: review criteria inspect source inputs and are meant to block
  unresolved owner, boundary, order, proof seam, fixture strategy, and temporal
  proof decisions before implementation (`.agents/skills/change-contract-check/SKILL.md:18`,
  `.agents/skills/change-contract-check/SKILL.md:25`,
  `.agents/skills/architecture-design-review/SKILL.md:235`,
  `.agents/skills/architecture-design-review/SKILL.md:254`).

### 3. The P6 Design Locked A Post-Install Cleanup Step

- **Location**: primary `.design/2026-05-26-p6-load-document.md:443`;
  additional `.design/2026-05-26-p6-load-document.md:488`,
  `.design/2026-05-26-p6-load-document.md:510`.
- **Description**: The selected form says that after preparation succeeds,
  `RuntimeRoot` calls the minimal interaction cleanup boundary, asks the pipeline
  to consume the prepared load, and combines store replacement with selection,
  camera, epoch/revision facts, and "post-install pointer-normalization/pending-tap
  cleanup" before cache/effect invalidation, repaint, and one public state
  publication (`.design/2026-05-26-p6-load-document.md:443`,
  `.design/2026-05-26-p6-load-document.md:449`). The lock-required dependency
  order also places post-install pointer normalization and pending tap cleanup
  after store replacement plus runtime facts (`.design/2026-05-26-p6-load-document.md:488`,
  `.design/2026-05-26-p6-load-document.md:492`).
- **Dependencies**: The design's handoff repeats the same sequencing fact:
  interrupt/preview cleanup before install, then pointer normalization and pending
  tap history clear after atomic install and before cache invalidation, repaint,
  or state publication (`.design/2026-05-26-p6-load-document.md:765`,
  `.design/2026-05-26-p6-load-document.md:768`). Its C4 diagram labels the
  interaction boundary as owning "Pre-install preview cleanup and post-install
  pointer cleanup" (`.design/2026-05-26-p6-load-document.md:560`,
  `.design/2026-05-26-p6-load-document.md:562`).
- **Data flow**: design selected form -> lock-required facts -> provisional data
  flow and sequence diagrams all include a post-install interaction cleanup step
  (`.design/2026-05-26-p6-load-document.md:575`,
  `.design/2026-05-26-p6-load-document.md:587`,
  `.design/2026-05-26-p6-load-document.md:617`,
  `.design/2026-05-26-p6-load-document.md:618`).

### 4. Durable Docs Carry Two Cleanup Placements

- **Location**: primary `docs/contracts/load_document.md:49`; additional
  `docs/contracts/load_document.md:75`,
  `docs/diagrams/seq_load_document_success.mmd:63`,
  `docs/diagrams/dfd_load_document_success_failure.mmd:81`.
- **Description**: The load contract says `PreparedDocumentLoad success` leads to
  runtime interrupt/preview cleanup and the boundary may clear active preview
  state and pointer normalization facts (`docs/contracts/load_document.md:49`,
  `docs/contracts/load_document.md:52`). The same success ordering later places
  "clear pointer normalization and pending tap history" after atomic install,
  runtime camera initialization, and revision increments
  (`docs/contracts/load_document.md:68`,
  `docs/contracts/load_document.md:75`).
- **Dependencies**: The sequence diagram installs the prepared document and
  clears selection in the same runtime result, then notifies interaction that the
  committed load is installed and clears pointer normalization and pending tap
  history (`docs/diagrams/seq_load_document_success.mmd:51`,
  `docs/diagrams/seq_load_document_success.mmd:64`). The DFD declares a
  `Post-install input cleanup` node and routes `AtomicRuntimeResult` to it
  "after install only" (`docs/diagrams/dfd_load_document_success_failure.mmd:25`,
  `docs/diagrams/dfd_load_document_success_failure.mmd:81`).
- **Data flow**: durable docs describe preparation -> interrupt/preview cleanup
  -> atomic install/selection clear -> post-install pending input cleanup ->
  cache/repaint/publication (`docs/diagrams/dfd_load_document_success_failure.mmd:70`,
  `docs/diagrams/dfd_load_document_success_failure.mmd:93`).

### 5. The Step 36 Contract Preserved That Post-Install Shape

- **Location**: primary `plan/step_36_p6_load_document.md:104`; additional
  `plan/step_36_p6_load_document.md:170`,
  `plan/step_36_p6_load_document.md:250`.
- **Description**: Step 36 puts in scope a minimal P6 interaction cleanup boundary
  with success-only interruption/preview cleanup before install and post-install
  pointer-normalization/pending-tap cleanup, with no store mutation in the
  interaction boundary (`plan/step_36_p6_load_document.md:104`,
  `plan/step_36_p6_load_document.md:107`). Its order constraints repeat the
  sequence: validate/materialize, interaction interruption/preview cleanup,
  atomic store replacement plus selection clear, runtime facts, post-install
  pointer cleanup, invalidation/repaint effects, one state publication
  (`plan/step_36_p6_load_document.md:170`,
  `plan/step_36_p6_load_document.md:177`).
- **Dependencies**: Unit 2 asks runtime external load to clear post-install
  pointer normalization and pending tap facts through the interaction boundary
  after consume, selection clear, camera, and revisions, before publication
  (`plan/step_36_p6_load_document.md:250`,
  `plan/step_36_p6_load_document.md:258`). Unit 4 asks ordering tests to fail if
  cleanup happens before successful preparation or if install happens before
  success-only interaction interruption, and to cover reentrant public mutation
  during delivery (`plan/step_36_p6_load_document.md:345`,
  `plan/step_36_p6_load_document.md:355`).
- **Data flow**: `.design` selected form -> Step 36 evidence and boundaries ->
  Unit 2 implementation order -> Unit 4 proof targets
  (`plan/step_36_p6_load_document.md:15`,
  `plan/step_36_p6_load_document.md:24`,
  `plan/step_36_p6_load_document.md:232`,
  `plan/step_36_p6_load_document.md:359`).

### 6. Guardrail Names And Routes Prove A Narrower Property Than Full Failure Atomicity

- **Location**: primary `tool/guardrails/src/guardrail_executor.dart:232`;
  additional `docs/verification/guardrails.md:194`,
  `docs/verification/guardrail_design_patterns.md:116`.
- **Description**: The guardrail inventory contains `load.prepares_before_interrupt`
  and `load.success_interrupts_before_install` in the blocking/load suite
  (`tool/guardrails/src/guardrail_registry.dart:153`,
  `tool/guardrails/src/guardrail_registry.dart:160`). The executor maps both ids
  to `test/runtime/load_document_ordering_test.dart`
  (`tool/guardrails/src/guardrail_executor.dart:232`,
  `tool/guardrails/src/guardrail_executor.dart:237`).
- **Dependencies**: The guardrail documentation defines the two load rules as
  "failed load does not interrupt gesture" and "success interrupt happens before
  atomic install" (`docs/verification/guardrails.md:194`,
  `docs/verification/guardrails.md:195`). The design-pattern ledger describes
  them as semantic sequence plus behavioral seam tests for failed-load no
  interrupt and success interrupt-before-install
  (`docs/verification/guardrail_design_patterns.md:116`,
  `docs/verification/guardrail_design_patterns.md:117`).
- **Data flow**: guardrail id -> executor proof path -> wrapper test -> Flutter
  fixture (`tool/guardrails/src/guardrail_executor.dart:95`,
  `tool/guardrails/src/guardrail_executor.dart:99`,
  `test/runtime/load_document_ordering_test.dart:6`,
  `test/runtime/load_document_ordering_test.dart:11`).

### 7. The Ordering Fixture Accepts Post-Install Cleanup As The Happy Path

- **Location**: primary `test/runtime/fixtures/load_document_ordering_fixture.dart:55`;
  additional `test/runtime/fixtures/load_document_ordering_fixture.dart:171`.
- **Description**: The successful-load scenario wires `onInterrupt` and
  `onPostInstallCleanup`, calls `root.edits.loadDocument`, and expects the event
  order `interrupt`, `post-install-cleanup`, `state`, `observer`
  (`test/runtime/fixtures/load_document_ordering_fixture.dart:49`,
  `test/runtime/fixtures/load_document_ordering_fixture.dart:57`). The interrupt
  callback observes the old document, while the post-install cleanup callback
  observes the replacement document (`test/runtime/fixtures/load_document_ordering_fixture.dart:61`,
  `test/runtime/fixtures/load_document_ordering_fixture.dart:68`).
- **Dependencies**: The recording boundary implements `interruptPreparedLoad()` by
  recording `interrupt` and `clearPostInstallFacts()` by recording
  `post-install-cleanup`; both optional callbacks are non-throwing in the fixture
  as written (`test/runtime/fixtures/load_document_ordering_fixture.dart:171`,
  `test/runtime/fixtures/load_document_ordering_fixture.dart:186`).
- **Data flow**: test root with injected boundary -> successful load -> interrupt
  before install -> post-install cleanup after replacement is readable -> state
  listener -> observer (`test/runtime/fixtures/load_document_ordering_fixture.dart:52`,
  `test/runtime/fixtures/load_document_ordering_fixture.dart:82`).

### 8. Existing Failure Tests Exercise Validation Failure, Not Post-Install Boundary Failure

- **Location**: primary `test/runtime/fixtures/load_document_ordering_fixture.dart:18`;
  additional `test/runtime/fixtures/load_document_state_publication_fixture.dart:49`.
- **Description**: The ordering fixture's failed-load path uses a duplicate-element
  document, expects `CanvasDataErrorCode.duplicateElementId`, records no boundary
  events, keeps the old document id, and keeps the same runtime state
  (`test/runtime/fixtures/load_document_ordering_fixture.dart:23`,
  `test/runtime/fixtures/load_document_ordering_fixture.dart:36`). The state
  publication fixture's failed-load path also uses duplicate elements, expects no
  snapshots/effects, preserves captured facts, preserves camera offset, and leaves
  generated element id at `e0`
  (`test/runtime/fixtures/load_document_state_publication_fixture.dart:61`,
  `test/runtime/fixtures/load_document_state_publication_fixture.dart:68`).
- **Dependencies**: The searched boundary implementations are the no-op production
  boundary and the recording test boundary; the no-op methods are empty, and the
  recording methods append event strings and call nullable callbacks
  (`lib/src/runtime/runtime_root.dart:492`,
  `lib/src/runtime/runtime_root.dart:499`,
  `test/runtime/fixtures/load_document_ordering_fixture.dart:177`,
  `test/runtime/fixtures/load_document_ordering_fixture.dart:185`).
- **Data flow**: invalid public document -> `ValidatedImportDraft` rejection during
  prepare -> no interrupt, consume, cleanup, publication, or effects in the tested
  failure paths (`lib/src/runtime/runtime_root.dart:373`,
  `lib/src/runtime/runtime_root.dart:377`,
  `test/runtime/fixtures/load_document_ordering_fixture.dart:34`).

### 9. RuntimeRoot Implements The Documented Post-Install Boundary

- **Location**: primary `lib/src/runtime/runtime_root.dart:373`; additional
  `lib/src/edit/staged_document_load.dart:70`,
  `lib/src/runtime/runtime_root.dart:418`.
- **Description**: `_loadDocument` prepares the load, interrupts the interaction
  boundary, consumes the prepared load, clears selection, sets the view camera,
  increments view-camera and epoch revisions, calls
  `_loadInteractionBoundary.clearPostInstallFacts()`, and then calls
  `_deliverLoadResult(...)` (`lib/src/runtime/runtime_root.dart:373`,
  `lib/src/runtime/runtime_root.dart:383`). `LoadDocumentPipeline.consume`
  validates ownership/one-shot use and calls `_store.replaceDocument(...)`
  (`lib/src/edit/staged_document_load.dart:70`,
  `lib/src/edit/staged_document_load.dart:82`).
- **Dependencies**: `LoadInteractionBoundary` declares two `void` methods,
  `interruptPreparedLoad()` and `clearPostInstallFacts()`
  (`lib/src/runtime/runtime_root.dart:487`,
  `lib/src/runtime/runtime_root.dart:489`). `_deliverLoadResult` sets the delivery
  guard, publishes runtime state, invokes the observer for non-empty effects, and
  catches `Object` exceptions only inside that delivery block
  (`lib/src/runtime/runtime_root.dart:418`,
  `lib/src/runtime/runtime_root.dart:430`).
- **Data flow**: public `CanvasEditPort.loadDocument` -> `EditKernel.loadDocument`
  -> `_installLoadedDocument(document)` -> `RuntimeRoot._loadDocument` ->
  `prepare` -> `interruptPreparedLoad` -> `consume`/store replacement ->
  selection/camera/epoch facts -> `clearPostInstallFacts` -> publication/effects
  (`lib/src/edit/edit_kernel.dart:83`,
  `lib/src/edit/edit_kernel.dart:90`,
  `lib/src/runtime/runtime_root.dart:102`,
  `lib/src/runtime/runtime_root.dart:112`).

## Code References

- `.agents/skills/architecture-design-workflow/SKILL.md:24` - fresh design
  reviewer is required after the design artifact exists.
- `.agents/skills/plan-step-contract/SKILL.md:27` - fresh primary contract
  reviewer is required after step authoring.
- `.agents/skills/plan-step-contract/SKILL.md:65` - fresh second contract
  reviewer is required after primary acceptance.
- `.agents/skills/architecture-design-review/SKILL.md:156` - contradictory
  provisional diagrams are blocking review findings.
- `.agents/skills/change-contract-check/SKILL.md:145` - unsafe order is a blocking
  contract criterion.
- `.design/2026-05-26-p6-load-document.md:443` - selected form begins the
  post-preparation runtime orchestration paragraph.
- `.design/2026-05-26-p6-load-document.md:448` - selected form names post-install
  pointer-normalization/pending-tap cleanup.
- `.design/2026-05-26-p6-load-document.md:510` - lock-required execution order
  starts.
- `.design/2026-05-26-p6-load-document.md:765` - handoff constraints place
  interrupt/preview cleanup before install.
- `.design/2026-05-26-p6-load-document.md:767` - handoff constraints place
  pointer normalization and pending tap clear after atomic install.
- `docs/contracts/load_document.md:49` - prepared-load success leads to runtime
  interrupt/preview cleanup.
- `docs/contracts/load_document.md:52` - early boundary may clear pointer
  normalization facts.
- `docs/contracts/load_document.md:75` - success ordering clears pointer
  normalization and pending tap history after install/revision steps.
- `docs/diagrams/seq_load_document_success.mmd:63` - sequence notifies interaction
  after committed load install.
- `docs/diagrams/dfd_load_document_success_failure.mmd:81` - DFD routes atomic
  runtime result to post-install cleanup after install only.
- `plan/step_36_p6_load_document.md:104` - Step 36 in-scope cleanup boundary
  includes post-install pointer cleanup.
- `plan/step_36_p6_load_document.md:170` - Step 36 order constraints begin.
- `plan/step_36_p6_load_document.md:256` - Unit 2 change names post-install
  pointer-normalization/pending-tap cleanup.
- `tool/guardrails/src/guardrail_executor.dart:232` - load prepare guardrail
  maps to the ordering test.
- `tool/guardrails/src/guardrail_executor.dart:235` - load success interrupt
  guardrail maps to the ordering test.
- `test/runtime/fixtures/load_document_ordering_fixture.dart:57` - success fixture
  expects `interrupt`, `post-install-cleanup`, `state`, `observer`.
- `test/runtime/fixtures/load_document_ordering_fixture.dart:68` - post-install
  cleanup observes the replacement document.
- `test/runtime/fixtures/load_document_state_publication_fixture.dart:63` - failed
  validation load publishes no snapshots.
- `lib/src/runtime/runtime_root.dart:373` - runtime load orchestration begins.
- `lib/src/runtime/runtime_root.dart:382` - runtime calls
  `clearPostInstallFacts()` before delivery.
- `lib/src/runtime/runtime_root.dart:487` - `LoadInteractionBoundary` declaration.
- `lib/src/edit/staged_document_load.dart:70` - prepared-load consume begins.
- `lib/src/edit/staged_document_load.dart:81` - consume calls store replacement.

## Observed Architecture Facts

- Pattern observed: source inputs and implementation all preserve the same
  post-install interaction cleanup slot; it appears in `.design`, durable
  contract, phase guide, sequence diagram, DFD, Step 36 contract, ordering
  fixture, and runtime code
  (`.design/2026-05-26-p6-load-document.md:448`,
  `docs/contracts/load_document.md:75`,
  `docs/implementation/p6_load_document.md:19`,
  `docs/diagrams/seq_load_document_success.mmd:64`,
  `docs/diagrams/dfd_load_document_success_failure.mmd:81`,
  `plan/step_36_p6_load_document.md:256`,
  `test/runtime/fixtures/load_document_ordering_fixture.dart:57`,
  `lib/src/runtime/runtime_root.dart:382`).
- Pattern observed: the named guardrails prove specific ordering claims, not a
  general "no owner-boundary calls after irreversible install" invariant
  (`docs/verification/guardrails.md:194`,
  `docs/verification/guardrails.md:195`,
  `tool/guardrails/src/guardrail_executor.dart:232`,
  `tool/guardrails/src/guardrail_executor.dart:237`).
- Data flow: public load -> edit port -> runtime load orchestration -> staged
  prepare -> interaction interrupt -> store consume -> selection/camera/epoch
  facts -> post-install interaction cleanup -> public state/effects
  (`lib/src/edit/edit_kernel.dart:83`,
  `lib/src/edit/edit_kernel.dart:90`,
  `lib/src/runtime/runtime_root.dart:373`,
  `lib/src/runtime/runtime_root.dart:383`).
- Data flow: validation failure -> exception before interaction boundary,
  consume/install, cleanup, publication, and effects in the current tested failure
  paths (`test/runtime/fixtures/load_document_ordering_fixture.dart:23`,
  `test/runtime/fixtures/load_document_ordering_fixture.dart:36`,
  `test/runtime/fixtures/load_document_state_publication_fixture.dart:61`,
  `test/runtime/fixtures/load_document_state_publication_fixture.dart:68`).
- Key dependency: `LoadInteractionBoundary` is injectable through
  `RuntimeRoot.test`, while production uses `_NoopLoadInteractionBoundary`
  (`lib/src/runtime/runtime_root.dart:49`,
  `lib/src/runtime/runtime_root.dart:60`,
  `lib/src/runtime/runtime_root.dart:44`,
  `lib/src/runtime/runtime_root.dart:499`).

## Open Questions

- This repository snapshot contains the workflow rules and resulting P6 design
  and contract artifacts, but no saved chat verdict transcript for the specific
  P6 architecture-design-review or contract-review passes was found in the
  inspected repository paths. The visible durable evidence is therefore the
  accepted `.design/2026-05-26-p6-load-document.md`, the completed
  `plan/step_36_p6_load_document.md`, and the code/tests/guardrails above.
- The current production `LoadInteractionBoundary` implementation is no-op; the
  research did not identify a production interaction engine implementation behind
  `clearPostInstallFacts()` in this snapshot (`lib/src/runtime/runtime_root.dart:492`,
  `lib/src/runtime/runtime_root.dart:499`).
