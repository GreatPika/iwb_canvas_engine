# Change Contract: Root Package Layout Migration

## 1. Change Mandate

Promote the new engine from `next/iwb_canvas_engine_next/` into the repository root so the repository presents a standard `iwb_canvas_engine` package layout while `legacy/iwb_canvas_engine/` remains a temporary, separately runnable oracle until deletion.

## 2. Change Boundary

### Included in the Change

- Move the new-engine package ownership from `next/iwb_canvas_engine_next/` to the repository root.
- Rename the new engine package from `iwb_canvas_engine_next` to `iwb_canvas_engine`.
- Keep legacy source under `legacy/iwb_canvas_engine/` and preserve it as a runnable oracle/donor package during the transition.
- Update root package metadata, workspace configuration, documentation paths, documentation tooling, agent guidance, and verification commands so they describe the new root-owned package.
- Add structural verification that prevents `next/` from reappearing as a new-engine implementation or documentation owner.
- Add structural verification that prevents the new root package from importing `legacy/**`.

### Not Included in the Change

- Do not port additional engine behavior from legacy.
- Do not change the target architecture contracts except where path and package-name references must be updated.
- Do not delete `legacy/` in this migration.
- Do not keep a compatibility package named `iwb_canvas_engine_next`.
- Do not create root-level transition notes outside `plan/`.

## 3. Surrounding Code Review

### Inspected Artifacts

- `AGENTS.md` — currently defines the repository root as a workspace/control layer and names `next/iwb_canvas_engine_next/` as the only new-engine implementation and documentation owner.
- `pubspec.yaml` — currently names the root package `iwb_canvas_engine_workspace` and lists `legacy/iwb_canvas_engine`, `legacy/iwb_canvas_engine/example`, and `next/iwb_canvas_engine_next` as workspace members.
- `legacy/iwb_canvas_engine/pubspec.yaml` — the legacy package is currently named `iwb_canvas_engine` and uses `resolution: workspace`, which must be removed when legacy leaves the root workspace.
- `legacy/iwb_canvas_engine/example/pubspec.yaml` — the legacy example depends on the legacy package by `path: ../` and uses `resolution: workspace`, which must be removed when legacy leaves the root workspace.
- `next/iwb_canvas_engine_next/pubspec.yaml` — the new package is currently named `iwb_canvas_engine_next`, uses `resolution: workspace`, and carries the dependency set required by the new root package.
- `next/iwb_canvas_engine_next/docs/` — current new-engine documentation owner, including architecture, contracts, implementation, verification, donors, diagrams, registries, and docs tooling.
- `next/iwb_canvas_engine_next/docs/tool/check_docs.dart` — current documentation structural check; it assumes it runs from `next/iwb_canvas_engine_next/` and requires `../../plan`.
- `analysis_options.yaml` — root analysis rules already define the strict analyzer and DCM policy intended for root-owned Dart code.
- `dart_test.yaml` — root test configuration currently defines the `tool` tag.
- `plan/01_documentation_architecture_reorganization_contract.md` — existing root Change Contract precedent and naming pattern.
- `dart pub workspace list` output — confirms the current root workspace contains four packages: root workspace package, legacy package, legacy example, and next package.

### Current Entry Path

- New-engine package commands currently enter through `cd next/iwb_canvas_engine_next` and then run package-local commands such as `dart run docs/tool/check_docs.dart`.
- Workspace commands currently enter through the repository root with `flutter pub get`, `dart pub workspace list`, and `dart analyze`.
- Legacy oracle commands currently enter through `legacy/iwb_canvas_engine/` or `legacy/iwb_canvas_engine/example/`.

### Current Owner

- `next/iwb_canvas_engine_next/` currently owns the new engine package metadata and all new-engine documentation.
- The repository root currently owns workspace configuration, global analysis/test config, `AGENTS.md`, and root `plan/`.
- `legacy/iwb_canvas_engine/` owns the old engine package and must remain isolated from new-engine implementation.

### Adjacent Abstractions

- Root `plan/` is already the workspace-level planning and audit-trail owner.
- Root `analysis_options.yaml` and `dart_test.yaml` are already workspace-level mechanical rule owners.
- `next/iwb_canvas_engine_next/docs/_registry/` is the current documentation coverage registry owner.
- `next/iwb_canvas_engine_next/docs/tool/check_docs.dart` is the current documentation structural verification owner.

