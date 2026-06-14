<!-- CONTEXT:BEGIN -->
Registry id: `section_19_codec_boundary`
Registry source: `docs/_registry/sections.yaml`
Document path: `docs/contracts/codec_boundary.md`
Owns:
- 19. CodecBoundary
Must read before editing:
- `section_05_schema_v1_contract` -> `docs/contracts/schema_v1.md`
- `section_06_validation_limits` -> `docs/contracts/validation_limits.md`
Current owners:
- `contract`
Benchmarks:
- `none`
Related diagrams:
- `dfd_schema_v1_import_encode`
- `seq_schema_v1_import_encode_order`
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
- no codec surface outside v1 public API
- no schema version outside v1 read/write in production core
<!-- CONTEXT:END -->

## 19. CodecBoundary

### 19.1 Entry points

Production `CodecBoundary` owns schema v1 encode and the canonical schema v1
reader used by both internal runtime import and explicit schema v1 decode
helpers. The canonical reader lives in codec (`schema_v1_reader.dart`) and owns
wire-format navigation, field admission, diagnostics wrapping, document/resource
and layer/element dispatch, metadata budget checks, transform/color/value
admission, and import sink delivery modes. Codec must not read or write schema
versions outside v1.

```dart
const int canvasSchemaVersionWrite = 1;
const Set<int> canvasSchemaVersionsRead = {1};

Map<String, Object?> encodeCanvasDocument(CanvasDocument document);
String encodeCanvasDocumentToJson(CanvasDocument document);

// Internal only: runtime JSON load delegates to the canonical reader and emits
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
11. no runtime side effects and no committed store side effects.
```

Explicit schema v1 decode helpers are codec-local read/output routes over the
same canonical reader: the reader emits dependency-neutral schema v1 import
events into a non-exported `CanvasDocument` builder sink, the sink materializes
public DTOs, and decoder-owned reference validation rejects duplicate
resources/layers/elements and missing image resource references after public DTO
materialization. Those decode helpers are not runtime load routes. Runtime JSON
load shares the schema v1 reader policy, but the runtime load path does not
materialize `CanvasDocument`, `CanvasImageResource`, store rows from public DTOs,
store sinks outside the import handoff, or a retained document-sized validated
fact/list/tree payload. Duplicate id checks, id admission, missing resource
reference checks, and cross-row reference checks remain store-owned preparation
responsibilities for runtime import.

Public non-isolated import sinks receive events only after the codec-owned
validation pass succeeds, so invalid schema input cannot partially notify those
sinks. Runtime JSON load uses an isolated import sink instead: after raw JSON,
root object, and schemaVersion admission, codec validation and import event
emission may stream in one pass. If any codec validation, import event delivery,
or store-owned preparation step fails, the isolated sink must abort its pending
state before the exception escapes. Pending isolated sink state is not a
committed store mutation and must not be publicly observable.

The public encode helper still validates DTO input before writing canonical
schema v1 JSON. That validation may materialize and inspect public DTOs because
encode is an explicit projection/output path, not the runtime load path:

```text
1. validate `contracts/public` DTO;
2. reject invalid metadata or non-invertible element transforms;
3. enforce layer/node/resource limits;
4. no runtime/store side effects.
```

Runtime import validation rejects non-invertible element transforms before
document install or runtime mutation. This is codec boundary validation, not
runtime repair: validation failure does not expose a partial `CanvasDocument`,
does not call a public decode helper, does not commit store state, and does not
mutate runtime state.

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
