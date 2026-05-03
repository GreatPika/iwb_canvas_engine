# Change Contract: Documentation Architecture Reorganization

## 1. Change Mandate

Create a durable documentation architecture for `iwb_canvas_engine_next` where future agents can distinguish system architecture, subsystem contracts, verification assets, and transition planning without rereading the whole split implementation folder.

## 2. Change Boundary

### Included in the Change

- Reorganize `docs/split/implementation/` into role-based documentation areas.
- Add a compact architecture entrypoint that remains useful after implementation is complete.
- Add a machine-readable architecture manifest that can drive generated diagrams and dependency checks.
- Update split-documentation registries and indexes so moved documents are not orphaned.
- Replace old split entrypoints and source buckets instead of keeping duplicate old files.
- Delete superseded source documents after their content has a verified role-based home.

### Not Included in the Change

- No production Dart implementation changes.
- No legacy package changes.
- No public API, schema, runtime, or behavior changes.
- No archival duplicate of moved split documents.
- No retirement README for the old `implementation/` bucket.

## 3. Surrounding Code Review

### Inspected Artifacts

- `docs/split/README.md` — states the current outdated model: the split directory is a working navigation layer, canonical truth remains in two large `docs/` files, and `implementation/` contains one file per top-level implementation-plan section.
- `docs/iwb_canvas_engine_next_full_implementation_plan_v2.md` — current old canonical source for implementation-plan content that must be superseded by role-based split documents.
- `docs/iwb_canvas_engine_next_donor_inventory.md` — current old canonical source for donor content that must be superseded by split donor documentation and registries.
- `docs/split/implementation/*.md` — contains 29 mixed files: architecture decisions, subsystem contracts, tests, benchmarks, release gates, donor/oracle context, and draft-change history.
- `docs/split/_registry/sections.yaml` — records section ids, current file paths, phases, must-read edges, diagrams, guardrails, and tests.
- `docs/split/_registry/diagrams.yaml` — records planned Mermaid diagram ids, kinds, planned output paths, related sections, and phases.
- `docs/split/indexes/by_subsystem.md` — already groups current implementation sections by subsystem, but does not distinguish architecture from contracts or verification.
- `docs/split/diagrams/README.md` — is the existing human-readable catalog for required Mermaid deliverables.
- `docs/split/donors/*.md` and `docs/split/_registry/donors.yaml` — establish the existing pattern that human split files feed machine-readable registries and phase indexes.
- Root `AGENTS.md` — requires new-engine docs to live under `next/iwb_canvas_engine_next/docs/`, names the two current transition source documents, and requires user-facing chat in Russian while durable documentation remains English.

### Current Entry Path

- A future architecture task currently starts at `docs/split/README.md`, then usually enters `docs/split/implementation/`, `docs/split/indexes/by_subsystem.md`, or `docs/split/indexes/by_phase.md`.

### Current Owner

- `next/iwb_canvas_engine_next/docs/split/` owns the split documentation navigation layer.
- `docs/split/_registry/sections.yaml` owns machine-readable section-to-file relationships for current split implementation sections.
- `docs/split/_registry/diagrams.yaml` owns the current machine-readable diagram catalog.

### Adjacent Abstractions

- `docs/split/donors/` separates donor documentation from implementation sections.
- `docs/split/indexes/` separates read paths from source sections.
- `docs/split/_registry/` separates machine-readable coverage records from prose.
- `docs/split/diagrams/` separates diagram catalog prose from implementation section prose.

### Existing Tests

- No executable test or tool was found that validates the `docs/split` folder roles, the section registry file paths, or diagram freshness.
- Existing registry files provide data for a narrow link-consistency check, but they do not currently validate that recorded paths exist after a move.

### Analogous Implementation Path

- `docs/split/donors/` plus `docs/split/_registry/donors.yaml` is the closest valid precedent: prose documents are grouped by role, and a registry owns machine-readable relationships used by indexes.
- `docs/split/diagrams/README.md` plus `docs/split/_registry/diagrams.yaml` is the closest valid precedent for generated or checkable visual architecture assets.

### Governing Repository Rules

- Root `AGENTS.md` requires all new-engine documentation artifacts to live under `next/iwb_canvas_engine_next/docs/`.
- Root `AGENTS.md` forbids placing new engine implementation files in the repository root.
- Root `AGENTS.md` says durable project documentation is written in English unless explicitly requested otherwise.
- Root `AGENTS.md` prefers mechanically enforced repository-local rules over prose-only guidance when recurring confusion reveals a stable constraint.
- Root `AGENTS.md` says repository-specific knowledge that changes future implementation, testing, debugging, operation, or understanding must be updated in the repository source of truth.

