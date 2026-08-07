---
date: 2026-05-22
researcher: Codex
commit: 170af227
branch: new-architecture
research_question: "Research how documentation under /Users/blackpika/iwb_canvas_engine/docs is currently organized, including deletion candidates, synchronization pressure, and documentation entry points."
---

# Research: Docs Structure and Entrypoints

## Summary
The `docs/` tree is organized around role folders plus machine-readable registries. The root documentation entry says `docs/` is the durable source of truth for the new-engine transition and target architecture (`docs/README.md:3`), then routes architecture, implementation, guardrail-design, and donor work to separate entry points (`docs/README.md:6`). The layout separates architecture, contracts, implementation phases, verification, donors, diagrams, indexes, and registries (`docs/README.md:11`).

The strongest mechanically enforced layer is registry-backed. `docs/_registry/sections.yaml` maps section ids to files, phases, must-read links, donors, diagrams, guardrails, tests, and do-not-assume notes (`docs/_registry/sections.yaml:2`, `docs/_registry/sections.yaml:29`, `docs/_registry/sections.yaml:83`). `docs/tool/generate_context_capsules.dart` renders context capsules from that registry (`docs/tool/generate_context_capsules.dart:121`), and `docs/tool/check_docs.dart` verifies required entrypoints, registries, navigation links, diagram catalog membership, and phase/read-first references (`docs/tool/check_docs.dart:1`, `docs/tool/check_docs.dart:77`).

The highest synchronization pressure is in human-readable derivative views. The indexes mirror guardrail, test, donor, subsystem, and context-coverage relationships (`docs/indexes/by_guardrail.md:1`, `docs/indexes/by_test_area.md:1`, `docs/indexes/donor_to_phase.md:1`, `docs/indexes/by_subsystem.md:1`, `docs/indexes/context_coverage.md:1`), but the current documentation tools do not generate these files or validate their full semantic parity with the registries. The current `generate_context_capsules --check` command reports stale generated context in two section files, while `check_docs.dart` still passes.

## Detailed Findings

### 1. Root Entrypoint and Role Routing
- **Location**: primary `docs/README.md:1`; architecture entrypoint at `docs/architecture/README.md:1`.
- **Description**: The root entrypoint presents `docs/` as durable architecture-transition documentation (`docs/README.md:3`) and routes work by role: architecture to `architecture/README.md`, implementation to `docs/implementation/`, guardrail design to `verification/guardrail_design_patterns.md`, and donor work to `donors/00_reuse_rules.md` plus `_registry/donors.yaml` (`docs/README.md:6`). The layout section assigns primary responsibilities to `architecture/`, `contracts/`, `implementation/`, `verification/`, `donors/`, `diagrams/`, `indexes/`, and `_registry/` (`docs/README.md:11`).
- **Dependencies**: `docs/tool/check_docs.dart` requires `docs/README.md`, `docs/architecture/README.md`, both registries, and the diagram catalog (`docs/tool/check_docs.dart:162`). It also requires role directories plus `plan` to exist (`docs/tool/check_docs.dart:170`).
- **Data flow**: reader intent -> root routing (`docs/README.md:6`) -> role entrypoint or phase file -> registry-backed context and checks.

### 2. Architecture Entrypoint
- **Location**: primary `docs/architecture/README.md:10`.
- **Description**: The architecture entrypoint defines a read path through overview, runtime ownership, package boundaries, data model, accepted differences, graph YAML, and diagrams (`docs/architecture/README.md:10`). It routes public API, schema, validation, runtime, interaction, rendering, geometry/spatial, resources, diagnostics, verification, graph closure, implementation sequencing, legacy inventory, donors, and change contracts to owning folders or files (`docs/architecture/README.md:22`).
- **Dependencies**: The architecture entrypoint lists `dart run docs/tool/generate_context_capsules.dart --check`, `dart run docs/tool/check_docs.dart`, and `dart run tool/architecture_graph/generate_views.dart --phase P4 --check` as mechanical checks (`docs/architecture/README.md:72`).
- **Data flow**: architecture change -> read path -> role route -> generated context, docs check, and architecture graph view check.

