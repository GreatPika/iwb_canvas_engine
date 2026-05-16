# Change Contract

If `4B. Architecture Decision Gate` is filled, stop after section 4.

## 1. Change Mandate

Deliver P0 by creating the repository-root package skeleton, public API barrel, `RuntimeRoot` skeleton, hard-boundary guardrails, guardrail runner, and root CI target before any runtime behavior, donor code, codec, or Flutter surface implementation lands.

## 2. Change Boundary

### Included in the Change

- Populate the repository-root package skeleton required by `docs/architecture/02_package_boundaries.md`.
- Create `lib/iwb_canvas_engine.dart` as the only public package barrel and export only `lib/src/api/**`.
- Add the P0 public API skeleton under `lib/src/api/**` so the public names
  listed in `docs/_registry/public_api_v1.yaml` have declarations in API-owned
  files.
- Add one production `RuntimeRoot` skeleton under `lib/src/runtime/runtime_root.dart`.
- Add machine-enforced hard-boundary guardrails for P0:
  - `api.no_legacy_public_types`
  - `api.public_exports_complete`
  - `api.public_types_complete`
  - `core.no_legacy_imports`
  - `core.import_boundaries`
  - `core.no_unapproved_part_files`
  - `core.no_scene_controller_shape_dependency`
  - `core.no_node_spec_patch_shape_dependency`
  - `core.single_runtime_root`
  - `diagrams.all_required_present`
- Add the minimal `dart run tool/guardrails/run.dart` entrypoint with no-argument full run, `--suite=<name>`, `--guardrail=<id>`, and conservative `--changed` routing.
- Add runner metadata for the P0 hard-boundary guardrails.
- Add executable tests for the P0 API, source-boundary, diagram, runner, and CI wiring proofs named in the P0 phase file.
- Add a root-package CI workflow target.

### Not Included in the Change

- Public API freeze beyond skeleton declarations.
- Functional legacy oracle capture.
- Legacy facade, legacy public API compatibility, or app adapter implementation.
- Runtime behavior beyond an empty `RuntimeRoot` composition owner.
- Store, edit, frame, interaction, resource, spatial, geometry, codec, diagnostics, or Flutter bridge behavior.
- Donor code copying or donor structure adoption.
- Schema v1 encode/decode behavior.
- Benchmark implementation.

## 3. Surrounding Code Review

### Inspected Artifacts

- `docs/implementation/p0_package_skeleton_and_hard_boundaries.md` - defines
  P0 scope, required read-first sections, forbidden donor structures,
  guardrails, tests, exit gate, and the requirement to add the
  `api.public_exports_complete` and `api.public_types_complete` guardrail tests
  first.
- `PLAN.md` - is the active plan index and links each step to a dedicated `plan/step_<number>_<short_snake_case_summary>.md` file.
- `.agents/skills/change-contract/assets/change-contract-template.md` - defines the required Change Contract structure.
- `docs/architecture/00_architecture_overview.md` - locks the new root package as not API-compatible with legacy and forbids legacy facade, legacy runtime fallback, `SceneController`, `SceneSnapshot`, `NodeSpec`, `NodePatch`, `PatchField`, `SceneWriteTxn`, and old schema v7 public entrypoints in the new package.
- `docs/architecture/01_runtime_ownership.md` - defines one `RuntimeRoot` composition owner and the runtime subsystem ownership model.
- `docs/architecture/02_package_boundaries.md` - defines the root package layout, public barrel rule, test ownership layout, guardrail ownership split, and forbidden import matrix.
- `docs/contracts/public_api_v1.md` - defines the human-readable public API v1
  semantic contract and assigns `api.public_exports_complete` and
  `api.public_types_complete` to the public API contract.
- `docs/verification/guardrails.md` - defines the guardrail runner command contract, mandatory selection modes, conservative `--changed` widening, runner metadata source rule, and P0-relevant guardrail meanings.
- `docs/verification/tests.md` - lists required test paths, including P0 guardrail tests.
- `docs/indexes/by_guardrail.md` - maps `api.public_exports_complete`
  and `api.public_types_complete` to `test.guardrails.blocking_suite` and maps
  P0 hard-boundary guardrails to their proof tests.