### Rejected Misleading Local Patterns

- Keeping all target-system material under `docs/split/implementation/` — wrong owner because implementation phases, architecture, contracts, verification, and history are different documentation roles.
- Moving every architecture-relevant document into `architecture/` — wrong level because subsystem contracts are normative but too detailed for the architecture entrypoint.
- Treating `docs/split/indexes/by_subsystem.md` as the architecture map — wrong seam because it is a navigation index over current sections, not a durable source of truth for owners, boundaries, and dependency rules.
- Hand-maintaining Mermaid diagrams as the only architecture source — wrong seam because diagrams should be generated from or checked against machine-readable architecture data.

## 4. Architecture

### 4A. Locked Architectural Form

#### Problem Ownership Level

- This is a documentation architecture and documentation-navigation change inside the next package documentation layer.

#### Selected Architectural Form

- Split `docs/split/implementation/` into four role-based areas:
  - `docs/split/architecture/` for compact target-system architecture and read paths.
  - `docs/split/contracts/` for subsystem-level normative behavior and invariants.
  - `docs/split/verification/` for proof plans, tests, benchmarks, guardrails, and release gates.
  - `docs/split/planning/` for transition planning, legacy oracle context, and change-history material.
- Keep repository-root `plan/` for workspace-level Change Contracts. It is not a target architecture, contract, verification, or planning source folder.
- Add `docs/split/architecture/architecture.yaml` as the machine-readable source for runtime owners, allowed dependencies, forbidden dependencies, package boundaries, external actors, and diagram generation inputs.
- Keep `_registry/` as the machine-readable coverage layer, but update it so section records point to the new role-based paths.
- Keep `indexes/` as generated or maintained navigation, but update it to point readers to role-based documents instead of the old implementation bucket.
- Replace `docs/split/README.md` with a new role-based entrypoint; do not preserve the current README text.
- Delete `docs/split/implementation/` after all section files have moved and registries no longer reference it.
- Delete `docs/iwb_canvas_engine_next_full_implementation_plan_v2.md` and `docs/iwb_canvas_engine_next_donor_inventory.md` after their content is represented by role-based split documents, donor documents, registries, and indexes.
- Update root `AGENTS.md` in the same slice that deletes the old transition source documents, so repository guidance names the new role-based source of truth.

#### Owning Layer or Module

- `next/iwb_canvas_engine_next/docs/split/` owns this change.
- `docs/split/architecture/README.md` becomes the first architecture entrypoint.
- `docs/split/architecture/architecture.yaml` becomes the machine-readable architecture source for diagram and dependency checks.

#### Dependency Direction

- `architecture/` may point to `contracts/`, `verification/`, `diagrams/`, `indexes/`, and `_registry/`.
- `contracts/` may depend on `architecture/` decisions and may point to `verification/`.
- `verification/` may depend on `architecture/` and `contracts/`.
- `planning/` may reference all areas as historical or execution context.
- `architecture/` must not require reading `planning/` to understand the current target architecture.

#### State and Data Ownership

- Architecture ownership data lives in `architecture/architecture.yaml`.
- Human architecture explanations live in `architecture/*.md`.
- Subsystem behavior obligations live in `contracts/*.md`.
- Test, guardrail, benchmark, diagram-presence, and release-gate obligations live in `verification/*.md`.
- Transition sequencing and historical correction notes live in `planning/*.md`.
- Section ids, file paths, related phases, related diagrams, guardrails, and tests remain in `_registry/sections.yaml`.

#### Entry and Exit Boundaries

- Entry boundary for architecture work: `docs/split/architecture/README.md`.
- Entry boundary for subsystem work: `docs/split/architecture/README.md` routes to the relevant contract files.
- Exit boundary for documentation moves: all moved files are reachable from `_registry/sections.yaml`, at least one index, and the architecture README when relevant.
- Exit boundary for machine checks: registry/index navigation validation catches stale documentation paths, and diagram validation catches stale generated diagrams once diagram generation exists.

#### Permitted Extension Seam

- Add new owners, boundaries, diagrams, or contracts by changing `architecture/architecture.yaml` and the matching role-based markdown document in the same slice.
- Add new verification obligations by updating `verification/guardrails.md` or the relevant verification document and `_registry/sections.yaml`.

#### Rejected Alternatives

