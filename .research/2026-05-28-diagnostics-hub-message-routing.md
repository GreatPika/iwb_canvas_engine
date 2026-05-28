---
date: 2026-05-28
researcher: Codex
commit: 0461dc31
branch: new-architecture
research_question: "Исследовать код и документы на предмет того, кто и какие сообщения шлет в DiagnosticsHub."
---

# Research: DiagnosticsHub Message Routing

## Summary

`DiagnosticsHub` currently exists as an internal collector under `lib/src/diagnostics/` and stores `DiagnosticRecord` objects built from `DiagnosticEvent` values (`lib/src/diagnostics/diagnostics_hub.dart:19`, `lib/src/diagnostics/diagnostics_hub.dart:29`, `lib/src/diagnostics/diagnostics_hub.dart:34`). The public surface exposes diagnostics policy variants, not the hub itself: `CanvasDiagnosticPolicy` has disabled, summary, and verbose variants (`lib/src/contracts/public/canvas_diagnostics.dart:8`, `lib/src/contracts/public/canvas_diagnostics.dart:10`, `lib/src/contracts/public/canvas_diagnostics.dart:12`), and `CanvasRuntimeConfig` carries `diagnosticPolicy` with disabled as the default (`lib/src/contracts/public/canvas_runtime.dart:22`, `lib/src/contracts/public/canvas_runtime.dart:29`, `lib/src/contracts/public/canvas_runtime.dart:37`).

The current production write path into `DiagnosticsHub` is centralized through the schema v1 diagnostics bridge `recordSchemaV1FailureDiagnostic` (`lib/src/codec/schema_v1_diagnostics.dart:4`). That bridge records every supplied `CanvasDataException` as a `DiagnosticEvent` with `DiagnosticSeverity.error`, `DiagnosticSource.codec`, the exception code, path, message, and optional exception details (`lib/src/codec/schema_v1_diagnostics.dart:18`, `lib/src/codec/schema_v1_diagnostics.dart:20`, `lib/src/codec/schema_v1_diagnostics.dart:24`). Searches and read-throughs found no other direct production `hub.record(...)` caller under `lib/src` besides this bridge (`lib/src/codec/schema_v1_diagnostics.dart:18`).

The documents define a broader diagnostics model than the current production sender set: `DiagnosticRecord.source` is documented as `codec | edit | interaction | frame | spatial | resource | diagnostics` (`docs/contracts/diagnostics.md:43`, `docs/contracts/diagnostics.md:49`), while current schema v1 bridge records use `DiagnosticSource.codec` (`lib/src/codec/schema_v1_diagnostics.dart:22`). Tests assert the codec sender for one representative decode failure (`test/codec/schema_v1/diagnostics_routing_test.dart:314`) and assert policy gating, sanitized details, public exception shape, and no-allocation disabled behavior (`test/diagnostics/disabled_no_alloc_hot_path_test.dart:29`, `test/diagnostics/sanitizer_and_public_projection_test.dart:6`, `test/diagnostics/diagnostics_public_surface_test.dart:18`).

## Detailed Findings

### 1. DiagnosticsHub Storage and Policy Gate

