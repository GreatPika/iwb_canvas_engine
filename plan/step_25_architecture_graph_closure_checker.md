# Change Contract

Contract Mode: FULL
Contract Profile: ANALYZER_RULE
Contract Obligations: BUG_FIX, SEAM_MIGRATION

## 1. Mandate and Boundary

### Mandate

Create a phase-aware architecture graph closure checker that makes planned
architecture obligations, implemented code facts, placeholders, forbidden
dependencies, and graph-backed diagram views comparable by tool. The checker
must prove the process gap that allowed P0-P4 verification to pass while P3
codec diagnostics routing and P4 camera ownership obligations remained missing.
It must also prove that generated full and future graph views are honest
target-architecture views: they must not render architecture owners as
unconnected boxes unless the graph explicitly allows and explains that
isolation.

### In Scope

- Add one machine-readable expected architecture graph source of truth at
  `docs/architecture/architecture_graph.yaml` for graph-checkable architecture
  obligations derived from existing repository source-of-truth artifacts.
- Model P0-P14 with one uniform schema, including phase metadata, node and edge
  obligations, expected status, coverage scope, source documents, evidence, and
  graph-backed diagram view definitions.
- Add analyzer-backed actual graph extraction under `tool/architecture_graph/**`
  for architecture-level facts only: public exports, imports, declarations,
  implemented interfaces, composition fields, public placeholder members,
  `UnimplementedError`, direct public exception throws in architecture-sensitive
  owners, and simple facade-to-owner delegations.
- Add a strict standalone phase closure command:
  `dart run tool/architecture_graph/check.dart --phase P4`.
- Prove the checker reports the known P3/P4 drift classes instead of suppressing
  them: codec failures bypassing diagnostics and the closed-phase
  `CanvasRuntime.camera` placeholder.
- Generate only graph-backed Mermaid views under `docs/diagrams/generated/**`.
  Expected-only views must be reproducible from `architecture_graph.yaml` with
  an explicit selected phase for current-phase views, while the
  actual-vs-expected diff view must be reproducible from `architecture_graph.yaml`
  plus the analyzer-derived actual graph for the selected phase.
- Populate future-phase graph entries with all graph-checkable major owners,
  seams, and planned edges already present in repository source-of-truth
  artifacts. Missing private helper details remain out of scope, but missing
  SSOT-backed architecture edges are a contract failure.
- Add machine-checkable SSOT coverage data to the expected graph using
  registry section ids from `docs/_registry/sections.yaml`, so every
  registry-owned architecture section is classified as graph-backed obligations
  or explicitly non-graph-checkable semantics. The implementation must not
  claim full target-graph alignment from sourceDoc citations alone.
- Enforce generated full and future graph view connectivity: every rendered
  architecture node must have at least one incident rendered edge unless the
  graph entry explicitly marks isolation as allowed, cites source documents, and
  explains why the node belongs in that view while disconnected.
- Update architecture, diagram, and verification documentation only where needed
  to route readers to the new graph source, generated graph views, and
  standalone closure command.
- Keep the existing blocking guardrail suite green by leaving the strict
  selected-phase graph checker outside the default blocking suite until the
  known selected-phase violations are fixed in later implementation work.
- Update roadmap checkboxes in this step file and root `PLAN.md` only after the
  implementation step is actually complete.

### Out of Scope

- Fixing production codec diagnostics routing, runtime camera behavior, or any
  other P3/P4 production drift found by the new checker.
- Changing public API signatures, schema v1 payload formats, persistence
  formats, runtime semantics, or production package boundaries.
- Using extracted actual code facts to create, rewrite, or silently approve
  expected graph obligations.
- Parsing handwritten Mermaid diagrams as the durable source of graph-checkable
  architecture truth.
- Replacing sequence, state, lifecycle, detailed data-flow, or behavior diagrams
  that encode semantics outside topology-level graph obligations.
- Requiring every private helper import, private call, local variable, or
  helper-level dependency to be represented in the architecture graph.
- Adding the graph checker to the default blocking guardrail suite while the
  selected phase is expected to fail on known graph violations.

## 2. Evidence Map

### Baseline Evidence

These facts describe repository state before execution. They are evidence for
the change, not target-state requirements.

- `.design/2026-05-22-architecture-graph-closure-checker.md` is accepted as
  `READY_FOR_CONTRACT` and selects a phase-aware expected architecture graph
  plus analyzer-derived actual graph as the future implementation form.
- `.research/2026-05-22-p0-p4-architecture-closure.md:13` records that P0-P4
  are marked complete and that current code contains the expected public API,
  codec, diagnostics, runtime, store, projection, read-port, and selection
  owners for the completed scope.
- `.research/2026-05-22-p0-p4-architecture-closure.md:15` records a green
  verification run despite the architecture drift.
- `.research/2026-05-22-p0-p4-architecture-closure.md:17` records the two known
  drifts: codec failures bypass `DiagnosticsHub`, and `CanvasRuntime.camera`
  remains an allowlisted P4 placeholder.
- `.research/2026-05-22-p0-p4-architecture-closure.md:23` and
  `.research/2026-05-22-p0-p4-architecture-closure.md:24` record that `PLAN.md`
  and linked step documents define implementation order and closure scope.
- `.research/2026-05-22-p0-p4-architecture-closure.md:163` records that the
  actual P0-P4 code graph currently contains API, codec, diagnostics, runtime,
  selection, and store owners while P5+ production owners are absent.
- `.design/2026-05-22-architecture-graph-closure-checker.md:153` requires the
  expected graph to encode graph-checkable obligations already present in
  architecture docs, contracts, implementation phase documents, operation
  matrices, guardrail inventories, and diagram catalog phase metadata.
- `.design/2026-05-22-architecture-graph-closure-checker.md:336` and
  `.design/2026-05-22-architecture-graph-closure-checker.md:337` require
  validation of `architecture_graph.yaml` and proof that expected graph entries
  trace to SSOT evidence rather than extracted implementation facts.
- `docs/architecture/architecture_graph.yaml:367`,
  `docs/architecture/architecture_graph.yaml:383`, and
  `docs/architecture/architecture_graph.yaml:415` currently define future
  nodes such as `draw.tools`, `eraser_text.request`, and `release.measurement`.
  `docs/diagrams/generated/full_architecture.mmd:11`,
  `docs/diagrams/generated/full_architecture.mmd:13`, and
  `docs/diagrams/generated/full_architecture.mmd:19` currently render those
  nodes in the full graph view without matching incident edges.