- `docs/indexes/by_test_area.md` - maps `test.guardrails.required_diagrams_present`, `test.guardrails.blocking_suite`, and `test.guardrails.import_boundaries` to paths and guardrails.
- `docs/diagrams/README.md` - catalogs the required Mermaid files and their planned paths.
- `docs/tool/check_docs.dart` - is a root-owned structural documentation checker and a valid precedent for a thin Dart CLI that reads structured repository sources and exits non-zero on violations.
- `pubspec.yaml` - confirms the repository root is already the `iwb_canvas_engine` Dart/Flutter package.
- `analysis_options.yaml` - excludes `legacy/**`, enforces strict analyzer settings, and configures DCM rules and metrics for root code.
- `dart_test.yaml` - currently contains only a `tool` tag.
- `docs/_registry/**` - contains registry-owned structured inputs, including
  `sections.yaml` and `public_api_v1.yaml`; the public API registry is the
  machine-readable inventory for expected public API names.
- Root `lib/**`, `test/**`, `tool/**`, and `.github/**` - contain no implementation files yet.
- `plan/**` - contains this Step 1 Change Contract as the first active implementation contract.
- `legacy/iwb_canvas_engine/lib/iwb_canvas_engine.dart` - shows the legacy public barrel shape, including exports that P0 must explicitly reject for the new package.
- `legacy/iwb_canvas_engine/tool/goldens/public_api_symbols.txt` - contains the full 77-symbol legacy public API golden list that `api.no_legacy_public_types` must reject from the root package exports.
- `legacy/iwb_canvas_engine/tool/src/import_boundaries/import_boundaries_runner.dart` - shows an analogous Dart structural checker using parsed directives and root-relative path rules.
- `legacy/iwb_canvas_engine/tool/src/guardrails/guardrails_runner.dart` - shows an analogous thin guardrail dispatcher, but not the new runner contract or policy.
- `docs/donors/07_donors_to_avoid.md` - confirms legacy controller facades, whole interactive runtime, legacy scene builder public architecture, whole legacy codec, and whole scene store controller are forbidden as new package structure.

### Current Entry Path

- Package consumers will enter through `package:iwb_canvas_engine/iwb_canvas_engine.dart`.
- Developers and CI will enter hard-boundary checks through `dart run tool/guardrails/run.dart`.
- Dart tests will enter P0 proofs through `test/api_contract/**` and `test/guardrails/**`.

### Current Owner

- The repository-root package is the owner for the new engine.
- No root `lib/**`, `test/**`, `tool/**`, or `.github/**` implementation exists yet, so P0 creates the first owner files.
- The legacy package under `legacy/iwb_canvas_engine/**` is evidence and oracle material only; it is not the owner of the new package structure.

### Adjacent Abstractions

- `lib/src/api/**` is the public API declaration layer.
- `lib/src/runtime/runtime_root.dart` is the composition-root layer.
- `test/guardrails/**` owns cross-cutting proof integration with Dart test and CI.
- `tool/guardrails/**` owns CLI orchestration, runner metadata, and reusable guardrail check logic.
- `docs/tool/check_docs.dart` is adjacent documentation tooling, but it is not the owner for runtime/package hard-boundary checks.

### Existing Tests

- No root `test/**` implementation files exist.
- `docs/verification/tests.md` and `docs/indexes/by_test_area.md` name the P0 test paths before they exist.
- Legacy tests under `legacy/iwb_canvas_engine/test/**` are excluded from root analysis and are not P0 proof for the new package.

### Analogous Implementation Path

- `docs/tool/check_docs.dart` is the closest root-owned precedent for a single Dart command that reads structured repository sources and reports deterministic pass/fail output.
- `legacy/iwb_canvas_engine/tool/src/import_boundaries/import_boundaries_runner.dart` is the closest structural-check precedent for parsing Dart directives and normalizing root-relative paths.
- `legacy/iwb_canvas_engine/tool/src/guardrails/guardrails_runner.dart` is a useful dispatcher precedent, but P0 must implement the new runner contract from `docs/verification/guardrails.md`.

### Governing Repository Rules

- `AGENTS.md` - communicate in Russian, write documentation in English, update the source of truth when repository-specific knowledge changes, and run `dart analyze`, `dcm analyze .`, and `dcm calculate-metrics .` after code changes.
- `docs/README.md` - implementation starts with phase files under `docs/implementation/`, while root `plan/` stores workspace-level Change Contracts and audit trails.
- `docs/architecture/00_architecture_overview.md` - the new package must not import legacy code, wrap legacy runtime, or preserve the legacy public API shape.
- `docs/architecture/02_package_boundaries.md` - public barrel exports only `src/api/**`; production `lib/**` has no unapproved `part` or `part of`; source imports obey the forbidden import matrix.
- `docs/verification/guardrails.md` - guardrails run through `dart run tool/guardrails/run.dart`; runner metadata may live under `tool/guardrails/**`; `--changed` must widen to the full blocking suite when impact mapping is incomplete.
- `analysis_options.yaml` - root code must satisfy strict Dart analysis, Flutter lints, and DCM rules; `legacy/**` is excluded from root analysis.

