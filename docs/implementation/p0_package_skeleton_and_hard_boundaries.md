# P0 - package skeleton and hard boundaries

## Build

- populate the existing repository-root package skeleton
- create public barrel exporting only src/api/**
- add `api.no_legacy_public_types` guardrail
- add `core.no_legacy_imports` guardrail
- add RuntimeRoot skeleton
- add diagram file placeholders
- add CI target for the root package
- add `api.public_types_complete` guardrail test first, then close with it green.

## Read first

- `section_00_status_and_scope` -> `docs/architecture/00_architecture_overview.md`
- `section_02_architecture_model` -> `docs/architecture/01_runtime_ownership.md`
- `section_03_package_layout` -> `docs/architecture/02_package_boundaries.md`
- `section_22_guardrails_machine_checks` -> `docs/verification/guardrails.md`

## Required donors

- none

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

## Guardrails

- `diagrams.all_required_present` - required Mermaid files exist
- `api.no_legacy_public_types` - legacy public golden symbols not exported by root package
- `core.no_legacy_imports` - no import of legacy package/runtime
- `core.import_boundaries` - package-owned source paths obey the forbidden import matrix
- `core.no_node_spec_patch_shape_dependency` - no legacy NodeSpec/NodePatch/PatchField in core
- `core.no_scene_controller_shape_dependency` - no SceneController concept in core
- `core.single_runtime_root` - exactly one production RuntimeRoot

## Tests

- `test.api_contract.no_legacy_public_symbols` -> `test/api_contract/no_legacy_public_symbols_test.dart`
- `test.guardrails.import_boundaries` -> `test/guardrails/import_boundaries_test.dart`
- `test.guardrails.required_diagrams_present` -> `test/guardrails/required_diagrams_present_test.dart`
- `test.guardrails.blocking_suite` -> `test/guardrails/blocking_suite_test.dart`

## Exit gate

- root package builds empty public API skeleton
- legacy package not imported
- forbidden `lib/src/**` import boundaries are enforced
- legacy public symbols not exported
- all required public type names have files.