### Entry Paths

- `PLAN.md` is the active roadmap index and will point Step 25 to this contract.
- `.design/2026-05-22-architecture-graph-closure-checker.md` is the architecture
  design input for this step.
- `dart run tool/architecture_graph/check.dart --phase P4` is the required
  standalone closure entrypoint after implementation.
- `dart run tool/architecture_graph/generate_views.dart --phase P4 --check` is
  the required reproducibility entrypoint for graph-backed generated diagram
  views unless the implementation consolidates checking and generation under an
  equivalent sibling command in `tool/architecture_graph/**`.

### Current Owners

- `PLAN.md:12` through `PLAN.md:15` own roadmap order, linked step document
  scope, historical completed-step status, and same-change checkbox updates.
- `docs/tool/check_docs.dart:1` through `docs/tool/check_docs.dart:7` own
  structural documentation checking and explicitly reject free-form Markdown,
  Mermaid edge text, and runtime architecture invariants as docs-check inputs.
- `docs/verification/guardrails.md:98` through
  `docs/verification/guardrails.md:111` own the guardrail runner contract: the
  runner is a thin dispatcher and must not become a second source of truth.
- `tool/guardrails/src/guardrail_registry.dart:8` through
  `tool/guardrails/src/guardrail_registry.dart:23` own the current blocking
  guardrail inventory.
- `tool/guardrails/src/guardrail_executor.dart:42` through
  `tool/guardrails/src/guardrail_executor.dart:78` own guardrail dispatch and
  route descriptions for proof and structural checks.
- `docs/architecture/01_runtime_ownership.md:83` through
  `docs/architecture/01_runtime_ownership.md:90` own runtime view camera
  architecture intent.
- `tool/guardrails/src/public_api_placeholder_allowlist.dart:37` through
  `tool/guardrails/src/public_api_placeholder_allowlist.dart:41` currently
  allowlist `CanvasRuntime.camera` as a P4 placeholder.
- `lib/src/api/canvas_runtime.dart:45` is the current production placeholder
  site for `CanvasRuntime.camera`.
- `lib/src/codec/schema_v1_decoder.dart:48` through
  `lib/src/codec/schema_v1_decoder.dart:68` are current direct codec decode
  error paths.

### Existing Checks

- `dart analyze`, `dcm analyze .`, `dcm calculate-metrics .`,
  `dart run tool/guardrails/run.dart`, `dart run docs/tool/check_docs.dart`,
  and `dart test` passed in the P0-P4 research despite the two architecture
  drifts.
- `docs/tool/check_docs.dart` checks documentation entrypoints, registries,
  navigation, diagram catalog membership, and phase/read-first references only.
- The current guardrail runner can execute fixed guardrail ids and structural
  violation checks, but it has no phase-aware expected-vs-actual architecture
  graph checker.
- Public placeholder checks can detect unapproved placeholders, but the
  current allowlist has no selected-phase closure rule that fails a P4-owned
  placeholder after P4 is closed.
- `test/architecture_graph/architecture_graph_schema_test.dart` validates
  schema shape and sourceDoc traceability, and
  `test/architecture_graph/generated_graph_views_test.dart` validates
  deterministic generated output, but neither currently rejects isolated nodes
  in full or future generated graph views.
- Existing sourceDoc citation checks can prove every graph entry cites a file,
  but they cannot prove every graph-checkable obligation in the SSOT files was
  reviewed and either represented by graph ids or explicitly excluded as
  non-graph semantics.

### Valid Precedents

- `docs/verification/guardrail_design_patterns.md:16` through
  `docs/verification/guardrail_design_patterns.md:21` select registry parity,
  parsed AST scans, and analyzer resolution for source-of-truth, import/export,
  identity, and ownership invariants.
- `docs/verification/guardrail_design_patterns.md:64` through
  `docs/verification/guardrail_design_patterns.md:67` list proven patterns for
  fixed runner inventory, registry parity, parsed AST directives, and resolved
  element identity.
- `pubspec.yaml:19` through `pubspec.yaml:21` already provide `analyzer`,
  `test`, and `yaml` as dev dependencies, so the graph tooling can use the
  established local toolchain before adding any new dependency.
- `tool/guardrails/src/guardrail_executor.dart:23` and
  `tool/guardrails/src/guardrail_executor.dart:77` show structural checks are
  already first-class guardrail routes.
- `docs/diagrams/README.md:101` through `docs/diagrams/README.md:105` show
  that diagram catalog entries can intentionally span current and future
  phases, which supports phase-aware filtering instead of current-phase-only
  deletion.

### Repository Rules

- `docs/verification/guardrail_design_patterns.md:13` and
  `docs/verification/guardrail_design_patterns.md:14` require guardrail pattern
  selection from the invariant owner, not from the easiest syntax shape.
- `docs/verification/guardrails.md:108` through
  `docs/verification/guardrails.md:111` require the guardrail runner to remain a
  dispatcher, not a second test framework or second source of truth.
- `docs/tool/check_docs.dart:5` through `docs/tool/check_docs.dart:7` require
  runtime architecture constraints to live in structured registries, generated
  documentation, analyzer/lint rules, Dart tests, or benchmarks rather than
  free-form docs checks.
- `PLAN.md:13` requires detailed scope, closure rules, and verification to live
  in the linked step document.
- `PLAN.md:15` requires current navigation to use the current document map and
  active step contracts rather than treating completed step contracts as current
  source of truth.

### Misleading Patterns

- The existing public API placeholder allowlist looks like the right place to
  encode placeholder exceptions, but by itself it cannot prove phase closure
  because it can keep a closed-phase placeholder green.
- The existing handwritten Mermaid diagrams contain target architecture facts,
  but `docs/tool/check_docs.dart` explicitly rejects Mermaid edge text as a
  runtime architecture invariant source.
- Adding targeted checks only for `CanvasRuntime.camera` and codec diagnostics
  would repair the observed examples but leave the process gap that lets other
  phase-owned architecture obligations drift.
- Wiring the strict graph checker into the full blocking guardrail suite before
  the known P3/P4 drifts are fixed would make the repository's normal blocking
  proof fail by design.
- A generated file named `full_architecture.mmd` looks like a complete target
  architecture diagram to readers. Rendering a sparse seed graph under that
  name is misleading even when the YAML source is technically reproducible.