### Rejected Misleading Local Patterns

- `legacy/iwb_canvas_engine/lib/iwb_canvas_engine.dart` - useful as a barrel-export mechanics example, but it exports legacy symbols that P0 must ban.
- `legacy/iwb_canvas_engine/lib/src/interactive/scene_controller.dart` and related public controller facades - forbidden legacy public/runtime shape.
- `legacy/iwb_canvas_engine/lib/src/model/scene_builder.dart` and `legacy/iwb_canvas_engine/lib/src/model/scene_builder_api.dart` - forbidden as public architecture for the new package.
- `legacy/iwb_canvas_engine/lib/src/serialization/scene_codec.dart` - forbidden as a whole-codec structure for P0 and outside P0 scope.
- `legacy/iwb_canvas_engine/lib/src/controller/scene_store_controller.dart` - mixed legacy controller/store structure and not the new root owner.
- `docs/tool/check_docs.dart` - valid CLI precedent, but wrong owner for package/runtime hard-boundary guardrails and must not absorb them.

## 4. Architecture

### 4A. Locked Architectural Form

#### Problem Ownership Level

- P0 is owned at the repository-root package boundary level, not by an individual runtime subsystem.
- The first implementation must make package identity, public export shape, source boundaries, required diagrams, and guardrail execution mechanically visible before feature behavior exists.

#### Selected Architectural Form

- Root package skeleton with a single public barrel at `lib/iwb_canvas_engine.dart`.
- Public declarations live under `lib/src/api/**`; the public barrel exports API-owned files only.
- Runtime composition has exactly one production skeleton owner, `RuntimeRoot`, in `lib/src/runtime/runtime_root.dart`.
- Hard-boundary checks are implemented as reusable Dart logic under `tool/guardrails/src/**` and executed through `tool/guardrails/run.dart`.
- Cross-cutting proof lives under `test/guardrails/**`; API contract proof lives under `test/api_contract/**`.
- Root CI invokes the same root commands that developers run locally.

#### Owning Layer or Module

- Package ownership: repository root.
- Public API declaration layer: `lib/src/api/**`.
- Runtime composition-root layer: `lib/src/runtime/runtime_root.dart`.
- Guardrail orchestration and metadata: `tool/guardrails/**`.
- Guardrail proof integration: `test/guardrails/**`.
- API export proof: `test/api_contract/**`.

#### Dependency Direction

- `lib/iwb_canvas_engine.dart` exports only files from `lib/src/api/**`.
- `lib/src/api/**` may not import concrete internals from store, edit, frame, interaction, resources, codec, diagnostics, spatial, geometry, runtime, or Flutter bridge.
- Production `lib/**` must not import `tool/**`.
- Production `lib/**` must not import `legacy/**` or the legacy package.
- Tests may import reusable logic from `tool/guardrails/**` or execute `tool/guardrails/run.dart` when the proof needs the same command path as CI.
- `tool/guardrails/**` may read repository files and docs registries, but it must not become a replacement architecture source of truth.

#### State and Data Ownership

- Public API v1 semantics are owned by `docs/contracts/public_api_v1.md`.
- The machine-readable public API v1 name inventory is owned by
  `docs/_registry/public_api_v1.yaml`; guardrails and tests must read expected
  public names from this registry instead of hardcoding them or parsing
  Markdown prose.
- Package layout and forbidden import rules are owned by `docs/architecture/02_package_boundaries.md`.
- Mandatory guardrail ids and runner behavior are owned by `docs/verification/guardrails.md`.
- Runner metadata for implemented P0 hard-boundary guardrails is owned by `tool/guardrails/src/guardrail_registry.dart`.
- `RuntimeRoot` owns no runtime state in P0 beyond identifying the single future composition owner.

#### Entry and Exit Boundaries

- Consumer entry: `package:iwb_canvas_engine/iwb_canvas_engine.dart`.
- Local and CI guardrail entry: `dart run tool/guardrails/run.dart`.
- Direct guardrail selection: `dart run tool/guardrails/run.dart --guardrail=<id>`.
- Suite selection: `dart run tool/guardrails/run.dart --suite=<name>`.
- Changed-aware entry: `dart run tool/guardrails/run.dart --changed`, which falls back to the full blocking suite until impact metadata is complete.
- Exit boundary: all P0 hard-boundary guardrails pass locally and through the root CI target.

