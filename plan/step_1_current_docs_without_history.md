# Change Contract

## Goal

Active documentation describes only the maintained package's current state. It
does not mention legacy history, deleted package routes, old/new API migration,
or old public API symbol catalogs. The deleted legacy folder is not part of the
current package, so docs must not preserve it as context.

## Source Inputs

- Design: none
- Research: `.research/2026-06-09-docs-codebase-alignment.md`
- Phase: none
- PLAN: `PLAN.md`
- Other:
  - direct user requirement in the 2026-06-09 planning conversation:
    "documents must know nothing about legacy and must describe current state"
  - `AGENTS.md`
  - `docs/README.md`
  - `docs/architecture/architecture_graph.yaml`
  - `docs/tool/check_docs.dart`
  - `docs/verification/guardrails.md`
  - `docs/verification/tests.md`
  - `docs/verification/guardrail_design_patterns.md`
  - `docs/verification/release_gates.md`
  - `tool/guardrails/src/guardrail_registry.dart`
  - `tool/guardrails/src/public_api_registry.dart`
  - `tool/guardrails/src/public_api_checks.dart`
  - `tool/guardrails/src/core_boundary_checks.dart`
  - `test/api_contract/public_api_registry_test.dart`
  - `test/tool/current_invariant_transfer_test.dart`

## Classification

Profile: ANALYZER_RULE

Obligations: none

## Decision Trace

| Source decision | Contract location | Execution unit / proof surface |
|---|---|---|
| Active docs must not know about legacy, old/new API history, deleted package routes, or retired public API catalogs. | `Boundaries.In Scope`; `Unit 1`; `Unit 2` | one-time active-doc `rg` verification |
| `docs/_registry/` owns structured docs relationships and generated docs are regenerated from it. | `Source of Truth`; `Unit 1` | registry cleanup plus `dart run docs/tool/sync_generated_docs.dart --check` |
| `retired_public_exports` is a docs-owned deleted public API catalog. | `Source of Truth`; `Unit 1` | remove the field without creating a replacement catalog |
| Public export protection remains current allow-list based. | `Compatibility`; `Unit 1` | `api.public_exports_complete` rejects unregistered root-barrel exports |
| `docs/tool/check_docs.dart` is structural and should not grow broad wording checks. | `Boundaries.Owner`; `Unit 2` | one-time active-doc `rg` verification |
| Active docs must be English. | `Unit 2` | Cyrillic scan over active docs and generated docs |
| Architecture docs are in scope, so architecture graph checks are mandatory. | `Unit 2`; `Unit 3` | architecture graph generated views and graph check commands pass |

## Evidence

- `docs/README.md:24` / `Source of truth`: normative architecture lives under `docs/architecture/` -> historical framing there is active source-of-truth text and must be cleaned.
- `docs/README.md:27` / `Source of truth`: `docs/_registry/` owns structured relationships -> registry fields and ids that mention history must be cleaned before generated docs are synced.
- `docs/README.md:28` / `Generated navigation`: generated indexes and diagram catalog are active navigation -> clean owning sources, not generated files directly.
- `docs/tool/check_docs.dart:1` / `Docs checker boundary`: docs checker is structural only -> no-history wording cleanup is verified by one-time search proof, not ad hoc checker prose.
- `docs/architecture/00_architecture_overview.md:34` / `Architecture source`: current overview explains the package through a previous model -> active architecture docs know deleted history today.
- `docs/architecture/00_architecture_overview.md:77` / `Architecture source`: overview contains a deleted public API list -> active docs catalog deleted API names today.
- `docs/_registry/public_api_v1.yaml:114` / `Public API registry`: `retired_public_exports` is a docs-owned deleted-symbol catalog -> remove it without replacement.
- `docs/contracts/public_api_v1.md:82` / `Public API contract`: the root package exports exactly names listed in `public_api_v1.yaml` -> current `public_exports` remains the public API source of truth.
- `tool/guardrails/src/public_api_checks.dart:14` / `Public API guardrail`: `checkPublicExportsComplete()` rejects root-barrel exports absent from the current registry -> no old-symbol deny-list is needed for public extra-export protection.
- `docs/verification/guardrail_design_patterns.md:49` / `Guardrail pattern source`: guardrail guidance uses legacy-derived labels -> active verification docs preserve deleted-history framing today.
- `docs/diagrams/state_runtime_lifecycle.mmd:9` / `Diagram source`: runtime lifecycle diagram names deleted entities -> manual diagrams are active docs and must be cleaned.
- `test/tool/current_invariant_transfer_test.dart:71` / `Legacy transfer proof`: current tool tests alias `retired_public_exports` to a proof owner.
- `test/tool/current_invariant_transfer_test.dart:131` / `Legacy transfer proof`: current tool tests read `.design/2026-06-08-legacy-phase-cleanup.md` as an active proof source -> retire this bridge from active checks instead of migrating deleted-history rows.