## 3. Architecture Decision

### Selected Form

Implement a phase-aware expected architecture graph plus analyzer-derived actual
graph. The expected graph is the durable source of truth for graph-checkable
planned architecture obligations. The actual graph is derived from source code
and compared against the expected graph for a selected phase.

The first implementation must cover P0-P14 with one uniform schema and one
quality target. Already-closed phases may have richer bootstrap evidence because
their code exists now, but that is not a permanent lower bar for later phases.
For future phases, the graph does not need private helper-level implementation
details before the phase is active, but it must include every graph-checkable
major owner, seam, forbidden dependency, placeholder, and planned edge already
declared in the repository's source-of-truth documents.

### Ownership

`docs/architecture/architecture_graph.yaml` owns expected graph obligations for
architecture-seam-level nodes, edges, phase requirements, placeholders,
forbidden dependencies, graph-backed views, and coverage scope. Coverage must be
explicit schema data, not inferred globally by the checker. Existing architecture
docs, implementation phase docs, contracts, operation matrices, guardrail
inventories, and diagram catalog metadata remain the human-readable or
domain-specific source material that justifies graph entries.

The first schema must include coverage categories equivalent to this shape:

```yaml
coverage:
  publicSurfaces:
    - lib/iwb_canvas_engine.dart
    - lib/src/api/**
  architectureOwners:
    - lib/src/runtime/**
    - lib/src/codec/**
    - lib/src/diagnostics/**
  sensitiveThrows:
    - owner: codec.schema_v1
      under: lib/src/codec/**
      exception: CanvasDataException
  placeholders:
    - under: lib/src/api/**
  ignored:
    - "**/*_helper.dart"
    - "**/fixtures/**"
```

The checker may fail unknown architecture seams only inside declared coverage.
It must not infer repository-wide coverage from the presence of the graph file.
The expected graph schema must include source-coverage data keyed by
`docs/_registry/sections.yaml` section ids, not by parsed Markdown headings.
`docs/_registry/sections.yaml` remains the source of truth for the architecture
section inventory, including section id, file, title, phases, related diagrams,
guardrails, tests, and read-order metadata. Every registry section whose file
is under `docs/architecture/**`, `docs/contracts/**`, `docs/verification/**`,
or whose phases include `P0` through `P14` must have one explicit disposition:
`graph_obligation` with one or more graph ids, `non_graph_semantics` with a
reason, `superseded` with the successor source, or `out_of_graph_scope` with a
reason. A graph id referenced by source coverage must exist in nodes, edges,
placeholders, forbidden edges, or views. A graph entry must reference at least
one existing registry section id in addition to any diagnostic `sourceDocs`
paths. This is the mechanical completeness gate for claiming the target graph
matches the architecture SSOT; plain sourceDoc citations and duplicate heading
lists are not enough.
The graph schema must also own view-level connectivity intent for expected full
and future views. A rendered architecture node in those views is valid only when
it has at least one incident rendered edge, or when the node carries an explicit
isolation allowance with source documents and a plain-language reason. This
allowance is an exception for real standalone measurement or release scope, not
a substitute for missing future-phase architecture edges.

`tool/architecture_graph/**` owns schema parsing, validation, analyzer-backed
actual graph extraction, phase comparison, report formatting, and generated
graph-view rendering. Production `lib/**` code owns implemented runtime and API
facts and must not import graph tooling.

### Seam

The new seam is:

```text
ExpectedArchitectureGraph -> ActualArchitectureGraph -> PhaseClosureChecker
```

Consumers enter through the standalone checker command, generated graph-view
verification, future phase contracts, and later guardrail routing after known
selected-phase violations have been fixed. Handwritten sequence, state,
lifecycle, and detailed data-flow diagrams are not retired by this seam.

### Dependency Direction

Graph tooling may read `docs/**`, `plan/**`, and `lib/**`, and may import
project dev dependencies such as `analyzer`, `test`, and `yaml`. Production
code under `lib/**` must not import or depend on `tool/architecture_graph/**`.
The docs checker must not absorb runtime graph closure logic. The guardrail
runner may dispatch the graph checker only in a later contract once selected
phase graph violations are no longer expected.

### State and Data Ownership

The expected architecture graph is durable YAML. Extracted actual graph facts
are transient tool output unless a slice explicitly writes a debug artifact
under a tool-owned output path. Generated Mermaid graph views under
`docs/diagrams/generated/**` are derived artifacts. `full_architecture.mmd`,
`current_phase.mmd`, and `future_target.mmd` are expected-only generated views
from `architecture_graph.yaml` plus the selected phase where relevant.
`actual_vs_expected_diff.mmd` is generated from `architecture_graph.yaml` plus
the analyzer-derived actual graph for the selected phase. Extracted actual facts
must never rewrite expected graph obligations automatically.
`full_architecture.mmd` and `future_target.mmd` must render honest connected
target views: generated output must not hide graph incompleteness behind a
valid Mermaid render.

### Entry and Exit Boundaries

Entry boundaries:

- `docs/architecture/architecture_graph.yaml` for expected graph input.
- `dart run tool/architecture_graph/check.dart --phase Px` for selected-phase
  closure checking.
- `dart run tool/architecture_graph/generate_views.dart --phase Px --check` or
  an equivalent `tool/architecture_graph/**` command for generated view
  reproducibility. `current_phase.mmd` must be generated from the explicit
  `--phase Px` argument, and `PLAN.md` must not be used as generator input for
  current phase selection.

Exit boundaries:

- A product-legible checker report with graph ids, selected phase, expected
  fact, actual evidence, file paths, actual status, and violation message.
- Generated graph-backed Mermaid views in `docs/diagrams/generated/**`.
- Tests and negative fixtures proving missing required facts, forbidden edges,
  stale placeholders, future/deferred filtering, and known P3/P4 drift
  reporting.

### Verification Strategy

Use analyzer-rule proof: schema tests, extractor fixtures, checker fixtures,
known-drift regression tests, generated view reproducibility tests, full/future
view connectivity tests, targeted negative proof for forbidden shortcuts, and
the existing broad repository checks. The strict production P4 checker run is
expected to exit non-zero until the codec diagnostics and camera drift are fixed
in later implementation work; the proof must assert that non-zero result and
the named graph ids instead of pretending P4 is graph-clean.

### Decision Ledger

