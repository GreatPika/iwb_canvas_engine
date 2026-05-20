# P3 - schema v1 DTO validation and codec skeleton

## Purpose

Implement schema v1 validation and encode/decode boundaries before runtime
materialization, document loading, resources, or frame behavior depends on
external data shapes.

## Build scope

- schema v1 full-contract tests
- encode/decode skeleton
- validation limits
- metadata validator
- `CanvasMetadata` materialization/projection at the schema boundary
- color/offset/size/transform codecs
- resource/element JSON codecs.

## Dependencies on earlier phases

- P0 package and guardrail boundaries are enforced.
- P1 public API, external-adapter, legacy-ban, and validation checks are green.
- P2 public DTOs, ids, errors, and validation rules are frozen.

## Read first

- `section_05_schema_v1_contract` -> `docs/contracts/schema_v1.md`
- `section_06_validation_limits` -> `docs/contracts/validation_limits.md`
- `section_19_codec_boundary` -> `docs/contracts/codec_boundary.md`
- `section_20_diagnostics_hub` -> `docs/contracts/diagnostics.md`
- `section_23_tests` -> `docs/verification/tests.md`

## Required donors

- `direct_structure_validation` - decision: `copy/adapt`; target owner: DTO and schema structure validation
- `foundation_transform2d` - decision: `copy/adapt`; target owner: CanvasTransform and geometry math
- `foundation_contract_limits` - decision: `copy/adapt`; target owner: Validation limits and public constructors
- `foundation_error_contract` - decision: `copy/adapt`; target owner: CanvasDataException and DiagnosticsHub
- `foundation_validators` - decision: `adapt`; target owner: Public DTO, `CanvasMetadata`, and schema validators
- `dto_boundary_schema` - decision: `adapt`; target owner: Typed and JSON schema field groups
- `dto_scene_value_validation` - decision: `adapt/rewrite`; target owner: Runtime/model validation adapters
- `dto_node_boundary_mapping` - decision: `adapt`; target owner: Codec and store mapping families
- `codec_guards` - decision: `copy/adapt`; target owner: CodecBoundary raw JSON guards
- `codec_json_require` - decision: `copy/adapt`; target owner: Schema v1 strict field access
- `codec_json_parse` - decision: `adapt`; target owner: Schema v1 primitive parsers
- `codec_metadata_decode` - decision: `adapt`; target owner: Schema v1 metadata codec
- `codec_layer_decode` - decision: `adapt`; target owner: Layer schema codec
- `codec_node_common_decode` - decision: `adapt`; target owner: Element common schema codec
- `codec_family_decode` - decision: `adapt`; target owner: Element family codecs
- `codec_scene_codec_flow` - decision: `adapt/rewrite`; target owner: CodecBoundary codec reference
- `codec_validation_path_surface` - decision: `copy/adapt`; target owner: Diagnostic path projection
- `validated_import_draft` - decision: `adapt`; target owner: Validated document import draft

## Forbidden donor structure

- `avoid_scene_controller_facades` - decision: `avoid`
- `avoid_interactive_runtime_whole` - decision: `avoid`
- `avoid_scene_builder_public_architecture` - decision: `avoid`
- `avoid_scene_codec_whole` - decision: `avoid`
- `avoid_scene_store_controller_whole` - decision: `avoid`

## Diagrams to read or update

- `dfd_diagnostics_error_projection` -> `docs/diagrams/dfd_diagnostics_error_projection.mmd`
- `dfd_schema_v1_decode_encode` -> `docs/diagrams/dfd_schema_v1_decode_encode.mmd`
- `seq_schema_v1_decode_encode_order` -> `docs/diagrams/seq_schema_v1_decode_encode_order.mmd`

## Contracts satisfied by this phase

- schema v1 field contract from `section_05_schema_v1_contract`
- metadata remains a schema v1 JSON object on the wire and materializes to
  frozen public `CanvasMetadata` inside DTOs
- schema and public DTO validation limits from `section_06_validation_limits`,
  including `CanvasDiagnosticsVerbose` constructor/schema limit tests
- codec entrypoint and no-runtime-side-effect contract from `section_19_codec_boundary`
- diagnostic projection and disabled hot-path policy foundation from
  `section_20_diagnostics_hub`

## Tests and guardrails that prove this phase

- `test.codec.schema_v1.known_fields_validation` -> `test/codec/schema_v1/known_fields_validation_test.dart`
- `test.codec.schema_v1.resources_appkey_only` -> `test/codec/schema_v1/resources_appkey_only_test.dart`
- `test.codec.schema_v1.reject_unknown_element_kind` -> `test/codec/schema_v1/reject_unknown_element_kind_test.dart`
- `test.codec.schema_v1.reject_unknown_resource_source_kind` -> `test/codec/schema_v1/reject_unknown_resource_source_kind_test.dart`
- `test.codec.decode_encode_no_runtime_side_effects` -> `test/codec/decode_encode_no_runtime_side_effects_test.dart`
- `test.diagnostics.sanitizer_and_public_projection` -> `test/diagnostics/sanitizer_and_public_projection_test.dart`
- `test.codec.constructor_and_schema_limits` -> `test/codec/constructor_and_schema_limits_test.dart`
- `codec.schema_v1_exact`
- `codec.known_fields_validated`
- `codec.no_runtime_side_effects`
- `diagnostics.disabled_no_alloc_hot_path`
- `diagnostics.sanitized_public_projection`
- `api.id_validation_no_extension_type_escape`

## Exit gate

- all schema roundtrip tests green
- metadata roundtrip tests prove `CanvasMetadata` projects to canonical JSON
  object values without exposing raw maps as public DTO metadata
- known field validation tests green
- unknown-field policy tests green
- limits tests green
- `CanvasDiagnosticsVerbose` constructor/schema limit tests reject invalid preview and
  list-entry limits
- error payload tests green
- codec no-runtime-side-effect tests green
- diagnostics sanitizer tests green.

## Risks and trade-offs

- Letting runtime decode directly from raw JSON would spread boundary validation
  across later phases. P3 keeps external shape validation in `CodecBoundary`.
- Building runtime materialization here would cross ownership too early. P3
  stops at immutable public DTOs and validated import drafts.

## Why this phase belongs here

Runtime store, edit, load, resources, and frame phases all rely on trusted public
DTOs or validated import drafts. External data validation must be finished before
those internal owners are implemented.
