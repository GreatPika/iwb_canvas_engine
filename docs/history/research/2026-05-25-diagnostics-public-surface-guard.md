---
date: 2026-05-25
researcher: Codex
commit: cb104484
branch: new-architecture
research_question: "How is the diagnostics public surface guard currently tied to public API inventory, and is there an existing diagnostics surface registry?"
---

# Research: Diagnostics Public Surface Guard

## Summary

The diagnostics leak guard resolves the effective public API surface through the analyzer, but it selects diagnostics-facing declarations by a private name predicate inside the test. The predicate includes `CanvasDataException`, `CanvasDataErrorCode`, and names that start with `CanvasDiagnostic` or `CanvasDiagnostics`.

The repository already has a machine-readable public API v1 exported-name inventory in `docs/_registry/public_api_v1.yaml`. That registry includes the current public diagnostics declarations, and existing public API guardrails compare the registry with the resolved root public exports. The registry is currently a flat `public_exports` list; the reader exposes that list as a `Set<String>` and does not expose a diagnostics-specific inventory.

## Detailed Findings

### 1. Diagnostics Leak Guard
- **Location**: `test/diagnostics/diagnostics_public_surface_test.dart:7`
- **Description**: The test resolves the public API surface and checks that `CanvasDataException` exposes only `code`, `message`, `path`, and `details`, then expects `_diagnosticsRuntimeLeaks(surface)` to be empty (`test/diagnostics/diagnostics_public_surface_test.dart:11`, `test/diagnostics/diagnostics_public_surface_test.dart:13`, `test/diagnostics/diagnostics_public_surface_test.dart:19`).
- **Dependencies**: It imports `tool/guardrails/src/public_api_surface.dart` for analyzer-backed public API resolution (`test/diagnostics/diagnostics_public_surface_test.dart:5`).
- **Data flow**: `resolvePublicApiSurface()` -> exported elements -> `_diagnosticsRuntimeLeaks()` -> `_isDiagnosticsSurfaceName()` -> analyzer type traversal for leak-like type names (`test/diagnostics/diagnostics_public_surface_test.dart:11`, `test/diagnostics/diagnostics_public_surface_test.dart:44`, `test/diagnostics/diagnostics_public_surface_test.dart:56`, `test/diagnostics/diagnostics_public_surface_test.dart:103`).

### 2. Name-Based Diagnostics Selection
- **Location**: `test/diagnostics/diagnostics_public_surface_test.dart:128`
- **Description**: `_isDiagnosticsSurfaceName` returns true for `CanvasDataException`, `CanvasDataErrorCode`, names starting with `CanvasDiagnostic`, and names starting with `CanvasDiagnostics` (`test/diagnostics/diagnostics_public_surface_test.dart:128`).
- **Dependencies**: `_diagnosticsRuntimeLeaks` depends on `_isDiagnosticsSurfaceName` before inspecting a public element (`test/diagnostics/diagnostics_public_surface_test.dart:46`, `test/diagnostics/diagnostics_public_surface_test.dart:47`).
- **Data flow**: exported public names -> name predicate -> selected analyzer elements -> field/getter/method/constructor signatures -> string-based runtime leak type checks (`test/diagnostics/diagnostics_public_surface_test.dart:46`, `test/diagnostics/diagnostics_public_surface_test.dart:72`, `test/diagnostics/diagnostics_public_surface_test.dart:135`).

### 3. Public API Registry
- **Location**: `docs/_registry/public_api_v1.yaml:1`
- **Description**: The registry describes itself as the machine-readable inventory for the Public API v1 exported-name contract and contains a single `public_exports` list (`docs/_registry/public_api_v1.yaml:1`, `docs/_registry/public_api_v1.yaml:3`). The current diagnostics-related names in that list are `CanvasDiagnosticPolicy`, `CanvasDiagnosticsDisabled`, `CanvasDiagnosticsSummary`, `CanvasDiagnosticsVerbose`, `CanvasDataException`, and `CanvasDataErrorCode` (`docs/_registry/public_api_v1.yaml:98`, `docs/_registry/public_api_v1.yaml:103`).
- **Dependencies**: `readPublicApiRegistry()` reads only `public_exports` from this YAML file and returns it as a set (`tool/guardrails/src/public_api_registry.dart:7`, `tool/guardrails/src/public_api_registry.dart:10`, `tool/guardrails/src/public_api_registry.dart:12`).
- **Data flow**: `docs/_registry/public_api_v1.yaml` -> `readPublicApiRegistry()` -> API guardrail checks such as `checkPublicExportsComplete()` and declaration checks (`tool/guardrails/src/public_api_checks.dart:8`, `tool/guardrails/src/public_api_declaration_checks.dart:47`).

