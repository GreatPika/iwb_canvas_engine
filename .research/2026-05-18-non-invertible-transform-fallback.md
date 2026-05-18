---
date: 2026-05-18
researcher: Codex
commit: 97b5e42
branch: new-architecture
research_question: "What currently exists about removing non-invertible transform fallback across public DTO construction, decode, edit update, loadDocument, and runtime hit-test behavior?"
---

# Research: Non-Invertible Transform Fallback

## Summary

The root architecture docs currently contain an explicit redesign note for removing non-invertible transform fallback. That note states that non-invertible transforms are forbidden at public DTO construction, decode, edit update, and `loadDocument`, and that corrupted runtime rows are excluded from exact hit-test with a diagnostic record and no coarse candidate fallback (`redesign.md:3`, `redesign.md:10`, `redesign.md:19`).

The active public API and validation contracts already contain several supporting facts: `CanvasTransform` exposes `isInvertible`, `invert()`, and six affine components; validation says all transform components must be finite at public construction and decode; element transforms must be invertible; `CanvasDataErrorCode` includes `fieldMustBeInvertible`; and validation is applied at public DTO construction, edit/update construction, edit preflight, schema decode, and `loadDocument` materialization (`docs/contracts/public_api_v1.md:691`, `docs/contracts/public_api_v1.md:746`, `docs/contracts/public_api_v1.md:751`, `docs/contracts/public_api_v1.md:2064`, `docs/contracts/validation_limits.md:71`).

The current geometry and hit-test docs still document a fallback path for non-invertible transforms. Box/image/text/rect exact hit uses inverse transform, but the same block says non-invertible transform falls back to coarse candidate bounds; the hit-test sequence repeats that family rules own non-invertible transform fallback where the geometry contract allows it (`docs/contracts/geometry.md:70`, `docs/contracts/geometry.md:75`, `docs/diagrams/seq_hit_test_candidate_resolution.mmd:39`). Step 11 records that resolving the separate non-invertible transform fallback note was out of scope and that the note must remain in `redesign.md` (`plan/step_11_operation_matrix_field_effect_taxonomy.md:40`, `plan/step_11_operation_matrix_field_effect_taxonomy.md:390`).

## Detailed Findings

### 1. Redesign Note and Plan Status
- **Location**: `redesign.md:3`
- **Description**: `redesign.md` contains a single note titled "Non-invertible transform fallback убираем" and describes the problem as coarse fallback hiding corrupted state when transforms are expected to be invertible (`redesign.md:3`, `redesign.md:5`).
- **Dependencies**: The same note lists four input rejection points: public DTO construction, decode, edit update, and `loadDocument` (`redesign.md:10`, `redesign.md:13`). Step 11 explicitly marks resolving this redesign note as out of scope and separately forbids removing it from `redesign.md` (`plan/step_11_operation_matrix_field_effect_taxonomy.md:40`, `plan/step_11_operation_matrix_field_effect_taxonomy.md:390`).
- **Data flow**: Boundary inputs are described as rejected before acceptance (`redesign.md:10`) -> corrupted runtime rows are described as excluded from exact hit-test (`redesign.md:19`) -> diagnostics record is emitted (`redesign.md:20`) -> no coarse candidate fallback is used (`redesign.md:21`).

### 2. Public Transform DTO and Validation Surface
- **Location**: `docs/contracts/public_api_v1.md:691`
- **Description**: `CanvasTransform` is documented as a six-component affine public value type with fields `a`, `b`, `c`, `d`, `tx`, and `ty`; it exposes `isFinite`, `isInvertible`, `applyToPoint`, `applyToRect`, `invert()`, canvas matrix conversion, and JSON-map conversion (`docs/contracts/public_api_v1.md:691`, `docs/contracts/public_api_v1.md:721`, `docs/contracts/public_api_v1.md:728`).
- **Dependencies**: The public API registry includes `CanvasTransform`, `decodeCanvasDocument`, and `decodeCanvasDocumentFromJson` as exported names (`docs/_registry/public_api_v1.yaml:100`, `docs/_registry/public_api_v1.yaml:103`). `CanvasDataErrorCode` includes `fieldMustBeInvertible` (`docs/contracts/public_api_v1.md:2052`, `docs/contracts/public_api_v1.md:2064`).
- **Data flow**: Public construction/decode validates finite transform components (`docs/contracts/public_api_v1.md:746`) -> element transforms are required to be invertible (`docs/contracts/public_api_v1.md:751`) -> scale singular values are bounded when invertibility is required (`docs/contracts/public_api_v1.md:752`, `docs/contracts/validation_limits.md:61`).

