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
Required tests:
- `test.codec.decode_encode_no_runtime_side_effects`
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

Production `CodecBoundary` owns schema v1 decode/encode only. It must not read
or write legacy schema versions.

```dart
const int canvasSchemaVersionWrite = 1;
const Set<int> canvasSchemaVersionsRead = {1};

Map<String, Object?> encodeCanvasDocument(CanvasDocument document);
String encodeCanvasDocumentToJson(CanvasDocument document);
CanvasDocument decodeCanvasDocument(Map<String, Object?> json);
CanvasDocument decodeCanvasDocumentFromJson(String json);
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
8. elements validation;
9. duplicate id checks;
10. missing resource reference checks;
11. layer/node count checks;
12. metadata validation;
13. materialize CanvasDocument immutable DTO;
14. no runtime/store side effects.
```

### 19.3 Encode algorithm

```text
1. validate public DTO;
2. canonicalize default fields;
3. sort nothing: preserve layer/resource/element order;
4. uppercase color hex;
5. include all common element fields;
6. omit optional nullable family fields only if null where schema says nullable may be omitted;
7. preserve metadata with JSON-only values;
8. return JSON-compatible Map.
```

---
