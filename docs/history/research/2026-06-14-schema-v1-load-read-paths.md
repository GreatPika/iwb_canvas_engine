---
date: 2026-06-14
researcher: Codex
commit: 342d3fc1
branch: new-architecture
research_question: "Detailed research on the duplicated schema v1 public decoder and import-emitter read paths so a future design can be planned."
---

# Research: Schema V1 Load Read Paths

## Summary

Schema v1 JSON currently has two production read paths. The public decoder path
parses and validates JSON into public object projections, then validates
document-level references after materialization (`lib/src/codec/schema_v1_decoder.dart:24`,
`lib/src/codec/schema_v1_decoder.dart:65`,
`lib/src/codec/schema_v1_decoder.dart:78`). The runtime load path parses and
validates the same schema shape into dependency-neutral import events, then a
store-owned sink prepares and installs rows without first building a public
`CanvasDocument` (`lib/src/codec/schema_v1_import_emitter.dart:32`,
`lib/src/codec/schema_v1_import_emitter.dart:65`,
`lib/src/edit/staged_document_load.dart:123`,
`lib/src/store/schema_v1_store_import.dart:87`).

The faster runtime load path is an explicit architecture decision. Contracts
and tests require public JSON load to enter through
`runtime.edits.loadDocumentFromJson(json)`, avoid a public decode helper as the
load route, avoid retained public document/resource DTOs during load, and leave
the first public projection to an explicit `readDocument()` call
(`docs/contracts/public_api_v1.md:396`,
`docs/contracts/public_api_v1.md:808`,
`docs/contracts/codec_boundary.md:65`,
`docs/contracts/codec_boundary.md:68`,
`docs/architecture/03_data_model.md:61`,
`test/store/fixtures/schema_v1_store_import_fixture.dart:29`).

The duplicated surface is concentrated in schema v1 navigation and validation:
both paths read root sections, camera/background/grid/palette/resource/layer and
element fields, metadata, transforms, colors, text/path/stroke values, and
materialize those values into their target representation
(`lib/src/codec/schema_v1_decoder.dart:125`,
`lib/src/codec/schema_v1_decoder.dart:466`,
`lib/src/codec/schema_v1_import_emitter.dart:409`,
`lib/src/codec/schema_v1_import_emitter.dart:698`). Shared code currently covers
root `schemaVersion` validation and diagnostics wrapping only
(`lib/src/codec/schema_v1_validation.dart:5`,
`lib/src/codec/schema_v1_diagnostics.dart:5`).

## Detailed Findings

### 1. Public Decoder Path

- **Location**: `lib/src/codec/schema_v1_decoder.dart:24`.
- **What it does**: `decodeSchemaV1Document` validates the schema root, reads
  resources, background elements, layers, camera, background, grid, palette, and
  metadata, then materializes a public `CanvasDocument`
  (`lib/src/codec/schema_v1_decoder.dart:28`,
  `lib/src/codec/schema_v1_decoder.dart:30`,
  `lib/src/codec/schema_v1_decoder.dart:42`,
  `lib/src/codec/schema_v1_decoder.dart:46`,
  `lib/src/codec/schema_v1_decoder.dart:52`,
  `lib/src/codec/schema_v1_decoder.dart:65`).
- **JSON entry**: `decodeSchemaV1DocumentFromJson` checks raw string length,
  parses JSON, validates the root is a `Map<String, Object?>`, then delegates to
  `decodeSchemaV1Document` (`lib/src/codec/schema_v1_decoder.dart:83`,
  `lib/src/codec/schema_v1_decoder.dart:88`,
  `lib/src/codec/schema_v1_decoder.dart:97`,
  `lib/src/codec/schema_v1_decoder.dart:111`,
  `lib/src/codec/schema_v1_decoder.dart:122`).
- **Post-materialization reference policy**: `_validateDocumentReferences`
  collects resource and layer ids, rejects duplicate layer ids, duplicate element
  ids, and missing image resources after `CanvasDocument` materialization
  (`lib/src/codec/schema_v1_decoder.dart:732`,
  `lib/src/codec/schema_v1_decoder.dart:737`,
  `lib/src/codec/schema_v1_decoder.dart:748`,
  `lib/src/codec/schema_v1_decoder.dart:775`,
  `lib/src/codec/schema_v1_decoder.dart:785`).
