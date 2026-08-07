---
date: 2026-05-26
researcher: Codex
commit: b545a147
branch: new-architecture
research_question: "How should P6 handoff findings 3 and 5 be closed based on the current repository behavior, contracts, and guardrails?"
---

# Research: P6 Handoff Findings Closure

## Summary

`P6_HANDOFF_FINDINGS.md` contains two remaining P3 cleanup findings before P6:
finding 3 covers the `CanvasSurface.build` placeholder detector, and finding 5
covers the unused `canvasSchemaV1RootFields` constant
(`P6_HANDOFF_FINDINGS.md:7`, `P6_HANDOFF_FINDINGS.md:18`).

The public placeholder guardrail already uses analyzer AST parsing for exported
public `UnimplementedError` placeholders, but the `CanvasSurface.build`
placeholder is detected by an exact source substring in the same test
(`test/api_contract/public_api_no_unapproved_placeholders_test.dart:170`,
`test/api_contract/public_api_no_unapproved_placeholders_test.dart:182`). The
actual empty surface implementation lives in the private `_CanvasSurfaceState`
class, so the existing exported-public collector does not discover it through
the public class path (`lib/src/api/canvas_surface.dart:110`,
`test/api_contract/public_api_no_unapproved_placeholders_test.dart:311`).

The schema v1 contract and tests preserve an unknown-field policy: known schema
v1 fields are validated, unknown non-metadata fields are ignored on decode, and
unknown non-metadata fields are not preserved by canonical encode
(`docs/contracts/schema_v1.md:71`, `docs/contracts/schema_v1.md:74`,
`docs/contracts/schema_v1.md:75`, `docs/contracts/schema_v1.md:76`). The
`canvasSchemaV1RootFields` constant is declared in production validation code,
but repository search found it referenced only by its declaration and the P6
handoff note (`lib/src/codec/schema_v1_validation.dart:5`,
`P6_HANDOFF_FINDINGS.md:24`).

## Detailed Findings

### 1. P6 Handoff Findings

- **Location**: primary `P6_HANDOFF_FINDINGS.md:7`; additional
  `P6_HANDOFF_FINDINGS.md:18`
- **Description**: Finding 3 states that `CanvasSurface.build` placeholder
  detection uses exact source text instead of the AST-based public placeholder
  checks (`P6_HANDOFF_FINDINGS.md:13`, `P6_HANDOFF_FINDINGS.md:14`). Finding 5
  states that `canvasSchemaV1RootFields` looks like a schema field source of
  truth, while decode, encode, and tests do not consume it
  (`P6_HANDOFF_FINDINGS.md:24`, `P6_HANDOFF_FINDINGS.md:25`).
- **Dependencies**: The findings point to
  `test/api_contract/public_api_no_unapproved_placeholders_test.dart:182` and
  `lib/src/codec/schema_v1_validation.dart:5`
  (`P6_HANDOFF_FINDINGS.md:11`, `P6_HANDOFF_FINDINGS.md:22`).
- **Data flow**: Handoff note -> referenced guardrail/test or production file ->
  repository contracts and tests define the behavior that must remain true.

### 2. Public Placeholder Guardrail

- **Location**: primary
  `test/api_contract/public_api_no_unapproved_placeholders_test.dart:18`;
  additional `tool/guardrails/src/public_api_placeholder_allowlist.dart:15`
- **Description**: The placeholder test discovers public API placeholders and
  compares discovered declaration ids with
  `publicApiPlaceholderAllowlist.declarationId`
  (`test/api_contract/public_api_no_unapproved_placeholders_test.dart:18`,
  `test/api_contract/public_api_no_unapproved_placeholders_test.dart:21`). It
  requires both discovered-but-not-allowlisted and allowlisted-but-not-discovered
  sets to be empty (`test/api_contract/public_api_no_unapproved_placeholders_test.dart:25`,
  `test/api_contract/public_api_no_unapproved_placeholders_test.dart:26`).
- **Dependencies**: The test imports analyzer parsing and AST APIs
  (`test/api_contract/public_api_no_unapproved_placeholders_test.dart:3`,
  `test/api_contract/public_api_no_unapproved_placeholders_test.dart:4`), the
  placeholder allowlist
  (`test/api_contract/public_api_no_unapproved_placeholders_test.dart:7`), and
  the repository root helper
  (`test/api_contract/public_api_no_unapproved_placeholders_test.dart:8`).