### Existing Tests

- `dart run docs/tool/check_docs.dart`, when run from the current next package, checks documentation entrypoints, registries, diagram catalog symmetry, retired references, and semantic documentation probes.
- `dart analyze` from the repository root currently verifies the workspace packages under root analysis rules.
- There are no committed `lib/` or `test/` directories under `next/iwb_canvas_engine_next/` at inspection time; implementation movement is currently package metadata and documentation movement, not source code movement.

### Analogous Implementation Path

- `plan/01_documentation_architecture_reorganization_contract.md` is the closest precedent: it treats root `plan/` as the place for workspace-level contracts while keeping target-engine documentation under the package that owns the engine.
- `next/iwb_canvas_engine_next/docs/tool/check_docs.dart` is the closest mechanical precedent for enforcing documentation structure instead of relying on prose.

### Governing Repository Rules

- `AGENTS.md` requires new-engine artifacts to live under the new-engine owner and root `plan/` to remain workspace-level Change Contracts.
- `AGENTS.md` prohibits the new engine from importing the legacy package or any `legacy/**` source.
- `AGENTS.md` permits legacy changes only when explicitly requested or required to keep the moved legacy package runnable after workspace layout work.
- Root language policy requires durable project documentation in English and user-facing chat in Russian.
- Root file ownership currently limits root files to workspace/control artifacts; this rule must be replaced by root package ownership rules in the migration.

### Rejected Misleading Local Patterns

- Keeping root as `iwb_canvas_engine_workspace` with new-engine `lib/` placed beside it is rejected because the public package name would remain a workspace/control artifact instead of the engine.
- Keeping `next/iwb_canvas_engine_next/` as a nested package while adding forwarding files in root is rejected because it creates two apparent sources of truth.
- Renaming `legacy/iwb_canvas_engine/` to a different package name is rejected for this migration because preserving the legacy package's old public identity makes it a better oracle.
- Keeping legacy as a root workspace member after the root package is renamed to `iwb_canvas_engine` is rejected because it would place two packages with the same name in the same workspace.

## 4. Architecture

### 4A. Locked Architectural Form

#### Problem Ownership Level

- This is a repository layout and package ownership migration.

#### Selected Architectural Form

- The repository root becomes the canonical `iwb_canvas_engine` package.
- New-engine package files currently under `next/iwb_canvas_engine_next/` move to root-owned standard package paths:
  - `next/iwb_canvas_engine_next/pubspec.yaml` becomes the basis for root `pubspec.yaml`.
  - `next/iwb_canvas_engine_next/docs/` moves to `docs/`.
  - Future or existing `next/iwb_canvas_engine_next/lib/`, `test/`, and `tool/` paths move to root `lib/`, `test/`, and `tool/` if present at implementation time.
- `next/` is retired after the move.
- `legacy/iwb_canvas_engine/` remains under `legacy/` and is no longer a member of the root package workspace during the transition.

#### Owning Layer or Module

- The repository root owns the new engine package.
- `docs/` owns target architecture, subsystem contracts, implementation phases, verification, donor records, diagrams, registries, and documentation tooling.
- `plan/` remains the only root-level workspace planning and Change Contract area.
- `legacy/iwb_canvas_engine/` remains an isolated legacy oracle/donor package.

#### Dependency Direction

- Root package code, tests, root tooling, docs tooling, and package metadata may reference `docs/`, `plan/`, and package-local root files.
- Root package code and tests must not import or depend on `legacy/**`.
- Documentation may reference `legacy/**` as oracle/donor evidence.
- Legacy package and legacy example must not depend on root package metadata through workspace membership during the transition; they run as isolated packages from their own directories after `resolution: workspace` is deleted from both legacy pubspec files.

#### State and Data Ownership

- Root `pubspec.yaml` owns the canonical package name `iwb_canvas_engine`, version, environment, dependencies, dev dependencies, and package metadata for the new engine.
- `legacy/iwb_canvas_engine/pubspec.yaml` owns legacy package metadata while the legacy oracle exists.
- Root `pubspec.lock` and `.dart_tool/` are regenerated for the root package after dependency resolution.
- Legacy lock/config files are generated only by legacy-local commands and are not the source of truth for the new engine.

