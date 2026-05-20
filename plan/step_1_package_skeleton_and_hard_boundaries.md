# Change Contract

Contract Mode: FULL
Contract Profile: ANALYZER_RULE
Contract Obligations: SEAM_MIGRATION, PUBLIC_API_CHANGE

## 1. Mandate and Boundary

### Mandate

Implement P0 package skeleton and hard boundaries for the repository-root
`iwb_canvas_engine` package before runtime behavior, donor code, codecs, or
Flutter surface implementation land.

### In Scope

- Populate the root package skeleton declared for P0 with a minimal public API
  barrel, public API owner files under `lib/src/api/**`, a single
  `RuntimeRoot` skeleton, guardrail tests, guardrail runner entrypoint, runner
  metadata, and a root-package CI target.
- Enforce the P0 public and core boundary guardrails:
  `api.no_legacy_public_types`, `api.public_exports_complete`,
  `api.public_types_complete`, `core.no_legacy_imports`,
  `core.import_boundaries`, `core.no_unapproved_part_files`,
  `core.no_scene_controller_shape_dependency`,
  `core.no_node_spec_patch_shape_dependency`, and
  `core.single_runtime_root`.
- Support `dart run tool/guardrails/run.dart`, explicit
  `--guardrail=<id>` selection, and conservative `--changed` routing that falls
  back to the full blocking suite until impact metadata is complete.
- Add `api.public_exports_complete` and `api.public_types_complete` tests
  before completing the public skeleton, then close the slice only when those
  checks are green.

### Out of Scope

- Runtime behavior, edit behavior, rendering, codec behavior, resource
  resolution, donor-code migration, Flutter widgets, benchmarks, and public API
  semantics beyond compileable skeleton declarations needed by the P0 guards.
- Legacy API compatibility, legacy facade implementation, app adapters,
  `SceneController`, `SceneSnapshot`, `NodeSpec`, `NodePatch`, `PatchField`,
  `SceneWriteTxn`, schema v7 public entrypoints, or legacy runtime fallback.
- New documentation source-of-truth beyond this step contract and any CI or
  guardrail metadata required for executable enforcement.

## 2. Evidence Map

### Baseline Evidence

These facts describe repository state before execution. They are evidence for
the change, not target-state requirements.

### Entry Paths

- `PLAN.md` already indexes Step 1 as
  `plan/step_1_package_skeleton_and_hard_boundaries.md`; the linked step file
  was absent before this contract was created.
- `docs/implementation/p0_package_skeleton_and_hard_boundaries.md` defines P0
  as the phase that creates the root package skeleton, hard-boundary guardrails,
  `RuntimeRoot` skeleton, required diagram placeholders, guardrail runner, and
  CI target.
- `docs/README.md` is the documentation entry point for the rebuild, while
  implementation scope for this step is the repository-root package, not the
  legacy package.

### Current Owners

- `docs/architecture/00_architecture_overview.md` owns the mandatory decision
  that the root package is a new package with a new public API, one new runtime,
  no legacy facade, no legacy runtime fallback, and legacy code used only as a
  functional oracle.
- `docs/architecture/01_runtime_ownership.md` owns the single production
  `RuntimeRoot` composition boundary and lists `RuntimeRoot` as the owner of
  public runtime observation.
- `docs/architecture/02_package_boundaries.md` owns package layout, root barrel
  export policy, source boundary rules, test ownership folders, and the split
  between `test/guardrails/**` integration and `tool/guardrails/**` runner
  orchestration.
- `docs/verification/guardrails.md` owns mandatory guardrail ids and the runner
  contract.
- `docs/verification/guardrail_design_patterns.md` owns guardrail
  implementation pattern selection.
- `docs/_registry/public_api_v1.yaml` owns the machine-readable exported-name
  inventory for `api.public_exports_complete`.

### Existing Checks

- `analysis_options.yaml` excludes `legacy/**` from analyzer and DCM analysis,
  which means the new package checks can be added without making the legacy
  package part of the root implementation surface.
- `pubspec.yaml` already defines the root package name, SDK range, Flutter SDK
  dependency, and analyzer/test dependencies.
- `lib/**`, `test/**`, and `tool/**` contain no current files, so P0 guardrails
  must establish their first executable checks rather than adapt existing root
  implementations.
