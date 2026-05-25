# Change Contract

## Goal

Make diagnostics-facing public API membership an explicit Public API v1 registry classification and make `diagnostics.sanitized_public_projection` consume that registry-owned inventory, so a diagnostics-facing public declaration with a non-diagnostics-prefixed name cannot silently bypass the sanitizer/leak guard. This step does not change runtime behavior, add public API names, migrate schemas, or update durable architecture diagrams.

## Evidence

- `.design/2026-05-25-diagnostics-public-surface-guard.md` / selected form: READY_FOR_CONTRACT chooses extending the existing Public API v1 registry with diagnostics public surface membership, rejects local test allowlists, separate diagnostics registries, and file-based inference -> the contract must preserve the registry-owned classification and seam migration.
- `test/diagnostics/diagnostics_public_surface_test.dart` / `_diagnosticsRuntimeLeaks`: the leak scan iterates analyzer-resolved exported elements but skips any exported name that `_isDiagnosticsSurfaceName` does not accept -> the defect owner is diagnostics public surface recognition, not runtime sanitizer behavior.
- `test/diagnostics/diagnostics_public_surface_test.dart` / `_isDiagnosticsSurfaceName`: diagnostics membership is currently inferred from `CanvasDataException`, `CanvasDataErrorCode`, `CanvasDiagnostic*`, and `CanvasDiagnostics*` names -> the retired seam is the name predicate.
- `docs/_registry/public_api_v1.yaml` / `public_exports`: the registry is the current machine-readable Public API v1 exported-name inventory and already lists the current diagnostics declarations `CanvasDiagnosticPolicy`, `CanvasDiagnosticsDisabled`, `CanvasDiagnosticsSummary`, `CanvasDiagnosticsVerbose`, `CanvasDataException`, and `CanvasDataErrorCode` -> diagnostics membership belongs as the `diagnostics_public_surface` classification inside this registry, not as a second exported-name list.
- `tool/guardrails/src/public_api_registry.dart` / `readPublicApiRegistry`: the registry reader currently reads only `public_exports` and returns a `Set<String>` -> the entry boundary for the new classification is the registry reader API.
- `tool/guardrails/src/public_api_surface.dart` / `resolvePublicApiSurface`: the analyzer-backed resolver already returns exported names and elements, and supports fixture `libraryPath` inputs -> the leak guard can keep the resolved public surface proof and targeted non-prefix fixture proof.
- `docs/contracts/public_api_v1.md` / public exports section: the public API contract states that `docs/_registry/public_api_v1.yaml` is canonical for exported-name completeness and that the contract owns semantics/signature rules -> docs must clarify that registry diagnostics membership is classification metadata while public API semantics remain contract-owned.
- `docs/contracts/public_api_v1.md` / errors and diagnostics section: v1 exports no public diagnostics stream and projects diagnostics through `CanvasDataException` plus test-only/internal sinks -> the implementation must not broaden the public API surface while classifying diagnostics-facing public declarations.
- `docs/contracts/diagnostics.md` / diagnostics guardrails: `diagnostics.sanitized_public_projection` and `test.diagnostics.diagnostics_public_surface` are required diagnostics proof surfaces -> the diagnostics contract must remain aligned with the migrated proof.
- `docs/verification/guardrail_design_patterns.md` / guardrail pattern map: `api.public_exports_complete` uses `registry_parity` with `resolved_public_surface`, and `diagnostics.sanitized_public_projection` uses public surface proof -> the migrated guard should combine registry-owned membership with analyzer-resolved public signature traversal.
- `tool/guardrails/src/guardrail_executor.dart` / diagnostics routing: `diagnostics.sanitized_public_projection` already routes to `test/diagnostics/diagnostics_public_surface_test.dart` -> runner metadata does not need a new guardrail id, only the existing proof path must become stronger.
- `P6_HANDOFF_FINDINGS.md` / diagnostics public surface guard: the handoff calls out the name-based guard and suggests binding it to a registry or contract-owned diagnostics surface inventory -> this step closes that handed-off P2 finding.

## Boundaries

Owner:

Public API v1 registry and guardrail tooling own machine-readable diagnostics public surface membership; public API and diagnostics contracts own the normative semantics; diagnostics tests own the executable leak proof.

In Scope:

