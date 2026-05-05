# P3 - schema v1 DTO validation and codec skeleton

## Build

- schema_v1_full_contract tests
- encode/decode skeleton
- validation limits
- metadata validator
- color/offset/size/transform codecs
- resource/element JSON codecs.

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
- `foundation_validators` - decision: `adapt`; target owner: Public DTO and schema validators
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

## Guardrails

- `codec.known_fields_validated` - known schema v1 fields are validated and canonical encoder writes only v1 fields
- `codec.schema_v1_exact` - only schema v1 read/write
- `codec.no_runtime_side_effects` - schema v1 decode/encode does not mutate runtime or store state
- `diagnostics.disabled_no_alloc_hot_path` - no record allocation on successful hot path
- `diagnostics.sanitized_public_projection` - diagnostics expose only bounded sanitized public data
- `api.functional_ledger_complete` - every functional ledger row has API + tests
- `api.id_validation_no_extension_type_escape` - ids cannot be publicly constructed without validation

## Tests

- `test.schema_v1.known_fields_validation` -> `test/schema_v1/known_fields_validation_test.dart`
- `test.schema_v1.resources_appkey_only` -> `test/schema_v1/resources_appkey_only_test.dart`
- `test.schema_v1.reject_unknown_element_kind` -> `test/schema_v1/reject_unknown_element_kind_test.dart`
- `test.schema_v1.reject_unknown_resource_source_kind` -> `test/schema_v1/reject_unknown_resource_source_kind_test.dart`
- `test.codec.decode_encode_no_runtime_side_effects` -> `test/codec/decode_encode_no_runtime_side_effects_test.dart`
- `test.diagnostics.sanitizer_and_public_projection` -> `test/diagnostics/sanitizer_and_public_projection_test.dart`
- `test.validation_limits.constructor_and_schema_limits` -> `validation limits tests`

## Exit gate

- all schema roundtrip tests green
- known field validation tests green
- unknown-field policy tests green
- limits tests green
- error payload tests green.
- codec no-runtime-side-effect tests green
- diagnostics sanitizer tests green.