- **Reader helpers**: the decoder owns local map/list/typed field readers and a
  materialization wrapper that converts public constructor failures into schema
  diagnostics (`lib/src/codec/schema_v1_decoder.dart:821`,
  `lib/src/codec/schema_v1_decoder.dart:827`,
  `lib/src/codec/schema_v1_decoder.dart:877`,
  `lib/src/codec/schema_v1_decoder.dart:1428`).

### 2. Import Emitter Path

- **Location**: `lib/src/codec/schema_v1_import_emitter.dart:23`.
- **What it does**: `importSchemaV1DocumentFromJson` parses a JSON string into a
  root map and emits schema import events into a sink
  (`lib/src/codec/schema_v1_import_emitter.dart:23`,
  `lib/src/codec/schema_v1_import_emitter.dart:28`,
  `lib/src/codec/schema_v1_import_emitter.dart:29`).
- **Isolated entry**: `importSchemaV1DocumentFromJsonIntoIsolatedSink` decodes
  the root, emits into an isolated sink, and calls `sink.abortDocument()` on
  failures so pending sink state can be cleared
  (`lib/src/codec/schema_v1_import_emitter.dart:32`,
  `lib/src/codec/schema_v1_import_emitter.dart:40`,
  `lib/src/codec/schema_v1_import_emitter.dart:44`,
  `lib/src/codec/schema_v1_import_emitter.dart:45`).
- **Validation before public sink delivery**: non-isolated import validates the
  root and import event shape before any events are delivered
  (`lib/src/codec/schema_v1_import_emitter.dart:50`,
  `lib/src/codec/schema_v1_import_emitter.dart:55`,
  `lib/src/codec/schema_v1_import_emitter.dart:56`,
  `lib/src/codec/schema_v1_import_emitter.dart:57`).
- **Event order**: `_emitSchemaV1ImportEvents` reads the document event,
  resources, background elements, layers, and layer elements before ending the
  document (`lib/src/codec/schema_v1_import_emitter.dart:190`,
  `lib/src/codec/schema_v1_import_emitter.dart:196`,
  `lib/src/codec/schema_v1_import_emitter.dart:214`,
  `lib/src/codec/schema_v1_import_emitter.dart:221`,
  `lib/src/codec/schema_v1_import_emitter.dart:246`,
  `lib/src/codec/schema_v1_import_emitter.dart:250`,
  `lib/src/codec/schema_v1_import_emitter.dart:259`).
- **Reader helpers**: the emitter owns local map/list/string/number/materialized
  readers and records the diagnostics count before materialization to avoid
  duplicate records (`lib/src/codec/schema_v1_import_emitter.dart:1099`,
  `lib/src/codec/schema_v1_import_emitter.dart:1267`,
  `lib/src/codec/schema_v1_import_emitter.dart:1544`,
  `lib/src/codec/schema_v1_import_emitter.dart:1679`,
  `lib/src/codec/schema_v1_import_emitter.dart:1729`).

### 3. Duplicated Schema Navigation

- **Document envelope**: the decoder reads camera/background/grid/palette and
  metadata before constructing `CanvasDocument`
  (`lib/src/codec/schema_v1_decoder.dart:52`,
  `lib/src/codec/schema_v1_decoder.dart:65`). The emitter has corresponding
  document-event readers for camera, background, grid, palette, and metadata
  (`lib/src/codec/schema_v1_import_emitter.dart:409`,
  `lib/src/codec/schema_v1_import_emitter.dart:426`,
  `lib/src/codec/schema_v1_import_emitter.dart:445`,
  `lib/src/codec/schema_v1_import_emitter.dart:470`,
  `lib/src/codec/schema_v1_import_emitter.dart:504`).
- **Resources**: the decoder reads image resources into public resource
  declarations before document materialization
  (`lib/src/codec/schema_v1_decoder.dart:30`). The emitter reads image resource
  declarations into `SchemaV1ImageResourceImportEvent`
  (`lib/src/codec/schema_v1_import_emitter.dart:553`,
  `lib/src/codec/schema_v1_import_emitter.dart:640`).
- **Layers and elements**: the decoder dispatches element maps through its
  schema element reader, while the emitter dispatches through its import-event
  element reader (`lib/src/codec/schema_v1_decoder.dart:466`,
  `lib/src/codec/schema_v1_import_emitter.dart:642`,
  `lib/src/codec/schema_v1_import_emitter.dart:698`).