- **Location**: primary `lib/src/diagnostics/diagnostics_hub.dart:19`; policy declarations at `lib/src/contracts/public/canvas_diagnostics.dart:8`.
- **Description**: `DiagnosticsHub` stores a private `CanvasDiagnosticPolicy` and a private mutable `_records` list (`lib/src/diagnostics/diagnostics_hub.dart:20`, `lib/src/diagnostics/diagnostics_hub.dart:22`, `lib/src/diagnostics/diagnostics_hub.dart:23`). `record()` returns before building details when `isDisabled` is true (`lib/src/diagnostics/diagnostics_hub.dart:25`, `lib/src/diagnostics/diagnostics_hub.dart:29`, `lib/src/diagnostics/diagnostics_hub.dart:30`). When enabled, it appends a `DiagnosticRecord` using `event.code`, `event.severity`, `event.source`, `event.path`, sanitized `event.details()`, and optional revision/session/correlation fields (`lib/src/diagnostics/diagnostics_hub.dart:34`, `lib/src/diagnostics/diagnostics_hub.dart:36`, `lib/src/diagnostics/diagnostics_hub.dart:40`, `lib/src/diagnostics/diagnostics_hub.dart:41`, `lib/src/diagnostics/diagnostics_hub.dart:43`).
- **Dependencies**: `DiagnosticsHub` imports the public diagnostics policy, public errors, and sanitizer (`lib/src/diagnostics/diagnostics_hub.dart:1`, `lib/src/diagnostics/diagnostics_hub.dart:2`, `lib/src/diagnostics/diagnostics_hub.dart:3`). The sanitizer returns unmodifiable maps and limits entries, strings, depth, non-finite numbers, and unsupported objects (`lib/src/contracts/public/canvas_error_details_sanitizer.dart:14`, `lib/src/contracts/public/canvas_error_details_sanitizer.dart:23`, `lib/src/contracts/public/canvas_error_details_sanitizer.dart:42`, `lib/src/contracts/public/canvas_error_details_sanitizer.dart:117`, `lib/src/contracts/public/canvas_error_details_sanitizer.dart:139`).
- **Data flow**: `DiagnosticEvent` input (`lib/src/diagnostics/diagnostics_hub.dart:62`) -> disabled check (`lib/src/diagnostics/diagnostics_hub.dart:29`) -> sanitized details (`lib/src/diagnostics/diagnostics_hub.dart:48`) -> `DiagnosticRecord` stored in `_records` (`lib/src/diagnostics/diagnostics_hub.dart:34`) -> unmodifiable projection through `records` (`lib/src/diagnostics/diagnostics_hub.dart:27`).

### 2. Hub Creation and Runtime Load Routing

- **Location**: primary `lib/src/edit/staged_document_load.dart:36`; runtime construction path at `lib/src/runtime/runtime_root.dart:48`.
- **Description**: `LoadDocumentPipeline` owns `DiagnosticsHub? _diagnostics` (`lib/src/edit/staged_document_load.dart:45`). Its constructor maps `CanvasDiagnosticPolicy.disabled` to `null` and other policies to `DiagnosticsHub(policy: policy)` (`lib/src/edit/staged_document_load.dart:39`, `lib/src/edit/staged_document_load.dart:42`, `lib/src/edit/staged_document_load.dart:111`, `lib/src/edit/staged_document_load.dart:116`). `RuntimeRoot` passes `config.diagnosticPolicy` into `LoadDocumentPipeline` (`lib/src/runtime/runtime_root.dart:55`, `lib/src/runtime/runtime_root.dart:86`, `lib/src/runtime/runtime_root.dart:88`).
- **Dependencies**: Public runtime configuration defines `diagnosticPolicy` (`lib/src/contracts/public/canvas_runtime.dart:29`, `lib/src/contracts/public/canvas_runtime.dart:37`). `RuntimeConfig.from` also materializes `RuntimeDiagnosticsConfig` from the same policy (`lib/src/runtime/runtime_config.dart:8`, `lib/src/runtime/runtime_config.dart:14`, `lib/src/runtime/runtime_config.dart:27`).
- **Data flow**: `CanvasRuntimeConfig.diagnosticPolicy` (`lib/src/contracts/public/canvas_runtime.dart:29`) -> `RuntimeRoot` constructor (`lib/src/runtime/runtime_root.dart:48`) -> `LoadDocumentPipeline` (`lib/src/runtime/runtime_root.dart:86`) -> `_diagnostics` (`lib/src/edit/staged_document_load.dart:45`) -> `ValidatedImportDraft.fromDocument(... diagnostics: _diagnostics)` during load preparation (`lib/src/edit/staged_document_load.dart:54`, `lib/src/edit/staged_document_load.dart:57`).

### 3. Production Senders and Message Shapes