| ID | Decision | Owner | Proof |
|---|---|---|---|
| D1 | The expected graph is the durable source of truth for graph-checkable planned architecture obligations; actual code extraction is evidence, not an authoring source for expected obligations. | `docs/architecture/architecture_graph.yaml` | P1, P3 |
| D2 | Actual graph extraction is analyzer-backed and limited to architecture-level seams, public surface, placeholders, forbidden dependencies, and stable delegations. | `tool/architecture_graph/**` | P2 |
| D3 | Phase closure is strict for the selected phase and must report known P3/P4 drift rather than suppressing it. | `tool/architecture_graph/check.dart` | P3, P5 |
| D4 | Expected-only generated graph views are derived from the expected graph; the actual-vs-expected diff view is derived from the expected graph plus analyzer-derived actual graph for the selected phase. | `docs/diagrams/generated/**` | P4, P6 |
| D5 | Default blocking guardrail integration is deferred while known selected-phase graph violations remain. | `tool/guardrails/**` and `docs/verification/guardrails.md` | P7, P11 |
| D6 | Full and future generated graph views must be connected target-architecture views, with explicit source-backed isolation allowances only for nodes that are intentionally standalone in that view. | `docs/architecture/architecture_graph.yaml` and `tool/architecture_graph/**` | P6, P14 |
| D7 | Target-graph completeness is proven through machine-checkable coverage of registry-owned architecture sections from `docs/_registry/sections.yaml`, not through unstructured prose review, parsed Markdown headings, or sourceDoc citations alone. | `docs/architecture/architecture_graph.yaml` and `tool/architecture_graph/**` | P15 |

### Rejected Alternatives

- Targeted-only guardrails for camera and codec diagnostics are rejected because
  they would fix the observed examples without closing the phase-aware
  architecture drift class.
- Mermaid-as-source parsing is rejected because repository rules explicitly
  reject free-form Mermaid edge text as runtime architecture invariant input and
  existing diagrams intentionally include future-phase scope.
- Actual-graph-only review is rejected because it gives visibility without a
  closure gate and cannot fail on missing planned obligations.
- Immediate default blocking guardrail integration is rejected because the
  selected strict checker must currently report known P3/P4 violations.
- Renaming the sparse output instead of repairing graph completeness is rejected
  because the design already selected generated full/future graph views from the
  expected graph; the defect is the missing graph-checkable obligations and
  missing guardrail, not only the file name.
- Claiming full alignment from sourceDoc citations alone is rejected because it
  only proves that graph entries point to documents. It does not prove that all
  registry-owned graph-checkable sections were represented or explicitly
  excluded.
- Parsing Markdown headings into a second section inventory is rejected because
  `docs/_registry/sections.yaml` already owns section ids, files, titles,
  phases, diagrams, guardrails, tests, and read-order metadata. Duplicating that
  inventory would create synchronization work without a stronger guarantee.

## 4. Execution Guardrails

### Required Order

1. Define and test the expected graph schema and initial P0-P14 graph entries
   before adding the checker comparator.
2. Build analyzer-backed actual graph extraction before writing production-code
   closure comparisons that depend on extracted evidence.
3. Before implementing comparator success behavior, add or confirm failing
   reproducer fixtures for the two known BUG_FIX cases:
   `runtime.canvas_runtime.camera.closed_phase_placeholder` and
   `codec.schema_v1.failures.report_to_diagnostics`. Add 1 to 3 neighboring
   guard cases for the same closure contract, such as a future-phase placeholder
   that remains allowed, a deferred obligation that does not fail early, and a
   required non-placeholder edge that passes when extracted.
4. Add phase comparison and report formatting after both expected and actual
   graph inputs are available and after the failing drift fixtures exist.
5. Add generated graph views after graph ids, node/edge coverage, and phase
   filtering are stable enough to render reproducibly.
6. Repair the expected graph and generated-view validation before Step 25
   closure: audit repository source-of-truth artifacts for future-phase
   graph-checkable major edges, add missing planned edges or explicit
   source-backed isolation allowances, and prove full/future generated views do
   not contain unexplained isolated architecture nodes.
7. Add source-coverage validation before claiming target-graph completeness:
   every registry-owned architecture section from `docs/_registry/sections.yaml`
   must be mapped to graph ids or to a source-backed non-graph disposition, and
   every graph entry must reference at least one existing registry section id.
8. Update navigation and verification documentation after the commands and
   generated outputs exist.
9. Run broad verification last. The strict P4 graph checker proof must assert
   the expected non-zero known-drift report with both named graph ids:
   `runtime.canvas_runtime.camera.closed_phase_placeholder` and
   `codec.schema_v1.failures.report_to_diagnostics`. The default blocking
   guardrail suite must remain green because this step does not integrate the
   checker into that suite.

### Cross-Slice Constraints

- Do not edit production runtime behavior to make the new checker green.
- Do not add expected graph entries by scraping actual code. Every expected node
  or edge must cite repository source-of-truth evidence.
- Do not claim the target graph fully matches architecture documents unless
  source-coverage validation proves every registry-owned architecture section
  has a graph id mapping or an explicit non-graph/superseded/out-of-scope
  disposition.
- Do not make line numbers in `sourceDocs` hard schema blockers. Validate
  source document path existence, and treat line references as diagnostic
  evidence unless an entry explicitly marks a line anchor as `stableAnchor`.
- Do not require helper-level implementation details outside declared graph
  coverage scope.
- Do not treat future-phase architecture owners as complete merely because they
  are present as nodes. If the SSOT already declares their architecture seams,
  the expected graph must encode the corresponding planned edges.
- Do not keep a node in `full_architecture.mmd` or `future_target.mmd` without
  an incident rendered edge unless the graph entry has an explicit
  source-backed isolation allowance and the schema/view tests enforce that
  allowance.
- Do not add a new dependency while `analyzer`, `test`, and `yaml` are
  sufficient for the slice.
- Do not make generated Mermaid files sources of truth. Expected-only generated
  views must be reproducible from `architecture_graph.yaml`; the diff view must
  be reproducible from `architecture_graph.yaml` plus analyzer-derived actual
  graph input for the selected phase.
- Do not change public API, JSON schema, or persistence compatibility.

### Seam Migration

