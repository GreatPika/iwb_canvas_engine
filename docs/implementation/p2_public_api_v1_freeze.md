# P2 - public API v1 freeze

## Build

- all src/api DTOs implemented
- P1.5 v1 scope gate green
- id validation implemented
- CanvasOptional implemented
- public API docs generated
- DTO immutability tests
- public signatures no undefined types.

## Read first

- `section_04_public_api_v1` -> `docs/contracts/public_api_v1.md`
- `section_06_validation_limits` -> `docs/contracts/validation_limits.md`
- `section_09_accepted_differences` -> `docs/architecture/04_decisions_and_differences.md`
- `section_23_tests` -> `docs/verification/tests.md`

## Required donors

- `direct_numeric_policy` - decision: `copy`; target owner: GeometryPolicy numeric tolerance foundation
- `direct_structure_validation` - decision: `copy/adapt`; target owner: DTO and schema structure validation
- `foundation_transform2d` - decision: `copy/adapt`; target owner: CanvasTransform and geometry math
- `foundation_contract_limits` - decision: `copy/adapt`; target owner: Validation limits and public constructors
- `foundation_error_contract` - decision: `copy/adapt`; target owner: CanvasDataException and DiagnosticsHub
- `foundation_validators` - decision: `adapt`; target owner: Public DTO and schema validators
- `foundation_tri_state_patch_semantics` - decision: `copy/adapt`; target owner: CanvasOptional update semantics
- `foundation_immutable_collections` - decision: `adapt`; target owner: DTO immutability
- `foundation_pointer_input_contract` - decision: `copy/adapt`; target owner: Canvas pointer API and InteractionEngine
- `foundation_action_event_immutability` - decision: `adapt`; target owner: CanvasActionEvent and text edit events
- `dto_snapshot_behavior` - decision: `adapt`; target owner: CanvasDocument DTOs
- `dto_node_spec_behavior` - decision: `adapt`; target owner: Element creation DTO validation
- `dto_boundary_schema` - decision: `adapt`; target owner: Typed and JSON schema field groups
- `dto_scene_value_validation` - decision: `adapt/rewrite`; target owner: Runtime/model validation adapters
- `interaction_public_controller_behavior` - decision: `rewrite-reference`; target owner: Behavioral checklist only

## Forbidden donor structure

- `avoid_scene_controller_facades` - decision: `avoid`
- `avoid_interactive_runtime_whole` - decision: `avoid`
- `avoid_scene_builder_public_architecture` - decision: `avoid`
- `avoid_scene_codec_whole` - decision: `avoid`
- `avoid_scene_store_controller_whole` - decision: `avoid`

## Diagrams to read or update

- `c4_context` -> `docs/diagrams/c4_context.mmd`
- `dfd_diagnostics_error_projection` -> `docs/diagrams/dfd_diagnostics_error_projection.mmd`
- `dfd_public_edit` -> `docs/diagrams/dfd_public_edit.mmd`

## Guardrails

- `codec.known_fields_validated` - known schema v1 fields are validated and canonical encoder writes only v1 fields
- `api.dto_immutability` - DTO collections defensively copied and unmodifiable
- `api.functional_ledger_complete` - every functional ledger row has API + tests
- `api.id_validation_no_extension_type_escape` - ids cannot be publicly constructed without validation
- `api.no_undefined_public_type_references` - every exported signature type is exported or from Flutter/Dart SDK
- `api.public_api_compiles_as_written` - public API declarations compile in an empty consumer package
- `api.public_types_complete` - all public signatures reference defined public types
- `api.v1_scope_gate_green_before_freeze` - P1.5 scope gate passed before public API freeze starts

## Tests

- `test.api_contract.public_api_v1_compiles_as_written` -> `test/api_contract/public_api_v1_compiles_as_written_test.dart`
- `test.api_contract.no_undefined_public_type_references` -> `test/api_contract/no_undefined_public_type_references_test.dart`
- `test.api_contract.no_old_public_symbols` -> `test/api_contract/no_old_public_symbols_test.dart`
- `test.api_contract.dto_immutability` -> `test/api_contract/dto_immutability_test.dart`
- `test.api.typed_action_payloads` -> `test/api/typed_action_payloads_test.dart`
- `test.codec.constructor_and_schema_limits` -> `test/codec/constructor_and_schema_limits_test.dart`

## Exit gate

- P1.5 scope gate remains green
- public API compiles
- all public constructor validations pass/fail as specified
- legacy public symbols are not exported
- no public type references internal runtime classes.