- **Data flow**: The root barrel is read from `lib/iwb_canvas_engine.dart`
  (`test/api_contract/public_api_no_unapproved_placeholders_test.dart:138`).
  Export directives are parsed into file paths and export combinators
  (`test/api_contract/public_api_no_unapproved_placeholders_test.dart:146`).
  Each exported file is parsed as a compilation unit
  (`test/api_contract/public_api_no_unapproved_placeholders_test.dart:170`,
  `test/api_contract/public_api_no_unapproved_placeholders_test.dart:174`) and
  visited by `_PublicPlaceholderCollector`
  (`test/api_contract/public_api_no_unapproved_placeholders_test.dart:176`).

### 3. Exported Placeholder AST Detection

- **Location**: primary
  `test/api_contract/public_api_no_unapproved_placeholders_test.dart:195`
- **Description**: `_PublicPlaceholderCollector.collect()` inspects
  top-level declarations and handles `FunctionDeclaration` and
  `ClassDeclaration`
  (`test/api_contract/public_api_no_unapproved_placeholders_test.dart:201`,
  `test/api_contract/public_api_no_unapproved_placeholders_test.dart:209`).
  Public top-level functions are recorded only when their function body is an
  unimplemented body
  (`test/api_contract/public_api_no_unapproved_placeholders_test.dart:221`,
  `test/api_contract/public_api_no_unapproved_placeholders_test.dart:226`).
  Public class members are limited to methods and constructors
  (`test/api_contract/public_api_no_unapproved_placeholders_test.dart:244`,
  `test/api_contract/public_api_no_unapproved_placeholders_test.dart:246`,
  `test/api_contract/public_api_no_unapproved_placeholders_test.dart:248`).
- **Dependencies**: `_isUnimplementedBody()` recognizes expression bodies and
  one-statement block bodies
  (`test/api_contract/public_api_no_unapproved_placeholders_test.dart:281`,
  `test/api_contract/public_api_no_unapproved_placeholders_test.dart:285`).
  `_isUnimplementedThrow()` requires a `ThrowExpression`
  (`test/api_contract/public_api_no_unapproved_placeholders_test.dart:296`).
  `_isUnimplementedError()` recognizes `UnimplementedError` instance creation
  and bare invocation
  (`test/api_contract/public_api_no_unapproved_placeholders_test.dart:301`,
  `test/api_contract/public_api_no_unapproved_placeholders_test.dart:304`,
  `test/api_contract/public_api_no_unapproved_placeholders_test.dart:306`).
- **Data flow**: Parsed exported source -> top-level public filter -> class
  member scan -> structural `throw UnimplementedError()` detection ->
  declaration id set.

### 4. CanvasSurface Empty Surface Placeholder

- **Location**: primary `lib/src/api/canvas_surface.dart:110`; additional
  `test/api_contract/public_api_no_unapproved_placeholders_test.dart:182`
- **Description**: `CanvasSurface` is a public `StatefulWidget`
  (`lib/src/api/canvas_surface.dart:8`), and `createState()` returns
  `_CanvasSurfaceState` (`lib/src/api/canvas_surface.dart:24`). The actual
  `build` implementation is in the private `_CanvasSurfaceState` class and
  returns `const SizedBox.shrink()` (`lib/src/api/canvas_surface.dart:110`,
  `lib/src/api/canvas_surface.dart:112`).
- **Dependencies**: The public placeholder collector's default top-level filter
  treats names beginning with `_` as private
  (`test/api_contract/public_api_no_unapproved_placeholders_test.dart:311`).
  `CanvasSurface.build` is therefore added through `_surfacePlaceholders()`,
  which reads `canvas_surface.dart`
  (`test/api_contract/public_api_no_unapproved_placeholders_test.dart:182`,
  `test/api_contract/public_api_no_unapproved_placeholders_test.dart:183`) and
  checks for the exact text
  `Widget build(BuildContext context) => const SizedBox.shrink();`
  (`test/api_contract/public_api_no_unapproved_placeholders_test.dart:187`,
  `test/api_contract/public_api_no_unapproved_placeholders_test.dart:189`).
- **Data flow**: `canvas_surface.dart` raw source -> exact substring check ->
  add `CanvasSurface.build` to discovered placeholder ids. The allowlist contains
  `CanvasSurface.build` with owner phase `P13` and a removal condition
  (`tool/guardrails/src/public_api_placeholder_allowlist.dart:52`,
  `tool/guardrails/src/public_api_placeholder_allowlist.dart:53`,
  `tool/guardrails/src/public_api_placeholder_allowlist.dart:54`,
  `tool/guardrails/src/public_api_placeholder_allowlist.dart:57`).

