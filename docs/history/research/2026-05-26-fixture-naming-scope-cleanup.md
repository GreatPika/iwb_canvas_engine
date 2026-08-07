---
date: 2026-05-26
researcher: Codex
commit: 13860574
branch: new-architecture
research_question: "Research P6 handoff findings 4 and 7 around fixture naming and scope cleanup."
---

# Research: Fixture Naming Scope Cleanup

## Summary

P6 handoff finding 4 points at an edit fixture whose filename and wrapper test
name emphasize nullable field semantics while the fixture body covers multiple
`CanvasEdit.updateElement` admission and effect outcomes. The fixture contains
six tests: nullable clear, dynamic non-nullable clear rejection,
non-invertible transform rejection, update-kind mismatch rejection, geometry
revision effects, and selection pruning for visibility updates.

P6 handoff finding 7 points at a runtime fixture whose filename includes
publication, while the fixture body checks only the initial relationship between
`CanvasRuntime.state.value.summary` and the document returned by
`CanvasRuntime.readDocument()`. Transition and post-commit state publication
coverage exists in `test/runtime/runtime_state_publication_test.dart` and
`test/runtime/fixtures/commit_effect_observer_fixture.dart`.

The two findings share a fixture naming/scope shape: checked-in fixture names and
wrapper test names currently imply a narrower or broader behavioral claim than
the test body proves. Direct path references are limited to the wrapper tests and
historical plan/docs references; current generated test indexes identify
`test.edit.field_update_nullable_semantics` but do not list
`test/runtime/document_summary_publication_test.dart` as a registry id.

## Detailed Findings

### 1. P6 Handoff Findings

- **Location**: primary `P6_HANDOFF_FINDINGS.md:18`; related
  `P6_HANDOFF_FINDINGS.md:43`.
- **Description**: Finding 4 says
  `test/edit/fixtures/field_update_nullable_semantics_fixture.dart` covers
  nullable clears, rejected dynamic clears, non-invertible transforms,
  mismatched update kinds, geometry revisions, and selection pruning, while the
  name only suggests nullable semantics (`P6_HANDOFF_FINDINGS.md:22`,
  `P6_HANDOFF_FINDINGS.md:24`, `P6_HANDOFF_FINDINGS.md:25`,
  `P6_HANDOFF_FINDINGS.md:26`).
- **Description**: Finding 7 says
  `test/runtime/fixtures/document_summary_publication_fixture.dart` says
  publication/coherence but checks only the initial summary against the initial
  document projection; it also records that transition coverage lives elsewhere
  (`P6_HANDOFF_FINDINGS.md:47`, `P6_HANDOFF_FINDINGS.md:49`,
  `P6_HANDOFF_FINDINGS.md:50`, `P6_HANDOFF_FINDINGS.md:51`).
- **Dependencies**: The handoff file gives suggested work only as prose: rename
  finding 4 around broader field-update admission/effects semantics and either
  rename/scope down finding 7 or merge it into runtime state publication
  coverage (`P6_HANDOFF_FINDINGS.md:27`, `P6_HANDOFF_FINDINGS.md:28`,
  `P6_HANDOFF_FINDINGS.md:52`, `P6_HANDOFF_FINDINGS.md:53`).
- **Data flow**: Handoff finding -> fixture file path -> wrapper test path
  through `runFlutterInPackageTest`.

### 2. Field Update Fixture Current Scope

- **Location**: primary
  `test/edit/fixtures/field_update_nullable_semantics_fixture.dart:9`; wrapper
  `test/edit/field_update_nullable_semantics_test.dart:6`.
- **Description**: The wrapper test name is
  `field update nullable and rejected update semantics are enforced` and runs
  `test/edit/fixtures/field_update_nullable_semantics_fixture.dart`
  (`test/edit/field_update_nullable_semantics_test.dart:6`,
  `test/edit/field_update_nullable_semantics_test.dart:8`,
  `test/edit/field_update_nullable_semantics_test.dart:9`).