- Flat `implementation/` with better names — rejected because role confusion remains.
- One large `architecture.md` — rejected because subsystem-level contracts would either bloat the entrypoint or remain disconnected.
- Diagrams as hand-written source of truth — rejected because machine-generated or machine-checked diagrams are needed to detect drift.
- Keeping old canonical files after creating role-based split docs — rejected because duplicate documentation sources create drift and force future agents to guess which source wins.

#### Why This Level Is Correct

- The defect is not in one document's prose. It is a navigation and ownership problem across the documentation layer.
- The existing registry/index pattern already supports role-based grouping and machine-readable coverage.
- Future architecture correctness must be checked at the level of ownership, boundaries, dependencies, and proof mapping, not by relying on file names.

## 5. Locked Decisions

1. The current `implementation/` folder is not the final documentation owner for architecture or contracts.
2. `architecture/` stays compact and describes system-level target architecture, not every subsystem behavior.
3. Subsystem-level normative behavior moves to `contracts/`.
4. Tests, benchmarks, guardrails, and release gates move to `verification/`.
5. Legacy oracle, implementation phases, and previous-draft change notes live in `planning/`.
6. Change contracts for this documentation reorganization live in `plan/`.
7. `architecture.yaml` is required before generated diagrams or dependency checks are treated as authoritative.
8. Current section ids remain stable during the move.
9. Original section content is moved to its new role-based owner; the old source file is deleted after verification.
10. `_registry/sections.yaml` must be updated in the same slice as any file move.
11. `docs/split/README.md` must be replaced with a new role-based entrypoint.
12. The old full implementation plan and old donor inventory are deleted after split role documents and donor registries cover their content.

## 6. Result Requirements

1. A future agent can start at `docs/split/architecture/README.md` and understand the target system shape, ownership model, package boundaries, and read path without opening all contract files.
2. A future agent can identify the correct subsystem contract from the architecture README.
3. The architecture data needed for diagrams and dependency checks is represented in a machine-readable manifest.
4. Every moved section remains reachable by section id, human index, and registry path.
5. Verification documents clearly describe how architecture and contracts are proven.
6. Planning documents no longer appear to be target architecture.
7. The old `implementation/` bucket is absent after migration.
8. The old large canonical source documents are absent after migration.

## 7. Execution Order and Gates

### Required Order

- Create the target documentation folders and architecture README skeleton before moving sections.
- Add `architecture/architecture.yaml` before generating or checking diagrams from it.
- Move architecture-level documents before subsystem contracts so the new entrypoint has stable targets.
- Move contracts before verification documents so verification can link to stable contract paths.
- Move planning/history documents last.
- Update `_registry/sections.yaml` in the same slice as file moves.
- Update `docs/split/README.md` only after all role folders exist.
- Add the registry/index navigation check before moving registered files.

### Successor Seam and Deletion Gates

- Successor seam for architecture entry: `docs/split/architecture/README.md`.
- Successor seam for machine-readable architecture: `docs/split/architecture/architecture.yaml`.
- Deletion gate for `docs/split/implementation/`: no section registry file path points to `docs/split/implementation/`, no split index links to files under `implementation/`, and the `docs/split/implementation/` directory does not exist.
- Deletion gate for old canonical source files: `docs/iwb_canvas_engine_next_full_implementation_plan_v2.md` and `docs/iwb_canvas_engine_next_donor_inventory.md` do not exist, and `docs/split/README.md` names role-based split docs as the documentation source of truth.
- Replacement gate for hand-only diagrams: required architecture diagrams can be generated from, or checked against, `architecture.yaml`.

### Deferred Broad Verification

- Full documentation navigation check is deferred until all moves are complete.
- Full generated-diagram freshness check is deferred until diagram generation exists.
- Full code dependency enforcement is deferred until next package implementation files exist for the owners named in `architecture.yaml`.

## 8. File Map

### Implementation Files