### 3. Registry-Backed Section Context
- **Location**: primary `docs/_registry/sections.yaml:2`; generator at `docs/tool/generate_context_capsules.dart:121`.
- **Description**: Each section registry entry stores the section id, source marker, target file, title, phases, must-read links, donors, diagrams, guardrails, tests, and do-not-assume notes (`docs/_registry/sections.yaml:2`, `docs/_registry/sections.yaml:6`, `docs/_registry/sections.yaml:9`, `docs/_registry/sections.yaml:11`, `docs/_registry/sections.yaml:13`, `docs/_registry/sections.yaml:16`, `docs/_registry/sections.yaml:20`, `docs/_registry/sections.yaml:23`). The context generator renders those fields into a `<!-- CONTEXT:BEGIN -->` block (`docs/tool/generate_context_capsules.dart:121`) and requires that block to be the first block in each section file (`docs/tool/generate_context_capsules.dart:178`).
- **Dependencies**: The generator reads only `docs/_registry/sections.yaml` (`docs/tool/generate_context_capsules.dart:5`) and writes or checks section-file capsules (`docs/tool/generate_context_capsules.dart:75`).
- **Data flow**: `sections.yaml` -> `_SectionEntry` -> rendered context capsule -> section Markdown file (`docs/tool/generate_context_capsules.dart:89`, `docs/tool/generate_context_capsules.dart:121`, `docs/tool/generate_context_capsules.dart:154`).

### 4. Structural Documentation Checker
- **Location**: primary `docs/tool/check_docs.dart:1`.
- **Description**: The checker states that it verifies documentation entrypoints, registries, navigation links, diagram catalog membership, and phase/read-first references, and excludes free-form Markdown wording, Mermaid edge text, and runtime architecture invariants from its scope (`docs/tool/check_docs.dart:1`). It loads sections, donors, and the diagram catalog, then runs section-reference, donor-reference, diagram symmetry, implementation-diagram, Markdown-path, must-read graph, and phase read-first checks (`docs/tool/check_docs.dart:77`).
- **Dependencies**: It parses `docs/_registry/sections.yaml`, `docs/_registry/donors.yaml`, and `docs/diagrams/README.md` (`docs/tool/check_docs.dart:13`). It loads guardrails and tests fields from section entries (`docs/tool/check_docs.dart:206`), but `rg` over the checker shows only sentinel checks for those two fields (`docs/tool/check_docs.dart:276`, `docs/tool/check_docs.dart:277`).
- **Data flow**: registries and catalog -> in-memory entries -> structural checks -> "Docs check passed." or diagnostics (`docs/tool/check_docs.dart:77`, `docs/tool/check_docs.dart:94`, `docs/tool/check_docs.dart:103`).

### 5. Diagram Catalog and Generated Graph Views
- **Location**: primary `docs/diagrams/README.md:1`; graph view source at `docs/architecture/architecture_graph.yaml:812`.
- **Description**: The diagram catalog states that every listed item is a required Mermaid deliverable and links docs to planned Mermaid paths (`docs/diagrams/README.md:3`). Generated graph-backed Mermaid files live under `docs/diagrams/generated` and use `docs/architecture/architecture_graph.yaml` as source of truth (`docs/diagrams/README.md:10`). The graph YAML defines generated view outputs for full architecture, current phase, future target, actual-vs-expected diff, and release verification (`docs/architecture/architecture_graph.yaml:812`).
- **Dependencies**: The diagram catalog is parsed by `check_docs.dart`, which requires each catalog entry to have a planned path, related sections, and known phases, and checks catalog/registry symmetry (`docs/tool/check_docs.dart:380`, `docs/tool/check_docs.dart:477`). Generated graph views are checked or written by `tool/architecture_graph/generate_views.dart` (`tool/architecture_graph/generate_views.dart:40`, `tool/architecture_graph/generate_views.dart:52`).
- **Data flow**: handwritten diagram catalog + section registry -> structural symmetry check; architecture graph YAML -> generated Mermaid views.