- **Location**: primary bridge `lib/src/codec/schema_v1_diagnostics.dart:4`; sender enum at `lib/src/diagnostics/diagnostics_hub.dart:9`.
- **Description**: The bridge receives a nullable hub and a `CanvasDataException`; when the hub is `null`, it returns the same exception without recording (`lib/src/codec/schema_v1_diagnostics.dart:4`, `lib/src/codec/schema_v1_diagnostics.dart:13`, `lib/src/codec/schema_v1_diagnostics.dart:14`). When the hub exists, it records `DiagnosticEvent(code: exception.code, severity: DiagnosticSeverity.error, source: DiagnosticSource.codec, path: exception.path, details: ...)` (`lib/src/codec/schema_v1_diagnostics.dart:18`, `lib/src/codec/schema_v1_diagnostics.dart:20`, `lib/src/codec/schema_v1_diagnostics.dart:21`, `lib/src/codec/schema_v1_diagnostics.dart:22`, `lib/src/codec/schema_v1_diagnostics.dart:23`).
- **Dependencies**: `schema_v1_diagnostics.dart` imports public errors and `DiagnosticsHub` (`lib/src/codec/schema_v1_diagnostics.dart:1`, `lib/src/codec/schema_v1_diagnostics.dart:2`). `CanvasDataException` itself sanitizes public `details` at construction (`lib/src/contracts/public/canvas_errors.dart:29`, `lib/src/contracts/public/canvas_errors.dart:39`).
- **Data flow**: `CanvasDataException` input (`lib/src/contracts/public/canvas_errors.dart:28`) -> schema v1 bridge (`lib/src/codec/schema_v1_diagnostics.dart:4`) -> `DiagnosticEvent` with `source: codec` (`lib/src/codec/schema_v1_diagnostics.dart:22`) -> `DiagnosticsHub.record` (`lib/src/codec/schema_v1_diagnostics.dart:18`) -> stored `DiagnosticRecord` (`lib/src/diagnostics/diagnostics_hub.dart:84`).

Current production message map:

| Sender path | Triggering function/path | Codes/messages recorded | Diagnostic source | Fields added to details |
| --- | --- | --- | --- | --- |
| Schema root validation | `validateSchemaV1Root` (`lib/src/codec/schema_v1_validation.dart:5`) | Missing or unsupported schema version; message `schemaVersion must be 1.` (`lib/src/codec/schema_v1_validation.dart:14`, `lib/src/codec/schema_v1_validation.dart:17`) | `codec` through bridge (`lib/src/codec/schema_v1_diagnostics.dart:22`) | `message`; nested `details.actual` because exception details include `actual` (`lib/src/codec/schema_v1_validation.dart:19`, `lib/src/codec/schema_v1_diagnostics.dart:24`) |
| Raw JSON decode | `decodeSchemaV1DocumentFromJson` (`lib/src/codec/schema_v1_decoder.dart:83`) | Raw JSON length failure (`lib/src/contracts/public/canvas_value_validators.dart:223`, `lib/src/contracts/public/canvas_value_validators.dart:226`) and malformed/non-object JSON (`lib/src/codec/schema_v1_decoder.dart:96`, `lib/src/codec/schema_v1_decoder.dart:106`) | `codec` through bridge (`lib/src/codec/schema_v1_diagnostics.dart:22`) | `message`; optional nested `details`, including `maxLength` for raw length (`lib/src/contracts/public/canvas_value_validators.dart:229`, `lib/src/codec/schema_v1_diagnostics.dart:24`) |
| Schema v1 map decode/readers | `decodeSchemaV1Document` (`lib/src/codec/schema_v1_decoder.dart:24`) and private readers | Duplicate ids, missing resource reference, invalid field type, missing field (`lib/src/codec/schema_v1_decoder.dart:737`, `lib/src/codec/schema_v1_decoder.dart:764`, `lib/src/codec/schema_v1_decoder.dart:775`, `lib/src/codec/schema_v1_decoder.dart:847`, `lib/src/codec/schema_v1_decoder.dart:900`) | `codec` through bridge (`lib/src/codec/schema_v1_diagnostics.dart:22`) | `message`; optional nested `details` from exception (`lib/src/codec/schema_v1_diagnostics.dart:24`) |
| Schema v1 materialization | `_materialize` catches constructor/validator `CanvasDataException` (`lib/src/codec/schema_v1_decoder.dart:1416`, `lib/src/codec/schema_v1_decoder.dart:1420`) | Constructor/validator-owned codes such as finite/range/invertibility failures; example materialization sites include camera and resources (`lib/src/codec/schema_v1_decoder.dart:65`, `lib/src/codec/schema_v1_decoder.dart:281`) | `codec` through bridge (`lib/src/codec/schema_v1_diagnostics.dart:22`) | `message`; optional nested `details` (`lib/src/codec/schema_v1_diagnostics.dart:24`) |
| Schema v1 encode preflight | `encodeSchemaV1Document` validates the DTO through `ValidatedImportDraft.fromDocument` (`lib/src/codec/schema_v1_encoder.dart:15`, `lib/src/codec/schema_v1_encoder.dart:19`) | Duplicate/resource/reference/transform validation failures from import draft (`lib/src/codec/validated_import_draft.dart:34`, `lib/src/codec/validated_import_draft.dart:82`, `lib/src/codec/validated_import_draft.dart:96`) | `codec` through bridge (`lib/src/codec/schema_v1_diagnostics.dart:22`) | `message`; optional nested `details` (`lib/src/codec/schema_v1_diagnostics.dart:24`) |
| Runtime staged document load | `RuntimeRoot._loadDocument` calls `_loadPipeline.prepare(document)` (`lib/src/runtime/runtime_root.dart:430`, `lib/src/runtime/runtime_root.dart:431`) | Same import-draft validation failures as staged replacement preparation (`lib/src/edit/staged_document_load.dart:54`, `lib/src/edit/staged_document_load.dart:57`) | `codec` through bridge because `ValidatedImportDraft` records via schema v1 diagnostics (`lib/src/codec/validated_import_draft.dart:34`, `lib/src/codec/schema_v1_diagnostics.dart:22`) | `message`; optional nested `details` (`lib/src/codec/schema_v1_diagnostics.dart:24`) |