- `docs/split/architecture/README.md`
- `docs/split/architecture/00_architecture_overview.md`
- `docs/split/architecture/01_runtime_ownership.md`
- `docs/split/architecture/02_package_boundaries.md`
- `docs/split/architecture/03_data_model.md`
- `docs/split/architecture/04_decisions_and_differences.md`
- `docs/split/architecture/diagrams.md`
- `docs/split/architecture/architecture.yaml`
- `docs/split/contracts/public_api_v1.md`
- `docs/split/contracts/schema_v1.md`
- `docs/split/contracts/validation_limits.md`
- `docs/split/contracts/resources.md`
- `docs/split/contracts/edit_kernel.md`
- `docs/split/contracts/load_document.md`
- `docs/split/contracts/operation_matrix.md`
- `docs/split/contracts/interaction_engine.md`
- `docs/split/contracts/frame_rendering.md`
- `docs/split/contracts/geometry.md`
- `docs/split/contracts/spatial_kernel.md`
- `docs/split/contracts/cache_policy.md`
- `docs/split/contracts/codec_boundary.md`
- `docs/split/contracts/diagnostics.md`
- `docs/split/contracts/migration_tool.md`
- `docs/split/verification/functional_ledger.md`
- `docs/split/verification/guardrails.md`
- `docs/split/verification/tests.md`
- `docs/split/verification/benchmarks.md`
- `docs/split/verification/release_gates.md`
- `docs/split/planning/legacy_oracle.md`
- `docs/split/planning/implementation_phases.md`
- `docs/split/planning/changes_from_previous_draft.md`
- `docs/split/donors/00_reuse_rules.md`
- `docs/split/donors/01_summary_by_decision.md`
- `docs/split/donors/02_geometry_hit_test_eraser.md`
- `docs/split/donors/03_spatial_frame_render_cache.md`
- `docs/split/donors/04_dto_model_validation_structure.md`
- `docs/split/donors/05_codec_migration.md`
- `docs/split/donors/06_interaction_edit_event_staged_load.md`
- `docs/split/donors/07_donors_to_avoid.md`
- `docs/split/donors/08_p1_closure_requirements.md`
- `plan/01_documentation_architecture_reorganization_contract.md`
- `docs/split/README.md`
- `docs/iwb_canvas_engine_next_full_implementation_plan_v2.md`
- `docs/iwb_canvas_engine_next_donor_inventory.md`
- `AGENTS.md`
- `docs/split/diagrams/generated/c4_context.mmd`
- `docs/split/diagrams/generated/c4_container.mmd`
- `docs/split/diagrams/generated/c4_component_runtime.mmd`

### Test Files

- `none`

### Tool Files

- `docs/split/tool/check_split_navigation.dart`
- `docs/split/tool/check_split_source_coverage.dart`
- `docs/split/tool/generate_architecture_diagrams.dart`

### Fixtures and Supporting Data

- `docs/split/architecture/architecture.yaml`
- `docs/split/_registry/sections.yaml`
- `docs/split/_registry/diagrams.yaml`

### Registry, Inventory, and Workflow Files

- `docs/split/_registry/sections.yaml`
- `docs/split/_registry/diagrams.yaml`
- `docs/split/_registry/donors.yaml`
- `docs/split/_registry/phases.yaml`
- `docs/split/_registry/tests.yaml`
- `docs/split/_registry/guardrails.yaml`
- `docs/split/indexes/by_subsystem.md`
- `docs/split/indexes/by_phase.md`
- `docs/split/indexes/by_guardrail.md`
- `docs/split/indexes/by_test_area.md`
- `docs/split/indexes/diagram_to_phase.md`
- `docs/split/indexes/context_coverage.md`
- `docs/split/indexes/donor_to_phase.md`
- `docs/split/indexes/phase_to_donor.md`

### Analysis Area

- `docs/split/implementation/*.md`
- `docs/split/diagrams/README.md`
- `docs/iwb_canvas_engine_next_full_implementation_plan_v2.md`
- `docs/iwb_canvas_engine_next_donor_inventory.md`
- `AGENTS.md`
- `docs/split/_registry/*.yaml`
- `docs/split/indexes/*.md`

## 9. Implementation Rules

### Protected Invariants

- Section ids remain stable.
- Moved documents preserve the source content needed by the target role.
- Superseded source files are deleted after the target role documents and registries validate.
- Architecture docs do not require planning docs to explain current target architecture.
- Contracts do not redefine system ownership that belongs in architecture docs.
- Verification docs point back to the architecture or contract they prove.
- Machine-readable registry paths match actual files.
- The architecture manifest names owners and dependencies in a form that can be checked mechanically.

### Required Proof

