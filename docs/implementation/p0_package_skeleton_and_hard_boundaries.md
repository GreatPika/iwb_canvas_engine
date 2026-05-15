# P0 - package skeleton and hard boundaries

## Purpose

Create the root package skeleton and machine-enforced boundaries before any
runtime, API, donor, codec, or Flutter implementation can land.

## Build scope

- populate the existing repository-root package skeleton
- create public barrel exporting only `src/api/**`
- add `api.no_legacy_public_types` guardrail
- add `api.public_exports_complete` guardrail
- add `api.public_types_complete` guardrail
- add `core.no_legacy_imports` guardrail
- add `core.no_unapproved_part_files` guardrail
- add `RuntimeRoot` skeleton
- add diagram file placeholders
- add the minimal `tool/guardrails/run.dart` entrypoint
- add runner metadata for hard-boundary guardrails
- support full guardrail run and explicit `--guardrail=<id>` selection
- allow `--changed` to fall back to the full blocking suite until impact
  metadata is complete
- add CI target for the root package
- add `api.public_exports_complete` and `api.public_types_complete` guardrail
  tests first, then close with them green.

## Dependencies on earlier phases

- none.

## Read first

- `section_00_status_and_scope` -> `docs/architecture/00_architecture_overview.md`
- `section_02_architecture_model` -> `docs/architecture/01_runtime_ownership.md`
- `section_03_package_layout` -> `docs/architecture/02_package_boundaries.md`
- `section_22_guardrails_machine_checks` -> `docs/verification/guardrails.md`

## Required donors

- none.

## Forbidden donor structure

- `avoid_scene_controller_facades` - decision: `avoid`
- `avoid_interactive_runtime_whole` - decision: `avoid`
- `avoid_scene_builder_public_architecture` - decision: `avoid`
- `avoid_scene_codec_whole` - decision: `avoid`
- `avoid_scene_store_controller_whole` - decision: `avoid`

## Diagrams to read or update

- `c4_context` -> `docs/diagrams/c4_context.mmd`
- `c4_container` -> `docs/diagrams/c4_container.mmd`
- `c4_component_runtime` -> `docs/diagrams/c4_component_runtime.mmd`

## Contracts satisfied by this phase

- package ownership and public-barrel boundary from `section_03_package_layout`
- no legacy facade, no legacy imports, and no legacy public API exports from
  `section_00_status_and_scope`
- one production `RuntimeRoot` owner from `section_02_architecture_model`
- blocking guardrail suite presence from `section_22_guardrails_machine_checks`

## Tests and guardrails that prove this phase

- `test.api_contract.no_legacy_public_symbols` -> `test/api_contract/no_legacy_public_symbols_test.dart`
- `test.guardrails.import_boundaries` -> `test/guardrails/import_boundaries_test.dart`; also enforces no imports from another package's `src/**` and no unapproved production `part` / `part of` directives
- `test.guardrails.required_diagrams_present` -> `test/guardrails/required_diagrams_present_test.dart`
- `test.guardrails.blocking_suite` -> `test/guardrails/blocking_suite_test.dart`
- `dart run tool/guardrails/run.dart` -> full blocking guardrail suite
- `dart run tool/guardrails/run.dart --guardrail=core.import_boundaries`
- `diagrams.all_required_present`
- `api.no_legacy_public_types`
- `api.public_exports_complete`
- `api.public_types_complete`
- `core.no_legacy_imports`
- `core.import_boundaries`
- `core.no_unapproved_part_files`
- `core.no_node_spec_patch_shape_dependency`
- `core.no_scene_controller_shape_dependency`
- `core.single_runtime_root`

## Exit gate

- root package builds empty public API skeleton
- legacy package not imported
- forbidden `lib/src/**` import boundaries are enforced
- production `lib/**` contains no unapproved `part` or `part of` directives
- legacy public symbols not exported
- all required public names are exported by the public barrel and all public
  signatures reference defined public types.
- guardrail runner full run and explicit hard-boundary guardrail selection work.

## Risks and trade-offs

- A too-large skeleton would invite placeholder architecture. Keep this phase to
  package shape, boundaries, and guardrail wiring only.
- A too-small skeleton would let later phases introduce boundary drift before
  checks exist. Boundary tests must land before feature implementation.
- Early changed-aware routing can be incomplete. It must fall back to the full
  blocking suite rather than skipping an unmapped hard-boundary proof.

## Why this phase belongs here

Every later phase depends on package identity, public export shape, import
rules, required diagram placeholders, and the single runtime-root boundary.
Those constraints must be executable before donor code or runtime behavior is
introduced.