### 4. Public Codec Path and Non-recording Paths

- **Location**: primary `lib/src/api/canvas_codec.dart:14`.
- **Description**: Public codec functions have no diagnostics parameter and call internal schema v1 functions without passing a hub (`lib/src/api/canvas_codec.dart:14`, `lib/src/api/canvas_codec.dart:15`, `lib/src/api/canvas_codec.dart:22`, `lib/src/api/canvas_codec.dart:23`, `lib/src/api/canvas_codec.dart:26`, `lib/src/api/canvas_codec.dart:27`). Internal schema v1 decode/encode functions accept `DiagnosticsHub? diagnostics` (`lib/src/codec/schema_v1_decoder.dart:24`, `lib/src/codec/schema_v1_decoder.dart:26`, `lib/src/codec/schema_v1_encoder.dart:15`, `lib/src/codec/schema_v1_encoder.dart:17`).
- **Dependencies**: `decodeSchemaV1Document` passes diagnostics through root validation, section readers, materialization, and reference validation (`lib/src/codec/schema_v1_decoder.dart:28`, `lib/src/codec/schema_v1_decoder.dart:34`, `lib/src/codec/schema_v1_decoder.dart:65`, `lib/src/codec/schema_v1_decoder.dart:78`).
- **Data flow**: Public `decodeCanvasDocument`/`encodeCanvasDocument` (`lib/src/api/canvas_codec.dart:14`, `lib/src/api/canvas_codec.dart:22`) -> internal schema v1 call with omitted diagnostics (`lib/src/api/canvas_codec.dart:15`, `lib/src/api/canvas_codec.dart:23`) -> schema failure bridge receives `null` and returns the exception without recording (`lib/src/codec/schema_v1_diagnostics.dart:13`, `lib/src/codec/schema_v1_diagnostics.dart:14`). `prepareDraftReplacement` also calls `ValidatedImportDraft.fromDocument(document)` without diagnostics (`lib/src/edit/staged_document_load.dart:85`, `lib/src/edit/staged_document_load.dart:86`).

### 5. Documentation, Tests, and Guardrails

