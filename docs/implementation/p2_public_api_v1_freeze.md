# P2 - public API v1 freeze

## Purpose

Implement and freeze the public v1 API surface so runtime, codec, resource,
interaction, frame, and Flutter phases build against stable DTOs, ports, events,
errors, validation rules, and equality semantics.

## Build scope

- all `src/api` DTOs implemented
- P1.5 v1 scope gate green
- id validation implemented
- `CanvasOptional` implemented
- public equality policy implemented
- exported public API has non-empty dartdoc summaries
- public signatures obey Dart API design constraints from `section_04_public_api_v1`
- DTO immutability tests
- public equality policy tests
- public signatures no undefined types.

## Dependencies on earlier phases

- P0 package boundaries are enforced.
- P1 oracle and donor inventory are complete.
- P1.5 scope gate is green.

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

## Contracts satisfied by this phase

- full public API declarations from `section_04_public_api_v1`
- validation limit enforcement at public constructors from `section_06_validation_limits`
- accepted legacy differences from `section_09_accepted_differences`
- public DTO immutability, equality, id validation, class modifiers, dartdoc,
  and signature-shape obligations from `section_23_tests`

## Tests and guardrails that prove this phase

- `test.api_contract.public_api_v1_compiles_as_written` -> `test/api_contract/public_api_v1_compiles_as_written_test.dart`; also checks exported dartdoc and explicit public class modifiers with analyzer AST
- `test.api_contract.no_undefined_public_type_references` -> `test/api_contract/no_undefined_public_type_references_test.dart`; also checks public signature shape with analyzer AST
- `test.api_contract.no_legacy_public_symbols` -> `test/api_contract/no_legacy_public_symbols_test.dart`
- `test.api_contract.dto_immutability` -> `test/api_contract/dto_immutability_test.dart`
- `test.api_contract.public_equality_policy` -> `test/api_contract/public_equality_policy_test.dart`
- `test.api.typed_action_payloads` -> `test/api/typed_action_payloads_test.dart`
- `test.codec.constructor_and_schema_limits` -> `test/codec/constructor_and_schema_limits_test.dart`
- `api.v1_scope_gate_green_before_freeze`
- `api.public_types_complete`
- `api.public_api_compiles_as_written`
- `api.exported_dartdoc_complete`
- `api.public_class_modifiers_explicit`
- `api.public_signature_shape`
- `api.no_undefined_public_type_references`
- `api.no_legacy_public_types`
- `api.dto_immutability`
- `api.equality_policy_explicit`
- `api.id_validation_no_extension_type_escape`
- `api.functional_ledger_complete`
- `codec.known_fields_validated`

## Exit gate

- P1.5 scope gate remains green
- public API compiles
- exported public API has non-empty dartdoc summaries
- public classes have explicit subtype policy modifiers
- public signatures avoid `FutureOr`, nullable async/container returns, and unapproved `dynamic`
- all public constructor validations pass/fail as specified
- public value equality matches `docs/contracts/public_api_v1.md`
- legacy public symbols are not exported
- no public type references internal runtime classes.

## Risks and trade-offs

- Freezing too little would force runtime phases to invent internal public types.
- Freezing too much would lock in unproved behavior. The API must expose the v1
  surface only, while runtime semantics remain proved phase by phase.

## Why this phase belongs here

All runtime phases consume public DTOs, updates, ports, ids, events, and errors.
They need stable public contracts before internal state or feature behavior is
implemented.