| Seam or consumer | Migration action | Retirement gate | Negative proof |
|---|---|---|---|
| Graph-checkable architecture obligations scattered across phase docs, architecture docs, contracts, guardrails, operation matrix rows, diagram catalog metadata, and code review | Add `docs/architecture/architecture_graph.yaml` as the structured expected graph for graph-checkable obligations, with citations back to the existing SSOT surfaces. | A later phase contract may rely on graph ids only after schema tests, sourceDoc path validation, and selected-phase checker fixtures pass. | P1 and P3 prove expected obligations are graph-owned and phase-checked instead of inferred from current code. |
| Unstructured SSOT prose or duplicate Markdown heading inventory as implicit completeness proof | Add source-coverage data to `architecture_graph.yaml` keyed by `docs/_registry/sections.yaml` section ids, so every registry-owned architecture section is mapped to graph ids or an explicit non-graph disposition. | The target graph may be described as aligned with the architecture SSOT only when registry-section source-coverage validation passes. | P15 proves registry sections are exhaustively triaged and cross-linked to graph ids. |
| Manual graph-like architecture and diff views | Generate only graph-backed views under `docs/diagrams/generated/**`; keep non-graph semantic diagrams handwritten. | Generated view files compare cleanly against the generator output. No manual diagram is removed unless a later contract gives it a graph-backed successor. | P4 and P6 prove generated views are derived artifacts. |
| Sparse generated full/future target views | Migrate from node-presence-only rendering to connected target-view rendering, backed by planned edges or explicit isolation allowances in `architecture_graph.yaml`. | `full_architecture.mmd` and `future_target.mmd` have no unexplained isolated architecture nodes, and any allowed isolation has source-backed schema data. | P4, P6, and P14 prove generated views are connected or explicitly justified. |
| Default blocking guardrail suite as the closure entrypoint | Keep the new strict checker standalone in this step; do not add it to `_blockingEntries` while known P3/P4 graph violations remain. | A later contract may add runner integration only after selected-phase graph violations are fixed or the selected guardrail phase is changed. | P7 and P11 prove the current blocking guardrail suite remains green and does not include the failing standalone graph checker. |

### Forbidden Moves

- Do not modify `docs/tool/check_docs.dart` to match runtime architecture
  invariants, Mermaid edge text, or graph closure facts.
- Do not add one-off allowlists for the known camera or codec drift inside the
  graph checker.
- Do not treat P14 as a normal production implementation phase; model it as
  measurement and release-alignment scope. If `release.measurement` cannot be
  connected honestly in a runtime/full architecture view, remove it from that
  view and represent it only in a release or verification graph view owned by
  the graph schema.
- Do not delete or rewrite existing manual diagrams unless the slice has a
  graph-backed successor and this contract explicitly assigns that file.
- Do not use a manual checklist, chat summary, or reviewer memory as proof that
  target graph content matches architecture docs. The proof must be executable
  source-coverage validation over `docs/_registry/sections.yaml`.
- Do not parse Markdown headings to create a second section inventory for graph
  coverage. Use registry section ids from `docs/_registry/sections.yaml`.
- Do not mark Step 25 complete in `PLAN.md` or this file until all final-gate
  proof obligations are satisfied.

### Deferred Broad Verification

Default blocking guardrail integration is deferred to a later contract because
the strict P4 graph checker is expected to fail on known drift in the current
production code. The final broad checks for this step must still run the
existing blocking guardrail suite and prove it remains unaffected.

## 5. Proof Plan

### P1. Expected Graph Schema And SSOT Traceability

Proves `architecture_graph.yaml` parses, has unique graph ids, uses valid enum
values, references known P0-P14 phases, validates `sourceDocs` path existence,
validates explicit coverage schema entries, and does not define expected
obligations without source-of-truth citations. Line references are diagnostic
evidence, not schema validity blockers, unless the graph entry explicitly marks
that line reference as `stableAnchor`.

```sh
dart test test/architecture_graph/architecture_graph_schema_test.dart
```

Expected signal: the schema and traceability tests pass.

### P2. Analyzer-Backed Actual Graph Extraction

Proves extraction recognizes public exports, imports, declarations, implements,
composition fields, placeholders, direct public exception throws, and simple
delegations while ignoring helper-level facts outside declared coverage.

```sh
dart test test/architecture_graph/actual_graph_extractor_test.dart
```

Expected signal: positive and allowed-non-violation extractor fixtures pass.

### P3. Phase Closure Comparator

Proves the comparator fails missing required nodes or edges, forbidden edges,
closed-phase placeholders, public placeholders without graph-owned deferral,
unknown architecture seams inside coverage scope, and future entries required
too early. The fixtures must include the known camera placeholder drift as
`runtime.canvas_runtime.camera.closed_phase_placeholder` and the known codec
diagnostics bypass drift as `codec.schema_v1.failures.report_to_diagnostics`;
both must start as failing reproducer fixtures before the comparator/reporting
fix is implemented.

```sh
dart test test/architecture_graph/phase_closure_checker_test.dart
```

Expected signal: positive, negative, false-positive, false-negative, and bypass
fixtures pass, including the two named known-drift fixtures and 1 to 3
neighboring guard cases for the same selected-phase closure contract.

### P4. Generated Graph Views

Proves expected-only graph-backed Mermaid views are generated from
`architecture_graph.yaml` with an explicit selected phase where relevant, and
that `actual_vs_expected_diff.mmd` is generated from `architecture_graph.yaml`
plus the analyzer-derived actual graph for the selected phase.

```sh
dart test test/architecture_graph/generated_graph_views_test.dart
```

Expected signal: expected-only full, current-phase, and future-target views
compare cleanly against expected graph input, and actual-vs-expected diff output
compares cleanly against expected graph plus analyzer-derived actual graph
input.

### P5. Known P3/P4 Drift Report

Proves the strict standalone P4 checker reports the known drift instead of
suppressing it. The report must include both stable graph ids:
`runtime.canvas_runtime.camera.closed_phase_placeholder` for the P4
`CanvasRuntime.camera` placeholder and
`codec.schema_v1.failures.report_to_diagnostics` for the P3 codec failure path
bypassing `DiagnosticsHub`.

```sh
sh -c 'set +e; output=$(dart run tool/architecture_graph/check.dart --phase P4 2>&1); status=$?; printf "%s\n" "$output"; test "$status" -ne 0 && printf "%s\n" "$output" | grep -F "Architecture graph closure failed for P4." && printf "%s\n" "$output" | grep -F "Violations:" && printf "%s\n" "$output" | grep -F "runtime.canvas_runtime.camera.closed_phase_placeholder" && printf "%s\n" "$output" | grep -F "codec.schema_v1.failures.report_to_diagnostics"'
```