#### Entry and Exit Boundaries

- Entry boundary for new-engine development: repository root.
- Entry boundary for target documentation: `docs/README.md`.
- Entry boundary for Change Contracts: `plan/`.
- Entry boundary for legacy oracle checks: `legacy/iwb_canvas_engine/` or `legacy/iwb_canvas_engine/example/`.
- Exit boundary for migration completion: `next/` does not exist, root commands analyze and verify the new package, and legacy remains runnable through explicit legacy-local commands.

#### Permitted Extension Seam

- Add future new-engine source, tests, tools, and docs directly under root package paths.
- Add future transition contracts under root `plan/`.
- Add legacy oracle checks under `legacy/iwb_canvas_engine/` only when they verify old behavior or keep legacy runnable after layout changes.

#### Rejected Alternatives

- Root package named `iwb_canvas_engine_next` — rejected because the user explicitly wants no visible "next" label after the layout migration.
- Root package named `iwb_canvas_engine_workspace` with `lib/` added — rejected because it makes the root package identity a control-layer artifact rather than the product package.
- Keeping `next/` as an implementation container — rejected because it preserves the transitional shape the migration is intended to remove.
- Keeping duplicate `iwb_canvas_engine` packages in one root workspace — rejected because package identity becomes ambiguous and workspace resolution cannot be the durable owner boundary.
- Moving legacy into a renamed or nested compatibility package — rejected because this migration should not refactor legacy beyond the minimum needed to keep it runnable.

#### Why This Level Is Correct

- The defect is not in a source file; it is the repository's public shape and package ownership.
- The desired end state is a standard package at the repository root, so the owning layer must be root package metadata and root paths.
- Keeping legacy outside root workspace membership avoids public package-name conflict while preserving the old package as oracle evidence.

## 5. Locked Decisions

1. The new engine package name becomes `iwb_canvas_engine` during this migration.
2. Root `pubspec.yaml` is rewritten from workspace-only metadata into the canonical package pubspec.
3. The root package does not keep `iwb_canvas_engine_next` as a package name, import prefix, documentation identity, or compatibility package.
4. `next/iwb_canvas_engine_next/docs/` moves to root `docs/`.
5. Any existing new-engine `lib/`, `test/`, and package-local `tool/` directories under `next/iwb_canvas_engine_next/` move to root if they exist when the migration is implemented.
6. `legacy/iwb_canvas_engine/` remains in place and keeps its legacy package identity while it is still needed as an oracle.
7. Legacy is removed from root workspace membership to avoid duplicate `iwb_canvas_engine` package names.
8. Root `pubspec.yaml` has no `workspace:` block after promotion unless a later contract adds a non-legacy workspace member.
9. Delete `resolution: workspace` from promoted root `pubspec.yaml`; the donor `next/iwb_canvas_engine_next/pubspec.yaml` currently has this field, but the promoted root package is not workspace-resolved.
10. Delete `resolution: workspace` from `legacy/iwb_canvas_engine/pubspec.yaml`.
11. Delete `resolution: workspace` from `legacy/iwb_canvas_engine/example/pubspec.yaml`.
12. Root docs tooling is updated to run from the repository root and to require `plan/`, not `../../plan`.
13. `tool/check_root_package_layout.dart` is the owner of root package layout structural verification.
14. `tool/check_root_package_layout.dart` supports exactly two modes: `--pre-retirement` and `--final`.
15. Run pre-retirement structural verification with `dart run tool/check_root_package_layout.dart --pre-retirement`.
16. Run final structural verification with `dart run tool/check_root_package_layout.dart --final`.
17. Root `AGENTS.md` is updated in the same migration so future agents treat root as the new engine owner.
18. Final structural verification must fail if `next/` remains after the migration.
19. Both structural verification modes must fail if root package implementation imports `legacy/**`.

## 6. Result Requirements