### 4. Existing Public API Guardrail Pattern
- **Location**: `tool/guardrails/src/public_api_checks.dart:8`
- **Description**: `checkPublicExportsComplete()` compares registry names with the analyzer-resolved public surface and reports names that are exported but absent from the registry, or registry names that are missing from the public barrel (`tool/guardrails/src/public_api_checks.dart:9`, `tool/guardrails/src/public_api_checks.dart:11`, `tool/guardrails/src/public_api_checks.dart:12`, `tool/guardrails/src/public_api_checks.dart:17`, `tool/guardrails/src/public_api_checks.dart:23`).
- **Dependencies**: It uses `readPublicApiRegistry()` and `resolvePublicApiSurface()` (`tool/guardrails/src/public_api_checks.dart:4`, `tool/guardrails/src/public_api_checks.dart:5`).
- **Data flow**: registry names and resolved exports are compared by set difference (`tool/guardrails/src/public_api_checks.dart:11`, `tool/guardrails/src/public_api_checks.dart:12`).

### 5. Analyzer-Backed Public Surface
- **Location**: `tool/guardrails/src/public_api_surface.dart:9`
- **Description**: `PublicApiSurface` stores exported names, exported analyzer elements, and exported named extension names (`tool/guardrails/src/public_api_surface.dart:9`, `tool/guardrails/src/public_api_surface.dart:16`, `tool/guardrails/src/public_api_surface.dart:17`, `tool/guardrails/src/public_api_surface.dart:18`). `resolvePublicApiSurface()` defaults to `lib/iwb_canvas_engine.dart`, resolves the library, reads `exportNamespace.definedNames2`, filters public names, and returns the surface (`tool/guardrails/src/public_api_surface.dart:21`, `tool/guardrails/src/public_api_surface.dart:22`, `tool/guardrails/src/public_api_surface.dart:38`, `tool/guardrails/src/public_api_surface.dart:40`, `tool/guardrails/src/public_api_surface.dart:44`).
- **Dependencies**: It uses the analyzer `AnalysisContextCollection` and repository root path (`tool/guardrails/src/public_api_surface.dart:1`, `tool/guardrails/src/public_api_surface.dart:7`).
- **Data flow**: root barrel path -> resolved library -> export namespace -> public entries -> `PublicApiSurface` (`tool/guardrails/src/public_api_surface.dart:22`, `tool/guardrails/src/public_api_surface.dart:31`, `tool/guardrails/src/public_api_surface.dart:38`, `tool/guardrails/src/public_api_surface.dart:40`, `tool/guardrails/src/public_api_surface.dart:44`).

### 6. Contract Ownership for Diagnostics Semantics
- **Location**: `docs/contracts/public_api_v1.md:2395`
- **Description**: The public API contract has an "Errors and diagnostics" section containing declarations for `CanvasDataErrorCode`, `CanvasDataException`, `CanvasDiagnosticPolicy`, and the diagnostics policy variants (`docs/contracts/public_api_v1.md:2395`, `docs/contracts/public_api_v1.md:2398`, `docs/contracts/public_api_v1.md:2421`, `docs/contracts/public_api_v1.md:2449`, `docs/contracts/public_api_v1.md:2459`, `docs/contracts/public_api_v1.md:2463`, `docs/contracts/public_api_v1.md:2467`). It also states that public diagnostics are projected only through `CanvasDataException` and test-only/internal sinks (`docs/contracts/public_api_v1.md:2507`).
- **Dependencies**: The contract states the registry is the canonical machine-readable inventory for exported-name completeness, while the contract owns semantics and signature rules (`docs/contracts/public_api_v1.md:87`, `docs/contracts/public_api_v1.md:90`, `docs/contracts/public_api_v1.md:91`).
- **Data flow**: contract declarations and rules -> registry exported-name inventory -> guardrail proof through resolved public surface (`docs/contracts/public_api_v1.md:87`, `docs/_registry/public_api_v1.yaml:1`, `tool/guardrails/src/public_api_checks.dart:8`).