- Extend `docs/_registry/public_api_v1.yaml` with an explicit `diagnostics_public_surface` membership classification that is a subset of `public_exports`, initially containing exactly `CanvasDiagnosticPolicy`, `CanvasDiagnosticsDisabled`, `CanvasDiagnosticsSummary`, `CanvasDiagnosticsVerbose`, `CanvasDataException`, and `CanvasDataErrorCode`.
- Update `tool/guardrails/src/public_api_registry.dart` to parse and expose both the full public export set and diagnostics public surface set without creating a second source of truth.
- Add registry reader tests proving real registry parsing and diagnostics-subset validation.
- Migrate `test/diagnostics/diagnostics_public_surface_test.dart` from `_isDiagnosticsSurfaceName` to registry-owned diagnostics membership while preserving analyzer-backed traversal of fields, getters, methods, constructors, typedefs, functions, and top-level variables.
- Add a targeted negative fixture proof where a non-prefix diagnostics inventory name is scanned and rejected when it exposes a forbidden runtime-like type, without adding fixture-only names to the real registry.
- Update `docs/contracts/public_api_v1.md`, `docs/contracts/diagnostics.md`, `docs/verification/guardrails.md`, and `docs/verification/guardrail_design_patterns.md` only where needed to make the new registry-owned diagnostics membership and proof pattern normative.
- Remove or retire the name-predicate diagnostics recognition seam from the diagnostics public surface proof.

Out of Scope:

- Runtime diagnostics behavior changes, sanitizer behavior changes, public API additions/removals, schema migrations, durable architecture diagram updates, new guardrail ids, separate diagnostics registry files, local diagnostics allowlists inside tests, and file-placement-based diagnostics inference.
- Adding fake non-prefix diagnostics names to `docs/_registry/public_api_v1.yaml` or to any durable public API source of truth for fixture-only proof.
- Broad refactors of public API checker architecture beyond the registry reader shape needed for this classification.

Source of Truth:

`docs/_registry/public_api_v1.yaml` is the single machine-readable source for Public API v1 exported names and diagnostics public surface membership classification. The durable YAML key for diagnostics membership is `diagnostics_public_surface`, and its initial real-registry entries are exactly `CanvasDiagnosticPolicy`, `CanvasDiagnosticsDisabled`, `CanvasDiagnosticsSummary`, `CanvasDiagnosticsVerbose`, `CanvasDataException`, and `CanvasDataErrorCode`. `docs/contracts/public_api_v1.md` and `docs/contracts/diagnostics.md` remain the semantic source of truth. Fixture-only diagnostics membership belongs in test input data, not in durable registry or contract files.

Compatibility:

The root package public exports, public names, public signatures, schema formats, runtime behavior, guardrail ids, and guardrail runner entrypoints must remain compatible. Existing callers of the registry reader must continue to be able to obtain the public export set, either through the same API or through a mechanically migrated equivalent inside the same tooling boundary.

Order Constraints:

Update the registry schema/reader and its tests first, then update the required source-of-truth docs that make registry-owned diagnostics membership normative. After those owners are in place, migrate the diagnostics public surface test from the name predicate to the registry reader, then add the non-prefix negative fixture proof through the migrated helper seam. Run code, DCM, focused guardrail tests, and docs checks after the executable proof and documentation are complete.

## Execution Units

### [ ] Unit 1: Registry membership owner

Owner:

`docs/_registry/public_api_v1.yaml` and `tool/guardrails/src/public_api_registry.dart`.

Boundary:

Registry YAML parsing and registry data shape consumed by guardrail/test tooling.

Change:

Add the `diagnostics_public_surface` membership classification to the existing Public API v1 registry with exactly these initial entries: `CanvasDiagnosticPolicy`, `CanvasDiagnosticsDisabled`, `CanvasDiagnosticsSummary`, `CanvasDiagnosticsVerbose`, `CanvasDataException`, and `CanvasDataErrorCode`. Expose `diagnostics_public_surface` from the registry reader alongside `public_exports`. Add a parser seam in `tool/guardrails/src/public_api_registry.dart`, named `readPublicApiRegistryFromYaml`, so `test/api_contract/public_api_registry_test.dart` can exercise fixture YAML without mutating the real registry file. `readPublicApiRegistryFromYaml` returns a registry value object with `publicExports` and `diagnosticsPublicSurface`; `readPublicApiRegistry()` may remain as the public-export compatibility helper. Enforce that every diagnostics membership entry is also present in `public_exports` by throwing `StateError` from the reader/parser when the subset invariant is violated; the error message must name the missing entry. Keep existing public-export consumers migrated within the same tooling boundary without changing public package APIs. Invalid registry subset cases must use fixture/test YAML input only through `readPublicApiRegistryFromYaml`; the real registry is used for the passing real-registry parse path.

Completion Check:

`test/api_contract/public_api_registry_test.dart` fails a fixture YAML case through `readPublicApiRegistryFromYaml` when `diagnostics_public_surface` contains an entry absent from `public_exports`, observing `StateError` with the missing entry name in the message. The same test proves that the real `docs/_registry/public_api_v1.yaml` exposes exactly `CanvasDiagnosticPolicy`, `CanvasDiagnosticsDisabled`, `CanvasDiagnosticsSummary`, `CanvasDiagnosticsVerbose`, `CanvasDataException`, and `CanvasDataErrorCode` through `diagnostics_public_surface`, that this set is a subset of `public_exports`, and that existing `test/api_contract/public_exports_complete_test.dart` still passes with the migrated reader.