#### Permitted Extension Seam

- New P0 guardrails may be added by registering a `GuardrailDefinition` in `tool/guardrails/src/guardrail_registry.dart` and adding or extending the matching proof under `test/guardrails/**`.
- New public API skeleton declarations may be added only under `lib/src/api/**` and then exported by `lib/iwb_canvas_engine.dart`.
- New runtime behavior is not a P0 extension seam; it starts in later runtime phases.

#### Rejected Alternatives

- Copy the legacy public barrel or legacy public controller facade - rejected because the new package is not API-compatible with the legacy package and must not export any symbol from the legacy public API golden list.
- Place app adapters such as `AppCanvasPort`, `LegacyEngineAdapter`, or `NextEngineAdapter` in the package - rejected because the architecture overview keeps app integration outside `iwb_canvas_engine`.
- Implement runtime subsystems in P0 - rejected because P0 is limited to skeleton, ownership, and hard-boundary enforcement.
- Make guardrails prose-only or CI-only - rejected because P0 requires executable local guardrails through one project-owned runner.
- Expand `docs/tool/check_docs.dart` into runtime/package boundary checking - rejected because documentation structural checks and package hard-boundary checks have different owners.
- Add one-off guardrail scripts without runner metadata - rejected because `test.guardrails.blocking_suite` must make omitted mandatory guardrails visible.
- Hardcode expected public API names in tests - rejected because tests must prove
  the contract, not become the hidden contract.
- Parse expected public API names from `docs/contracts/public_api_v1.md` -
  rejected because Markdown is the human-readable semantic contract, not a
  stable machine data format.

#### Why This Level Is Correct

- Later phases depend on package identity, public export shape, import boundaries, diagram presence, and the single runtime root.
- Enforcing those constraints at the root package and guardrail-runner level prevents later feature slices from spreading legacy policy checks across callers or subsystem implementations.
- P0 has no feature behavior to own inside store, edit, frame, interaction, resource, codec, diagnostics, spatial, geometry, or Flutter bridge layers.

## 5. Locked Decisions

1. The first plan entry for P0 is `plan/step_1_package_skeleton_and_hard_boundaries.md`.
2. `api.public_exports_complete` and `api.public_types_complete` are proven
   first through `test/guardrails/blocking_suite_test.dart`, because the
   inspected guardrail index maps both guardrails to
   `test.guardrails.blocking_suite`.
3. P0 does not create separate
   `test/guardrails/public_exports_complete_test.dart` or
   `test/guardrails/public_types_complete_test.dart`; the public API guardrail
   proof stays in `test/guardrails/blocking_suite_test.dart` unless the docs
   registry and indexes are updated in the same change.
4. Public skeleton declarations are minimal compileable declarations that satisfy exported-name and boundary checks; they do not lock final behavior, validation, equality, dartdoc completeness, or signature semantics reserved for later phases.
5. `api.public_exports_complete` owns exported-name inventory completeness.
   Expected P0 public names are stored in
   `docs/_registry/public_api_v1.yaml`. The public skeleton inventory proof
   reads that registry and compares it with declarations exported through
   `lib/iwb_canvas_engine.dart`; it must not hardcode the list in tests and must
   not parse names out of `docs/contracts/public_api_v1.md`.
6. `api.public_types_complete` keeps the meaning defined by
   `docs/verification/guardrails.md` and `docs/indexes/by_guardrail.md`: all
   exported public signatures reference defined public types. P0 implements the
   minimal version of that signature-reference check for the skeleton API; it
   does not redefine the guardrail as exported-name inventory completeness.
7. `test/guardrails/import_boundaries_test.dart` owns P0 source-boundary structural proof for `core.import_boundaries` and `core.no_unapproved_part_files`.
8. `test/api_contract/no_legacy_public_symbols_test.dart` owns direct public-barrel proof for `api.no_legacy_public_types`.
9. `test/guardrails/blocking_suite_test.dart` owns runner metadata completeness for the P0 hard-boundary guardrails and proves runner selection paths.
10. `test/guardrails/required_diagrams_present_test.dart` owns `diagrams.all_required_present`.
11. The P0 runner registers the P0 hard-boundary subset now and preserves the command shape needed for later section 22 guardrails.
12. The root CI workflow runs root-package checks and `dart run tool/guardrails/run.dart`; it does not call legacy package checks as P0 proof.

## 6. Result Requirements

