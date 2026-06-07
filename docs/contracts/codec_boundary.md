<!-- CONTEXT:BEGIN -->
Registry id: `section_19_codec_boundary`
Registry source: `docs/_registry/sections.yaml`
Document path: `docs/contracts/codec_boundary.md`
Owns:
- 19. CodecBoundary
Must read before editing:
- `section_05_schema_v1_contract` -> `docs/contracts/schema_v1.md`
- `section_06_validation_limits` -> `docs/contracts/validation_limits.md`
Feeds phases:
- `P3`
Related donors:
- `codec_guards`
- `codec_json_require`
- `codec_json_parse`
- `codec_metadata_decode`
- `codec_layer_decode`
- `codec_node_common_decode`
- `codec_family_decode`
- `codec_scene_codec_flow`
- `codec_validation_path_surface`
Related diagrams:
- `dfd_schema_v1_decode_encode`
- `seq_schema_v1_decode_encode_order`
Required tests:
- `test.codec.decode_encode_no_runtime_side_effects`
- `test.codec.schema_v1.canonical_encode_roundtrip`
- `test.codec.schema_v1.metadata_projection`
- `test.guardrails.codec_no_runtime_imports`
Guardrails:
- `codec.schema_v1_exact`
- `codec.known_fields_validated`
- `codec.no_runtime_side_effects`
Do not assume:
- no legacy SceneCodec surface as next API
- no schema v7 read/write in production core
<!-- CONTEXT:END -->

## 19. CodecBoundary

### 19.1 Entry points

Production `CodecBoundary` owns schema v1 encode and internal schema v1 import
validation for runtime JSON load. It must not read or write legacy schema
versions.

```dart
const int canvasSchemaVersionWrite = 1;
const Set<int> canvasSchemaVersionsRead = {1};

Map<String, Object?> encodeCanvasDocument(CanvasDocument document);
String encodeCanvasDocumentToJson(CanvasDocument document);

// Internal only: runtime JSON load validates schema v1 JSON and emits
// dependency-neutral import events for store-owned preparation.
```

### 19.2 Decode algorithm

```text
1. raw JSON length check for string path;
2. JSON parse;
3. root object check;
4. schemaVersion check;
5. known field validation and v1 unknown field policy;
6. primitive validation;
7. resources validation;
8. elements validation, including non-invertible element transform rejection;
9. metadata validation;
10. dependency-neutral import event emission;
11. no runtime/store side effects.
```

The public API does not expose `decodeCanvasDocument` or
`decodeCanvasDocumentFromJson` as runtime load routes. Runtime JSON load shares
the schema v1 validation policy, but the codec side does not materialize
`CanvasDocument`, `CanvasImageResource`, store rows, store sinks, or a retained
document-sized validated fact/list/tree payload. Duplicate id checks, id
admission, missing resource reference checks, and cross-row reference checks are
store-owned preparation responsibilities.

The public encode helper still validates DTO input before writing canonical
schema v1 JSON. That validation may materialize and inspect public DTOs because
encode is an explicit projection/output path, not the runtime load path:

```text
1. validate `contracts/public` DTO;
2. reject invalid metadata or non-invertible element transforms;
3. enforce layer/node/resource limits;
4. no runtime/store side effects.
```

Runtime import validation rejects non-invertible element transforms before any
store preparation or runtime mutation. This is codec boundary validation, not
runtime repair: validation failure does not expose a partial `CanvasDocument`,
does not call a public decode helper, and does not mutate runtime or store
state.

### 19.3 Encode algorithm

```text
1. validate `contracts/public` DTO;
2. canonicalize default fields;
3. sort nothing: preserve layer/resource/element order;
4. uppercase color hex;
5. include all common element fields;
6. omit optional nullable family fields only if null where schema says nullable may be omitted;
7. project `CanvasMetadata` to JSON-only object values and preserve metadata;
8. return JSON-compatible Map.
```

Raw `Map<String, Object?>` values belong to the JSON entry and exit boundary.
Public contract metadata-bearing DTOs expose `CanvasMetadata`; the codec imports
`lib/src/contracts/public/**` declarations directly, validates and freezes raw
metadata before DTO exposure, and projects `CanvasMetadata` back to the schema
v1 object shape during encode without importing API facade wrappers.

---