1. A developer opening the repository sees a normal `iwb_canvas_engine` package at the root.
2. There is no `next` label in package identity, package path, root documentation entrypoints, or new-engine command instructions.
3. The legacy package remains available as old-behavior evidence until a later explicit deletion.
4. Root commands verify the new engine without requiring `cd next/iwb_canvas_engine_next`.
5. Legacy commands are explicit and local to `legacy/iwb_canvas_engine/` or `legacy/iwb_canvas_engine/example/`.
6. Documentation and agent guidance describe root package ownership and legacy isolation consistently.
7. Mechanical checks detect stale `next/iwb_canvas_engine_next` path references outside approved historical Change Contracts.
8. Mechanical checks detect any root implementation dependency on `legacy/**`.

## 7. Execution Order and Gates

### Required Order

- Inventory current `next/iwb_canvas_engine_next/` paths immediately before edits; include `lib/`, `test/`, and `tool/` only if present.
- Add `tool/check_root_package_layout.dart` before treating the migration as complete; use `--pre-retirement` before deleting `next/` and `--final` after deleting `next/`.
- Move package metadata and package-local files from `next/iwb_canvas_engine_next/` to root.
- Remove transitional root workspace membership before root dependency resolution, because root and legacy both use package name `iwb_canvas_engine` after promotion.
- Isolate legacy package resolution and keep legacy-local commands runnable.
- Rewrite documentation, registries, diagrams, docs tooling, and agent guidance from nested next paths to root paths.
- Remove `next/` only after moved files, updated references, and checks pass.
- Run final root verification after all path references and workspace changes are complete.

### Successor Seam and Retirement Gates

- Successor package seam: repository root replaces `next/iwb_canvas_engine_next/`.
- Successor documentation seam: root `docs/` replaces `next/iwb_canvas_engine_next/docs/`.
- Successor docs check seam: root `docs/tool/check_docs.dart` replaces `next/iwb_canvas_engine_next/docs/tool/check_docs.dart`.
- Legacy execution seam: legacy-local package commands replace root workspace membership for legacy checks.
- `next/` retirement gate: no required source, test, tool, docs, registry, or command reference remains under `next/`.
- Workspace retirement gate: root `pubspec.yaml` has no `workspace:` block after promotion; root package verification replaces `dart pub workspace list` as the source of truth.

### Deferred Broad Verification

- Full root `flutter pub get`, root `dart analyze`, root docs check, and root test suite are reserved for the final gate after dependency, workspace-membership, and path migration is complete.
- Legacy `flutter pub get` and `flutter analyze` are reserved for the final gate after legacy workspace isolation is complete.

## 8. File Map

### Implementation Files

- `pubspec.yaml`
- `pubspec.lock`
- `analysis_options.yaml`
- `dart_test.yaml`
- `lib/**` if present under `next/iwb_canvas_engine_next/` at implementation time
- `tool/check_root_package_layout.dart`
- other `tool/**` files if present under `next/iwb_canvas_engine_next/` at implementation time
- `docs/tool/check_docs.dart`
- `docs/tool/generate_context_capsules.dart`
- `legacy/iwb_canvas_engine/pubspec.yaml`
- `legacy/iwb_canvas_engine/example/pubspec.yaml`

### Test Files

- `test/**` if present under `next/iwb_canvas_engine_next/` at implementation time
- `test/guardrails/import_boundaries_test.dart` if created by the package skeleton slice before or during this migration

### Fixtures and Supporting Data

- `docs/diagrams/**`
- `docs/_registry/**`
- `docs/indexes/**`
- Existing generated package configuration under `.dart_tool/` is not edited manually and must be regenerated by package commands.

### Registry, Inventory, and Workflow Files

- `AGENTS.md`
- `docs/README.md`
- `docs/architecture/**`
- `docs/contracts/**`
- `docs/implementation/**`
- `docs/verification/**`
- `docs/donors/**`
- `docs/_registry/sections.yaml`
- `docs/_registry/donors.yaml`
- `docs/indexes/**`
- `plan/02_root_package_layout_contract.md`

### Analysis Area

- Root package metadata and root package commands.
- Documentation path references from `next/iwb_canvas_engine_next/` to root.
- Legacy package dependency resolution after removal from root workspace membership.
- Import boundaries between root package implementation and `legacy/**`.

## 9. Implementation Rules

### Protected Invariants