1. The root package has a compileable empty public API skeleton.
2. Public consumers can import only the root barrel and receive only API-owned public exports.
3. Legacy package paths and legacy runtime/public API shapes are absent from production root code.
4. Exactly one production `RuntimeRoot` exists.
5. Production root code has no unapproved `part` or `part of` directives.
6. Source imports obey the package boundary matrix from `docs/architecture/02_package_boundaries.md`.
7. Required P0 Mermaid diagram files are present.
8. The guardrail runner can run the full registered P0 blocking suite and selected hard-boundary guardrails.
9. `--changed` never skips proof when impact mapping is incomplete.
10. Root CI can execute the same P0 hard-boundary proof path as local development.

## 7. Execution Order and Gates

### Required Order

- Add the `api.public_exports_complete` skeleton inventory proof and the
  `api.public_types_complete` signature-reference proof before adding the
  public API declarations that make them pass.
- Add the public barrel and API skeleton before closing `api.no_legacy_public_types`.
- Add `RuntimeRoot` before closing `core.single_runtime_root`.
- Add source-boundary checks before adding future subsystem folders beyond the P0 skeleton.
- Add runner metadata before closing `test.guardrails.blocking_suite`.
- Add CI wiring after the local runner commands are green.

### Successor Seam and Retirement Gates

- Successor seam: `tool/guardrails/run.dart` replaces ad hoc manual hard-boundary proof for P0.
- Consumer migration order: local developer commands first, root CI second.
- Retirement gate: no separate P0-only guardrail scripts may remain outside the runner after `test.guardrails.blocking_suite` is green.
- Registry references that must be represented in runner metadata before P0 closure: the P0 hard-boundary guardrail ids listed in section 2.
- Workflow references that must move before P0 closure: root CI must call `dart run tool/guardrails/run.dart` rather than individual hard-boundary proof commands.

### Deferred Broad Verification

- `dart analyze` - reserved for final P0 implementation gate after code changes.
- `dcm analyze .` - reserved for final P0 implementation gate after code changes.
- `dcm calculate-metrics .` - reserved for final P0 implementation gate after code changes.
- Full `dart test` - reserved for final P0 implementation gate after slice-local tests pass.

## 8. File Map

### Implementation Files

- `lib/iwb_canvas_engine.dart`
- `lib/src/api/canvas_runtime.dart`
- `lib/src/api/canvas_surface.dart`
- `lib/src/api/canvas_document.dart`
- `lib/src/api/canvas_element.dart`
- `lib/src/api/canvas_element_update.dart`
- `lib/src/api/canvas_resource.dart`
- `lib/src/api/canvas_ids.dart`
- `lib/src/api/canvas_geometry.dart`
- `lib/src/api/canvas_tools.dart`
- `lib/src/api/canvas_pointer.dart`
- `lib/src/api/canvas_preview.dart`
- `lib/src/api/canvas_events.dart`
- `lib/src/api/canvas_errors.dart`
- `lib/src/api/canvas_diagnostics.dart`
- `lib/src/runtime/runtime_root.dart`
- `tool/guardrails/run.dart`
- `tool/guardrails/src/guardrail_definition.dart`
- `tool/guardrails/src/guardrail_registry.dart`
- `tool/guardrails/src/guardrail_runner.dart`
- `tool/guardrails/src/public_api_boundary_check.dart`
- `tool/guardrails/src/source_boundary_check.dart`
- `tool/guardrails/src/diagram_presence_check.dart`
- `tool/guardrails/src/path_normalization.dart`

### Test Files

- `test/api_contract/no_legacy_public_symbols_test.dart`
- `test/guardrails/import_boundaries_test.dart`
- `test/guardrails/required_diagrams_present_test.dart`
- `test/guardrails/blocking_suite_test.dart`

### Fixtures and Supporting Data

- No persistent fixtures are required for P0; guardrail tests may create temporary source trees for negative scenarios.

### Registry, Inventory, and Workflow Files

- `PLAN.md`
- `plan/step_1_package_skeleton_and_hard_boundaries.md`
- `.github/workflows/root_package.yml`
- `docs/implementation/p0_package_skeleton_and_hard_boundaries.md` - read-only P0 phase source.
- `docs/_registry/sections.yaml` - read-only guardrail and test source.
- `docs/_registry/public_api_v1.yaml` - machine-readable public-name source for
  P0 skeleton completeness.
- `docs/verification/guardrails.md` - read-only runner and guardrail contract source.
- `docs/indexes/by_guardrail.md` - read-only guardrail-to-test map.
- `docs/indexes/by_test_area.md` - read-only test path map.
- `docs/diagrams/README.md` - read-only diagram catalog.
- `docs/contracts/public_api_v1.md` - read-only human-readable public API
  semantic contract.