### 5. Placeholder Contract Context

- **Location**: primary `plan/step_22_p2_public_api_freeze_hardening.md:681`
- **Description**: Step 22 records that the surface rendering placeholder is
  deferred and listed with a P13 removal condition in the placeholder allowlist
  (`plan/step_22_p2_public_api_freeze_hardening.md:681`,
  `plan/step_22_p2_public_api_freeze_hardening.md:682`,
  `plan/step_22_p2_public_api_freeze_hardening.md:683`). The same step records
  that public API code must have no unapproved placeholders
  (`plan/step_22_p2_public_api_freeze_hardening.md:697`,
  `plan/step_22_p2_public_api_freeze_hardening.md:698`).
- **Dependencies**: The allowlist is tooling-owned data and does not affect
  production behavior (`plan/step_22_p2_public_api_freeze_hardening.md:294`,
  `plan/step_22_p2_public_api_freeze_hardening.md:295`).
- **Data flow**: Plan contract -> allowlist metadata -> public API placeholder
  test exact-set assertion.

### 6. Schema V1 Root Validation

- **Location**: primary `lib/src/codec/schema_v1_validation.dart:5`
- **Description**: `canvasSchemaV1RootFields` declares the root keys
  `schemaVersion`, `camera`, `background`, `palette`, `resources`,
  `backgroundLayer`, `layers`, and `metadata`
  (`lib/src/codec/schema_v1_validation.dart:5`,
  `lib/src/codec/schema_v1_validation.dart:6`,
  `lib/src/codec/schema_v1_validation.dart:13`). The same file defines
  `validateSchemaV1Root()` (`lib/src/codec/schema_v1_validation.dart:16`).
- **Dependencies**: `validateSchemaV1Root()` reads only
  `json['schemaVersion']` (`lib/src/codec/schema_v1_validation.dart:20`) and
  requires it to be the integer `1`
  (`lib/src/codec/schema_v1_validation.dart:21`). It emits `missingField` for
  a null version and `unsupportedSchemaVersion` otherwise
  (`lib/src/codec/schema_v1_validation.dart:25`,
  `lib/src/codec/schema_v1_validation.dart:27`).
- **Data flow**: Public decode -> schema v1 decoder -> `validateSchemaV1Root()`
  -> schemaVersion check -> explicit section readers.

### 7. Schema V1 Decode and Encode Root Fields

- **Location**: primary `lib/src/codec/schema_v1_decoder.dart:28`; additional
  `lib/src/codec/schema_v1_encoder.dart:21`
- **Description**: `decodeSchemaV1Document()` calls `validateSchemaV1Root()`
  before reading document sections (`lib/src/codec/schema_v1_decoder.dart:24`,
  `lib/src/codec/schema_v1_decoder.dart:28`). It reads root `resources`,
  `backgroundLayer`, `layers`, `camera`, `background`, `palette`, and
  `metadata` through explicit key-specific calls
  (`lib/src/codec/schema_v1_decoder.dart:30`,
  `lib/src/codec/schema_v1_decoder.dart:42`,
  `lib/src/codec/schema_v1_decoder.dart:46`,
  `lib/src/codec/schema_v1_decoder.dart:52`,
  `lib/src/codec/schema_v1_decoder.dart:53`,
  `lib/src/codec/schema_v1_decoder.dart:58`,
  `lib/src/codec/schema_v1_decoder.dart:59`).
- **Dependencies**: Public codec functions delegate directly to schema v1
  functions (`lib/src/api/canvas_codec.dart:14`,
  `lib/src/api/canvas_codec.dart:22`,
  `lib/src/api/canvas_codec.dart:26`). `encodeSchemaV1Document()` validates the
  public DTO and returns a literal root map
  (`lib/src/codec/schema_v1_encoder.dart:15`,
  `lib/src/codec/schema_v1_encoder.dart:19`,
  `lib/src/codec/schema_v1_encoder.dart:21`). The literal map writes
  `schemaVersion`, `camera`, `background`, `palette`, `resources`,
  `backgroundLayer`, `layers`, and `metadata`
  (`lib/src/codec/schema_v1_encoder.dart:22`,
  `lib/src/codec/schema_v1_encoder.dart:31`).
- **Data flow**: Decode map/string -> schemaVersion validation -> explicit root
  key reads -> `CanvasDocument` construction. Encode DTO -> validation ->
  literal canonical root map.

### 8. Schema Unknown-Field and Canonical Encode Contracts