- The new engine must not import the legacy package or any `legacy/**` source.
- Legacy remains old-behavior evidence and is not refactored beyond package-resolution changes required by this layout migration.
- Root `plan/` remains the only workspace-level Change Contract location.
- Durable target-engine documentation lives under root `docs/`.
- Package identity must be `iwb_canvas_engine`, not `iwb_canvas_engine_next`.
- No new-engine implementation, tests, tools, or durable docs may remain under `next/` after the retirement gate.

### Required Proof

- behavioral proof: root dependency resolution, root analysis, root docs check, and root tests where tests exist.
- behavioral proof: legacy dependency resolution and legacy analysis still run from legacy-local directories after workspace isolation.
- structural proof: `dart run tool/check_root_package_layout.dart --pre-retirement` fails on stale `next/iwb_canvas_engine_next` active references outside historical Change Contracts and outside the transitional `next/` tree.
- structural proof: `dart run tool/check_root_package_layout.dart --pre-retirement` fails when root `pubspec.yaml` contains `workspace:` or `resolution: workspace` after promotion.
- structural proof: `dart run tool/check_root_package_layout.dart --pre-retirement` fails on root implementation imports from `legacy/**`.
- structural proof: `dart run tool/check_root_package_layout.dart --final` fails when `next/` exists.
- for refactors: existing documentation checks and root package commands are characterization proof; add `tool/check_root_package_layout.dart` before accepting the move.

### Allowed Change Surface

- Root package metadata and package-local root directories.
- New-engine documentation paths moved from `next/iwb_canvas_engine_next/docs/` to `docs/`.
- Documentation tooling path assumptions.
- Root agent guidance that defines current repository ownership.
- Deleting `resolution: workspace` from `legacy/iwb_canvas_engine/pubspec.yaml` and `legacy/iwb_canvas_engine/example/pubspec.yaml`.

### Forbidden Moves

- Do not move legacy implementation into root.
- Do not make root implementation import from `legacy/**`.
- Do not leave a compatibility forwarding package under `next/`.
- Do not update legacy behavior, public API, examples, assets, or tests except for dependency-resolution changes needed by this migration.
- Do not treat historical mentions inside existing Change Contracts as active migration blockers; active docs and guidance must be updated, historical contracts may remain historical evidence.
- Do not delete `legacy/` in this migration.

## 10. Vertical Slices

### Slice 1. [ ] Lock Target Layout Checks

#### Slice Contract

Create `tool/check_root_package_layout.dart` as the mechanical check that defines the target root package layout before and after `next/` retirement.

#### Change

- Add `tool/check_root_package_layout.dart` for package layout verification.
- Make `tool/check_root_package_layout.dart --pre-retirement` fail when root package metadata is not the canonical `iwb_canvas_engine` package after promotion.
- Make `tool/check_root_package_layout.dart --pre-retirement` fail when root `pubspec.yaml` contains `workspace:` or `resolution: workspace` after promotion.
- Make `tool/check_root_package_layout.dart --pre-retirement` allow `next/` to exist only as the transitional source tree before Slice 5.
- Make `tool/check_root_package_layout.dart --final` fail when `next/` exists.
- Make both modes fail on forbidden root implementation imports from `legacy/**`.
- Make both modes allow historical references inside `plan/*.md`.
- Make `--pre-retirement` block active guidance, docs, source, tests, and tools outside `next/` from depending on `next/iwb_canvas_engine_next`.
- Make `--final` block all active guidance, docs, source, tests, and tools from depending on `next/iwb_canvas_engine_next`.

#### Behavioral Verification

- Run `dart run tool/check_root_package_layout.dart --pre-retirement` once before the move and record the expected target-layout failures.
- Run `dart run tool/check_root_package_layout.dart --final` once before the move and record that it fails because `next/` still exists.

#### Structural Verification

- `dart run tool/check_root_package_layout.dart --pre-retirement` must identify stale active `next/iwb_canvas_engine_next` references outside `next/`, root `pubspec.yaml` workspace fields after promotion, and forbidden `legacy/**` implementation imports.
- `dart run tool/check_root_package_layout.dart --final` must identify that `next/` still exists before retirement.

#### Fixtures Used

- Repository file tree.
- Active docs, package metadata, source, tests, and tools.

#### Positive Scenarios

- Root `docs/`, root `lib/`, root `test/`, and root package metadata are accepted.
- Historical references inside `plan/*.md` are accepted.