- `.github/**` is absent, so the root-package CI target must be introduced by
  this step if CI enforcement is required.

### Valid Precedents

- `docs/architecture/02_package_boundaries.md` gives the target folder layout
  and states that `lib/iwb_canvas_engine.dart` exports only `src/api/**`.
- `docs/verification/guardrails.md` gives the supported runner modes:
  full suite, `--suite=<name>`, `--guardrail=<id>`, and `--changed`.
- `docs/verification/guardrail_design_patterns.md` maps P0 guardrails to
  `runner_inventory`, `registry_parity`, `parsed_ast_directive`,
  `resolved_public_surface`, `negative_legacy_shape`, and
  `resolved_element_identity` patterns.
- `docs/diagrams/README.md` lists `c4_context`, `c4_container`, and
  `c4_component_runtime` as required Mermaid deliverables for P0.

### Repository Rules

- `PLAN.md` is the active roadmap index, and completed plan steps must update
  both the index and linked step document in the same change.
- Root `AGENTS.md` requires `dart analyze`, `dcm analyze .`, and
  `dcm calculate-metrics .` after code changes. This contract is documentation
  only, so those checks are not required for this planning change; they are
  required for the future P0 implementation.
- Guardrails are mandatory architecture and release rules and must be
  executable through `dart run tool/guardrails/run.dart`.
- Production `lib/**` must not import `tool/**`; tests may call reusable
  guardrail check logic or execute the runner when proving the CI path.

### Misleading Patterns

- The legacy package under `legacy/iwb_canvas_engine/**` is oracle evidence, not
  a source layout, public API, runtime fallback, or package dependency for the
  new root package.
- Historical plan step files use previous contract shapes and must not be used
  as the structure for this step.
- Existing required diagram files under `docs/diagrams/**` are documentation
  evidence; P0 does not require an executable diagram presence guardrail.
- A text scan of `lib/iwb_canvas_engine.dart` is insufficient for public API
  completeness because aliases, re-exports, generics, and signature references
  require resolved public-surface analysis.

## 3. Architecture Decision

### Selected Form

Build a minimal root package skeleton plus a project-owned guardrail runner.
The skeleton creates only the public API declarations, public barrel, and
single runtime-root owner required for hard-boundary enforcement. The guardrail
runner remains a thin dispatcher over typed guardrail checks and Dart tests; it
does not become a second test framework or a second source of truth.

### Ownership

- Public API declarations are owned by `lib/src/api/**` and are exported only
  through `lib/iwb_canvas_engine.dart`.
- Runtime composition identity is owned by `lib/src/runtime/runtime_root.dart`.
- Guardrail orchestration, metadata, and reusable structural check logic are
  owned by `tool/guardrails/**`.
- Cross-cutting proof integration is owned by `test/guardrails/**`, while public
  API proof is owned by `test/api_contract/**`.
- CI execution for the root package is owned by a new workflow under
  `.github/workflows/**`.

### Seam

P0 creates two shared seams:

- `package:iwb_canvas_engine/iwb_canvas_engine.dart` as the only package
  consumer public import seam.
- `dart run tool/guardrails/run.dart` as the only project-owned guardrail
  execution seam for developers and CI.

Both seams must be created once and protected by tests in this step.

### Dependency Direction

- Root public barrel -> `lib/src/api/**` exports only.
- `lib/src/api/**` -> Dart SDK and Flutter SDK public types only; no concrete
  `src/store`, `src/edit`, `src/frame`, `src/interaction`, `src/resources`,
  `src/codec`, `src/diagnostics`, or legacy dependencies.
- `lib/src/runtime/runtime_root.dart` -> internal composition placeholders only;
  it must not depend on legacy paths or expose runtime internals publicly.
- `test/guardrails/**` -> may import or execute `tool/guardrails/**`.
- Production `lib/**` -> must not import `tool/**`, another package's `src/**`,
  or legacy package/runtime paths.
- CI -> uses the public guardrail runner and repository analysis commands
  instead of duplicating guardrail logic in workflow shell.

### State and Data Ownership

No durable runtime state is introduced in P0. Public API DTO and port
declarations are shape-only skeletons. Runner metadata owns guardrail ids,
suite membership, command dispatch data, and changed-path impact metadata. The
public exported-name inventory remains owned by
`docs/_registry/public_api_v1.yaml`; implementation must not duplicate it as a
second canonical list.