- `legacy/iwb_canvas_engine/tool/goldens/public_api_symbols.txt` - read-only legacy public API golden source for `api.no_legacy_public_types`.

### Analysis Area

- `lib/**`
- `test/**`
- `tool/guardrails/**`
- `.github/workflows/**`
- `docs/_registry/public_api_v1.yaml`
- `docs/diagrams/*.mmd`
- `docs/contracts/public_api_v1.md`
- `docs/architecture/02_package_boundaries.md`
- `docs/verification/guardrails.md`

## 9. Implementation Rules

### Protected Invariants

- The root public barrel exports only `lib/src/api/**`.
- Every P0 public name required by `docs/_registry/public_api_v1.yaml` is
  declared in API-owned files and exported only through the root barrel.
- Every exported public signature in the P0 skeleton references only public
  types that are exported by the root barrel or allowed Dart/Flutter SDK types.
- No symbol from `legacy/iwb_canvas_engine/tool/goldens/public_api_symbols.txt` is exported by the root package.
- Production root code imports no legacy package paths and no other package's `src/**`.
- Production root code has no `part` or `part of` directives in P0.
- There is exactly one production `RuntimeRoot`.
- `tool/guardrails/run.dart` is a dispatcher over registered checks, not a second test framework.
- `--changed` widens to the full registered P0 blocking suite when path-to-guardrail impact is unknown.

### Required Proof

- behavioral proof: package import and guardrail runner commands execute successfully for the P0 skeleton.
- structural proof: tests include positive and negative scenarios that make public export drift, forbidden imports, unapproved part directives, missing diagrams, missing P0 guardrail metadata, and invalid guardrail selection mechanically visible.
- public skeleton inventory proof: `api.public_exports_complete` fails when a
  P0 public name required by `docs/_registry/public_api_v1.yaml` is missing
  from API-owned declarations or not exported through
  `lib/iwb_canvas_engine.dart`.
- public signature-reference proof: `api.public_types_complete` fails when any
  exported public signature references a type that is not defined by the public
  barrel or allowed Dart/Flutter SDK imports.
- legacy public API proof: `api.no_legacy_public_types` reads the full golden list from `legacy/iwb_canvas_engine/tool/goldens/public_api_symbols.txt` and fails if any listed symbol is exported by `lib/iwb_canvas_engine.dart`.
- for bug fixes, regressions, false positives, false negatives, and invariant-enforcement gaps: one failing reproducer first, plus 1 to 3 guard tests for neighboring branches of the same contract.
- for refactors: existing locking tests must be named or missing characterization tests must be added before structural edits, plus 1 to 3 guard tests for neighboring branches when needed.

### Allowed Change Surface

- The files listed in section 8.
- Directory creation needed for the listed files.
- `PLAN.md` status checkbox update after P0 final verification passes.
- `plan/step_1_package_skeleton_and_hard_boundaries.md` slice checkbox updates after their corresponding slice verification passes.

### Forbidden Moves

- Do not import from `legacy/**` or the legacy package in production root code.
- Do not copy the legacy public barrel, legacy controller facade, scene builder public API, whole legacy codec, or whole legacy store controller.
- Do not add `AppCanvasPort`, `LegacyEngineAdapter`, or `NextEngineAdapter` to the root package.
- Do not implement runtime subsystem behavior beyond the `RuntimeRoot` skeleton.
- Do not use string-only import parsing when the Dart analyzer can parse directives.
- Do not create guardrail metadata that silently omits an implemented P0 hard-boundary guardrail.
- Do not make CI the only enforcement path.

### Optional: Recognition Forms That Must Be Supported

- Dart `import`, `export`, `part`, and `part of` directives in production `lib/**`.
- Relative imports that resolve across forbidden `lib/src/**` boundaries.
- `package:iwb_canvas_engine/src/**` imports from within or outside the package.
- Any `package:<name>/src/**` import in production `lib/**`.
- Legacy public API exports matching any symbol from `legacy/iwb_canvas_engine/tool/goldens/public_api_symbols.txt`.
- Legacy shape references through imported paths or production declarations containing `SceneController`, `NodeSpec`, `NodePatch`, `PatchField`, `SceneSnapshot`, or `SceneWriteTxn`.
- Missing or duplicate `RuntimeRoot` production declarations.
- Missing Mermaid files listed for P0 in the diagram catalog and phase file.
- Unknown `--guardrail` and `--suite` selections.

### Optional: Allowed Forms That Are Not Violations