### 6. Implementation Phase Files
- **Location**: primary `docs/implementation/p4_runtime_spine.md:1`.
- **Description**: Phase files use a repeated structure: purpose, build scope, dependencies, read-first section ids, required donors, forbidden donor structure, diagrams, contracts, tests/guardrails, exit gate, risks, and placement rationale (`docs/implementation/p4_runtime_spine.md:3`, `docs/implementation/p4_runtime_spine.md:10`, `docs/implementation/p4_runtime_spine.md:32`, `docs/implementation/p4_runtime_spine.md:39`, `docs/implementation/p4_runtime_spine.md:46`, `docs/implementation/p4_runtime_spine.md:52`, `docs/implementation/p4_runtime_spine.md:60`, `docs/implementation/p4_runtime_spine.md:67`, `docs/implementation/p4_runtime_spine.md:78`, `docs/implementation/p4_runtime_spine.md:90`).
- **Dependencies**: `check_docs.dart` has a hardcoded P0-P14 phase-to-file map (`docs/tool/check_docs.dart:17`), verifies phase read-first section ids against the registry (`docs/tool/check_docs.dart:662`), and verifies phase diagram references against the catalog (`docs/tool/check_docs.dart:543`).
- **Data flow**: phase file read-first and diagram sections -> checker regex extraction -> registry/catalog parity checks (`docs/tool/check_docs.dart:702`, `docs/tool/check_docs.dart:557`).

### 7. Manual Indexes
- **Location**: primary `docs/indexes/by_test_area.md:1`; other indexes at `docs/indexes/by_guardrail.md:1`, `docs/indexes/donor_to_phase.md:1`, `docs/indexes/by_subsystem.md:1`, and `docs/indexes/context_coverage.md:1`.
- **Description**: `by_test_area.md` claims to list explicit and phase-required tests from the registry, linked to phases, sections, and guardrails (`docs/indexes/by_test_area.md:3`). `by_guardrail.md` describes guardrails extracted from split section 22 (`docs/indexes/by_guardrail.md:3`). `donor_to_phase.md` maps donors to target phases and marks avoid records as forbidden structure (`docs/indexes/donor_to_phase.md:3`). `by_subsystem.md` is a subsystem-oriented reading map over the section registry (`docs/indexes/by_subsystem.md:3`). `context_coverage.md` summarizes context capsule and registry coverage (`docs/indexes/context_coverage.md:3`).
- **Dependencies**: `check_docs.dart` includes `docs/indexes` in Markdown roots for path and section-id scans (`docs/tool/check_docs.dart:65`) but has no generator or semantic parity check for the index contents. A code search for index names under `docs/tool` and `tool` found only root/path mentions in `check_docs.dart`, not a generator or per-index checker.
- **Data flow**: registry/phase/verification facts -> manually maintained reverse lookup Markdown files -> path/section-id scan only.