- **Location**: primary `docs/contracts/schema_v1.md:71`; additional
  `docs/contracts/codec_boundary.md:56`
- **Description**: The schema v1 unknown-field policy says known schema v1
  fields are validated, unknown non-metadata fields are ignored on decode,
  unknown non-metadata fields are not preserved by canonical encode, metadata is
  the only roundtripped extension area, unsupported schemaVersion is rejected,
  unknown element kind is rejected, unknown resource source kind is rejected,
  and unknown enum value is rejected (`docs/contracts/schema_v1.md:71`,
  `docs/contracts/schema_v1.md:74`, `docs/contracts/schema_v1.md:81`).
- **Dependencies**: The codec boundary decode algorithm includes schemaVersion
  checking and known field validation with the v1 unknown-field policy
  (`docs/contracts/codec_boundary.md:58`,
  `docs/contracts/codec_boundary.md:62`,
  `docs/contracts/codec_boundary.md:63`). The encode algorithm validates the
  public DTO, canonicalizes defaults, preserves order, uppercases colors,
  includes all common element fields, projects `CanvasMetadata`, and returns a
  JSON-compatible map (`docs/contracts/codec_boundary.md:82`,
  `docs/contracts/codec_boundary.md:83`,
  `docs/contracts/codec_boundary.md:90`).
- **Data flow**: Contracted schema policy -> decode validation and unknown-field
  behavior -> canonical encode proof.

### 9. Schema Tests Covering Root Fields and Unknown Fields

- **Location**: primary `test/codec/schema_v1/known_fields_validation_test.dart:28`
- **Description**: The known-fields test asserts that decoding
  `{'schemaVersion': 1, 'unknownRootField': true}` produces a
  `CanvasDocument` (`test/codec/schema_v1/known_fields_validation_test.dart:28`,
  `test/codec/schema_v1/known_fields_validation_test.dart:30`,
  `test/codec/schema_v1/known_fields_validation_test.dart:31`). The same test
  rejects invalid known root or nested shapes, including `camera: null`,
  invalid `background.grid.enabled`, and invalid `layers[].elements`
  (`test/codec/schema_v1/known_fields_validation_test.dart:47`,
  `test/codec/schema_v1/known_fields_validation_test.dart:49`,
  `test/codec/schema_v1/known_fields_validation_test.dart:55`,
  `test/codec/schema_v1/known_fields_validation_test.dart:63`).
- **Dependencies**: `constructor_and_schema_limits_test.dart` also accepts
  `{'schemaVersion': 1, 'unknown': true}` as a `CanvasDocument`
  (`test/codec/constructor_and_schema_limits_test.dart:188`,
  `test/codec/constructor_and_schema_limits_test.dart:190`,
  `test/codec/constructor_and_schema_limits_test.dart:191`).
  Canonical encode root keys are asserted against `_rootKeys`
  (`test/codec/schema_v1/canonical_encode_roundtrip_test.dart:161`,
  `test/codec/schema_v1/canonical_encode_roundtrip_test.dart:162`,
  `test/codec/schema_v1/canonical_encode_roundtrip_test.dart:380`), and
  legacy root `backgroundElements` is absent
  (`test/codec/schema_v1/canonical_encode_roundtrip_test.dart:164`).
- **Data flow**: Decode tests prove unknown root fields are accepted and invalid
  known fields fail. Encode tests prove canonical root output writes the accepted
  v1 fields and omits non-v1 legacy root output.

### 10. Metadata Projection and Unknown Non-Metadata Omission

- **Location**: primary `test/codec/schema_v1/metadata_projection_test.dart:101`
- **Description**: The metadata projection test adds unknown non-metadata fields
  at the document, resource, background element, layer, and layer element
  positions (`test/codec/schema_v1/metadata_projection_test.dart:47`,
  `test/codec/schema_v1/metadata_projection_test.dart:69`,
  `test/codec/schema_v1/metadata_projection_test.dart:93`,
  `test/codec/schema_v1/metadata_projection_test.dart:97`,
  `test/codec/schema_v1/metadata_projection_test.dart:101`). After decode and
  encode, it asserts those unknown non-metadata fields are absent from encoded
  output (`test/codec/schema_v1/metadata_projection_test.dart:119`,
  `test/codec/schema_v1/metadata_projection_test.dart:123`,
  `test/codec/schema_v1/metadata_projection_test.dart:129`,
  `test/codec/schema_v1/metadata_projection_test.dart:133`,
  `test/codec/schema_v1/metadata_projection_test.dart:137`).