- All `dart run docs/split/tool/...` commands run from `next/iwb_canvas_engine_next/`.
- navigation proof: `dart run docs/split/tool/check_split_navigation.dart` is both behavioral and structural proof for documentation navigation; it validates that documented read paths route each role to the expected folder and that paths recorded in split registries and indexes resolve to existing files.
- source coverage proof: `dart run docs/split/tool/check_split_source_coverage.dart` validates that the old large source documents are fully represented by the role-based split documents, donor split documents, registries, and indexes before those old source files are deleted.
- diagram proof: `dart run docs/split/tool/generate_architecture_diagrams.dart --check` validates generated Mermaid output against `docs/split/architecture/architecture.yaml`.
- for bug fixes, regressions, false positives, false negatives, and invariant-enforcement gaps: one failing reproducer first, plus 1 to 3 guard tests for neighboring branches of the same contract.
- for refactors: existing locking tests must be named or missing characterization tests must be added before structural edits, plus 1 to 3 guard tests for neighboring branches when needed.

### Allowed Change Surface

- Documentation files under `next/iwb_canvas_engine_next/docs/split/`.
- Repository-local documentation validation tools under the next package when needed.
- Registry and index files that refer to moved split documentation.
- Creation or update of exactly these generated Mermaid diagram files under `next/iwb_canvas_engine_next/docs/split/diagrams/generated/`:
  - `c4_context.mmd`
  - `c4_container.mmd`
  - `c4_component_runtime.mmd`
- Deletion of `next/iwb_canvas_engine_next/docs/iwb_canvas_engine_next_full_implementation_plan_v2.md`.
- Deletion of `next/iwb_canvas_engine_next/docs/iwb_canvas_engine_next_donor_inventory.md`.
- Update of root `AGENTS.md` only to replace references to the old transition source documents with the new role-based split documentation source of truth.

### Forbidden Moves

- Do not move new-engine documentation to the repository root.
- Do not modify legacy source or legacy documentation for this change.
- Do not change public API, schema, or runtime behavior while reorganizing docs.
- Do not keep duplicate source-of-truth documents after replacement.
- Do not leave moved files unregistered.
- Do not make diagrams the only architecture source of truth.

### Optional: Recognition Forms That Must Be Supported

- Architecture owner definitions in YAML.
- Allowed and forbidden dependencies in YAML.
- Diagram ids linked to owner, boundary, or flow definitions.
- Section ids linked to new role-based document paths.

### Optional: Allowed Forms That Are Not Violations

- Keeping original section numbers in moved document headers when they remain useful for traceability.
- Keeping historical context only when it is itself the target content of a `planning/` document, not as a duplicate of a moved source file.

### Optional: Resolution Rules

- If architecture prose and `architecture.yaml` disagree, `architecture.yaml` is the structural source for diagrams and dependency checks, while prose must be corrected in the same slice.
- If a contract and architecture prose disagree about owner boundaries, architecture owns the boundary and the contract must be corrected or escalated.
- If verification documents list a guardrail that is not in `_registry/guardrails.yaml`, the registry must be updated or the guardrail removed.

## 10. Vertical Slices

### Slice 1. [ ] Establish Documentation Architecture Entry

#### Slice Contract

Create the new role folders, add `architecture/README.md`, add `architecture/architecture.yaml`, and add the narrow registry/index navigation check before moving registered files.

#### Change

- Create `architecture/`, `contracts/`, `verification/`, and `planning/`; keep repository-root `plan/` for Change Contracts.
- Add the architecture README with read order, role definitions, and subsystem routing.
- Add an initial architecture manifest with external actors, runtime owners, package boundaries, allowed dependencies, forbidden dependencies, and diagram generation targets.
- Add `docs/split/tool/check_split_navigation.dart`.

#### Verification

- Run `test -f docs/split/architecture/README.md`.
- Run `test -f docs/split/architecture/architecture.yaml`.
- Run `dart run docs/split/tool/check_split_navigation.dart`.
- The navigation command must validate the architecture README role routing for `architecture/`, `contracts/`, `verification/`, `planning/`, repository-root `plan/`, and `donors/`.

#### Fixtures Used

- `docs/split/_registry/sections.yaml`
- `docs/split/_registry/diagrams.yaml`
- `docs/split/tool/check_split_navigation.dart`

#### Positive Scenarios

- Public API work routes to `contracts/public_api_v1.md`.
- Render work routes to `contracts/frame_rendering.md`, `contracts/cache_policy.md`, and `verification/tests.md`.
- Architecture ownership work routes to `architecture/architecture.yaml`.

#### Negative Scenarios

- A reader is not sent to `planning/implementation_phases.md` to understand current runtime ownership.
- A reader is not told to scan every file in `implementation/`.

#### Closure Evidence

- Required role folders exist.
- Architecture README and manifest exist.
- `docs/split/tool/check_split_navigation.dart` exists before Slice 2 begins.