- **Description**: The fixture contains tests for nullable clears, dynamic
  non-nullable clear rejection, non-invertible transform rejection, mismatched
  update kind rejection, geometry revision advancement, and selection pruning
  caused by visibility updates
  (`test/edit/fixtures/field_update_nullable_semantics_fixture.dart:10`,
  `test/edit/fixtures/field_update_nullable_semantics_fixture.dart:14`,
  `test/edit/fixtures/field_update_nullable_semantics_fixture.dart:18`,
  `test/edit/fixtures/field_update_nullable_semantics_fixture.dart:22`,
  `test/edit/fixtures/field_update_nullable_semantics_fixture.dart:26`,
  `test/edit/fixtures/field_update_nullable_semantics_fixture.dart:30`).
- **Dependencies**: The fixture imports public API, `CommitPlan`,
  `DraftDocument`, and `RuntimeRoot`
  (`test/edit/fixtures/field_update_nullable_semantics_fixture.dart:4`,
  `test/edit/fixtures/field_update_nullable_semantics_fixture.dart:5`,
  `test/edit/fixtures/field_update_nullable_semantics_fixture.dart:6`,
  `test/edit/fixtures/field_update_nullable_semantics_fixture.dart:7`).
- **Data flow**: Each fixture case creates or uses document-edit state, calls
  `CanvasEdit.updateElement` or `DraftDocument.updateElement`, then checks
  mutation/rejection, revision, effect, or selection-touched output. The
  nullable clear case mutates `fillColor` and checks document revision
  (`test/edit/fixtures/field_update_nullable_semantics_fixture.dart:41`,
  `test/edit/fixtures/field_update_nullable_semantics_fixture.dart:45`,
  `test/edit/fixtures/field_update_nullable_semantics_fixture.dart:50`,
  `test/edit/fixtures/field_update_nullable_semantics_fixture.dart:54`). The
  dynamic non-nullable clear and non-invertible transform cases assert no
  revision and no effect batches after rejection
  (`test/edit/fixtures/field_update_nullable_semantics_fixture.dart:62`,
  `test/edit/fixtures/field_update_nullable_semantics_fixture.dart:71`,
  `test/edit/fixtures/field_update_nullable_semantics_fixture.dart:75`,
  `test/edit/fixtures/field_update_nullable_semantics_fixture.dart:76`,
  `test/edit/fixtures/field_update_nullable_semantics_fixture.dart:83`,
  `test/edit/fixtures/field_update_nullable_semantics_fixture.dart:94`,
  `test/edit/fixtures/field_update_nullable_semantics_fixture.dart:97`,
  `test/edit/fixtures/field_update_nullable_semantics_fixture.dart:98`).
  The mismatched-kind case throws before mutation
  (`test/edit/fixtures/field_update_nullable_semantics_fixture.dart:105`,
  `test/edit/fixtures/field_update_nullable_semantics_fixture.dart:114`,
  `test/edit/fixtures/field_update_nullable_semantics_fixture.dart:117`,
  `test/edit/fixtures/field_update_nullable_semantics_fixture.dart:118`). The
  geometry case checks document, bounds, and element-visual revisions
  (`test/edit/fixtures/field_update_nullable_semantics_fixture.dart:127`,
  `test/edit/fixtures/field_update_nullable_semantics_fixture.dart:137`,
  `test/edit/fixtures/field_update_nullable_semantics_fixture.dart:138`,
  `test/edit/fixtures/field_update_nullable_semantics_fixture.dart:139`). The
  visibility case checks selection and geometry touched state
  (`test/edit/fixtures/field_update_nullable_semantics_fixture.dart:148`,
  `test/edit/fixtures/field_update_nullable_semantics_fixture.dart:155`,
  `test/edit/fixtures/field_update_nullable_semantics_fixture.dart:156`).

### 3. Field Update Owner And Existing Registry Mentions

- **Location**: primary `lib/src/edit/draft_document.dart:119`; taxonomy owner
  `lib/src/edit/commit_compiler.dart:24`.
- **Description**: `DraftDocument.updateElement` keeps update admission, draft
  replacement, touched taxonomy, and revision delta together
  (`lib/src/edit/draft_document.dart:119`, `lib/src/edit/draft_document.dart:122`,
  `lib/src/edit/draft_document.dart:128`, `lib/src/edit/draft_document.dart:135`,
  `lib/src/edit/draft_document.dart:141`, `lib/src/edit/draft_document.dart:145`,
  `lib/src/edit/draft_document.dart:159`).