### 8. Donor Registry and Donor Markdown
- **Location**: primary `docs/_registry/donors.yaml:2`; donor rule entrypoint at `docs/donors/00_reuse_rules.md:1`.
- **Description**: Donor registry records include source paths, decision, target phases, target owner, use-for notes, do-not-copy notes, required tests, blocks, related sections, and notes (`docs/_registry/donors.yaml:2`, `docs/_registry/donors.yaml:7`, `docs/_registry/donors.yaml:8`, `docs/_registry/donors.yaml:11`, `docs/_registry/donors.yaml:12`, `docs/_registry/donors.yaml:14`, `docs/_registry/donors.yaml:16`, `docs/_registry/donors.yaml:18`, `docs/_registry/donors.yaml:21`, `docs/_registry/donors.yaml:24`). The root docs say donor use is controlled by `_registry/donors.yaml` (`docs/README.md:24`) and donor allowance requires a target phase and owner in that registry (`docs/README.md:62`).
- **Dependencies**: `check_docs.dart` validates donor ids, decisions, required list fields, target phase values, block phase values, and donor/section reverse references (`docs/tool/check_docs.dart:228`, `docs/tool/check_docs.dart:238`, `docs/tool/check_docs.dart:257`, `docs/tool/check_docs.dart:331`, `docs/tool/check_docs.dart:363`). Donor Markdown files contain context blocks that identify `docs/_registry/donors.yaml` as canonical source and also say they feed that registry (`docs/donors/00_reuse_rules.md:3`, `docs/donors/00_reuse_rules.md:4`, `docs/donors/00_reuse_rules.md:5`).
- **Data flow**: donor YAML -> checker validation and implementation phase references; donor Markdown -> human-readable donor rules and summaries.

### 9. Verification Docs and Guardrail Pattern Map
- **Location**: primary `docs/verification/guardrails.md:94`; pattern guidance at `docs/verification/guardrail_design_patterns.md:1`.
- **Description**: `guardrails.md` defines the guardrail runner contract and says guardrails must be executable through one project-owned entrypoint (`docs/verification/guardrails.md:96`). It states the runner must not become a second test framework or second source of truth for required guardrails (`docs/verification/guardrails.md:108`). It also says future mandatory guardrails remain owned by `docs/_registry/sections.yaml` and this section until implementation adds executable proof (`docs/verification/guardrails.md:144`).
- **Dependencies**: `guardrail_design_patterns.md` says each mandatory guardrail must choose a pattern from that document before executable proof is added (`docs/verification/guardrail_design_patterns.md:150`). `frame.committed_facts_via_frame_facts_port` is listed as a mandatory guardrail in the guardrails context and table (`docs/verification/guardrails.md:69`, `docs/verification/guardrails.md:207`) and in `by_guardrail.md` (`docs/indexes/by_guardrail.md:373`), while an `rg` search for that id in `docs/verification/guardrail_design_patterns.md` returns no match.
- **Data flow**: mandatory guardrail list -> design pattern map -> executable proof selection; current tooling does not enforce full guardrail-to-pattern coverage.

### 10. Current Mechanical Verification State
- **Location**: primary `docs/tool/generate_context_capsules.dart:189`; related stale files at `docs/architecture/03_data_model.md:24` and `docs/verification/tests.md:96`.
- **Description**: `dart run docs/tool/check_docs.dart` currently passes. `dart run tool/architecture_graph/generate_views.dart --phase P4 --check` exits successfully without stale-output diagnostics. `dart run docs/tool/generate_context_capsules.dart --check` reports stale context capsules in `docs/architecture/03_data_model.md` and `docs/verification/tests.md`.
- **Dependencies**: The data-model registry entry includes `test.guardrails.store_projection_checks` and `test.guardrails.selection_boundary_checks` (`docs/_registry/sections.yaml:349`, `docs/_registry/sections.yaml:350`), while the current data-model context capsule's required tests stop before those two ids (`docs/architecture/03_data_model.md:24`). The tests registry entry includes the same two guardrail tests (`docs/_registry/sections.yaml:1025`, `docs/_registry/sections.yaml:1026`), while the current tests context capsule omits them between the frame facts guardrail test and frame paint-plan tests (`docs/verification/tests.md:167`).
- **Data flow**: registry changed -> generated context expected output changed -> `--check` reports stale generated block, while structural docs check remains green.