### 3. Element DTO and Update Boundaries
- **Location**: `docs/contracts/public_api_v1.md:763`
- **Description**: The common `CanvasElement` constructor accepts `CanvasTransform transform = CanvasTransform.identity`, and concrete element family constructors forward `super.transform` (`docs/contracts/public_api_v1.md:763`, `docs/contracts/public_api_v1.md:767`, `docs/contracts/public_api_v1.md:797`, `docs/contracts/public_api_v1.md:934`). `CanvasElementUpdate` declares `transform` as `CanvasFieldUpdate<CanvasTransform>` with an absent default (`docs/contracts/public_api_v1.md:964`, `docs/contracts/public_api_v1.md:967`, `docs/contracts/public_api_v1.md:979`).
- **Dependencies**: Update semantics reject kind mismatch before draft mutation and reject dynamic/generated clears for non-nullable fields before draft mutation (`docs/contracts/public_api_v1.md:1154`, `docs/contracts/public_api_v1.md:1164`). Changed update effects are field-granular and compiled by the edit contract's Element update field-effect taxonomy (`docs/contracts/public_api_v1.md:1167`, `docs/contracts/public_api_v1.md:1171`).
- **Data flow**: Caller supplies a `CanvasElementUpdate.transform` field intent (`docs/contracts/public_api_v1.md:979`) -> `CanvasEdit.updateElement` accepts the update (`docs/contracts/public_api_v1.md:1188`) -> `CommitCompiler` converts changed fields into typed effects after update-kind validation and before atomic install (`docs/contracts/edit_kernel.md:154`, `docs/contracts/edit_kernel.md:157`).

### 4. Edit Update Transform Effects
- **Location**: `docs/contracts/edit_kernel.md:152`
- **Description**: `CommitCompiler` owns the field-effect taxonomy for `CanvasEdit.updateElement`; absent fields, no-op updates, equal values, validation failures, and rollback paths do not publish the listed effects (`docs/contracts/edit_kernel.md:154`, `docs/contracts/edit_kernel.md:162`, `docs/contracts/edit_kernel.md:165`).
- **Dependencies**: The `CanvasElementUpdate.transform` row maps transform changes to internal bounds, elementVisual, and projection revisions; a touched spatial update; projection eviction; no resource effect; main repaint; and no selection normalization (`docs/contracts/edit_kernel.md:170`, `docs/contracts/edit_kernel.md:172`). The operation matrix consumes this taxonomy for the single `CanvasEdit.updateElement` row (`docs/contracts/operation_matrix.md:50`).
- **Data flow**: Changed transform field -> taxonomy-defined internal revisions and spatial/projection/repaint effects (`docs/contracts/edit_kernel.md:172`) -> typed `CommitPlan` effects (`docs/contracts/edit_kernel.md:147`) -> post-install dispatch to runtime owners through the runtime/applier boundary (`docs/contracts/edit_kernel.md:149`).

### 5. Schema Decode and LoadDocument Boundaries
- **Location**: `docs/contracts/codec_boundary.md:53`
- **Description**: Schema decode checks raw JSON length, parses JSON, checks root object and schema version, validates known fields, validates primitives/resources/elements/ids/references/counts/metadata, materializes an immutable `CanvasDocument` DTO, and performs no runtime/store side effects (`docs/contracts/codec_boundary.md:55`, `docs/contracts/codec_boundary.md:69`).
- **Dependencies**: Schema v1 defines `CanvasTransform` JSON as `{ "a": number, "b": number, "c": number, "d": number, "tx": number, "ty": number }` with finite values and scale singular values in `[1e-4, 1e4]` when invertibility is needed (`docs/contracts/schema_v1.md:90`). The codec sequence routes decode failures through `DiagnosticsHub` and states that failures do not materialize partial DTOs or mutate runtime/store state (`docs/diagrams/seq_schema_v1_decode_encode_order.mmd:14`, `docs/diagrams/seq_schema_v1_decode_encode_order.mmd:58`).
- **Data flow**: `decodeCanvasDocument` / `decodeCanvasDocumentFromJson` receives a Map or string (`docs/contracts/codec_boundary.md:49`, `docs/contracts/codec_boundary.md:50`) -> schema validators accept validated v1 document facts (`docs/diagrams/seq_schema_v1_decode_encode_order.mmd:47`) -> codec materializes immutable `CanvasDocument` with `CanvasMetadata` (`docs/diagrams/seq_schema_v1_decode_encode_order.mmd:49`). `loadDocument` separately validates the public `CanvasDocument`, materializes `PreparedDocumentLoad`, and only then interrupts active interaction and installs replacement state (`docs/contracts/load_document.md:61`, `docs/contracts/load_document.md:76`).