### Public API Compatibility

The public contract owner is `lib/iwb_canvas_engine.dart` plus
`lib/src/api/**`, governed by `docs/_registry/public_api_v1.yaml` for exported
names. P0 is a breaking new-package public API creation relative to the legacy
package because the architecture overview explicitly rejects API compatibility
with the legacy engine. No migration shim or compatibility facade is shipped in
this package; app-level migration remains outside `iwb_canvas_engine`.

The versioning note for P0 is that the root package remains pre-1.0 at the
existing `0.1.0` package version while the v1 API contract is being built and
frozen by later phases. Registry handling is parity-only in this step: the
implementation must use `docs/_registry/public_api_v1.yaml` as the source of
truth for exported names and must not edit it unless P0 evidence proves the
registry itself is missing an already documented P0 public name. Public contract
proof is P1, P2, P3, and the public API portions of P9.

### Entry and Exit Boundaries

- External package consumers enter through
  `package:iwb_canvas_engine/iwb_canvas_engine.dart` only.
- Developers and CI enter hard-boundary checks through
  `dart run tool/guardrails/run.dart`.
- `--guardrail=<id>` exits after the selected guardrail result.
- `--changed` exits through the full blocking suite whenever changed files
  cannot be confidently mapped by runner-owned impact metadata.
- Public API compile fixtures under `test/api_contract/fixtures/**` model
  external consumers and may import only the public barrel.

### Verification Strategy

Use analyzer-backed or parsed-AST guardrails where structural recognition is
required, registry parity where the source of truth is already structured, and
Dart tests where the proof is compile or runner behavior. Final implementation
verification must include `dart analyze`, `dcm analyze .`,
`dcm calculate-metrics .`, and `dart run tool/guardrails/run.dart`.

### Decision Ledger

| ID | Decision | Owner | Proof |
|---|---|---|---|
| D1 | The only public import seam is the root barrel exporting `lib/src/api/**` declarations listed by `docs/_registry/public_api_v1.yaml`. | `lib/iwb_canvas_engine.dart`, `lib/src/api/**` | P1, P2, P9 |
| D2 | P0 creates exactly one production `RuntimeRoot` declaration and keeps it internal. | `lib/src/runtime/runtime_root.dart` | P5, P9 |
| D3 | Hard-boundary guardrails are implemented as project-owned checks dispatched through one runner. | `tool/guardrails/**`, `test/guardrails/**` | P3, P4, P7, P9 |
| D4 | Changed-aware guardrail routing is conservative and widens to the full blocking suite when impact metadata is incomplete. | `tool/guardrails/**` | P7, P9 |
| D5 | Root CI invokes repository-owned checks and does not duplicate guardrail logic. | `.github/workflows/**` | P8, P9 |

### Rejected Alternatives

- Do not copy or wrap the legacy package layout. The architecture overview makes
  legacy code a functional oracle only.
- Do not export internal runtime, frame, store, interaction, resource, codec, or
  diagnostic implementation files from the public barrel.
- Do not implement guardrails as prose-only checklist items or workflow-local
  shell snippets; the repository-owned runner is the guardrail seam.
- Do not make `--changed` skip unmapped checks. Until impact metadata is
  complete, uncertain routing must widen to the full blocking suite.
- Do not add placeholder runtime behavior to satisfy public exports. P0 must
  stop at compileable skeleton declarations and hard-boundary enforcement.

## 4. Execution Guardrails

### Required Order

1. Add the public export and public type completeness tests first, while the
   root public barrel is still incomplete, so they can prove the intended
   failure before the skeleton closes.
2. Add minimal public API skeleton files and the root barrel until
   `api.public_exports_complete` and `api.public_types_complete` pass.
3. Add core import, legacy-shape, retired-shape, part-file,
   single-runtime-root, and diagram presence guardrails.
4. Add the guardrail runner, metadata, selection modes, and conservative
   `--changed` fallback.
5. Add the root CI target after the local runner command is green.
6. Run final broad verification.

### Cross-Slice Constraints

- Every guardrail id introduced in runner metadata must correspond to an
  executable check or delegated Dart test before the blocking suite can pass.