Expected signal: the command exits successfully only when the checker itself
exits non-zero, prints the stable closure-failure report header for P4, prints
the violation count marker, and names both required graph ids:
`runtime.canvas_runtime.camera.closed_phase_placeholder` and
`codec.schema_v1.failures.report_to_diagnostics`.

### P6. Generated View Reproducibility Command

Proves checked-in generated graph views match the generator output for both
expected-only views and the actual-vs-expected diff view for the selected phase.

```sh
dart run tool/architecture_graph/generate_views.dart --phase P4 --check
```

Expected signal: the command exits zero when generated graph views are current.

### P7. Documentation Structure

Proves documentation navigation, registries, and diagram catalog structure stay
valid after graph and generated-view documentation changes.

```sh
dart run docs/tool/check_docs.dart
```

Expected signal: documentation structural checks pass.

### P8. Dart Analyzer

Proves source and tooling are analyzer-clean.

```sh
dart analyze
```

Expected signal: analyzer exits zero.

### P9. DCM Analysis

Proves static analysis remains green.

```sh
dcm analyze .
```

Expected signal: DCM exits zero.

### P10. DCM Metrics

Proves metrics review signals do not report unaddressed issues.

```sh
dcm calculate-metrics .
```

Expected signal: DCM metrics exits zero, or any intentional local suppression
has a nearby plain-language justification.

### P11. Existing Blocking Guardrails

Proves the existing blocking guardrail suite remains green and has not absorbed
the strict graph checker while known selected-phase violations remain.

```sh
dart run tool/guardrails/run.dart
```

Expected signal: current blocking guardrails exit zero.

### P12. Production Import Boundary

Proves production code does not depend on graph tooling.

```sh
sh -c '! rg "architecture_graph|tool/architecture_graph" lib'
```

Expected signal: no production `lib/**` reference to graph tooling exists.

### P13. Whitespace Validation

Proves the roadmap, graph documentation, generated views, graph tooling, and
graph tests do not contain trailing whitespace.

```sh
sh -c '! rg -n "[[:blank:]]+$" PLAN.md plan/step_25_architecture_graph_closure_checker.md docs/architecture docs/diagrams/generated tool/architecture_graph test/architecture_graph'
```

Expected signal: no trailing-whitespace matches are reported in the contract's
owned roadmap, documentation, generated view, tool, or test surfaces.

### P14. Full And Future View Connectivity

Proves expected full and future generated graph views do not render
architecture nodes as disconnected boxes unless the graph explicitly allows that
isolation with sourceDocs and an explanation.

```sh
dart test test/architecture_graph/generated_graph_views_test.dart --name "full and future graph views reject unexplained isolated nodes"
```

Expected signal: the focused generated-view connectivity test passes, including
at least one negative fixture or constructed graph case where an unexplained
isolated rendered node is rejected.

### P15. SSOT Source Coverage Completeness

Proves every registry-owned architecture section from
`docs/_registry/sections.yaml` is explicitly classified in
`architecture_graph.yaml` and every graph-checkable section maps to existing
graph ids. The test must fail when a registry-owned architecture section is
absent from source coverage, when a `graph_obligation` entry has no graph ids,
when a referenced graph id does not exist, when a graph entry lacks an existing
registry section id, or when a non-graph disposition omits its reason or
successor.

```sh
dart test test/architecture_graph/architecture_graph_schema_test.dart --name "expected graph source coverage is complete"
```

Expected signal: the focused source-coverage test passes for architecture
sections registered in `docs/_registry/sections.yaml`, including sections whose
files live under `docs/architecture/**`, `docs/contracts/**`,
`docs/verification/**`, or whose phases include `P0` through `P14`. Its
negative fixture or constructed graph case proves an omitted graph-checkable
registry section is rejected.

## 6. Vertical Slices

### Slice 1. [x] Expected graph schema and P0-P14 expected graph

#### Implements

D1

#### Obligations Covered

BUG_FIX, SEAM_MIGRATION

#### Files

- Primary expected graph source of truth:
  `docs/architecture/architecture_graph.yaml` - new durable graph obligation
  registry with P0-P14 phases, node and edge entries, expected status,
  coverage scope, sourceDocs, evidence, and diagram view definitions.
- Schema parsing and validation tooling:
  `tool/architecture_graph/**` - proposed graph model, parser, validation, and
  stable diagnostic types needed by later extractor and checker slices.
- Schema and traceability proof:
  `test/architecture_graph/architecture_graph_schema_test.dart` - executable
  validation for required fields, enum values, phase references, path/sourceDoc
  existence, explicit coverage schema entries, graph id uniqueness,
  source-of-truth citation requirements, and line-reference stability rules.
- Analyzer fixtures:
  `test/architecture_graph/fixtures/**` - proposed fixture directory used only
  for graph and extractor tests.
- Explicit exclusions:
  `lib/**` - no production behavior changes in this slice.

#### Change

Add the graph schema and initial expected graph covering P0-P14 at
architecture-seam level. P0-P4 entries must include the known codec diagnostics
and camera ownership obligations as required selected-phase facts. P5-P13
future owners must be represented as future or deferred obligations with their
own `phaseRequiredBy`. P14 must be represented as measurement and
release-alignment scope rather than a normal production component phase.
P5-P13 expected graph entries must include known major owners and seams from
source-of-truth artifacts. Absence of private helper details is acceptable
before the owning phase becomes active, but absence of SSOT-backed
architecture-level planned edges is a contract failure.

#### Proof

Run P1.

#### Closure

The expected graph parses, validates, cites repository source-of-truth evidence,
and represents current, future, deferred, and forbidden facts without reading
implementation code as the expected-obligation source.

### Slice 2. [x] Analyzer-backed actual graph extractor

#### Implements

D2

#### Obligations Covered

SEAM_MIGRATION

#### Files

- Actual graph extraction owner:
  `tool/architecture_graph/**` - analyzer-backed extraction for public exports,
  imports, declarations, implemented interfaces, composition fields, public
  placeholders, `UnimplementedError`, direct public exception throws, and simple
  facade delegations.
- Extractor proof:
  `test/architecture_graph/actual_graph_extractor_test.dart` - positive,
  negative, and allowed-non-violation fixture tests for extraction coverage and
  helper-level exclusions.