- Imports from Dart SDK libraries and approved Flutter public packages in API files.
- Imports among `lib/src/api/**` files.
- Test imports from `tool/guardrails/**`.
- Tool reads of `docs/**` registry and catalog files.
- Legacy references inside `docs/**`, `test/**` negative fixtures, and `legacy/**`.

### Optional: Resolution Rules

- Normalize filesystem paths to repository-relative POSIX paths before applying boundary rules.
- Resolve relative Dart directives before checking forbidden layer edges.
- Treat generated-file exemptions as unavailable in P0 unless a later approved generated-code phase adds them explicitly.
- Treat incomplete changed-impact metadata as a full-suite request.

## 10. Vertical Slices

### Slice 1. [ ] Public Skeleton and API Boundary Proof

#### Slice Contract

The root package exposes a compileable empty public API skeleton through one public barrel, and P0 proves first that required public names are present and every symbol from the legacy public API golden list is absent.

#### Change

- Add the failing `api.public_exports_complete` and
  `api.public_types_complete` proofs in `test/guardrails/blocking_suite_test.dart`.
- Use `docs/_registry/public_api_v1.yaml` as the machine-readable expected
  public-name inventory.
- Add `tool/guardrails/src/guardrail_definition.dart`.
- Add the initial `tool/guardrails/src/guardrail_registry.dart` entries for
  the public API guardrails.
- Add `tool/guardrails/src/public_api_boundary_check.dart`.
- Add `test/api_contract/no_legacy_public_symbols_test.dart`.
- Add `lib/iwb_canvas_engine.dart`.
- Add the P0 `lib/src/api/**` skeleton files from section 8.
- Export only API-owned files from `lib/iwb_canvas_engine.dart`.

#### Behavioral Verification

- `dart test test/api_contract/no_legacy_public_symbols_test.dart`
- `dart test test/guardrails/blocking_suite_test.dart`

#### Structural Verification

- `api.public_exports_complete` reads expected public names from
  `docs/_registry/public_api_v1.yaml`, fails before public skeleton declarations
  exist, and passes after the API-owned declarations are added.
- `api.public_types_complete` fails when a temporary exported skeleton signature
  references an undefined public type and passes when all exported signature
  types are public or allowed SDK/Flutter types.
- `api.no_legacy_public_types` reads all symbols from `legacy/iwb_canvas_engine/tool/goldens/public_api_symbols.txt`, fails against temporary barrels that export golden-listed symbols, and passes against the root barrel.
- Public barrel verification fails if any export target is outside `lib/src/api/**`.

#### Fixtures Used

- Temporary source trees created by the tests.

#### Positive Scenarios

- Root barrel imports successfully from a consumer test.
- Every public name required for the P0 skeleton is declared in API-owned files.
- No symbol from the legacy public API golden list is exported.

#### Negative Scenarios

- Missing public skeleton declaration.
- Exported public signature references an undefined type.
- Public barrel export outside `lib/src/api/**`.
- Any exported symbol from `legacy/iwb_canvas_engine/tool/goldens/public_api_symbols.txt`.

#### Closure Evidence

- Slice-local tests pass and the root barrel remains API-only.

### Slice 2. [ ] Core Source Boundaries and RuntimeRoot Proof

#### Slice Contract

Production root code has one runtime composition owner and hard source boundaries that prevent legacy imports, forbidden layer imports, another package's `src/**` imports, unapproved part files, and legacy shape dependencies.

#### Change

- Add `lib/src/runtime/runtime_root.dart`.
- Add source-boundary check logic under `tool/guardrails/src/source_boundary_check.dart`.
- Add path normalization under `tool/guardrails/src/path_normalization.dart`.
- Add `test/guardrails/import_boundaries_test.dart`.
- Extend `tool/guardrails/src/guardrail_registry.dart` with source-boundary
  guardrails.

#### Behavioral Verification

- `dart test test/guardrails/import_boundaries_test.dart`

#### Structural Verification

- Negative scenarios prove violations for API importing concrete internals, production legacy imports, production imports of another package's `src/**`, unapproved `part` and `part of` directives, missing `RuntimeRoot`, duplicate `RuntimeRoot`, and legacy shape references.
- Positive scenarios prove allowed API-to-API imports and the single `RuntimeRoot` skeleton pass.

#### Fixtures Used

- Temporary source trees created by the tests.

#### Positive Scenarios

- `lib/src/api/**` imports another API-owned file.
- Production code imports public Dart or Flutter libraries.
- Exactly one `RuntimeRoot` production declaration exists.