- **Element families**: the emitter has separate readers for common element
  fields, image, path, text, stroke, line, and rect events
  (`lib/src/codec/schema_v1_import_emitter.dart:744`,
  `lib/src/codec/schema_v1_import_emitter.dart:827`,
  `lib/src/codec/schema_v1_import_emitter.dart:859`,
  `lib/src/codec/schema_v1_import_emitter.dart:912`,
  `lib/src/codec/schema_v1_import_emitter.dart:994`,
  `lib/src/codec/schema_v1_import_emitter.dart:1038`,
  `lib/src/codec/schema_v1_import_emitter.dart:1065`). The public decoder owns
  the corresponding public element materialization path and field readers under
  its element dispatch (`lib/src/codec/schema_v1_decoder.dart:466`).
- **Value admission examples**: both paths validate colors, transforms, sizes,
  metadata, and text/path-specific values through local readers before
  materialization; examples on the emitter side include color, offset, size, and
  transform admission (`lib/src/codec/schema_v1_import_emitter.dart:1267`,
  `lib/src/codec/schema_v1_import_emitter.dart:1333`,
  `lib/src/codec/schema_v1_import_emitter.dart:1374`,
  `lib/src/codec/schema_v1_import_emitter.dart:1419`). The decoder color reader
  is local to the decoder (`lib/src/codec/schema_v1_decoder.dart:1072`).

### 4. Shared Validation and Diagnostics

- **Root schema validation**: `validateSchemaV1Root` currently validates only
  `schemaVersion` presence, integer type, and value `1`
  (`lib/src/codec/schema_v1_validation.dart:5`,
  `lib/src/codec/schema_v1_validation.dart:9`,
  `lib/src/codec/schema_v1_validation.dart:10`,
  `lib/src/codec/schema_v1_validation.dart:11`,
  `lib/src/codec/schema_v1_validation.dart:14`,
  `lib/src/codec/schema_v1_validation.dart:16`).
- **Diagnostics wrapper**: `recordSchemaV1Diagnostic` optionally records a
  diagnostic event on a hub and returns the original `CanvasDataException`
  (`lib/src/codec/schema_v1_diagnostics.dart:5`,
  `lib/src/codec/schema_v1_diagnostics.dart:14`,
  `lib/src/codec/schema_v1_diagnostics.dart:19`,
  `lib/src/codec/schema_v1_diagnostics.dart:32`).
- **Import event contract**: `SchemaV1ImportSink` declares `beginDocument`,
  `imageResource`, `backgroundElement`, `layer`, `layerElement`, and
  `endDocument`; `IsolatedSchemaV1ImportSink` adds `abortDocument`
  (`lib/src/contracts/internal/schema_v1_import_events.dart:10`,
  `lib/src/contracts/internal/schema_v1_import_events.dart:11`,
  `lib/src/contracts/internal/schema_v1_import_events.dart:16`,
  `lib/src/contracts/internal/schema_v1_import_events.dart:20`,
  `lib/src/contracts/internal/schema_v1_import_events.dart:22`).
- **Event payloads**: the internal event file defines document, image resource,
  layer, and sealed element import events plus common element fields
  (`lib/src/contracts/internal/schema_v1_import_events.dart:25`,
  `lib/src/contracts/internal/schema_v1_import_events.dart:39`,
  `lib/src/contracts/internal/schema_v1_import_events.dart:57`,
  `lib/src/contracts/internal/schema_v1_import_events.dart:64`,
  `lib/src/contracts/internal/schema_v1_import_events.dart:173`).

### 5. Runtime Load Flow

- **Public entry**: `CanvasEditPort` declares
  `loadDocumentFromJson(String json)`, and `CanvasRuntime.edits` exposes the
  root edit port (`lib/src/contracts/public/canvas_runtime.dart:135`,
  `lib/src/contracts/public/canvas_runtime.dart:138`,
  `lib/src/api/canvas_runtime.dart:36`,
  `lib/src/api/canvas_runtime.dart:38`).
- **Edit boundary**: `_EditKernelPort.loadDocumentFromJson` checks the mutation
  guard, rejects active edit callbacks, and calls the runtime load installer
  (`lib/src/edit/edit_kernel.dart:316`,
  `lib/src/edit/edit_kernel.dart:325`,
  `lib/src/edit/edit_kernel.dart:327`,
  `lib/src/edit/edit_kernel.dart:332`).