- Analyzer fixtures:
  `test/architecture_graph/fixtures/**` - extractor fixture packages and files
  with controlled imports, declarations, placeholders, exceptions, and
  delegations.
- Explicit exclusions:
  `lib/**` - verify-only input; no production edits.

#### Change

Add actual graph extraction that uses analyzer-backed parsing and resolution
where architecture-sensitive identity matters. The extractor must report stable
evidence paths and must not attempt exhaustive private implementation graph
closure.

#### Proof

Run P2.

#### Closure

The extractor recognizes the locked architecture-level facts, ignores allowed
non-violations outside coverage scope, and emits stable evidence for later
comparison.

### Slice 3. [x] Phase closure comparator and strict standalone checker

#### Implements

D1, D2, D3

#### Obligations Covered

BUG_FIX, SEAM_MIGRATION

#### Files

- Checker entrypoint:
  `tool/architecture_graph/check.dart` - selected-phase CLI for comparing
  expected and actual graph facts.
- Checker implementation owner:
  `tool/architecture_graph/**` - phase filtering, expected-vs-actual
  comparison, violation classification, report formatting, and exit-code
  behavior.
- Comparator proof:
  `test/architecture_graph/phase_closure_checker_test.dart` - fixtures for
  missing required node/edge, forbidden edge, stale placeholder, public
  placeholder without deferral, future/deferred filtering, unknown seam inside
  coverage, the two named failing reproducer fixtures, and 1 to 3 neighboring
  guard cases for the same selected-phase closure contract.
- Analyzer fixtures:
  `test/architecture_graph/fixtures/**` - checker fixture inputs for positive,
  negative, false-positive, false-negative, and bypass cases.
- Explicit exclusions:
  `tool/guardrails/src/guardrail_registry.dart` and
  `tool/guardrails/src/guardrail_executor.dart` - do not add default blocking
  graph guardrail integration in this slice.
- Explicit exclusions:
  `lib/src/api/canvas_runtime.dart` and `lib/src/codec/**` - verify-only
  production inputs for known drift reporting, not production fix targets.

#### Change

Add `dart run tool/architecture_graph/check.dart --phase Px` with strict
selected-phase closure semantics. The checker must fail required selected-phase
missing facts, forbidden edges, stale placeholders, unrepresented architecture
seams in coverage, and graph-required missing docs/diagram/code paths. The P4
production run must currently report both stable graph ids:
`runtime.canvas_runtime.camera.closed_phase_placeholder` for the closed-phase
camera placeholder and `codec.schema_v1.failures.report_to_diagnostics` for
codec failures bypassing `DiagnosticsHub`. The run must exit non-zero.

Before implementing the owner-side comparator/reporting fix, this slice must
add or confirm failing reproducer fixtures for both named graph ids and add 1 to
3 neighboring guard cases. Acceptable neighboring guard cases include a
future-phase placeholder that remains allowed, a deferred obligation that does
not fail before its phase, and a required non-placeholder edge that passes when
extracted.

#### Proof

Run P3 and P5.

#### Closure

The checker is strict, phase-aware, standalone, and produces actionable
violations with graph ids, paths, selected phase, expected facts, actual
evidence, and messages. It does not suppress the known P3/P4 drift.

### Slice 4. [x] Generated graph-backed architecture views

#### Implements

D4

#### Obligations Covered

SEAM_MIGRATION

#### Files

- Generated view command:
  `tool/architecture_graph/generate_views.dart` - proposed command that renders
  graph-backed Mermaid views and supports explicit `--phase Px` selection plus
  `--check` reproducibility mode.
- Generated view implementation owner:
  `tool/architecture_graph/**` - renderer and deterministic ordering for graph
  view output.
- Derived graph views:
  `docs/diagrams/generated/full_architecture.mmd` - generated full graph view.
- Derived graph views:
  `docs/diagrams/generated/current_phase.mmd` - generated selected current
  phase view produced from the explicit generator `--phase Px` argument.
- Derived graph views:
  `docs/diagrams/generated/future_target.mmd` - generated future target view.
- Derived graph views:
  `docs/diagrams/generated/actual_vs_expected_diff.mmd` - generated
  expected-vs-actual diff view from expected graph input plus analyzer-derived
  actual graph input for the selected phase.
- Generated view proof:
  `test/architecture_graph/generated_graph_views_test.dart` - deterministic
  output and checked-in view reproducibility tests.
- Explicit exclusions:
  `docs/diagrams/*.mmd` outside `docs/diagrams/generated/**` - no manual
  behavior, sequence, state, lifecycle, or detailed data-flow diagram
  replacement in this slice.

#### Change

Generate only graph-backed architecture and diff views. Expected-only views
(`full_architecture.mmd`, `current_phase.mmd`, and `future_target.mmd`) are
generated from `architecture_graph.yaml` plus the selected phase where relevant.
`actual_vs_expected_diff.mmd` is generated from `architecture_graph.yaml` plus
the analyzer-derived actual graph for the selected phase. Keep generated files
clearly derived and do not promote them over the YAML graph, current source
extraction, or existing manually maintained semantic diagrams. The selected
phase for `current_phase.mmd` and `actual_vs_expected_diff.mmd` must be
deterministic and explicit through the generator `--phase Px` argument; do not
read the current phase from `PLAN.md`.

#### Proof

Run P4 and P6.

#### Closure

Expected-only generated graph views are reproducible from `architecture_graph.yaml`,
and `actual_vs_expected_diff.mmd` is reproducible from `architecture_graph.yaml`
plus the analyzer-derived actual graph for the selected phase. All generated
views remain limited to the graph semantics this contract owns.

### Slice 5. [x] Full and future graph completeness repair

#### Implements

D1, D4, D6, D7

#### Obligations Covered

BUG_FIX, SEAM_MIGRATION

#### Files

- Primary expected graph source of truth:
  `docs/architecture/architecture_graph.yaml` - repair future-phase planned
  edges, source-coverage data, and any explicit view-isolation metadata from
  repository SSOT evidence.
- Generated view implementation owner:
  `tool/architecture_graph/**` - enforce full/future rendered-node
  connectivity and support explicit source-backed isolation allowances if the
  schema needs them.
- Generated view proof:
  `test/architecture_graph/generated_graph_views_test.dart` - add negative and
  positive coverage for unexplained isolated nodes in `full_architecture.mmd`
  and `future_target.mmd`.