- **Dependencies**: Field update application uses `_updatedElement`,
  `_updateMatchesElement`, `_requiredField`, `_nullableField`, and
  `_requiredListField` inside `DraftDocument`
  (`lib/src/edit/draft_document.dart:570`,
  `lib/src/edit/draft_document.dart:597`,
  `lib/src/edit/draft_document.dart:806`,
  `lib/src/edit/draft_document.dart:818`,
  `lib/src/edit/draft_document.dart:827`).
- **Data flow**: `CommitCompiler.compileElementUpdate` computes revision and
  touched outputs from before/after elements
  (`lib/src/edit/commit_compiler.dart:24`,
  `lib/src/edit/commit_compiler.dart:28`,
  `lib/src/edit/commit_compiler.dart:30`,
  `lib/src/edit/commit_compiler.dart:35`). Effects are derived from the revision
  delta and touched set, including projection, spatial, repaint, selection, and
  public-state effects (`lib/src/edit/commit_compiler.dart:56`,
  `lib/src/edit/commit_compiler.dart:61`,
  `lib/src/edit/commit_compiler.dart:62`,
  `lib/src/edit/commit_compiler.dart:64`,
  `lib/src/edit/commit_compiler.dart:66`,
  `lib/src/edit/commit_compiler.dart:67`).
- **Registry mentions**: The generated test-area index contains
  `test.edit.field_update_nullable_semantics`
  (`docs/indexes/by_test_area.md:114`). `docs/contracts/edit_kernel.md` lists
  the same id as a required test (`docs/contracts/edit_kernel.md:27`,
  `docs/contracts/edit_kernel.md:32`). `docs/verification/tests.md` lists the id
  in the test-id inventory and maps it to
  `test/edit/field_update_nullable_semantics_test.dart`
  (`docs/verification/tests.md:158`, `docs/verification/tests.md:265`).
- **Current docs scope**: `docs/verification/tests.md` describes only the
  non-invertible transform part of the field-update fixture
  (`docs/verification/tests.md:335`, `docs/verification/tests.md:336`,
  `docs/verification/tests.md:337`).

### 4. Document Summary Fixture Current Scope

- **Location**: primary
  `test/runtime/fixtures/document_summary_publication_fixture.dart:6`; wrapper
  `test/runtime/document_summary_publication_test.dart:6`.
- **Description**: The wrapper test name says runtime summary is coherent with
  committed document facts and runs
  `test/runtime/fixtures/document_summary_publication_fixture.dart`
  (`test/runtime/document_summary_publication_test.dart:6`,
  `test/runtime/document_summary_publication_test.dart:8`,
  `test/runtime/document_summary_publication_test.dart:9`).
- **Description**: The fixture body constructs one `CanvasRuntime`, reads the
  initial document projection once, compares summary counts to that document,
  asserts `elementCount` is 2, and disposes the runtime
  (`test/runtime/fixtures/document_summary_publication_fixture.dart:8`,
  `test/runtime/fixtures/document_summary_publication_fixture.dart:10`,
  `test/runtime/fixtures/document_summary_publication_fixture.dart:12`,
  `test/runtime/fixtures/document_summary_publication_fixture.dart:13`,
  `test/runtime/fixtures/document_summary_publication_fixture.dart:15`).
- **Dependencies**: The fixture imports public API only, plus
  `flutter_test.dart`
  (`test/runtime/fixtures/document_summary_publication_fixture.dart:3`,
  `test/runtime/fixtures/document_summary_publication_fixture.dart:4`).
- **Data flow**: `_document()` creates one resource, one background element, and
  one layer with one element
  (`test/runtime/fixtures/document_summary_publication_fixture.dart:19`,
  `test/runtime/fixtures/document_summary_publication_fixture.dart:21`,
  `test/runtime/fixtures/document_summary_publication_fixture.dart:27`,
  `test/runtime/fixtures/document_summary_publication_fixture.dart:33`,
  `test/runtime/fixtures/document_summary_publication_fixture.dart:36`).
  `_expectSummaryMatchesDocument` compares `document.resources.length`,
  `document.layers.length`, and a locally computed element count with
  `runtime.state.value.summary`
  (`test/runtime/fixtures/document_summary_publication_fixture.dart:47`,
  `test/runtime/fixtures/document_summary_publication_fixture.dart:51`,
  `test/runtime/fixtures/document_summary_publication_fixture.dart:55`,
  `test/runtime/fixtures/document_summary_publication_fixture.dart:56`,
  `test/runtime/fixtures/document_summary_publication_fixture.dart:59`).