- **Location**: primary `docs/contracts/diagnostics.md:29`; architecture graph route at `docs/architecture/architecture_graph.yaml:643`.
- **Description**: The diagnostics contract states `DiagnosticsHub` is internal (`docs/contracts/diagnostics.md:29`, `docs/contracts/diagnostics.md:31`) and documents `DiagnosticRecord` fields (`docs/contracts/diagnostics.md:43`, `docs/contracts/diagnostics.md:55`). The architecture graph defines `diagnostics.hub` as the P3 diagnostics owner (`docs/architecture/architecture_graph.yaml:213`, `docs/architecture/architecture_graph.yaml:228`) and defines `codec.schema_v1.failures.report_to_diagnostics` as a required diagnostic route from codec to diagnostics (`docs/architecture/architecture_graph.yaml:643`, `docs/architecture/architecture_graph.yaml:661`).
- **Dependencies**: Public API diagnostics membership is stored in `docs/_registry/public_api_v1.yaml` under `diagnostics_public_surface` (`docs/_registry/public_api_v1.yaml:111`, `docs/_registry/public_api_v1.yaml:117`). The diagnostics contract states that this classification does not create a public diagnostics stream (`docs/contracts/diagnostics.md:61`, `docs/contracts/diagnostics.md:68`), and public API v1 states no public diagnostics stream is exported (`docs/contracts/public_api_v1.md:2517`).
- **Data flow**: Architecture docs route codec failure paths through `recordSchemaV1FailureDiagnostic` to `DiagnosticsHub` (`docs/architecture/architecture_graph.yaml:653`, `docs/architecture/architecture_graph.yaml:656`, `docs/architecture/architecture_graph.yaml:658`) while tests assert actual codec source/severity/details for representative failures (`test/codec/schema_v1/diagnostics_routing_test.dart:310`, `test/codec/schema_v1/diagnostics_routing_test.dart:314`, `test/codec/schema_v1/diagnostics_routing_test.dart:318`).

## Code References

- `lib/src/diagnostics/diagnostics_hub.dart:19` - `DiagnosticsHub` declaration.
- `lib/src/diagnostics/diagnostics_hub.dart:29` - disabled policy check in `record`.
- `lib/src/diagnostics/diagnostics_hub.dart:34` - record append into `_records`.
- `lib/src/diagnostics/diagnostics_hub.dart:62` - `DiagnosticEvent` declaration.
- `lib/src/diagnostics/diagnostics_hub.dart:84` - `DiagnosticRecord` declaration.
- `lib/src/contracts/public/canvas_diagnostics.dart:8` - public diagnostics policy sealed class.
- `lib/src/contracts/public/canvas_runtime.dart:29` - runtime config default diagnostic policy.
- `lib/src/edit/staged_document_load.dart:42` - load pipeline maps policy to nullable hub.
- `lib/src/edit/staged_document_load.dart:57` - load preparation passes diagnostics into `ValidatedImportDraft`.
- `lib/src/edit/staged_document_load.dart:111` - disabled policy maps to no hub.
- `lib/src/runtime/runtime_root.dart:86` - runtime root creates `LoadDocumentPipeline`.
- `lib/src/codec/schema_v1_diagnostics.dart:4` - schema v1 diagnostics bridge.
- `lib/src/codec/schema_v1_diagnostics.dart:18` - bridge calls `hub.record`.
- `lib/src/codec/schema_v1_diagnostics.dart:22` - recorded source is `DiagnosticSource.codec`.
- `lib/src/codec/schema_v1_validation.dart:11` - schema root validation throws through diagnostics bridge.
- `lib/src/codec/schema_v1_decoder.dart:90` - raw length failure records through diagnostics bridge.
- `lib/src/codec/schema_v1_decoder.dart:262` - unknown resource kind records through diagnostics bridge.
- `lib/src/codec/schema_v1_decoder.dart:737` - duplicate layer id records through diagnostics bridge.
- `lib/src/codec/schema_v1_decoder.dart:1416` - materialization wrapper catches `CanvasDataException`.
- `lib/src/codec/schema_v1_encoder.dart:19` - encode preflight validates through `ValidatedImportDraft`.
- `lib/src/codec/validated_import_draft.dart:34` - duplicate resource id records through diagnostics bridge.
- `lib/src/codec/validated_import_draft.dart:82` - transform admission failure records through diagnostics bridge.
- `lib/src/api/canvas_codec.dart:14` - public encode has no diagnostics parameter.
- `lib/src/api/canvas_codec.dart:22` - public decode has no diagnostics parameter.
- `docs/contracts/diagnostics.md:43` - documented `DiagnosticRecord` shape.
- `docs/architecture/architecture_graph.yaml:643` - required codec-to-diagnostics route.
- `test/codec/schema_v1/diagnostics_routing_test.dart:314` - test asserts codec diagnostic source.
- `test/diagnostics/disabled_no_alloc_hot_path_test.dart:48` - test asserts disabled diagnostics do not build details.
- `test/diagnostics/diagnostics_public_surface_test.dart:27` - test asserts public exception fields.

