# P0 - package skeleton and hard boundaries

## Build

- create packages/iwb_canvas_engine_next
- create public barrel exporting only src/api/**
- add old-public-symbol ban guardrail
- add no-old-import guardrail
- add RuntimeRoot skeleton
- add diagram file placeholders
- add CI target for new package
- add failing public_types_defined_test.

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
- `new_api.no_old_public_types` - old public golden symbols not exported by new package
- `new_core.no_legacy_imports` - no import of old package/runtime
- `new_core.no_node_spec_patch_shape_dependency` - no old NodeSpec/NodePatch/PatchField in core
- `new_core.no_scene_controller_shape_dependency` - no SceneController concept in core
- `new_core.single_runtime_root` - exactly one production RuntimeRoot

## Tests

- `test.api_contract.no_old_public_symbols` -> `test/api_contract/no_old_public_symbols_test.dart`
- `test.diagrams.required_present` -> `required Mermaid files present tests`
- `test.guardrails.blocking_suite` -> `blocking guardrail suite`

## Exit gate

- new package builds empty public API skeleton
- old package not imported
- old public symbols not exported
- all required public type names have files.