### 5. Runtime Summary Owner And Existing Publication Coverage

- **Location**: primary `lib/src/runtime/runtime_root.dart:366`; store summary
  `lib/src/store/committed_document.dart:58`.
- **Description**: `CanvasRuntime.readDocument` and `CanvasRuntime.state`
  delegate to `RuntimeRoot` (`lib/src/api/canvas_runtime.dart:39`,
  `lib/src/api/canvas_runtime.dart:40`). `RuntimeRoot.readDocument` delegates to
  `DocumentStoreKernel.readDocument`
  (`lib/src/runtime/runtime_root.dart:128`), and
  `DocumentStoreKernel.readDocument` returns a projection from the projection
  cache (`lib/src/store/document_store_kernel.dart:46`).
- **Dependencies**: Runtime summary values are built from
  `DocumentStoreKernel.documentSummary` and `SelectionFacts`
  (`lib/src/runtime/runtime_root.dart:366`,
  `lib/src/runtime/runtime_root.dart:371`,
  `lib/src/runtime/runtime_root.dart:375`,
  `lib/src/runtime/runtime_root.dart:385`,
  `lib/src/runtime/runtime_root.dart:386`,
  `lib/src/runtime/runtime_root.dart:387`,
  `lib/src/runtime/runtime_root.dart:388`,
  `lib/src/runtime/runtime_root.dart:389`). Store document summary is derived
  from element, layer, and resource tables
  (`lib/src/store/committed_document.dart:58`,
  `lib/src/store/committed_document.dart:60`,
  `lib/src/store/committed_document.dart:61`,
  `lib/src/store/committed_document.dart:62`).
- **Data flow**: Runtime state is initialized from `_runtimeState(store, null, 0)`
  in the `RuntimeRoot` constructor (`lib/src/runtime/runtime_root.dart:55`,
  `lib/src/runtime/runtime_root.dart:56`). Runtime state is republished by
  assigning `_state.value = _runtimeState(...)`
  (`lib/src/runtime/runtime_root.dart:329`,
  `lib/src/runtime/runtime_root.dart:330`). Accepted edit apply results publish
  state before delivering commit effects when `shouldPublishState` is true
  (`lib/src/runtime/runtime_root.dart:346`,
  `lib/src/runtime/runtime_root.dart:349`,
  `lib/src/runtime/runtime_root.dart:350`,
  `lib/src/runtime/runtime_root.dart:352`,
  `lib/src/runtime/runtime_root.dart:353`).
- **Existing publication tests**:
  `test/runtime/runtime_state_publication_test.dart` proves initial public
  state, value equality, exactly one coherent state snapshot after document
  edits, no publication for no-op edits, and persisted camera behavior
  (`test/runtime/runtime_state_publication_test.dart:7`,
  `test/runtime/runtime_state_publication_test.dart:66`,
  `test/runtime/runtime_state_publication_test.dart:117`,
  `test/runtime/runtime_state_publication_test.dart:134`,
  `test/runtime/runtime_state_publication_test.dart:138`,
  `test/runtime/runtime_state_publication_test.dart:142`).
  `test/runtime/fixtures/commit_effect_observer_fixture.dart` proves observer
  delivery after state publication and checks the state snapshot summary after an
  accepted edit (`test/runtime/fixtures/commit_effect_observer_fixture.dart:9`,
  `test/runtime/fixtures/commit_effect_observer_fixture.dart:73`,
  `test/runtime/fixtures/commit_effect_observer_fixture.dart:90`,
  `test/runtime/fixtures/commit_effect_observer_fixture.dart:92`,
  `test/runtime/fixtures/commit_effect_observer_fixture.dart:93`).

### 6. Document Summary Registry Mentions

- **Location**: primary
  `plan/step_24_p4_runtime_spine_store_and_projection_cache.md:492`.
- **Description**: Step 24 calls
  `test/runtime/document_summary_publication_test.dart` a P4 contract-local
  document summary proof and says it proves `CanvasDocumentSummary` and
  `CanvasRuntimeSummary` are coherent projections of the same committed store
  facts (`plan/step_24_p4_runtime_spine_store_and_projection_cache.md:492`).
