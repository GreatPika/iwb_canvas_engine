# P2 - public API v1 freeze

## Purpose

Implement and freeze the public v1 API surface so runtime, codec, resource,
interaction, frame, and Flutter phases build against stable DTOs, ports, events,
errors, validation rules, and equality semantics.

## Build scope

- public DTOs implemented and, after the Step 38 architecture repair, owned by
  `lib/src/contracts/public/**` with `src/api/**` kept as facade/wrapper-export
  compatibility files
- `CanvasMetadata` implemented as the public metadata value object for
  metadata-bearing DTOs
- P1 public API, external-adapter, legacy-ban, and validation checks are green
- id validation implemented
- `CanvasFieldUpdate` and its public variants implemented
- `CanvasPreviewState` implemented as a sealed public union with exported
  readable preview variants, including shared `CanvasStrokePreview` facts
- `CanvasRuntime.state`, `CanvasRuntimeState`, `CanvasRuntimeRevisions`, and
  `CanvasRuntimeSummary` implemented as the single public runtime observation
  surface
- public equality policy implemented
- exported public API has non-empty dartdoc summaries
- public signatures obey Dart API design constraints from `section_04_public_api_v1`
- DTO immutability tests, including defensive copies, unmodifiable collections,
  `CanvasMetadata` deep-freeze, invalid construction rejection, and const-policy
  drift
- public equality policy tests
- public signatures no undefined types.

## Dependencies on earlier phases

- P0 package boundaries are enforced.
- P1 public API, external-adapter, legacy-ban, and validation checks are green.

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
- `foundation_validators` - decision: `adapt`; target owner: Public DTO, `CanvasMetadata`, and schema validators
- `foundation_tri_state_patch_semantics` - decision: `copy/adapt`; target owner: CanvasFieldUpdate update semantics
- `foundation_immutable_collections` - decision: `adapt`; target owner: DTO immutability and `CanvasMetadata` deep-freeze
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
- `seq_single_active_surface` -> `docs/diagrams/seq_single_active_surface.mmd`

## Contracts satisfied by this phase

- full public API declarations from `section_04_public_api_v1`
- `CanvasMetadata` replaces raw metadata maps in metadata-bearing public DTOs;
  raw maps remain only at JSON codec boundaries and diagnostic details
- validation limit enforcement at public constructors from `section_06_validation_limits`,
  including `CanvasDiagnosticsVerbose` preview and list-entry limits
- public-readable resource and diagnostics policy variants from
  `section_04_public_api_v1`
- sealed `CanvasPreviewState` public API, exported preview variants, stable
  `CanvasPreviewKind` values, and default identity equality policy from
  `section_04_public_api_v1`
- accepted legacy differences from `section_09_accepted_differences`
- public DTO immutability, equality, id validation, class modifiers, dartdoc,
  and signature-shape obligations from `section_23_tests`

## Tests and guardrails that prove this phase

- `test.api_contract.public_api_v1_compiles_as_written` -> `test/api_contract/public_api_v1_compiles_as_written_test.dart`; compiles the public barrel from an empty consumer and exercises P2-owned constructor, getter, method, default, and return shapes
- `test.guardrails.public_api_declaration_checks` -> `test/guardrails/public_api_declaration_checks_test.dart`; checks exported dartdoc summaries and explicit public class modifiers
- `test.guardrails.public_api_import_cycles` -> `test/guardrails/public_api_import_cycles_test.dart`; checks public API import-cycle fixtures and the live public API import graph
- `test.api_contract.app_next_engine_adapter_compile_fixture` -> `test/api_contract/app_next_engine_adapter_compile_fixture_test.dart`; proves app-level adapter responsibilities compile from the public barrel only and rejects forbidden fixture imports
- `test.api_contract.public_readable_union_variants` -> `test/api_contract/public_readable_union_variants_test.dart`
- `test.api_contract.preview_state_sealed_union` -> `test/api_contract/preview_state_sealed_union_test.dart`
- `test.api_contract.canvas_field_update_static_semantics` -> `test/api_contract/canvas_field_update_static_semantics_test.dart`
- `test.api_contract.no_undefined_public_type_references` -> `test/api_contract/no_undefined_public_type_references_test.dart`; also checks public signature shape with analyzer AST
- `test.api_contract.no_retired_public_exports` -> `test/api_contract/no_retired_public_exports_test.dart`
- `test.api_contract.dto_immutability` -> `test/api_contract/dto_immutability_test.dart`
- `test.api_contract.public_equality_policy` -> `test/api_contract/public_equality_policy_test.dart`
- `test.api.canvas_field_update` -> `test/api/canvas_field_update_test.dart`
- `test.api.typed_action_payloads` -> `test/api/typed_action_payloads_test.dart`
- `test.codec.constructor_and_schema_limits` -> `test/codec/constructor_and_schema_limits_test.dart`
- `api.integration_surface_complete`
- `api.public_types_complete`
- `api.public_api_compiles_as_written`
- `api.preview_state_sealed_union_publicly_readable`
- `api.exported_dartdoc_complete`
- `api.public_class_modifiers_explicit`
- `api.no_public_api_import_cycles`
- `api.public_signature_shape`
- `api.no_undefined_public_type_references`
- `api.no_retired_public_exports`
- `api.dto_immutability`
- `api.equality_policy_explicit`
- `api.id_validation_no_extension_type_escape`
- `codec.known_fields_validated`

## Exit gate

- P1 public API, external-adapter, legacy-ban, and validation checks remain green
- public API compiles
- public runtime observation compiles through
  `ValueListenable<CanvasRuntimeState> get state`, and the retired
  document/preview listener getters are not exported
- external app-adapter compile fixture proves the integration surface through
  only `package:iwb_canvas_engine/iwb_canvas_engine.dart`
- exported public API has non-empty dartdoc summaries
- public classes have explicit subtype policy modifiers
- public signatures avoid `FutureOr`, nullable async/container returns, and unapproved `dynamic`
- all public constructor validations pass/fail as specified
- public constructors accepting caller-provided values with documented runtime
  validation or sanitization are non-const factories; const is allowed only for
  marker, empty, default, or private storage forms
- `CanvasFieldSet(null)` and clear-on-non-nullable update misuse are rejected
  by static analyzer proof for ordinary public consumers
- `CanvasDiagnosticsVerbose` accepts defaults and boundary values, and
  rejects zero, negative, and over-limit preview/list-entry values
- public value equality matches `docs/contracts/public_api_v1.md`
- public value equality covers `CanvasRuntimeState`,
  `CanvasRuntimeRevisions`, and `CanvasRuntimeSummary`
- `CanvasPreviewState`, `CanvasStrokePreview`, and every concrete preview
  variant are exported and publicly readable through the sealed preview-state
  contract
- legacy public symbols are not exported
- no public type references internal runtime classes.

## Risks and trade-offs

- Freezing too little would force runtime phases to invent internal public types.
- Freezing too much would lock in unproved behavior. The API must expose the v1
  surface only, while runtime semantics remain proved phase by phase.

## Why this phase belongs here

All runtime phases consume `contracts/public/**` DTOs, updates, ports, ids,
events, and errors through stable public contracts. `src/api/**` remains the
package facade/wrapper layer, not the implementation type library.