- **Runtime wiring**: `RuntimeRoot` creates `LoadDocumentPipeline` with the
  store and diagnostics hub, then wires `_loadDocumentFromJson` into the edit
  kernel (`lib/src/runtime/runtime_root.dart:155`,
  `lib/src/runtime/runtime_root.dart:181`,
  `lib/src/runtime/runtime_root.dart:185`,
  `lib/src/runtime/runtime_root.dart:234`,
  `lib/src/runtime/runtime_root.dart:243`).
- **Preparation**: `LoadDocumentPipeline.prepareFromJson` creates
  `StoreSchemaV1ImportBuilder`, imports JSON events into it through the isolated
  emitter, and asks the store to prepare the schema v1 import
  (`lib/src/edit/staged_document_load.dart:123`,
  `lib/src/edit/staged_document_load.dart:124`,
  `lib/src/edit/staged_document_load.dart:125`,
  `lib/src/edit/staged_document_load.dart:132`).
- **No prepared projection**: `PreparedDocumentLoad.document` throws
  `StateError`, so prepared JSON load is not a materialized public
  `CanvasDocument` projection (`lib/src/edit/staged_document_load.dart:56`,
  `lib/src/edit/staged_document_load.dart:59`).
- **Install**: `RuntimeRoot._loadDocumentFromJson` prepares the load, clears
  interaction/text state after successful preparation, consumes the prepared
  load, clears selection, copies the prepared camera into runtime view camera,
  increments view camera and epoch revisions, and delivers load effects
  (`lib/src/runtime/runtime_root.dart:1744`,
  `lib/src/runtime/runtime_root.dart:1745`,
  `lib/src/runtime/runtime_root.dart:1751`,
  `lib/src/runtime/runtime_root.dart:1752`,
  `lib/src/runtime/runtime_root.dart:1753`,
  `lib/src/runtime/runtime_root.dart:1754`,
  `lib/src/runtime/runtime_root.dart:1755`,
  `lib/src/runtime/runtime_root.dart:1756`,
  `lib/src/runtime/runtime_root.dart:1760`).

### 6. Store Import Flow

- **Sink implementation**: `StoreSchemaV1ImportBuilder` implements
  `IsolatedSchemaV1ImportSink` and accumulates document, resource, family,
  layer, and order builders (`lib/src/store/schema_v1_store_import.dart:15`,
  `lib/src/store/schema_v1_store_import.dart:16`,
  `lib/src/store/schema_v1_store_import.dart:17`,
  `lib/src/store/schema_v1_store_import.dart:19`,
  `lib/src/store/schema_v1_store_import.dart:21`,
  `lib/src/store/schema_v1_store_import.dart:23`).
- **Event consumption**: background and layer element events populate family
  rows and order/layer membership facts (`lib/src/store/schema_v1_store_import.dart:47`,
  `lib/src/store/schema_v1_store_import.dart:62`).
- **Abort behavior**: `abortDocument` clears the pending document and marks the
  builder aborted (`lib/src/store/schema_v1_store_import.dart:77`,
  `lib/src/store/schema_v1_store_import.dart:82`).
- **Prepare behavior**: `prepare` rejects aborted/not-ended/not-started state,
  advances revisions, consumes resource/family/layer/order builders, creates an
  `ElementRegistry`, and creates `CommittedDocument.fromStoreTables`
  (`lib/src/store/schema_v1_store_import.dart:87`,
  `lib/src/store/schema_v1_store_import.dart:91`,
  `lib/src/store/schema_v1_store_import.dart:94`,
  `lib/src/store/schema_v1_store_import.dart:97`,
  `lib/src/store/schema_v1_store_import.dart:101`,
  `lib/src/store/schema_v1_store_import.dart:102`,
  `lib/src/store/schema_v1_store_import.dart:105`,
  `lib/src/store/schema_v1_store_import.dart:110`).
- **Store boundary**: `DocumentStoreKernel.prepareSchemaV1Import` delegates to
  builder preparation with current base revisions, and
  `installPreparedSchemaV1Import` consumes the prepared import and replaces the
  committed document (`lib/src/store/document_store_kernel.dart:309`,
  `lib/src/store/document_store_kernel.dart:354`,
  `lib/src/store/document_store_kernel.dart:365`).
- **Store-owned rejection**: family tables reject duplicate element ids and
  missing image resources during schema v1 import row admission
  (`lib/src/store/family_tables.dart:543`,
  `lib/src/store/family_tables.dart:547`,
  `lib/src/store/family_tables.dart:557`,
  `lib/src/store/family_tables.dart:565`).

### 7. Contract and Design Sources