#### Negative Scenarios

- `lib/src/api/**` imports `lib/src/store/**`.
- Production code imports `package:other_package/src/internal.dart`.
- Production code contains `part` or `part of`.
- Production code imports or references a legacy package path.
- Production code declares `SceneController`, `NodeSpec`, `NodePatch`, or `PatchField`.
- Zero or two production `RuntimeRoot` declarations exist.

#### Closure Evidence

- Source-boundary tests pass. Runner execution for `core.import_boundaries` is
  closed in Slice 3, after the runner entrypoint exists.

### Slice 3. [ ] Runner, Diagrams, Changed Fallback, and CI Target

#### Slice Contract

The P0 hard-boundary guardrails are reachable through one local runner and the root CI target, diagram presence is proved, and changed-aware routing never skips the blocking proof when mapping is incomplete.

#### Change

- Add `tool/guardrails/run.dart`.
- Add `tool/guardrails/src/guardrail_runner.dart`.
- Finish `tool/guardrails/src/guardrail_registry.dart` metadata for all P0
  hard-boundary guardrails.
- Add `tool/guardrails/src/diagram_presence_check.dart`.
- Add `test/guardrails/required_diagrams_present_test.dart`.
- Add or finish `test/guardrails/blocking_suite_test.dart`.
- Add `.github/workflows/root_package.yml`.

#### Behavioral Verification

- `dart test test/guardrails/required_diagrams_present_test.dart`
- `dart test test/guardrails/blocking_suite_test.dart`
- `dart run tool/guardrails/run.dart`
- `dart run tool/guardrails/run.dart --suite=api`
- `dart run tool/guardrails/run.dart --guardrail=core.import_boundaries`
- `dart run tool/guardrails/run.dart --changed`

#### Structural Verification

- `test.guardrails.blocking_suite` fails if any P0 hard-boundary guardrail id is missing from runner metadata.
- Runner selection tests fail on an unknown `--guardrail` or `--suite`.
- Changed-aware routing tests prove unknown impact maps to the full registered P0 blocking suite.
- CI workflow proof fails if the workflow omits `dart run tool/guardrails/run.dart` or root package analysis commands.
- Diagram proof fails if a required P0 Mermaid file is missing.

#### Fixtures Used

- Temporary runner registries or source trees created by the tests.

#### Positive Scenarios

- Full runner executes all registered P0 hard-boundary guardrails.
- `--guardrail=core.import_boundaries` executes only the selected guardrail and its dependencies, if any.
- `--suite=api` executes registered API guardrails.
- `--changed` without complete impact metadata executes the full registered P0 blocking suite.
- Required P0 diagram files exist.
- Root CI workflow references the local runner and root analysis commands.

#### Negative Scenarios

- Missing P0 guardrail registry entry.
- Unknown guardrail id.
- Unknown suite id.
- Changed path without impact mapping tries to run a partial suite.
- Missing P0 diagram file.
- CI workflow omits guardrail runner execution.

#### Closure Evidence

- Runner, diagram, changed-fallback, and CI proof tests pass; local runner commands succeed.

## 11. Final Verification

- `dart test`
- `dart run tool/guardrails/run.dart`
- `dart run tool/guardrails/run.dart --suite=api`
- `dart run tool/guardrails/run.dart --guardrail=core.import_boundaries`
- `dart run tool/guardrails/run.dart --changed`
- `dart analyze`
- `dcm analyze .`
- `dcm calculate-metrics .`

## 12. Acceptance Criteria

- `PLAN.md` links this contract as Step 1.
- `PLAN.md` marks Step 1 complete after P0 final verification passes.
- Slice 1, Slice 2, and Slice 3 checkboxes in this linked step contract are marked complete after their corresponding slice verification and final gate pass.
- The root package builds a compileable empty public API skeleton.
- `lib/iwb_canvas_engine.dart` exports only `lib/src/api/**`.
- No symbol from `legacy/iwb_canvas_engine/tool/goldens/public_api_symbols.txt` is exported by the root package.
- Root production code imports no legacy package path and no other package's `src/**`.
- Root production code contains no unapproved `part` or `part of` directive.
- Exactly one production `RuntimeRoot` exists.
- Required P0 Mermaid diagram files are present.
- P0 hard-boundary guardrails are registered and executable through `dart run tool/guardrails/run.dart`.
- `--guardrail=<id>`, `--suite=<name>`, and `--changed` behave as specified by `docs/verification/guardrails.md`.
- Root CI runs the same P0 guardrail entrypoint as local development.
- Final verification commands in section 11 pass.