- **Dependencies**: The same test asserts metadata materializes as
  `CanvasMetadata` at all covered owners
  (`test/codec/schema_v1/metadata_projection_test.dart:104`,
  `test/codec/schema_v1/metadata_projection_test.dart:105`,
  `test/codec/schema_v1/metadata_projection_test.dart:112`,
  `test/codec/schema_v1/metadata_projection_test.dart:114`).
- **Data flow**: Raw schema map with known metadata and unknown non-metadata ->
  decode into public DTO metadata -> encode -> unknown non-metadata omitted and
  metadata retained.

## Code References

- `P6_HANDOFF_FINDINGS.md:7` - finding 3 title.
- `P6_HANDOFF_FINDINGS.md:18` - finding 5 title.
- `test/api_contract/public_api_no_unapproved_placeholders_test.dart:18` -
  placeholder allowlist exact-set test.
- `test/api_contract/public_api_no_unapproved_placeholders_test.dart:170` -
  analyzer AST parse path for ordinary public placeholders.
- `test/api_contract/public_api_no_unapproved_placeholders_test.dart:182` -
  `CanvasSurface.build` surface placeholder detector.
- `test/api_contract/public_api_no_unapproved_placeholders_test.dart:281` -
  structural `UnimplementedError` body detection.
- `lib/src/api/canvas_surface.dart:110` - private state class that owns the
  current empty `build` implementation.
- `tool/guardrails/src/public_api_placeholder_allowlist.dart:52` -
  `CanvasSurface.build` allowlist entry.
- `lib/src/codec/schema_v1_validation.dart:5` - unused root fields constant.
- `lib/src/codec/schema_v1_validation.dart:16` - root validation function.
- `lib/src/codec/schema_v1_decoder.dart:28` - schema root validation call before
  section reads.
- `lib/src/codec/schema_v1_encoder.dart:21` - canonical root map literal.
- `docs/contracts/schema_v1.md:71` - schema unknown-field policy.
- `docs/contracts/codec_boundary.md:56` - decode algorithm section.
- `test/codec/schema_v1/known_fields_validation_test.dart:30` - unknown root
  field accepted on decode.
- `test/codec/schema_v1/canonical_encode_roundtrip_test.dart:380` - canonical
  root key set in test proof.
- `test/codec/schema_v1/metadata_projection_test.dart:119` - unknown
  non-metadata root field omitted on encode.

## Observed Architecture Facts

- Pattern observed: public API placeholder detection is exact-set enforcement
  against a tooling-owned allowlist
  (`test/api_contract/public_api_no_unapproved_placeholders_test.dart:18`,
  `test/api_contract/public_api_no_unapproved_placeholders_test.dart:25`,
  `plan/step_22_p2_public_api_freeze_hardening.md:294`).
- Pattern observed: ordinary exported public `UnimplementedError` placeholders
  are structurally detected by analyzer AST, while `CanvasSurface.build` uses a
  separate text-based detector
  (`test/api_contract/public_api_no_unapproved_placeholders_test.dart:170`,
  `test/api_contract/public_api_no_unapproved_placeholders_test.dart:182`,
  `test/api_contract/public_api_no_unapproved_placeholders_test.dart:281`).
- Data flow: public decode entrypoint -> schema v1 decoder -> root validation ->
  explicit field readers -> immutable DTO construction
  (`lib/src/api/canvas_codec.dart:22`,
  `lib/src/codec/schema_v1_decoder.dart:28`,
  `lib/src/codec/schema_v1_decoder.dart:65`).
- Data flow: public encode entrypoint -> schema v1 encoder -> validated import
  draft -> canonical literal root map
  (`lib/src/api/canvas_codec.dart:14`,
  `lib/src/codec/schema_v1_encoder.dart:19`,
  `lib/src/codec/schema_v1_encoder.dart:21`).
- Key dependency: schema v1 behavior is documented in `docs/contracts/schema_v1.md`
  and `docs/contracts/codec_boundary.md`, with required tests listed in the
  schema contract (`docs/contracts/schema_v1.md:27`,
  `docs/contracts/schema_v1.md:34`,
  `docs/contracts/codec_boundary.md:25`).
- Key dependency: unknown root fields are accepted by current tests, while
  invalid known fields are rejected
  (`test/codec/schema_v1/known_fields_validation_test.dart:30`,
  `test/codec/schema_v1/known_fields_validation_test.dart:47`).

## Open Questions

None from the factual research pass.