- Runner metadata must inventory every mandatory guardrail id from
  `docs/verification/guardrails.md` and `docs/_registry/sections.yaml`. P0
  blocking execution runs the P0 hard-boundary subset from this contract; later
  phase guardrails may be present only with explicit deferred phase ownership
  and must not be silently omitted from the metadata inventory.
- Public API skeleton declarations may be minimal but must compile and must not
  depend on legacy symbols, internal runtime classes, or another package's
  `src/**`.
- `PUBLIC_API_CHANGE` closes only when the public owner, compatibility decision,
  versioning note, registry parity, public export proof, and public signature
  proof are all satisfied.
- Guardrail checks must use the patterns selected in
  `docs/verification/guardrail_design_patterns.md` for each P0 guardrail.
- Tests must exercise the same runner command path that CI uses for the
  blocking suite and selected guardrail execution.

### Seam Migration

| Seam | Migration order | References to move or create | Closure gate |
|---|---|---|---|
| Root public package import seam | Create `lib/src/api/**`, then export through `lib/iwb_canvas_engine.dart`, then prove the effective public namespace through public API guardrails. | `lib/iwb_canvas_engine.dart`, `test/api_contract/**`, `docs/_registry/public_api_v1.yaml` | `api.no_legacy_public_types`, `api.public_exports_complete`, `api.public_types_complete`, `core.no_scene_controller_shape_dependency`, and `core.no_node_spec_patch_shape_dependency` pass with no legacy public exports or retired public API shapes. |
| Guardrail execution seam | Implement check logic and metadata, then runner selection, then CI invocation. | `tool/guardrails/**`, `test/guardrails/**`, `.github/workflows/**` | `dart run tool/guardrails/run.dart` and explicit P0 `--guardrail=<id>` selections pass locally and are invoked by CI. |

No existing root-package consumers require code migration because the root
`lib/**` package skeleton is empty before P0. This contract creates shared
seams and migrates future P0 proof entrypoints onto them; it does not retire an
existing repository-owned shared seam, so no retired-seam negative proof is
required.

### Forbidden Moves

- Do not import from `legacy/**` or depend on legacy package names in
  production `lib/**`.
- Do not create `part` or `part of` directives in production code unless an
  explicit generated-code approval list is added and tested.
- Do not put app adapters, legacy facade classes, or public schema v7 entry
  points in the root package.
- Do not make CI the owner of guardrail ids, suite membership, or changed-path
  impact metadata.
- Do not weaken DCM or analyzer configuration to make the empty skeleton pass.

### Deferred Broad Verification

No broad runtime, Flutter surface, codec, resource, edit, frame, spatial, or
benchmark verification is required in P0 because those implementations are out
of scope. P0 must still leave the final broad repository checks green for the
files it introduces.

## 5. Proof Plan

### P1. Public export inventory completeness

Proves the root public barrel exports every name listed in
`docs/_registry/public_api_v1.yaml`.

```sh
dart test test/api_contract/public_exports_complete_test.dart
```

Expected signal: the test fails before the public skeleton is complete and
passes after `lib/iwb_canvas_engine.dart` exports the complete skeleton.

### P2. Public signature type completeness

Proves every public signature exposed by the root barrel references defined
public types or approved SDK/Flutter types.

```sh
dart test test/api_contract/public_types_complete_test.dart
```

Expected signal: the test fails on undefined public signature references and
passes after the P0 public declarations are self-contained.

### P3. API legacy public type rejection

Proves legacy public symbols are not exported through the root package public
barrel.

```sh
dart test test/api_contract/no_legacy_public_symbols_test.dart
```

Expected signal: the test rejects `SceneController`, `SceneSnapshot`,
`NodeSpec`, `NodePatch`, `PatchField`, `SceneWriteTxn`, and schema v7 public
entrypoints in the effective public namespace.

### P4. Core boundary guardrails

Proves production source paths obey P0 import, legacy, retired-shape, and
`part` boundaries.

```sh
dart test test/guardrails/import_boundaries_test.dart
```

Expected signal: the test rejects legacy imports, another package's `src/**`
imports, forbidden internal dependency directions, unapproved production
`part` / `part of` directives, `SceneController` shape dependency, and
`NodeSpec` / `NodePatch` / `PatchField` shape dependency.