### 6. Runtime Hit-Test, Spatial Fallback, and Diagnostics
- **Location**: `docs/contracts/geometry.md:70`
- **Description**: The current geometry contract says box/image/text/rect hit-test uses transformed coarse bounds, exact hit uses inverse transform, and non-invertible transform falls back to coarse candidate bounds (`docs/contracts/geometry.md:73`, `docs/contracts/geometry.md:75`). Hit eligibility requires a finite point, visible/selectable element, and finite transform; invertibility is not named in that eligibility line (`docs/contracts/geometry.md:54`, `docs/contracts/geometry.md:57`).
- **Dependencies**: The hit-test sequence resolves bounded spatial candidate handles and then calls exact family hit with transform, bounds, padding, and slop (`docs/diagrams/seq_hit_test_candidate_resolution.mmd:24`, `docs/diagrams/seq_hit_test_candidate_resolution.mmd:38`). The same diagram states non-invertible transform fallback to coarse candidate bounds where geometry allows it (`docs/diagrams/seq_hit_test_candidate_resolution.mmd:39`).
- **Data flow**: Pointer hit-test caller -> Interaction -> Spatial query with revision/generation gate (`docs/diagrams/seq_hit_test_candidate_resolution.mmd:15`, `docs/diagrams/seq_hit_test_candidate_resolution.mmd:18`) -> stale candidates are rejected through Store/ReadPort (`docs/diagrams/seq_hit_test_candidate_resolution.mmd:30`, `docs/diagrams/seq_hit_test_candidate_resolution.mmd:33`) -> current rows are checked by hit eligibility and exact family geometry (`docs/diagrams/seq_hit_test_candidate_resolution.mmd:35`, `docs/diagrams/seq_hit_test_candidate_resolution.mmd:39`).

### 7. Spatial Budget and Diagnostic Recording
- **Location**: `docs/contracts/spatial_kernel.md:53`
- **Description**: Spatial tile policy uses cell size 256, outlier threshold over 1024 covered tiles, query tile fallback over 50000 query tiles, and `maxFallbackCandidates = 4096` (`docs/contracts/spatial_kernel.md:56`, `docs/contracts/spatial_kernel.md:59`).
- **Dependencies**: Fallback budget behavior increments a diagnostic counter whenever a query tile or candidate budget is hit, returns no partial hit/paint candidates as valid results when budget is exceeded, schedules rebuild or retry outside hot pointer/paint path, and forbids silent full-scene scans (`docs/contracts/spatial_kernel.md:85`, `docs/contracts/spatial_kernel.md:91`). Diagnostics disabled policy forbids `DiagnosticRecord` allocation on successful pointer move and successful paint, while public `CanvasDataException` may allocate details on error paths (`docs/contracts/diagnostics.md:31`, `docs/contracts/diagnostics.md:38`).
- **Data flow**: Spatial query request -> revision/generation gate -> tile/outlier union -> candidate budget gate -> typed result (`docs/contracts/spatial_kernel.md:94`, `docs/contracts/spatial_kernel.md:97`). Query tile count over 50000 routes to fallback candidate union with diagnostic counter, and fallback candidate count over budget routes to typed budget-exceeded result without partial candidates (`docs/contracts/spatial_kernel.md:98`, `docs/contracts/spatial_kernel.md:100`; `docs/diagrams/dfd_spatial_query_budget.mmd:24`, `docs/diagrams/dfd_spatial_query_budget.mmd:35`).

## Code References