- **Public API contract**: documented runtime construction has no document or
  JSON input; saved schema v1 content is loaded after construction through
  `runtime.edits.loadDocumentFromJson(json)`
  (`docs/contracts/public_api_v1.md:363`,
  `docs/contracts/public_api_v1.md:365`,
  `docs/contracts/public_api_v1.md:395`,
  `docs/contracts/public_api_v1.md:396`,
  `docs/contracts/public_api_v1.md:397`).
- **Codec boundary**: the codec boundary owns schema v1 encode and internal
  import validation; the documented import order is raw length, JSON parse,
  root object, schema version, known fields, primitives, resources, elements,
  metadata, and dependency-neutral events
  (`docs/contracts/codec_boundary.md:35`,
  `docs/contracts/codec_boundary.md:51`,
  `docs/contracts/codec_boundary.md:61`).
- **No public DTO load route**: runtime load must not expose public decode
  helpers as the load route or materialize `CanvasDocument`,
  `CanvasImageResource`, store rows, store sinks, or a retained document-sized
  fact graph on the codec side (`docs/contracts/codec_boundary.md:65`,
  `docs/contracts/codec_boundary.md:68`,
  `docs/contracts/public_api_v1.md:811`,
  `docs/contracts/public_api_v1.md:813`).
- **Load contract**: successful load ordering includes raw length check,
  parse/schema validation, import events into isolated sink, store preparation,
  cleanup, atomic install, runtime camera initialization, revision increments,
  cache invalidation, repaint, and one public state publication
  (`docs/contracts/load_document.md:60`,
  `docs/contracts/load_document.md:63`,
  `docs/contracts/load_document.md:66`,
  `docs/contracts/load_document.md:69`,
  `docs/contracts/load_document.md:73`,
  `docs/contracts/load_document.md:78`,
  `docs/contracts/load_document.md:80`,
  `docs/contracts/load_document.md:81`,
  `docs/contracts/load_document.md:85`,
  `docs/contracts/load_document.md:86`,
  `docs/contracts/load_document.md:87`).
- **Data model**: schema v1 JSON load uses dependency-neutral events into
  store-owned rows/tables/resource ids/reference/camera/projection invalidation
  facts; public DTOs are projections, not live retained store state
  (`docs/architecture/03_data_model.md:61`,
  `docs/architecture/03_data_model.md:65`,
  `docs/architecture/03_data_model.md:67`,
  `docs/architecture/03_data_model.md:75`,
  `docs/architecture/03_data_model.md:127`).
- **Design pressure**: the canonical schema v1 JSON load design records the
  current codec decoder as public DTO/resource descriptor materialization and
  selects a separate runtime importer that reuses schema validation semantics
  without codec-to-store imports or a retained import graph
  (`docs/history/designs/2026-06-07-canonical-schema-v1-json-load-api.md:541`,
  `docs/history/designs/2026-06-07-canonical-schema-v1-json-load-api.md:552`,
  `docs/history/designs/2026-06-07-canonical-schema-v1-json-load-api.md:580`,
  `docs/history/designs/2026-06-07-canonical-schema-v1-json-load-api.md:597`).

### 8. Tests, Guardrails, and Benchmarks

- **Emitter structural checks**: tests assert the import emitter does not
  contain `CanvasDocument`, `CanvasImageResource`, store/runtime/edit/frame
  imports, public decode calls, retained `List<SchemaV1...`, or
  `Map<CanvasElementId...` patterns
  (`test/codec/schema_v1_import_emitter_test.dart:22`,
  `test/codec/schema_v1_import_emitter_test.dart:27`,
  `test/codec/schema_v1_import_emitter_test.dart:34`,
  `test/codec/schema_v1_import_emitter_test.dart:36`).
- **Emitter behavior checks**: valid JSON emits ordered dependency-neutral
  events; invalid non-isolated documents emit no partial events; isolated
  failures abort pending state
  (`test/codec/schema_v1_import_emitter_test.dart:67`,
  `test/codec/schema_v1_import_emitter_test.dart:72`,
  `test/codec/schema_v1_import_emitter_test.dart:221`,
  `test/codec/schema_v1_import_emitter_test.dart:247`,
  `test/codec/schema_v1_import_emitter_test.dart:276`).
- **Codec/store policy split**: duplicate ids and missing resource references
  are asserted as not codec-owned policy in the emitter tests, while store import
  fixtures assert store preparation owns duplicate/reference rejection
  (`test/codec/schema_v1_import_emitter_test.dart:356`,
  `test/codec/schema_v1_import_emitter_test.dart:386`,
  `test/store/fixtures/schema_v1_store_import_fixture.dart:48`,
  `test/store/fixtures/schema_v1_store_import_fixture.dart:266`).