### P5. Single runtime root

Proves there is exactly one production `RuntimeRoot`.

```sh
dart test test/guardrails/single_runtime_root_test.dart
```

Expected signal: the test finds one production `RuntimeRoot` declaration and
rejects zero or duplicate production runtime roots.

### P7. Guardrail runner behavior

Proves the repository-owned runner executes the P0 hard-boundary blocking
suite, inventories later mandatory guardrails with explicit deferred phase
ownership, supports explicit guardrail selection, and widens incomplete
changed-path routing to the blocking suite.

```sh
dart test test/guardrails/blocking_suite_test.dart
```

Expected signal: the test passes only when runner metadata covers all P0
mandatory guardrails, inventories later mandatory guardrails with explicit
deferred phase ownership, `--guardrail=<id>` dispatches a single selected P0
guardrail, and `--changed` cannot silently skip unmapped hard-boundary checks.

### P8. Root CI target

Proves root-package CI invokes repository-owned checks, including the guardrail
runner, instead of duplicating guardrail logic.

```sh
dart test test/guardrails/root_ci_target_test.dart
```

Expected signal: the test finds a root workflow that runs package setup,
analysis, and `dart run tool/guardrails/run.dart`.

### P9. Final repository checks

Proves the P0 code change is clean under the repository-required broad checks.

```sh
dart analyze
dcm analyze .
dcm calculate-metrics .
dart run tool/guardrails/run.dart
```

Expected signal: every command exits successfully from the repository root.

## 6. Vertical Slices

### Slice 1. [x] Public API skeleton and completeness guardrails

#### Implements

D1.

#### Obligations Covered

SEAM_MIGRATION, PUBLIC_API_CHANGE

#### Files

- Primary public API proof:
  `test/api_contract/public_exports_complete_test.dart` — verifies root barrel
  export names against `docs/_registry/public_api_v1.yaml`.
- Primary public type proof:
  `test/api_contract/public_types_complete_test.dart` — verifies exported
  signatures do not reference undefined public types.
- Public barrel:
  `lib/iwb_canvas_engine.dart` — exports only public API skeleton files under
  `lib/src/api/**`.
- Public API skeleton owners:
  `lib/src/api/**` — compileable declarations for the names in
  `docs/_registry/public_api_v1.yaml`, with no runtime behavior beyond shape.
- Fixture/support role:
  `test/support/**` — shared analyzer or fixture helpers only if needed by both
  public API checks.
- Verify-only source of truth:
  `docs/_registry/public_api_v1.yaml` — exported-name inventory read by tests,
  not edited by this slice unless an already documented P0 name is missing.

#### Change

Add the public export and public type completeness tests first, then create the
minimal public API declarations and root barrel required for those tests to pass
green. The tests must use resolved public-surface or registry-parity logic
rather than root-barrel text matching alone. Keep declarations shape-only and do
not implement runtime, document, edit, codec, rendering, resource, or Flutter
behavior.

#### Proof

Run P1, P2, and P3.

#### Closure

The public barrel exports all P0 public names, exported signatures are
self-contained, and legacy public symbols are absent from the effective
namespace.

### Slice 2. [x] Core boundary and runtime-root guardrails

#### Implements

D2, D3.

#### Files

- Runtime root skeleton:
  `lib/src/runtime/runtime_root.dart` — sole production `RuntimeRoot`
  declaration with no legacy dependency.
- Core boundary proof:
  `test/guardrails/import_boundaries_test.dart` — verifies legacy imports,
  another package's `src/**`, forbidden internal dependency directions, and
  unapproved production `part` directives.
- Runtime proof:
  `test/guardrails/single_runtime_root_test.dart` — verifies exactly one
  production `RuntimeRoot`.
- Guardrail check helpers:
  `tool/guardrails/**` — reusable AST, resolver, path, or registry logic used
  by tests when needed.
#### Change

Add the internal runtime-root skeleton and executable core hard-boundary
guardrails using parsed AST, resolved identity, negative legacy shape, and
registry-parity patterns selected by the guardrail design document.

#### Proof

Run P4 and P5.

#### Closure

The tests reject forbidden production imports, legacy package dependencies,
retired shape dependencies, unapproved production `part` directives, and any
production state where `RuntimeRoot` is absent or duplicated.