- `redesign.md:3` - non-invertible transform fallback removal note.
- `redesign.md:10` - public DTO construction/decode/edit update/loadDocument rejection list starts.
- `redesign.md:19` - runtime corrupted row policy starts.
- `docs/contracts/public_api_v1.md:691` - `CanvasTransform` declaration.
- `docs/contracts/public_api_v1.md:746` - finite transform validation at public construction and decode.
- `docs/contracts/public_api_v1.md:751` - element transforms must be invertible.
- `docs/contracts/public_api_v1.md:979` - `CanvasElementUpdate.transform` type.
- `docs/contracts/public_api_v1.md:1167` - changed update effects are field-granular and compiled by the edit taxonomy.
- `docs/contracts/public_api_v1.md:1188` - public `CanvasEdit.updateElement` signature.
- `docs/contracts/public_api_v1.md:2064` - `fieldMustBeInvertible` data error code.
- `docs/contracts/validation_limits.md:61` - transform singular-value bounds.
- `docs/contracts/validation_limits.md:71` - validation boundary list.
- `docs/contracts/schema_v1.md:90` - schema v1 transform JSON shape and validation.
- `docs/contracts/codec_boundary.md:55` - decode algorithm.
- `docs/contracts/load_document.md:61` - `loadDocument` success ordering starts with validation and materialization.
- `docs/contracts/load_document.md:88` - `loadDocument` failure ordering.
- `docs/contracts/edit_kernel.md:152` - Element update field-effect taxonomy section.
- `docs/contracts/edit_kernel.md:172` - transform update taxonomy row.
- `docs/contracts/operation_matrix.md:50` - `CanvasEdit.updateElement` operation row delegates to taxonomy.
- `docs/contracts/operation_matrix.md:72` - `loadDocument success` operation row.
- `docs/contracts/geometry.md:75` - current geometry fallback for non-invertible transform.
- `docs/contracts/spatial_kernel.md:85` - fallback budget behavior.
- `docs/contracts/diagnostics.md:31` - disabled diagnostics hot-path policy.
- `docs/diagrams/seq_hit_test_candidate_resolution.mmd:39` - hit-test diagram repeats non-invertible fallback where geometry allows it.
- `docs/diagrams/dfd_spatial_query_budget.mmd:34` - budget exceeded is forbidden from producing typed candidate result.
- `plan/step_11_operation_matrix_field_effect_taxonomy.md:40` - non-invertible transform fallback redesign note out of Step 11 scope.
- `plan/step_11_operation_matrix_field_effect_taxonomy.md:390` - Step 11 forbids removing the note.

## Observed Architecture Facts

- Pattern observed: public API owns transform DTO shape and validation statements, while edit kernel owns changed-field effects for update operations (`docs/contracts/public_api_v1.md:691`, `docs/contracts/public_api_v1.md:1167`, `docs/contracts/edit_kernel.md:154`).
- Pattern observed: schema decode materializes public immutable DTOs without runtime/store side effects, while `loadDocument` performs a separate runtime validation/materialization/install sequence (`docs/contracts/codec_boundary.md:69`, `docs/contracts/load_document.md:61`).
- Data flow: decode boundary -> schema validators -> immutable `CanvasDocument` DTO -> `loadDocument` staging -> `PreparedDocumentLoad` -> atomic runtime install (`docs/diagrams/seq_schema_v1_decode_encode_order.mmd:47`, `docs/contracts/load_document.md:63`, `docs/contracts/load_document.md:66`).
- Data flow: hit-test request -> spatial candidate handles -> Store/ReadPort current-row resolution -> hit eligibility -> exact family geometry (`docs/diagrams/seq_hit_test_candidate_resolution.mmd:17`, `docs/diagrams/seq_hit_test_candidate_resolution.mmd:35`, `docs/diagrams/seq_hit_test_candidate_resolution.mmd:38`).
- Documented split: `redesign.md` states no coarse candidate fallback for non-invertible runtime rows, while current geometry and hit-test sequence docs still document a coarse fallback path where geometry allows it (`redesign.md:21`, `docs/contracts/geometry.md:75`, `docs/diagrams/seq_hit_test_candidate_resolution.mmd:39`).

## Open Questions

- The root docs contain both the unresolved redesign note requiring non-invertible transform rejection/no fallback and active geometry/hit-test text that still allows fallback (`redesign.md:10`, `redesign.md:21`, `docs/contracts/geometry.md:75`, `docs/diagrams/seq_hit_test_candidate_resolution.mmd:39`).
- No root production `lib/` implementation was present in this investigation scope; the observed facts are from the root architecture docs, plan documents, and diagrams.