#### Negative Scenarios

- final mode: `next/iwb_canvas_engine_next/docs/README.md` remains.
- Root `lib/**` imports a file under `legacy/**`.

#### Closure Evidence

- `tool/check_root_package_layout.dart` exists, supports both required modes, and fails for the current pre-move layout for the expected mode-specific reasons.

### Slice 2. [ ] Promote Package Metadata And Files

#### Slice Contract

Make the repository root the canonical `iwb_canvas_engine` package without creating duplicate new-engine package owners.

#### Change

- Replace root workspace-only `pubspec.yaml` with the new-engine package metadata using package name `iwb_canvas_engine`.
- Remove donor workspace fields from promoted root `pubspec.yaml`: no `workspace:` and no `resolution: workspace`.
- Remove root workspace membership for `next/iwb_canvas_engine_next`, `legacy/iwb_canvas_engine`, and `legacy/iwb_canvas_engine/example` before resolving the promoted root package.
- Move current next package directories to root package paths.
- Regenerate root dependency metadata through package commands.

#### Behavioral Verification

- Run `flutter pub get` from the repository root.
- Run `dart analyze` from the repository root.

#### Structural Verification

- Run `dart run tool/check_root_package_layout.dart --pre-retirement`; package metadata checks must pass for root ownership, package name, and absence of root workspace fields while `next/` may still exist.

#### Fixtures Used

- Current `next/iwb_canvas_engine_next/pubspec.yaml`.
- Current root `pubspec.yaml`.

#### Positive Scenarios

- Root package resolves as `iwb_canvas_engine`.
- Root docs tooling is available from `docs/tool/`.

#### Negative Scenarios

- Root package remains named `iwb_canvas_engine_workspace`.
- Any package metadata still names `iwb_canvas_engine_next` as the new engine.

#### Closure Evidence

- Root package commands resolve dependencies and analyze the promoted package.

### Slice 3. [ ] Isolate Legacy Oracle

#### Slice Contract

Keep legacy runnable while preventing duplicate `iwb_canvas_engine` package ownership in the root workspace.

#### Change

- Delete `resolution: workspace` from `legacy/iwb_canvas_engine/pubspec.yaml`.
- Delete `resolution: workspace` from `legacy/iwb_canvas_engine/example/pubspec.yaml`.
- Keep `legacy/iwb_canvas_engine/` package name as `iwb_canvas_engine`.
- Keep the legacy example dependency on its adjacent legacy package.

#### Behavioral Verification

- Run `flutter pub get` from `legacy/iwb_canvas_engine/`.
- Run `flutter analyze` from `legacy/iwb_canvas_engine/` if dependencies resolve in the environment.
- Run `flutter pub get` from `legacy/iwb_canvas_engine/example/`.

#### Structural Verification

- Run `dart run tool/check_root_package_layout.dart --pre-retirement`; it must verify root implementation has no legacy imports while `next/` may still exist.
- Verify root dependency resolution does not include legacy as a workspace member.

#### Fixtures Used

- `legacy/iwb_canvas_engine/pubspec.yaml`
- `legacy/iwb_canvas_engine/example/pubspec.yaml`

#### Positive Scenarios

- Legacy package can resolve dependencies from its own directory.
- Legacy example resolves its path dependency to `legacy/iwb_canvas_engine/`.

#### Negative Scenarios

- Root workspace contains both root `iwb_canvas_engine` and legacy `iwb_canvas_engine`.
- Legacy becomes a dependency of root implementation.

#### Closure Evidence

- Legacy-local dependency resolution works and root package ownership is unambiguous.

### Slice 4. [ ] Rewrite Documentation And Guidance Paths

#### Slice Contract

Make root `docs/` and root package commands the active documentation source of truth.

#### Change

- Update `AGENTS.md` so root owns the new engine package and `legacy/` is documented as isolated oracle/donor code.
- Update docs, registries, indexes, diagrams, and docs tooling to remove active `next/iwb_canvas_engine_next` assumptions.
- Update `docs/tool/check_docs.dart` path assumptions from `../../plan` to `plan`.
- Update command examples to run from root.

#### Behavioral Verification

- Run `dart run docs/tool/check_docs.dart` from the repository root.

#### Structural Verification