## Boundaries

Owner:

- Active docs source of truth: `docs/README.md`, `docs/architecture/README.md`,
  `docs/architecture/**`, `docs/contracts/**`, `docs/verification/**`,
  `docs/_registry/**`, `docs/diagrams/*.mmd`, and
  `docs/architecture/architecture_graph.yaml`.
- Generated active docs: `docs/indexes/**`, `docs/diagrams/catalog.md`, and
  `docs/diagrams/generated/*.mmd`; regenerate them from owning sources.
- Tooling owner only where the docs cleanup removes docs-owned registry fields
  or renames docs-facing guardrail ids that current tools still require,
  including `tool/guardrails/src/guardrail_registry.dart`,
  `tool/guardrails/src/guardrail_executor.dart`,
  `tool/guardrails/src/public_api_checks.dart`, and
  `tool/guardrails/src/core_boundary_checks.dart`.

In Scope:

- Remove legacy/retired/old-new/donor/deleted-package wording from active docs,
  docs registries, diagrams, generated docs, architecture graph source, and
  generated graph views.
- Remove `retired_public_exports` from `docs/_registry/public_api_v1.yaml`
  without creating any replacement list, fixture, helper, registry, generated
  file, or documentation artifact that preserves the deleted public API catalog.
- Remove `api.no_retired_public_exports`, `checkNoRetiredPublicExports`, and
  their docs/test/runner references because the deleted-symbol catalog no longer
  exists.
- Keep current public API protection through `api.public_exports_complete` and
  strengthen it with a neutral unregistered-export test that does not reference
  old symbols.
- Apply `Guardrail Id Migration` exactly; do not choose different names during
  implementation.
- Verify active docs stay free of deleted-history wording through one-time
  implementation proof commands.

Out of Scope:

- Creating any committed replacement catalog of deleted public API names.
- Changing current public API names, signatures, exported declarations, schema
  shape, runtime behavior, or package compatibility.
- Deleting internal negative tests for current boundary behavior solely because
  their fixtures contain forbidden examples, provided they do not leak into
  active docs or docs-owned registries.
- Adding tests whose primary claim is only that an old file, folder, route, or
  word is
  absent.
- Rewriting `.research/` or `.design/` historical evidence inputs.
- Keeping `.design/2026-06-08-legacy-phase-cleanup.md` as an active
  current-invariant test input.
- Adding broad free-form wording checks inside `docs/tool/check_docs.dart`.

Source of Truth:

- Active package docs own only current package state.
- `docs/_registry/public_api_v1.yaml` owns current `public_exports` and current
  public API classifications only.
- There is no replacement source of truth for deleted public API symbols.
- `api.public_exports_complete` is the current public export protection surface:
  any root-barrel export absent from `public_exports` is rejected as an
  unregistered public export.

Compatibility:

- Current public API names, signatures, schemas, runtime behavior, package
  exports, and package compatibility do not change.
- Removing `retired_public_exports` and `api.no_retired_public_exports` must not
  weaken public export protection because `api.public_exports_complete` remains
  the current allow-list guardrail and gains a neutral extra-export rejection
  proof.
- Renamed guardrail ids keep the same current boundary behavior; only
  deleted-history wording in ids, docs, test names, and messages changes.

One-Time Active-Docs Search Terms:

- Case-insensitive wording: `legacy`, `retired`, `old API`, `new API`,
  `old public`, `new public`, `previous model`, `prior model`, `donor`,
  `deleted package`, `old engine`, `new engine`, `old runtime`, `schema v7`,
  `old schema`, `new schema`, `functional oracle`, `next API`,
  `replacement API`.
- Russian transition terms: `стар`, `нов`, `преж`.
- Named current contaminants observed in active docs/research:
  `SceneController`, `SceneBuilder`, `SceneWriteTxn`, `SceneSnapshot`,
  `SceneCodec`, `NodeSpec`, `NodePatch`, `PatchField`, `PatchFieldState`,
  `decodeScene`, `decodeSceneFromJson`, `encodeScene`, `encodeSceneToJson`,
  `decodeCanvasDocument`, `decodeCanvasDocumentFromJson`,
  `notifySceneChanged`, `LegacyEngineAdapter`, `NextEngineAdapter`,
  `AppCanvasPort`, `Transform2D`.

Guardrail Id Migration:

| Current id/name | Action | New current-state id/name | Required surfaces |
|---|---|---|---|
| `api.no_retired_public_exports` | remove | none; covered by `api.public_exports_complete` | `tool/guardrails/src/guardrail_registry.dart`, `tool/guardrails/src/guardrail_executor.dart`, `tool/guardrails/src/public_api_checks.dart`, `docs/_registry/sections.yaml`, `docs/verification/guardrails.md`, `docs/verification/release_gates.md`, `test/guardrails/blocking_suite_test.dart`, `test/api_contract/no_retired_public_exports_test.dart` |
| `test.api_contract.no_retired_public_exports` | remove | `test.api_contract.public_exports_complete` | `docs/_registry/sections.yaml`, `docs/verification/tests.md`, generated test-area index |
| `api.no_retired_public_load_routes` | rename | `api.current_document_load_surface_only` | guardrail registry/executor, public API checks, docs registry, guardrail docs, release gates, API contract tests |
| `core.no_retired_package_imports` | rename | `core.no_unapproved_external_package_imports` | guardrail registry/executor, core boundary checks, docs registry, guardrail docs, release gates, core boundary tests |
| `core.no_retired_controller_shape_dependency` | rename | `core.no_unapproved_controller_shape_dependency` | guardrail registry/executor, core boundary checks, docs registry, guardrail docs, release gates, core boundary tests |
| `core.no_retired_node_patch_shape_dependency` | rename | `core.no_unapproved_patch_shape_dependency` | guardrail registry/executor, core boundary checks, docs registry, guardrail docs, release gates, core boundary tests |
| `negative_legacy_shape` | rename | `forbidden_shape` | `docs/verification/guardrail_design_patterns.md` |
| `test/tool/current_invariant_transfer_test.dart` legacy transfer bridge | retire from active checks | none | remove reads of `.design/2026-06-08-legacy-phase-cleanup.md`, remove the `retired_public_exports` alias, and keep no active replacement proof for deleted-history transfer rows |

Order Constraints:

1. Remove docs-owned deleted public API catalog and dependent guardrail route
   before regenerating docs.
2. Clean manual docs, diagrams, architecture graph source, and docs-facing
   guardrail names from owning sources.
3. Run one-time active-doc text and Cyrillic scans after the cleaned
   sources exist.
4. Run focused tool/API checks before final docs, architecture, Dart, and
   DCM checks.

## Execution Units

### [x] Unit 1: Registry and guardrail surface migration

Owner:

- Public API registry and guardrail tooling surfaces.

Boundary:

- `docs/_registry/public_api_v1.yaml`, `docs/_registry/sections.yaml`, public
  API registry parser/tests, guardrail registry/executor, public API guardrail
  checks, core boundary guardrail checks, affected API/core guardrail tests,
  generated docs that reference those registry fields, and public export focused
  tests.

Change:

- Remove `retired_public_exports` from `docs/_registry/public_api_v1.yaml`.
- Delete `checkNoRetiredPublicExports`, `api.no_retired_public_exports`, and
  their runner/docs/test references with no no-op replacement.
- Apply `Guardrail Id Migration` exactly.
- Retire the active legacy transfer bridge in
  `test/tool/current_invariant_transfer_test.dart`; do not read
  `.design/2026-06-08-legacy-phase-cleanup.md` from active tests.
- Update public API registry parser/tests so only current registry fields are
  required.
- Add a neutral unregistered-export fixture/test to
  `test/api_contract/public_exports_complete_test.dart` proving
  `api.public_exports_complete` rejects any root-barrel export absent from
  `public_exports`.
- Regenerate docs after registry updates.

Completion Check:

- Claim: docs no longer own a deleted public API catalog and public extra-export
  protection remains current-state based.
- Direct outcome: `retired_public_exports` and `api.no_retired_public_exports`
  are absent from active docs/tooling/tests; `dart test test/api_contract/public_exports_complete_test.dart`
  proves both clean real root and neutral extra-export rejection; generated docs
  sync passes; renamed guardrails remain selectable through the runner.
- Proxy risk: deleting the deny-list without neutral extra-export proof could
  silently weaken public surface protection.
- Required proof: `dart test test/api_contract/public_api_registry_test.dart`,
  `dart test test/api_contract/public_exports_complete_test.dart`,
  `dart test test/api_contract/current_document_load_surface_only_test.dart`,
  `dart test test/guardrails/core_boundary_negative_fixtures_test.dart`,
  `dart test test/guardrails/blocking_suite_test.dart`,
  `dart test test/tool/current_invariant_transfer_test.dart` if the file remains,
  `rg -n "retired_public_exports|api\\.no_retired_public_exports|checkNoRetiredPublicExports|api\\.no_retired_public_load_routes|core\\.no_retired_package_imports|core\\.no_retired_controller_shape_dependency|core\\.no_retired_node_patch_shape_dependency|negative_legacy_shape" docs tool test lib -S`
  with no hits, and `dart run docs/tool/sync_generated_docs.dart --check`.