- **Dependencies**: The same step includes the test in the P2 store projection
  and admission proof command
  (`plan/step_24_p4_runtime_spine_store_and_projection_cache.md:520`,
  `plan/step_24_p4_runtime_spine_store_and_projection_cache.md:521`) and names
  its expected signal as summary coherence over committed store facts
  (`plan/step_24_p4_runtime_spine_store_and_projection_cache.md:524`,
  `plan/step_24_p4_runtime_spine_store_and_projection_cache.md:526`).
- **Data flow**: Current generated test indexes include runtime state
  publication and load-document publication ids, but no
  `test.runtime.document_summary_publication` id
  (`docs/indexes/by_test_area.md:338`, `docs/indexes/by_test_area.md:342`).

## Code References

- `P6_HANDOFF_FINDINGS.md:18` - finding 4 title.
- `P6_HANDOFF_FINDINGS.md:43` - finding 7 title.
- `test/edit/field_update_nullable_semantics_test.dart:9` - wrapper path for the
  field-update fixture.
- `test/edit/fixtures/field_update_nullable_semantics_fixture.dart:10` - first
  field-update fixture test.
- `test/edit/fixtures/field_update_nullable_semantics_fixture.dart:30` - final
  field-update fixture test.
- `test/runtime/document_summary_publication_test.dart:9` - wrapper path for the
  document-summary fixture.
- `test/runtime/fixtures/document_summary_publication_fixture.dart:7` - document
  summary fixture test name.
- `test/runtime/runtime_state_publication_test.dart:117` - existing transition
  publication coverage.
- `test/runtime/fixtures/commit_effect_observer_fixture.dart:73` - existing
  post-publication observer proof.
- `lib/src/edit/draft_document.dart:119` - update admission and touched taxonomy
  owner comment.
- `lib/src/edit/commit_compiler.dart:24` - field update effect compiler entry.
- `lib/src/runtime/runtime_root.dart:366` - runtime state construction helper.
- `lib/src/store/committed_document.dart:58` - store document summary source.
- `docs/indexes/by_test_area.md:114` - generated index entry for the current
  field-update test id.
- `plan/step_24_p4_runtime_spine_store_and_projection_cache.md:492` - historical
  plan entry for document summary proof scope.

## Observed Architecture Facts

- Pattern observed: wrapper tests run fixture files by literal path through
  `runFlutterInPackageTest` (`test/support/flutter_in_package_test_harness.dart:10`,
  `test/support/flutter_in_package_test_harness.dart:19`,
  `test/support/flutter_in_package_test_harness.dart:20`,
  `test/support/flutter_in_package_test_harness.dart:22`).
- Data flow: `CanvasRuntime` facade -> `RuntimeRoot` -> `DocumentStoreKernel`
  for `readDocument` and runtime state summary
  (`lib/src/api/canvas_runtime.dart:39`,
  `lib/src/api/canvas_runtime.dart:40`,
  `lib/src/runtime/runtime_root.dart:128`,
  `lib/src/store/document_store_kernel.dart:46`,
  `lib/src/runtime/runtime_root.dart:385`).
- Data flow: `CanvasEdit.updateElement` -> `DraftDocument.updateElement` ->
  `CommitCompiler.compileElementUpdate` -> typed commit effects
  (`lib/src/api/canvas_runtime.dart:193`,
  `lib/src/edit/draft_document.dart:122`,
  `lib/src/edit/commit_compiler.dart:24`,
  `lib/src/edit/commit_compiler.dart:56`).
- Key dependencies: finding 4's fixture uses internal edit/runtime seams as an
  in-package proof (`test/edit/fixtures/field_update_nullable_semantics_fixture.dart:5`,
  `test/edit/fixtures/field_update_nullable_semantics_fixture.dart:6`,
  `test/edit/fixtures/field_update_nullable_semantics_fixture.dart:7`), while
  finding 7's fixture uses only the public runtime API
  (`test/runtime/fixtures/document_summary_publication_fixture.dart:4`).

## Open Questions

- If the current test id `test.edit.field_update_nullable_semantics` is renamed,
  generated documentation inputs may also need an owner update before running
  documentation sync; this research did not trace the generator source for test
  ids beyond existing docs references.
- Historical plan files contain the old document-summary test path and scope;
  this research records those references but does not determine whether completed
  historical plan files are expected to be edited during cleanup.