### 7. Diagnostics Contract and Guardrail Routing
- **Location**: `docs/contracts/diagnostics.md:1`
- **Description**: The diagnostics contract context lists `test.diagnostics.diagnostics_public_surface` as a required test and `diagnostics.sanitized_public_projection` as a guardrail (`docs/contracts/diagnostics.md:18`, `docs/contracts/diagnostics.md:21`, `docs/contracts/diagnostics.md:22`, `docs/contracts/diagnostics.md:24`). The body states `DiagnosticsHub` is internal, public exceptions expose only code/message/path/sanitized details, and sanitizer output must not include runtime objects, handles, full scene dumps, unsanitized field values, images, closures, or canvases (`docs/contracts/diagnostics.md:31`, `docs/contracts/diagnostics.md:57`, `docs/contracts/diagnostics.md:58`, `docs/contracts/diagnostics.md:65`, `docs/contracts/diagnostics.md:66`, `docs/contracts/diagnostics.md:81`).
- **Dependencies**: The guardrail executor routes `diagnostics.sanitized_public_projection` to both sanitizer behavior tests and the public surface leak test (`tool/guardrails/src/guardrail_executor.dart:205`, `tool/guardrails/src/guardrail_executor.dart:206`, `tool/guardrails/src/guardrail_executor.dart:207`).
- **Data flow**: diagnostics contract -> guardrail id -> guardrail runner proof paths -> diagnostics tests (`docs/contracts/diagnostics.md:22`, `tool/guardrails/src/guardrail_executor.dart:205`).

## Code References
- `test/diagnostics/diagnostics_public_surface_test.dart:44` - leak scan iterates resolved exported elements.
- `test/diagnostics/diagnostics_public_surface_test.dart:47` - leak scan skips elements that do not match the diagnostics name predicate.
- `test/diagnostics/diagnostics_public_surface_test.dart:128` - diagnostics surface selection is implemented as a name predicate.
- `docs/_registry/public_api_v1.yaml:98` - current registry includes `CanvasDiagnosticPolicy`.
- `docs/_registry/public_api_v1.yaml:103` - current registry includes `CanvasDataErrorCode`.
- `tool/guardrails/src/public_api_registry.dart:7` - registry reader entrypoint.
- `tool/guardrails/src/public_api_registry.dart:10` - registry reader reads `public_exports`.
- `tool/guardrails/src/public_api_checks.dart:8` - public exports completeness check compares registry and resolved surface.
- `tool/guardrails/src/public_api_surface.dart:21` - analyzer-backed public surface resolver.
- `docs/contracts/public_api_v1.md:2507` - v1 public diagnostics projection is limited to `CanvasDataException` and test-only/internal sinks.
- `docs/contracts/diagnostics.md:57` - internal diagnostic provenance is not projected as a public exception field.
- `tool/guardrails/src/guardrail_executor.dart:205` - sanitized public projection guardrail runs diagnostics public surface test.

## Observed Architecture Facts
- Pattern observed: API guardrails already use `registry_parity` with `resolved_public_surface` for exported-name completeness (`docs/verification/guardrail_design_patterns.md:85`).
- Pattern observed: diagnostics sanitized projection is documented as `behavioral_seam_test` plus `resolved_public_surface` (`docs/verification/guardrail_design_patterns.md:147`).
- Data flow: `lib/iwb_canvas_engine.dart` exports API files, including `canvas_diagnostics.dart` and `canvas_errors.dart` (`lib/iwb_canvas_engine.dart:3`, `lib/iwb_canvas_engine.dart:7`); the analyzer resolver reads the effective export namespace (`tool/guardrails/src/public_api_surface.dart:38`); the diagnostics public surface test filters those names with `_isDiagnosticsSurfaceName` (`test/diagnostics/diagnostics_public_surface_test.dart:47`).
- Key dependency: `docs/_registry/public_api_v1.yaml` is the current machine-readable exported-name inventory, but its reader returns only a flat `public_exports` set (`docs/_registry/public_api_v1.yaml:3`, `tool/guardrails/src/public_api_registry.dart:10`).

## Open Questions
- Whether the diagnostics public surface should be represented as a new category inside `docs/_registry/public_api_v1.yaml`, a separate diagnostics registry, or another contract-owned inventory is not specified by the current files read.
- Whether future public diagnostics-facing types are allowed outside the current v1 statement that diagnostics are projected only through `CanvasDataException` and test-only/internal sinks is not specified beyond `docs/contracts/public_api_v1.md:2507`.