Depends On:

- none

### [x] Unit 2: Active docs current-state rewrite

Owner:

- Documentation source of truth.

Boundary:

- `docs/README.md`, `docs/architecture/README.md`, `docs/architecture/**`,
  `docs/contracts/**`, `docs/verification/**`, `docs/_registry/**`,
  `docs/diagrams/*.mmd`, `docs/architecture/architecture_graph.yaml`, and
  generated docs/graph views.

Change:

- Rewrite active docs to describe the maintained package directly in English.
- Remove transition history, old/new API comparisons, legacy/retired wording,
  donor/deleted-package wording, deleted public API symbol catalogs, and
  diagrams notes that name deleted entities.
- Rewrite guardrail design-pattern and release-gate wording through current
  proof shapes and current guardrail names.
- Rename remaining docs-facing guardrail ids according to `Guardrail Id Migration`.
- Regenerate generated docs and architecture graph views from cleaned sources.

Completion Check:

- Claim: active docs and generated docs no longer mention deleted history.
- Direct outcome: a case-insensitive search using `One-Time Active-Docs Search
  Terms` reports no hits in active docs, docs registries, manual diagrams,
  architecture graph source, generated docs, or generated graph views; `rg -n "[А-Яа-яЁё]" docs/README.md docs/architecture docs/contracts docs/verification docs/_registry docs/diagrams -S` reports no hits.
- Proxy risk: editing generated docs directly can pass temporarily while stale
  owning sources regenerate bad text.
- Required proof: one-time active-doc search,
  `dart run docs/tool/sync_generated_docs.dart --check`, and
  `dart run tool/architecture_graph/generate_views.dart --check`.

Depends On:

- Unit 1

### [x] Unit 3: Verification

Owner:

- Mixed documentation/tooling verification.

Boundary:

- Repository checks required for changed docs, architecture docs, Dart tool/test
  owners, and generated docs/views.

Change:

- Run focused tests affected by registry/tooling migration.
- Run docs checks, architecture graph checks, Dart analysis, DCM analysis, and
  targeted DCM metrics for changed Dart/tool/test owners.
- After all required proof passes, update `PLAN.md` and this linked step file to
  mark the implemented step and completed execution units done in the same
  implementation change. These checkboxes stay unchecked during planning.

Completion Check:

- Claim: docs cleanup is complete without weakening current package enforcement.
- Direct outcome: focused tests pass; `dart run docs/tool/sync_generated_docs.dart --check`,
  `dart run docs/tool/check_docs.dart`, `dart run tool/architecture_graph/check.dart`,
  `dart run tool/architecture_graph/generate_views.dart --check`,
  `dart analyze`, `dcm analyze .`, and targeted `dcm calculate-metrics` pass for
  changed Dart/test/tool owners; `PLAN.md` and this linked step file are updated
  only after those proofs exist.
- Proxy risk: docs checks alone could pass while parser, runner, or public export
  guardrails are broken.
- Required proof: command output from all required checks, with unavailable
  commands reported explicitly.

Completion Evidence:

- `dart test test/api_contract/public_api_registry_test.dart test/api_contract/public_exports_complete_test.dart test/api_contract/current_document_load_surface_only_test.dart test/guardrails/core_boundary_negative_fixtures_test.dart test/guardrails/blocking_suite_test.dart test/api_contract/public_integration_compile_fixture_test.dart test/api_contract/public_facade_wrapper_test.dart test/guardrails/interaction_guardrail_enforcement_test.dart test/api/tool_port_settings_test.dart test/api/command_port_actions_test.dart test/api/typed_action_payloads_test.dart`:
  passed, 108 tests.
- `dart run docs/tool/sync_generated_docs.dart --check`: passed.
- `dart run docs/tool/check_docs.dart`: passed.
- `dart run tool/architecture_graph/check.dart`: passed.
- `dart run tool/architecture_graph/generate_views.dart --check`: passed.
- `dart analyze`: passed with no issues.
- `dcm analyze .`: passed with no issues.
- `dcm calculate-metrics tool/guardrails/src test/api test/api_contract test/guardrails`:
  passed with no metric violations.
- Guardrail migration scan over `docs tool test lib`: no hits.
- Active-doc forbidden-term scan over docs, architecture, contracts,
  verification, registries, and diagrams: no hits.
- Active-doc Cyrillic scan over docs, architecture, contracts, verification,
  registries, and diagrams: no hits.
- Expanded active-doc cleanup scan over docs, architecture, contracts,
  verification, registries, and diagrams: no hits.

Depends On:

- Unit 2