- **Store import projection checks**: store import tests assert valid import
  prepares and installs rows without increasing `projectionBuildCount`; explicit
  `readDocument()` builds the first projection
  (`test/store/fixtures/schema_v1_store_import_fixture.dart:29`,
  `test/store/fixtures/schema_v1_store_import_fixture.dart:32`,
  `test/store/fixtures/schema_v1_store_import_fixture.dart:36`,
  `test/store/fixtures/schema_v1_store_import_fixture.dart:38`,
  `test/store/fixtures/schema_v1_store_import_fixture.dart:41`).
- **Store import structural checks**: tests assert store import code does not
  construct public resources/documents or retain event lists in preparation
  (`test/store/schema_v1_store_import_test.dart:18`,
  `test/store/schema_v1_store_import_test.dart:32`,
  `test/store/schema_v1_store_import_test.dart:33`,
  `test/store/schema_v1_store_import_test.dart:34`,
  `test/store/schema_v1_store_import_test.dart:36`).
- **Runtime load publication**: runtime fixtures cover successful one-snapshot
  publication, replacement install, load effects, selection clearing, preview
  cleanup, and failure paths that leave runtime facts unchanged
  (`test/runtime/fixtures/load_document_state_publication_fixture.dart:19`,
  `test/runtime/fixtures/load_document_state_publication_fixture.dart:113`,
  `test/runtime/fixtures/load_document_state_publication_fixture.dart:117`,
  `test/runtime/fixtures/load_document_state_publication_fixture.dart:151`,
  `test/runtime/fixtures/load_document_state_publication_fixture.dart:259`,
  `test/runtime/fixtures/load_document_state_publication_fixture.dart:393`).
- **API guardrail**: document load input guardrail tests accept production load
  surfaces and reject unapproved `CanvasDocument` load inputs, runtime/store
  bypasses, renamed/aliased inputs, store installer/import inputs, testing
  constructors, and load callback inputs
  (`test/api_contract/no_unapproved_document_load_inputs_test.dart:13`,
  `test/api_contract/no_unapproved_document_load_inputs_test.dart:29`,
  `test/api_contract/no_unapproved_document_load_inputs_test.dart:46`,
  `test/api_contract/no_unapproved_document_load_inputs_test.dart:57`,
  `test/api_contract/no_unapproved_document_load_inputs_test.dart:198`,
  `tool/guardrails/src/document_load_input_guardrail.dart:292`).
- **Projection guardrail**: store projection guardrail rejects retained public
  `CanvasDocument` fields/top-level variables and non-read projection
  construction/invocation/return paths
  (`tool/guardrails/src/store_projection_checks.dart:1`,
  `tool/guardrails/src/store_projection_checks.dart:45`,
  `tool/guardrails/src/store_projection_checks.dart:87`,
  `tool/guardrails/src/store_projection_checks.dart:179`,
  `tool/guardrails/src/store_projection_checks.dart:201`).
- **Benchmark registry**: registry contains `projection.read_document`,
  `codec.decode_v1`, `load_document.success`, `load_document.breakdown`, and
  `load_document.failure`; load success requires `schema_import_load_us`
  (`docs/_registry/benchmarks.yaml:640`,
  `docs/_registry/benchmarks.yaml:661`,
  `docs/_registry/benchmarks.yaml:680`,
  `docs/_registry/benchmarks.yaml:694`,
  `docs/_registry/benchmarks.yaml:700`,
  `docs/_registry/benchmarks.yaml:720`).
- **Benchmark measurement split**: the probe measures load success through
  `runtime.edits.loadDocumentFromJson(encodedJson)` and measures decode,
  runtime construction, load, and first projection separately in breakdown
  (`test/benchmarks/benchmark_probe_flutter.dart:2000`,
  `test/benchmarks/benchmark_probe_flutter.dart:2012`,
  `test/benchmarks/benchmark_probe_flutter.dart:2047`,
  `test/benchmarks/benchmark_probe_flutter.dart:2051`,
  `test/benchmarks/benchmark_probe_flutter.dart:2052`,
  `test/benchmarks/benchmark_probe_flutter.dart:2086`).

## Code References