- Run `rg -n "next/iwb_canvas_engine_next|iwb_canvas_engine_next" AGENTS.md docs pubspec.yaml analysis_options.yaml dart_test.yaml`; no active matches are allowed unless a specific docs contract explicitly documents retired historical naming.
- Run `dart run tool/check_root_package_layout.dart --pre-retirement`.

#### Fixtures Used

- Root `AGENTS.md`.
- Root `docs/**`.
- Root package metadata.

#### Positive Scenarios

- `docs/README.md` is the new documentation entrypoint.
- Docs checks require root `plan/`.

#### Negative Scenarios

- Active docs still instruct running commands from `next/iwb_canvas_engine_next`.
- Active docs still describe the package as `iwb_canvas_engine_next`.

#### Closure Evidence

- Documentation checks pass from root and active guidance names root as the new-engine owner.

### Slice 5. [ ] Retire Next Directory And Run Final Gate

#### Slice Contract

Delete the transitional `next/` container only after root package ownership, documentation, and legacy isolation have been verified.

#### Change

- Delete `next/` after all moved paths are verified.
- Regenerate dependency metadata where required by final package commands.

#### Behavioral Verification

- Run `flutter pub get` from root.
- Run `dart analyze` from root.
- Run `dart run docs/tool/check_docs.dart` from root.
- Run `dart test` from root if root tests exist.
- Run the legacy-local dependency and analysis commands from Slice 3.

#### Structural Verification

- Run `test ! -d next`.
- Run a stale-reference search over existing active paths only: `AGENTS.md`, `docs`, `pubspec.yaml`, `analysis_options.yaml`, `dart_test.yaml`, and existing `lib`, `test`, or `tool` directories. No active `next/iwb_canvas_engine_next` or `iwb_canvas_engine_next` matches are allowed.
- Run `dart run tool/check_root_package_layout.dart --final`.

#### Fixtures Used

- Complete repository tree after migration.

#### Positive Scenarios

- Repository root is a normal `iwb_canvas_engine` package.
- Legacy remains only under `legacy/`.

#### Negative Scenarios

- Any required new-engine file remains under `next/`.
- Any active root instruction still routes new-engine work through `next/`.

#### Closure Evidence

- `next/` is absent and all final verification commands pass or are explicitly reported with environment-specific blockers.

## 11. Final Verification

- Run `flutter pub get` from `/Users/blackpika/iwb_canvas_engine`.
- Run `dart analyze` from `/Users/blackpika/iwb_canvas_engine`.
- Run `dart run docs/tool/check_docs.dart` from `/Users/blackpika/iwb_canvas_engine`.
- Run `dart test` from `/Users/blackpika/iwb_canvas_engine` if `test/` exists.
- Run `flutter pub get` from `/Users/blackpika/iwb_canvas_engine/legacy/iwb_canvas_engine`.
- Run `flutter analyze` from `/Users/blackpika/iwb_canvas_engine/legacy/iwb_canvas_engine` if dependencies resolve in the environment.
- Run `flutter pub get` from `/Users/blackpika/iwb_canvas_engine/legacy/iwb_canvas_engine/example`.
- Run `test ! -d /Users/blackpika/iwb_canvas_engine/next`.
- Run a stale-reference search from root over existing active paths only: `AGENTS.md`, `docs`, `pubspec.yaml`, `analysis_options.yaml`, `dart_test.yaml`, and existing `lib`, `test`, or `tool` directories. No active `next/iwb_canvas_engine_next` or `iwb_canvas_engine_next` matches are allowed.
- Run `dart run tool/check_root_package_layout.dart --final`.

## 12. Acceptance Criteria

- Root `pubspec.yaml` names the package `iwb_canvas_engine`.
- Root `docs/README.md` is the target-engine documentation entrypoint.
- Root `AGENTS.md` names root as the new-engine owner and `legacy/` as isolated oracle/donor code.
- `next/` does not exist.
- New-engine source, tests, tools, and docs live only under root package paths.
- `legacy/iwb_canvas_engine/` remains present and runnable by legacy-local commands.
- Root package implementation has no imports from `legacy/**`.
- Active documentation and command examples no longer require `cd next/iwb_canvas_engine_next`.
- Final verification commands are run and their results are reported without claiming unrun checks.