## Code References
- `docs/README.md:3` - root claim that `docs/` is the durable source of truth.
- `docs/README.md:6` - root routing to architecture, implementation, guardrail design, and donor entrypoints.
- `docs/README.md:72` - root documentation mechanical checks.
- `docs/architecture/README.md:10` - architecture read path.
- `docs/architecture/README.md:72` - architecture-specific mechanical checks.
- `docs/_registry/sections.yaml:2` - section registry entry shape begins.
- `docs/_registry/donors.yaml:2` - donor registry entry shape begins.
- `docs/_registry/public_api_v1.yaml:1` - public API exported-name inventory declares semantic ownership remains in the contract doc.
- `docs/tool/generate_context_capsules.dart:121` - context capsule rendering from registry fields.
- `docs/tool/generate_context_capsules.dart:189` - stale generated context failure in `--check` mode.
- `docs/tool/check_docs.dart:77` - structural checker execution flow.
- `docs/tool/check_docs.dart:162` - required docs entrypoints and directories.
- `docs/tool/check_docs.dart:267` - section reference validation.
- `docs/tool/check_docs.dart:315` - donor reference validation.
- `docs/tool/check_docs.dart:477` - diagram catalog and registry symmetry.
- `docs/tool/check_docs.dart:543` - implementation phase diagram-reference validation.
- `docs/tool/check_docs.dart:662` - phase read-first reference validation.
- `docs/diagrams/README.md:10` - generated diagram source-of-truth statement.
- `docs/architecture/architecture_graph.yaml:812` - generated graph view outputs.
- `docs/verification/guardrails.md:144` - ownership statement for future mandatory guardrails.
- `docs/verification/guardrail_design_patterns.md:150` - pattern-selection requirement for mandatory guardrails.
- `docs/indexes/by_test_area.md:3` - test reverse-index claim.
- `docs/indexes/by_guardrail.md:3` - guardrail reverse-index claim.
- `docs/indexes/context_coverage.md:3` - context coverage summary claim.

## Observed Architecture Facts
- Pattern observed: documentation has a source layer (`architecture/`, `contracts/`, `verification/`, `donors/`), execution layer (`implementation/` phase files), machine-readable layer (`_registry/`), generated/context layer, diagram layer, and reverse-index layer (`docs/README.md:11`).
- Pattern observed: sections registry owns the cross-document metadata that context capsules repeat into section files (`docs/_registry/sections.yaml:2`, `docs/tool/generate_context_capsules.dart:121`).
- Pattern observed: `check_docs.dart` is intentionally structural and excludes semantic contract checking from free-form Markdown (`docs/tool/check_docs.dart:1`).
- Pattern observed: diagram catalog membership and section-registry diagram references are checked bidirectionally (`docs/tool/check_docs.dart:477`).
- Pattern observed: phase read-first section ids and phase diagram references are checked, while phase test/guardrail lists are not validated by `check_docs.dart` beyond Markdown path and section-id scans (`docs/tool/check_docs.dart:543`, `docs/tool/check_docs.dart:662`, `docs/tool/check_docs.dart:276`, `docs/tool/check_docs.dart:277`).
- Pattern observed: `docs/indexes/*` files are human-readable reverse lookups, but current tools only scan them for paths and section ids (`docs/tool/check_docs.dart:65`, `docs/tool/check_docs.dart:596`).
- Pattern observed: current context-capsule generation detects drift that the structural docs checker does not detect (`docs/tool/generate_context_capsules.dart:189`, `docs/tool/check_docs.dart:103`).

## Open Questions
- Whether `docs/indexes/*` should remain checked-in static Markdown, become generated Markdown, or be replaced by a query command is a documentation product decision not made in this research note.
- Whether donor Markdown should remain editorial evidence, become generated summaries from `docs/_registry/donors.yaml`, or be consolidated into the registry depends on the intended human review workflow for donor decisions.
- Whether test and guardrail inventories should be normalized into separate machine-readable registries or generated from existing verification docs depends on which artifact the project wants to treat as the single owner for proof inventory.