- `lib/src/codec/schema_v1_decoder.dart:24` - public schema v1 map decode entry.
- `lib/src/codec/schema_v1_decoder.dart:65` - decoder materializes `CanvasDocument`.
- `lib/src/codec/schema_v1_decoder.dart:78` - decoder validates references after materialization.
- `lib/src/codec/schema_v1_decoder.dart:83` - public schema v1 JSON decode entry.
- `lib/src/codec/schema_v1_decoder.dart:466` - decoder element dispatch.
- `lib/src/codec/schema_v1_decoder.dart:732` - decoder document reference validation.
- `lib/src/codec/schema_v1_decoder.dart:821` - decoder local map reader.
- `lib/src/codec/schema_v1_decoder.dart:1428` - decoder materialization wrapper.
- `lib/src/codec/schema_v1_import_emitter.dart:23` - JSON import emitter entry.
- `lib/src/codec/schema_v1_import_emitter.dart:32` - isolated import emitter entry.
- `lib/src/codec/schema_v1_import_emitter.dart:81` - import event validation pass.
- `lib/src/codec/schema_v1_import_emitter.dart:190` - import event emission order.
- `lib/src/codec/schema_v1_import_emitter.dart:409` - emitter document event reader.
- `lib/src/codec/schema_v1_import_emitter.dart:553` - emitter image resource reader.
- `lib/src/codec/schema_v1_import_emitter.dart:698` - emitter element dispatch.
- `lib/src/codec/schema_v1_import_emitter.dart:1099` - emitter local map reader.
- `lib/src/codec/schema_v1_import_emitter.dart:1679` - emitter materialization wrapper.
- `lib/src/codec/schema_v1_validation.dart:5` - shared schema v1 root validation.
- `lib/src/codec/schema_v1_diagnostics.dart:5` - shared schema v1 diagnostic wrapper.
- `lib/src/contracts/internal/schema_v1_import_events.dart:10` - import sink protocol.
- `lib/src/edit/staged_document_load.dart:123` - runtime load preparation from JSON.
- `lib/src/store/schema_v1_store_import.dart:15` - store import builder sink implementation.
- `lib/src/store/schema_v1_store_import.dart:87` - store import preparation.
- `lib/src/store/document_store_kernel.dart:309` - store prepare boundary.
- `lib/src/store/document_store_kernel.dart:354` - store install boundary.
- `lib/src/runtime/runtime_root.dart:1744` - runtime JSON load install/publication flow.
- `docs/contracts/codec_boundary.md:65` - public decode helpers are not runtime load routes.
- `docs/contracts/codec_boundary.md:68` - codec side must not materialize public DTOs/store rows/retained import graph.
- `docs/contracts/load_document.md:60` - documented load success ordering.
- `docs/history/designs/2026-06-07-canonical-schema-v1-json-load-api.md:541` - prior design pressure around decoder materialization and separate runtime importer.

## Search Coverage

- Inspected production codec files: `lib/src/codec/schema_v1_decoder.dart`,
  `lib/src/codec/schema_v1_import_emitter.dart`,
  `lib/src/codec/schema_v1_validation.dart`,
  `lib/src/codec/schema_v1_diagnostics.dart`.
- Inspected internal event/store/runtime flow files:
  `lib/src/contracts/internal/schema_v1_import_events.dart`,
  `lib/src/edit/staged_document_load.dart`,
  `lib/src/edit/edit_kernel.dart`,
  `lib/src/runtime/runtime_root.dart`,
  `lib/src/store/schema_v1_store_import.dart`,
  `lib/src/store/document_store_kernel.dart`,
  `lib/src/store/family_tables.dart`,
  `lib/src/store/resource_table.dart`,
  `lib/src/store/document_projection_cache.dart`.
- Inspected contracts and design sources:
  `docs/contracts/public_api_v1.md`,
  `docs/contracts/codec_boundary.md`,
  `docs/contracts/load_document.md`,
  `docs/contracts/schema_v1.md`,
  `docs/contracts/resources.md`,
  `docs/contracts/validation_limits.md`,
  `docs/architecture/03_data_model.md`,
  `docs/history/designs/2026-06-07-canonical-schema-v1-json-load-api.md`.
- Inspected tests and guardrails:
  `test/codec/schema_v1_import_emitter_test.dart`,
  `test/codec/schema_v1/diagnostics_routing_test.dart`,
  `test/store/fixtures/schema_v1_store_import_fixture.dart`,
  `test/store/schema_v1_store_import_test.dart`,
  `test/runtime/fixtures/load_document_state_publication_fixture.dart`,
  `test/api_contract/no_unapproved_document_load_inputs_test.dart`,
  `tool/guardrails/src/store_projection_checks.dart`,
  `tool/guardrails/src/document_load_input_guardrail.dart`.