### Slice 2. [ ] Move Architecture Sections

#### Slice Contract

Move compact system-level target architecture documents out of `implementation/` and update registries and indexes in the same slice.

#### Change

- Move `00_status_and_scope.md` to `architecture/00_architecture_overview.md`.
- Move `02_architecture_model.md` to `architecture/01_runtime_ownership.md`.
- Move `03_package_layout.md` to `architecture/02_package_boundaries.md`.
- Move `10_runtime_data_model.md` to `architecture/03_data_model.md`.
- Move `09_accepted_differences.md` to `architecture/04_decisions_and_differences.md`.
- Move `21_diagrams.md` to `architecture/diagrams.md`.
- Update `_registry/sections.yaml` and affected indexes.

#### Verification

- Run `dart run docs/split/tool/check_split_navigation.dart`.
- Run `test -f docs/split/architecture/00_architecture_overview.md`.
- Run `test -f docs/split/architecture/01_runtime_ownership.md`.
- The navigation command must validate that architecture section ids resolve to architecture files and that the architecture read path reaches only architecture-level documents before routing to contracts.

#### Fixtures Used

- `docs/split/_registry/sections.yaml`
- `docs/split/indexes/by_subsystem.md`
- `docs/split/indexes/context_coverage.md`

#### Positive Scenarios

- `section_02_architecture_model` resolves to `architecture/01_runtime_ownership.md`.
- `section_21_diagrams` resolves to `architecture/diagrams.md`.

#### Negative Scenarios

- No architecture section registry path points to `implementation/`.
- No architecture README link points to the retired implementation bucket.

#### Closure Evidence

- Registry and index paths resolve.
- Architecture folder is sufficient for high-level architecture orientation.

### Slice 3. [ ] Move Subsystem Contracts

#### Slice Contract

Move subsystem-level normative behavior from `implementation/` to `contracts/` while preserving section ids and original bodies.

#### Change

- Move API, schema, validation, resource, edit, load, operation, interaction, frame, geometry, spatial, cache, codec, diagnostics, and migration-tool contract sections to `contracts/`.
- Update `_registry/sections.yaml`, subsystem index, guardrail index, and test-area index.

#### Verification

- Run `dart run docs/split/tool/check_split_navigation.dart`.
- Run `test -f docs/split/contracts/edit_kernel.md`.
- Run `test -f docs/split/contracts/frame_rendering.md`.
- The navigation command must validate that subsystem routing entries resolve to contract files and that contract files are reachable from `_registry/sections.yaml` and `indexes/by_subsystem.md`.

#### Fixtures Used

- `docs/split/_registry/sections.yaml`
- `docs/split/indexes/by_subsystem.md`
- `docs/split/indexes/by_guardrail.md`
- `docs/split/indexes/by_test_area.md`

#### Positive Scenarios

- `section_11_edit_kernel` resolves to `contracts/edit_kernel.md`.
- `section_15_frame_render_contract` resolves to `contracts/frame_rendering.md`.
- `section_19_codec_boundary` resolves to `contracts/codec_boundary.md`.

#### Negative Scenarios

- Contract files do not live under `architecture/`.
- Contract files do not depend on planning files for current behavior.

#### Closure Evidence

- All contract registry paths resolve.
- Subsystem index points to contract files or stable section ids with new paths.

### Slice 4. [ ] Move Verification And Planning Sections

#### Slice Contract

Move proof and planning documents into their final role folders, replace the split README, and delete the old `implementation/` bucket.

#### Change

- Move `08_functional_ledger.md`, `22_guardrails_machine_checks.md`, `23_tests.md`, `24_benchmarks.md`, and `27_final_release_gates.md` to `verification/`.
- Move `01_legacy_oracle.md`, `26_implementation_phases.md`, and `28_changes_from_previous_draft.md` to `planning/`.
- Replace `docs/split/README.md` with a new role-based entrypoint.
- Update `_registry/sections.yaml`, phase indexes, guardrail indexes, test-area indexes, and `docs/split/README.md`.
- Delete `docs/split/implementation/`.
- Keep this change contract in `plan/01_documentation_architecture_reorganization_contract.md`.

#### Verification

- Run `dart run docs/split/tool/check_split_navigation.dart`.
- Run `test ! -d docs/split/implementation`.
- Run `rg -n "docs/split/implementation" docs/split/_registry docs/split/indexes`; no matches are allowed.
- The navigation command must validate that verification and planning documents are reachable from their relevant indexes and no active registry/index path points to `implementation/`.