### Slice 3. [x] Guardrail runner and conservative selection metadata

#### Implements

D3, D4.

#### Obligations Covered

SEAM_MIGRATION

#### Files

- Runner entrypoint:
  `tool/guardrails/run.dart` — command-line dispatcher for the blocking suite,
  suite selection, guardrail selection, and changed-path mode.
- Runner metadata and checks:
  `tool/guardrails/**` — guardrail ids, suite membership, command mapping, and
  changed-path impact metadata.
- Runner integration proof:
  `test/guardrails/blocking_suite_test.dart` — proves inventory coverage,
  dispatch behavior, and conservative changed fallback.
- Verify-only guardrail registry:
  `docs/verification/guardrails.md` — mandatory guardrail id source for runner
  inventory.
- Verify-only section registry:
  `docs/_registry/sections.yaml` — section-owned guardrail id source for runner
  inventory and deferred phase ownership.

#### Change

Create the project-owned guardrail runner seam. The runner dispatches existing
proof commands and check functions, supports `--guardrail=<id>`, inventories
all mandatory guardrails from the registry with later-phase guardrails marked as
deferred, and makes `--changed` fall back to the blocking suite when impact
metadata does not confidently cover a changed path.

#### Proof

Run P7 and representative explicit selections:

```sh
dart run tool/guardrails/run.dart --guardrail=api.public_exports_complete
dart run tool/guardrails/run.dart --guardrail=core.import_boundaries
dart run tool/guardrails/run.dart --guardrail=core.no_scene_controller_shape_dependency
dart run tool/guardrails/run.dart --guardrail=core.no_node_spec_patch_shape_dependency
dart run tool/guardrails/run.dart --guardrail=core.single_runtime_root
```

Expected signal: each selected command exits successfully and runs only the
selected guardrail path.

#### Closure

The P0 blocking suite, mandatory-id inventory, and explicit P0 guardrail
selections work through `tool/guardrails/run.dart`, and incomplete changed-path
impact metadata cannot skip hard-boundary proof.

### Slice 4. [x] Root package CI target

#### Implements

D5.

#### Files

- CI workflow:
  `.github/workflows/root_package.yml` — root-package workflow that runs setup,
  analysis, and the guardrail runner.
- CI structural proof:
  `test/guardrails/root_ci_target_test.dart` — verifies the workflow invokes
  repository-owned commands.

#### Change

Add the CI target after local guardrail runner proof is green. The workflow must
call repository-owned commands and must not duplicate guardrail ids or suite
membership in workflow-local shell.

#### Proof

Run P8.

#### Closure

The root workflow exists, invokes the repository-owned guardrail runner, and
keeps guardrail ownership in `tool/guardrails/**`.

### Slice 5. [x] Final P0 closure

#### Implements

D1, D2, D3, D4, D5.

#### Obligations Covered

SEAM_MIGRATION, PUBLIC_API_CHANGE

#### Files

- Finalization owner:
  `PLAN.md` — mark Step 1 complete only when all P0 implementation proof has
  passed.
- Finalization owner:
  `plan/step_1_package_skeleton_and_hard_boundaries.md` — mark slice checkboxes
  complete with evidence from the implementation change.
- Verify-only implementation files:
  `lib/**`, `test/**`, `tool/**`, `.github/workflows/**` — surfaces covered by
  the final proof set.

#### Change

Run the full P0 proof set after all implementation slices have closed and update
the roadmap checkboxes in the same implementation change.

#### Proof

Run P9.

#### Closure

All P0 guardrails pass through the runner, broad repository checks pass, the
public barrel and guardrail runner seams are protected, and Step 1 is marked
complete in both `PLAN.md` and this step document.

## 7. Final Gate

### Run Proof Set

P1, P2, P3, P4, P5, P7, P8, and P9 must pass from the repository root
before Step 1 can be marked complete.

### Done When

- D1, D2, D3, D4, and D5 have passing proof through the active P0 proof set;
- `SEAM_MIGRATION` and `PUBLIC_API_CHANGE` are satisfied by their listed slice
  closures and proof IDs;
- no out-of-scope runtime, donor, codec, rendering, resource, edit, spatial, or
  Flutter behavior was implemented;
- no out-of-scope files were changed;
- whitespace validation passes.