- Schema proof:
  `test/architecture_graph/architecture_graph_schema_test.dart` - validate
  source-coverage completeness and any explicit isolation allowance fields,
  including required sourceDocs and explanation text.
- Derived graph views:
  `docs/diagrams/generated/full_architecture.mmd` - regenerated connected full
  target graph view.
- Derived graph views:
  `docs/diagrams/generated/future_target.mmd` - regenerated connected future
  target graph view.
- Derived graph views:
  `docs/diagrams/generated/current_phase.mmd` and
  `docs/diagrams/generated/actual_vs_expected_diff.mmd` - regenerated only if
  deterministic generator output changes.
- Source-of-truth evidence inputs:
  `docs/_registry/sections.yaml` - verify-only source of the architecture
  section inventory and section ids that graph coverage must use.
- Source-of-truth evidence inputs:
  files referenced by covered `docs/_registry/sections.yaml` entries -
  verify-only audit surfaces for graph-checkable future-phase owners, seams,
  planned edges, release/measurement scope, and diagram-view metadata.
- Explicit exclusions:
  `lib/**` - no production behavior changes in this repair slice.
- Explicit exclusions:
  handwritten diagrams outside `docs/diagrams/generated/**` - no manual
  sequence, state, lifecycle, or detailed data-flow diagram replacement in this
  repair slice.

#### Change

Audit repository source-of-truth documents for graph-checkable future-phase
architecture obligations that should already be represented in
`architecture_graph.yaml`. Add missing planned edges for future owners such as
`draw.tools` and `eraser_text.request` when the SSOT already defines their
major seams. Resolve `release.measurement` explicitly: either connect it
through a release/verification relationship that belongs in the generated view,
or exclude it from runtime full/future architecture views and represent it only
in a release or verification view owned by the graph schema.

Add owner-side validation so generated full and future graph views reject
unexplained isolated architecture nodes. If any isolated node is intentionally
valid, encode the allowance in `architecture_graph.yaml` with sourceDocs and a
plain-language reason, and prove the renderer/schema accepts only that explicit
case.

Add source-coverage data to `architecture_graph.yaml` for every registry-owned
architecture section selected from `docs/_registry/sections.yaml`. Every
graph-checkable registry section must map to one or more graph ids; every
non-graph section must have an explicit disposition and reason. The schema test
must make missing source coverage, dangling graph id references, graph entries
without registry section ids, and reasonless non-graph dispositions fail.

#### Proof

Run P1, P4, P6, P14, and P15.

#### Closure

`full_architecture.mmd` and `future_target.mmd` no longer contain unexplained
isolated architecture nodes. Every rendered future-phase architecture owner is
connected by SSOT-backed planned edges or has a schema-validated
source-backed isolation allowance. Source-coverage validation proves every
registry-owned architecture section is either represented by graph ids or
explicitly classified as non-graph/superseded/out-of-scope. The generated files
are reproducible from the repaired graph source and generator.

### Slice 6. [ ] Documentation routing and non-blocking rollout finalization

#### Implements

D1, D3, D4, D5

#### Obligations Covered

SEAM_MIGRATION

#### Files

- Architecture navigation:
  `docs/architecture/README.md` - route readers to
  `docs/architecture/architecture_graph.yaml` if the current architecture index
  requires graph discoverability.
- Diagram catalog:
  `docs/diagrams/README.md` - catalog generated graph-backed views only if
  generated views are treated as diagram deliverables.
- Verification docs:
  `docs/verification/release_gates.md` - document the standalone phase closure
  command if release or phase closure guidance needs the new proof entrypoint.
- Guardrail docs:
  `docs/verification/guardrails.md` - update only if needed to state that the
  graph checker remains standalone until selected-phase violations are fixed;
  do not claim it is in the default blocking suite in this step.
- Guardrail pattern docs:
  `docs/verification/guardrail_design_patterns.md` - update only if the
  implementation introduces a genuinely new reusable pattern beyond registry
  parity, analyzer identity, semantic sequence, runner inventory, and
  behavioral seam tests.
- Roadmap finalization:
  `PLAN.md` - mark Step 25 complete only after all final-gate proof passes.
- Step contract finalization:
  `plan/step_25_architecture_graph_closure_checker.md` - mark completed slice
  checkboxes only after the corresponding implementation proof passes.
- Explicit exclusions:
  `tool/guardrails/src/guardrail_registry.dart` and
  `tool/guardrails/src/guardrail_executor.dart` - no default blocking graph
  checker route while known selected-phase violations remain.

#### Change

Route readers to the expected graph, generated graph views, and standalone
checker without overstating rollout status. Document the deferred guardrail
integration decision only if the existing verification docs need that
clarification.

#### Proof

Run P7, P11, and P12.

#### Closure

Documentation points to the new graph/checker surfaces accurately, the existing
blocking guardrail suite remains green, and production code has no graph-tooling
dependency.

## 7. Final Gate

### Run Proof Set

Run P1, P2, P3, P4, P5, P6, P7, P8, P9, P10, P11, P12, P13, P14, and P15.

### Done When

- all referenced Decision Ledger decisions have passing proof;
- all Contract Obligations are satisfied;
- the strict standalone selected-phase checker reports both known P3/P4 graph
  drift ids, `runtime.canvas_runtime.camera.closed_phase_placeholder` and
  `codec.schema_v1.failures.report_to_diagnostics`, instead of suppressing
  either one;
- the graph checker is not added to the default blocking guardrail suite while
  selected-phase violations are known;
- expected-only generated graph views are reproducible from
  `architecture_graph.yaml`, and `actual_vs_expected_diff.mmd` is reproducible
  from `architecture_graph.yaml` plus the analyzer-derived actual graph for the
  selected phase;
- `full_architecture.mmd` and `future_target.mmd` contain no unexplained
  isolated architecture nodes, and any intentionally isolated rendered node is
  backed by explicit graph schema data, sourceDocs, and explanation text;
- source-coverage validation proves every registry-owned architecture section
  from `docs/_registry/sections.yaml` is mapped to graph ids or explicitly
  classified with a
  source-backed non-graph/superseded/out-of-scope disposition;
- no production runtime behavior, public API, schema, or persistence format was
  changed;
- no out-of-scope files were changed;
- Step 25 is checked complete in `PLAN.md` and this file only after all final
  proof passes;
- P13 whitespace validation passes.