## Observed Architecture Facts

- Pattern observed: internal hub plus public policy. `CanvasRuntimeConfig` carries a public `diagnosticPolicy` (`lib/src/contracts/public/canvas_runtime.dart:29`), `LoadDocumentPipeline` converts it to nullable internal `DiagnosticsHub` (`lib/src/edit/staged_document_load.dart:42`), and public codec functions do not expose diagnostics parameters (`lib/src/api/canvas_codec.dart:14`, `lib/src/api/canvas_codec.dart:22`).
- Data flow: runtime config -> `RuntimeRoot` -> `LoadDocumentPipeline` -> `ValidatedImportDraft` -> schema v1 diagnostics bridge -> `DiagnosticsHub.record` (`lib/src/contracts/public/canvas_runtime.dart:29`, `lib/src/runtime/runtime_root.dart:55`, `lib/src/edit/staged_document_load.dart:57`, `lib/src/codec/validated_import_draft.dart:34`, `lib/src/codec/schema_v1_diagnostics.dart:18`).
- Data flow: internal schema v1 decode/encode -> `recordSchemaV1FailureDiagnostic` -> `DiagnosticEvent(source: codec)` -> sanitized `DiagnosticRecord` (`lib/src/codec/schema_v1_decoder.dart:24`, `lib/src/codec/schema_v1_encoder.dart:17`, `lib/src/codec/schema_v1_diagnostics.dart:22`, `lib/src/diagnostics/diagnostics_hub.dart:40`).
- Key dependency boundary: owner DAG tests allow `edit -> diagnostics`, `codec -> diagnostics`, and `diagnostics -> contracts/public` (`test/guardrails/owner_dag_import_boundaries_test.dart:291`, `test/guardrails/owner_dag_import_boundaries_test.dart:318`, `test/guardrails/owner_dag_import_boundaries_test.dart:319`), while forbidding `api -> diagnostics` and several diagnostics outbound edges (`test/guardrails/owner_dag_import_boundaries_test.dart:417`, `test/guardrails/owner_dag_import_boundaries_test.dart:429`).
- Test coverage fact: diagnostics routing tests assert source/severity/message for invalid resource kind (`test/codec/schema_v1/diagnostics_routing_test.dart:310`, `test/codec/schema_v1/diagnostics_routing_test.dart:318`) and assert several other failure categories by record count/code/path (`test/codec/schema_v1/diagnostics_routing_test.dart:123`, `test/codec/schema_v1/diagnostics_routing_test.dart:156`, `test/codec/schema_v1/diagnostics_routing_test.dart:239`).

## Open Questions

- The read production source set shows only schema v1 bridge writes to `DiagnosticsHub.record`, and that bridge always records `DiagnosticSource.codec` (`lib/src/codec/schema_v1_diagnostics.dart:18`, `lib/src/codec/schema_v1_diagnostics.dart:22`). The documented `DiagnosticSource` set includes `edit`, `interaction`, `frame`, `spatial`, `resource`, and `diagnostics` in addition to `codec` (`lib/src/diagnostics/diagnostics_hub.dart:9`, `docs/contracts/diagnostics.md:49`).
- The diagnostics contract lists `DiagnosticRecord` fields but does not list `message` as a top-level field (`docs/contracts/diagnostics.md:43`, `docs/contracts/diagnostics.md:55`). Current schema v1 bridge stores the exception message inside the record `details` map under key `message` (`lib/src/codec/schema_v1_diagnostics.dart:24`, `lib/src/codec/schema_v1_diagnostics.dart:25`).
- The tests assert the sender/source for the invalid resource kind codec failure (`test/codec/schema_v1/diagnostics_routing_test.dart:314`), while several other schema diagnostics tests assert record count/code/path without asserting `record.source` (`test/codec/schema_v1/diagnostics_routing_test.dart:123`, `test/codec/schema_v1/diagnostics_routing_test.dart:156`, `test/codec/schema_v1/diagnostics_routing_test.dart:239`).
- No dedicated sender/message table was found among the read source-of-truth documents; the existing diagnostics contract documents the record field shape (`docs/contracts/diagnostics.md:43`) and the architecture graph documents the codec-to-diagnostics route (`docs/architecture/architecture_graph.yaml:643`).