#### Fixtures Used

- `docs/split/_registry/sections.yaml`
- `docs/split/indexes/by_phase.md`
- `docs/split/indexes/by_guardrail.md`
- `docs/split/indexes/by_test_area.md`
- `docs/split/indexes/diagram_to_phase.md`

#### Positive Scenarios

- Release readiness routes to `verification/release_gates.md`.
- Historical draft changes route to `planning/changes_from_previous_draft.md`.

#### Negative Scenarios

- A future architecture task does not start from `planning/legacy_oracle.md`.
- No registry or index path depends on the old implementation bucket.

#### Closure Evidence

- `docs/split/README.md` documents the new role-based layout.
- `docs/split/implementation/` does not exist.

### Slice 5. [ ] Delete Superseded Canonical Source Documents

#### Slice Contract

Delete the old large canonical source documents after the role-based split documents and donor split documents are verified as the documentation source of truth.

#### Change

- Delete `docs/iwb_canvas_engine_next_full_implementation_plan_v2.md`.
- Delete `docs/iwb_canvas_engine_next_donor_inventory.md`.
- Update `docs/split/README.md` so it does not describe those files as canonical.
- Update any registry or index reference that still points to those files as source-of-truth input.
- Update root `AGENTS.md` so the "current transition source documents" section points to `docs/split/architecture/README.md`, `docs/split/contracts/`, `docs/split/verification/`, `docs/split/planning/`, and `docs/split/donors/` instead of the deleted files.
- Update `docs/split/donors/*.md` headers so `Source` and `Canonical original` no longer point to `docs/iwb_canvas_engine_next_donor_inventory.md`; they must point to split donor ids and `_registry/donors.yaml`.
- Add `docs/split/tool/check_split_source_coverage.dart`.
- Run the source coverage tool before deleting the two old large source documents; deletion is blocked unless it passes.

#### Verification

- Run `dart run docs/split/tool/check_split_source_coverage.dart`.
- Run `dart run docs/split/tool/check_split_navigation.dart`.
- Run `test ! -f docs/iwb_canvas_engine_next_full_implementation_plan_v2.md`.
- Run `test ! -f docs/iwb_canvas_engine_next_donor_inventory.md`.
- Run `rg -n "iwb_canvas_engine_next_full_implementation_plan_v2|iwb_canvas_engine_next_donor_inventory" AGENTS.md docs/split/donors docs/split/README.md docs/split/_registry docs/split/indexes`; no matches are allowed.

#### Fixtures Used

- `docs/split/README.md`
- `docs/split/_registry/sections.yaml`
- `docs/split/_registry/donors.yaml`
- `docs/split/indexes/context_coverage.md`
- `docs/split/donors/*.md`
- `AGENTS.md`
- `docs/split/tool/check_split_navigation.dart`
- `docs/split/tool/check_split_source_coverage.dart`

#### Positive Scenarios

- Architecture source-of-truth routing resolves to `architecture/`, `contracts/`, `verification/`, `planning/`, and `donors/`.
- Donor routing resolves to `docs/split/donors/` and `_registry/donors.yaml`.

#### Negative Scenarios

- No active documentation entrypoint says the old large files are canonical.
- No active registry path requires the deleted old large files.

#### Closure Evidence

- The two old large source files are absent.
- The split README, donor headers, `AGENTS.md`, registries, and indexes no longer reference the deleted files.
- Source coverage passes before deletion and remains documented as the deletion gate evidence.

### Slice 6. [ ] Generate And Check Architecture Diagrams

#### Slice Contract

Make architecture diagrams machine-generatable from `architecture.yaml`.

#### Change

- Add `docs/split/tool/generate_architecture_diagrams.dart`.
- The generator reads `docs/split/architecture/architecture.yaml`.
- The generator writes exactly these Mermaid files under `docs/split/diagrams/generated/`: `c4_context.mmd`, `c4_container.mmd`, and `c4_component_runtime.mmd`.
- `generate_architecture_diagrams.dart --check` regenerates the expected Mermaid content in memory and fails if any on-disk `docs/split/diagrams/generated/*.mmd` output differs or is missing.
- Update `_registry/diagrams.yaml` so diagram ids map to architecture manifest entries where applicable.

#### Verification

