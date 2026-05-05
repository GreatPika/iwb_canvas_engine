# P1.5 - v1 scope gate before public API freeze

## Build

- scope checklist based on legacy functional behavior and approved v1 additions
- public API draft probe
- public API compiles as written.

## Read first

- `section_00_status_and_scope` -> `docs/architecture/00_architecture_overview.md`
- `section_04_public_api_v1` -> `docs/contracts/public_api_v1.md`
- `section_06_validation_limits` -> `docs/contracts/validation_limits.md`
- `section_09_accepted_differences` -> `docs/architecture/04_decisions_and_differences.md`

## Required donors

- `foundation_contract_limits` - decision: `copy/adapt`; target owner: Validation limits and public constructors

## Forbidden donor structure

- `avoid_scene_controller_facades` - decision: `avoid`
- `avoid_interactive_runtime_whole` - decision: `avoid`
- `avoid_scene_builder_public_architecture` - decision: `avoid`
- `avoid_scene_codec_whole` - decision: `avoid`
- `avoid_scene_store_controller_whole` - decision: `avoid`

## Diagrams to read or update

- `c4_container` -> `docs/diagrams/c4_container.mmd`
- `c4_context` -> `docs/diagrams/c4_context.mmd`
- `dfd_diagnostics_error_projection` -> `docs/diagrams/dfd_diagnostics_error_projection.mmd`
- `dfd_public_edit` -> `docs/diagrams/dfd_public_edit.mmd`

## Guardrails

- `codec.known_fields_validated` - known schema v1 fields are validated and canonical encoder writes only v1 fields
- `api.dto_immutability` - DTO collections defensively copied and unmodifiable
- `api.id_validation_no_extension_type_escape` - ids cannot be publicly constructed without validation
- `api.no_undefined_public_type_references` - every exported signature type is exported or from Flutter/Dart SDK
- `api.public_api_compiles_as_written` - public API declarations compile in an empty consumer package
- `api.public_types_complete` - all public signatures reference defined public types
- `api.v1_scope_gate_green_before_freeze` - P1.5 scope gate passed before public API freeze starts
- `core.no_legacy_imports` - no import of legacy package/runtime
- `core.no_node_spec_patch_shape_dependency` - no legacy NodeSpec/NodePatch/PatchField in core
- `core.no_scene_controller_shape_dependency` - no SceneController concept in core

## Tests

- `test.api_contract.v1_scope_gate` -> `public API v1 scope gate probe`

## Exit gate

- mandatory v1 scope is green
- public API compiles as written
- no undefined public type references remain
- P2 public API freeze is blocked until this gate is green.