Depends On:

None.

### [ ] Unit 2: Source-of-truth documentation

Owner:

`docs/contracts/public_api_v1.md`, `docs/contracts/diagnostics.md`, `docs/verification/guardrails.md`, and `docs/verification/guardrail_design_patterns.md`.

Boundary:

Normative public API, diagnostics, and guardrail-proof documentation only.

Change:

Document that diagnostics-facing Public API v1 declarations are classified by the `diagnostics_public_surface` membership group inside `docs/_registry/public_api_v1.yaml`, that this group initially contains `CanvasDiagnosticPolicy`, `CanvasDiagnosticsDisabled`, `CanvasDiagnosticsSummary`, `CanvasDiagnosticsVerbose`, `CanvasDataException`, and `CanvasDataErrorCode`, that it must remain a subset of `public_exports`, and that `diagnostics.sanitized_public_projection` uses registry-owned membership plus analyzer-resolved public signature traversal. Update the `diagnostics.sanitized_public_projection` row in `docs/verification/guardrail_design_patterns.md` unless that row already names both registry-owned membership or `registry_parity` and `resolved_public_surface`.

Completion Check:

Documentation describes the registry-owned diagnostics membership and subset invariant without implying new public diagnostics streams or new public API names, and `dart run docs/tool/sync_generated_docs.dart --check` plus `dart run docs/tool/check_docs.dart` pass.

Depends On:

Unit 1.

### [ ] Unit 3: Diagnostics leak guard migration

Owner:

`test/diagnostics/diagnostics_public_surface_test.dart`.

Boundary:

Diagnostics public surface recognition and leak traversal over `PublicApiSurface` analyzer elements.

Change:

Replace `_isDiagnosticsSurfaceName` recognition with registry-owned diagnostics membership. Keep the existing leak traversal over analyzer-resolved public elements and make missing diagnostics registry entries in the resolved public surface produce an explicit test failure rather than a silent skip.

Completion Check:

`dart test test/diagnostics/diagnostics_public_surface_test.dart` passes for the real public barrel. The test or helper explicitly compares `diagnostics_public_surface` registry entries with `surface.exportedElements` and fails with the missing registry entry name when a diagnostics membership entry is absent from the resolved public surface. The test source no longer contains `_isDiagnosticsSurfaceName`, `CanvasDiagnostic` prefix matching, or any local diagnostics allowlist that duplicates the registry classification.

Depends On:

Units 1 and 2.

### [ ] Unit 4: Non-prefix bypass proof

Owner:

Diagnostics guardrail tests and fixture inputs under `test/diagnostics/**` or an existing test fixture/support boundary.

Boundary:

Fixture-only public surface resolution through `resolvePublicApiSurface(libraryPath: ...)` plus an explicit diagnostics membership set supplied to the leak-check helper.

Change:

Add `test/diagnostics/fixtures/non_prefix_diagnostics_surface_fixture.dart` with a public non-prefix diagnostics declaration named `CanvasIssueReport` that exposes `final CanvasRuntime runtime`. Parameterize the diagnostics leak-check helper so the fixture test can supply diagnostics membership `{'CanvasIssueReport'}` without adding fake names to `docs/_registry/public_api_v1.yaml`.

Completion Check:

A focused diagnostics fixture test resolves `test/diagnostics/fixtures/non_prefix_diagnostics_surface_fixture.dart`, supplies diagnostics membership `{'CanvasIssueReport'}`, proves the non-prefix fixture member is scanned, and reports a leak signal containing `CanvasIssueReport.runtime:CanvasRuntime`. The real registry file contains no `CanvasIssueReport` fixture-only diagnostics name.

Depends On:

Unit 3.

### [ ] Unit 5: Guardrail closure verification

Owner:

Guardrail/test verification surfaces for Public API and diagnostics.

Boundary:

Commands that prove the migrated registry and diagnostics guard still integrate with the existing guardrail suite.

Change:

Run and, if failures reveal contract-scoped omissions, repair only the registry/diagnostics/docs surfaces covered by this step.

Completion Check:

The following commands pass from the repository root: `dart test test/api_contract/public_api_registry_test.dart`; `dart test test/diagnostics/diagnostics_public_surface_test.dart`; `dart test test/api_contract/public_exports_complete_test.dart`; `dart analyze`; `dcm analyze .`; `dcm calculate-metrics .`; `dart run docs/tool/sync_generated_docs.dart --check`; and `dart run docs/tool/check_docs.dart`.

Depends On:

Units 1, 2, 3, and 4.