- Run `dart run docs/split/tool/generate_architecture_diagrams.dart --check`.
- Run `dart run docs/split/tool/check_split_navigation.dart`.
- Run `test -f docs/split/diagrams/generated/c4_context.mmd`.
- Run `test -f docs/split/diagrams/generated/c4_container.mmd`.
- Run `test -f docs/split/diagrams/generated/c4_component_runtime.mmd`.

#### Fixtures Used

- `docs/split/architecture/architecture.yaml`
- `docs/split/_registry/diagrams.yaml`
- `docs/split/diagrams/generated/c4_context.mmd`
- `docs/split/diagrams/generated/c4_container.mmd`
- `docs/split/diagrams/generated/c4_component_runtime.mmd`

#### Positive Scenarios

- `RuntimeRoot` diagram includes all runtime owners from `architecture.yaml`.
- `EditKernel` dependencies match allowed dependencies from `architecture.yaml`.

#### Negative Scenarios

- A diagram missing a manifest owner fails validation.
- A diagram showing a forbidden dependency fails validation or generation diff.

#### Closure Evidence

- Generated or validated Mermaid diagrams exist.
- Diagram check command is documented in `docs/split/architecture/README.md` or `docs/split/README.md`.

### Slice 7. [ ] Complete Structural Guardrails For Documentation Architecture

#### Slice Contract

Complete the persistent link and diagram checks that protect long-lived documentation navigation.

#### Change

- Keep `docs/split/tool/check_split_navigation.dart` narrow: it validates registry/index paths, required entrypoint files, and documented role-routing targets.
- Keep `docs/split/tool/generate_architecture_diagrams.dart` focused on generating and checking Mermaid files from `architecture.yaml`.
- Document both commands in `docs/split/README.md`.

#### Verification

- Run `dart run docs/split/tool/check_split_navigation.dart`.
- Run `dart run docs/split/tool/check_split_source_coverage.dart`.
- Run `dart run docs/split/tool/generate_architecture_diagrams.dart --check`.

#### Fixtures Used

- `docs/split/architecture/architecture.yaml`
- `docs/split/_registry/sections.yaml`
- `docs/split/_registry/diagrams.yaml`

#### Positive Scenarios

- Required entrypoint files pass.
- All registry file paths resolve.

#### Negative Scenarios

- A missing `architecture/README.md` fails.
- A section registry path pointing to a missing file fails.
- A registry or index path pointing to a missing file fails.

#### Closure Evidence

- Check command passes in the repository.
- README names the command and what it proves.

## 11. Final Verification

- Run `dart run docs/split/tool/check_split_navigation.dart`.
- Run `dart run docs/split/tool/check_split_source_coverage.dart`.
- Run `dart run docs/split/tool/generate_architecture_diagrams.dart --check`.
- Run `test ! -d docs/split/implementation`.
- Run `test ! -f docs/iwb_canvas_engine_next_full_implementation_plan_v2.md`.
- Run `test ! -f docs/iwb_canvas_engine_next_donor_inventory.md`.
- Run `rg -n "canonical truth remains|docs/split/implementation|iwb_canvas_engine_next_full_implementation_plan_v2|iwb_canvas_engine_next_donor_inventory" docs/split`; no matches are allowed outside this change contract or explicit deletion-check fixtures.
- Run `rg -n "iwb_canvas_engine_next_full_implementation_plan_v2|iwb_canvas_engine_next_donor_inventory" ../../AGENTS.md docs/split/donors`; no matches are allowed outside this change contract or explicit deletion-check fixtures.
- Run `rg --files docs/split`; role-based paths must exist.

## 12. Acceptance Criteria

- `docs/split/architecture/README.md` is the documented first stop for architecture work.
- `docs/split/architecture/architecture.yaml` exists and names the target architecture owners, boundaries, and allowed dependencies.
- Architecture-level documents are compact and do not include subsystem implementation contracts.
- Subsystem contracts live under `docs/split/contracts/`.
- Proof and release-readiness documents live under `docs/split/verification/`.
- Legacy oracle, implementation phases, and previous-draft changes live under `docs/split/planning/`.
- Change contracts for this reorganization live under repository-root `plan/`.
- `_registry/sections.yaml` paths match actual files.
- Required split indexes point to the new role-based document locations.
- `docs/split/tool/check_split_navigation.dart` exists and passes.
- `docs/split/tool/check_split_source_coverage.dart` exists and passes as the deletion-gate evidence for the old source documents.
- `docs/split/tool/generate_architecture_diagrams.dart` exists and passes the final diagram check command.
- The old `implementation/` folder does not exist.
- The old large canonical source documents do not exist.