- Inspected benchmark surfaces:
  `docs/_registry/benchmarks.yaml`,
  `test/benchmarks/benchmark_probe_flutter.dart`,
  `test/benchmarks/benchmark_manifest_test.dart`,
  `test/benchmarks/benchmark_diff_test.dart`,
  `tool/bench/src/benchmark_diff.dart`,
  `tool/bench/manual/reference_reports/xiaomi_22081283g_android14_flutter_3_44_0.json`.
- Searched repository-local docs/code for
  `loadDocumentFromJson`, `decodeSchemaV1DocumentFromJson`,
  `importSchemaV1DocumentFromJsonIntoIsolatedSink`, `schema_import_load_us`,
  `CanvasDocument`, `CanvasImageResource`, `retained`, `projection`, and
  `decodeCanvasDocument`.

## Observed Architecture Facts

- The public runtime load route is `CanvasEditPort.loadDocumentFromJson`, not a
  constructor input or public decode helper (`lib/src/contracts/public/canvas_runtime.dart:138`,
  `docs/contracts/public_api_v1.md:396`,
  `docs/contracts/public_api_v1.md:808`).
- Public `CanvasDocument` is a projection for reads and encode/decode surfaces;
  runtime JSON load prepares store rows through import events before any public
  projection is built (`docs/architecture/03_data_model.md:61`,
  `docs/architecture/03_data_model.md:75`,
  `lib/src/edit/staged_document_load.dart:56`).
- The import event protocol is dependency-neutral from runtime/store owner
  types, while the store import builder is the first runtime-load path component
  that converts events into store-owned tables
  (`lib/src/contracts/internal/schema_v1_import_events.dart:10`,
  `lib/src/store/schema_v1_store_import.dart:15`,
  `lib/src/store/schema_v1_store_import.dart:87`).
- Reference/admission policy is split: the public decoder validates duplicates
  and missing image resources after `CanvasDocument` materialization, while the
  emitter lets duplicate/missing-reference event streams reach the store and the
  store rejects them during row admission
  (`lib/src/codec/schema_v1_decoder.dart:732`,
  `test/codec/schema_v1_import_emitter_test.dart:356`,
  `lib/src/store/family_tables.dart:543`).
- Current shared codec helpers do not hold the full schema v1 field navigation
  policy; they cover root version validation and diagnostics wrapping
  (`lib/src/codec/schema_v1_validation.dart:5`,
  `lib/src/codec/schema_v1_diagnostics.dart:5`).
- Benchmark infrastructure treats `schema_import_load_us` as a separate load
  metric and keeps first public projection in a separate breakdown metric
  (`docs/_registry/benchmarks.yaml:694`,
  `test/benchmarks/benchmark_probe_flutter.dart:2051`,
  `test/benchmarks/benchmark_probe_flutter.dart:2058`).

## Not Found

- No `decodeCanvasDocument` match was found in `docs/contracts` or
  `docs/_registry/public_api_v1.yaml`.
- No `initialDocument` match was found in `docs/contracts` or
  `docs/_registry/public_api_v1.yaml`.
- No old public load signature match such as `loadDocument(CanvasDocument`,
  `void loadDocument(`, or `loadDocument(document` was found in
  `docs/contracts` or `docs/_registry/public_api_v1.yaml`.
- No runtime load call path was found from `LoadDocumentPipeline.prepareFromJson`
  to `decodeSchemaV1DocumentFromJson`; the traced runtime path calls
  `importSchemaV1DocumentFromJsonIntoIsolatedSink`
  (`lib/src/edit/staged_document_load.dart:125`).

## Open Questions

- The prior design states a 50k Xiaomi acceptance gate of
  `schema_import_load_us < 574000`, while current benchmark diff policy uses
  `schemaImportLoadSuccess50kMaxUs = 1500000`
  (`docs/history/designs/2026-06-07-canonical-schema-v1-json-load-api.md:641`,
  `tool/bench/src/benchmark_diff.dart:23`,
  `test/benchmarks/benchmark_diff_test.dart:926`).
- The current research records duplicated read/navigation areas at file and
  owner level. A future design may need a field-by-field parity matrix if the
  design changes the boundary of shared schema v1 reading code.
