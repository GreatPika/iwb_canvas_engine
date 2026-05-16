# Change Contract

## 1. Change Mandate

Close the documentation gap for public-readable union variants. The public API
contract, export registry, verification mappings, diagrams, audit, and redesign
notes must agree that app-read `CanvasResourceSource` and
`CanvasDiagnosticPolicy` variants are public concrete classes.

## 2. Change Boundary

### Included in the Change

- Replace documentation references to private concrete variants for
  `CanvasResourceSource.appKey` with exported public
  `CanvasAppKeyResourceSource`.
- Replace documentation references to private concrete diagnostics policy
  variants with exported public `CanvasDiagnosticsDisabled`,
  `CanvasDiagnosticsSummary`, and `CanvasDiagnosticsVerbose`.
- Preserve base factory entrypoints on `CanvasResourceSource` and
  `CanvasDiagnosticPolicy`.
- Preserve `CanvasDiagnosticsVerbose` validation wording and public readable
  verbose limit fields.
- Add the exported concrete variant names to the public API registry.
- Add verification mappings for the future executable proof
  `test.api_contract.public_readable_union_variants` and guardrail
  `api.resource_source_app_key_publicly_readable`.
- Update resource-resolution diagrams so the app-facing descriptor explicitly
  exposes `CanvasAppKeyResourceSource.key`.
- Retire the stale HOLE-001 audit entry and the corresponding redesign item.
- Mark this documentation step complete in `PLAN.md`.

### Not Included in the Change

- No production Dart files.
- No test implementation files.
- No `lib/`, `test/`, or `tool/` scaffolding.
- No resource source kind beyond `appKey`.
- No schema v1 JSON shape change for `"source": { "kind": "appKey" }`.
- No engine IO, asset-bundle, file, or network resource loading.
- No public diagnostics stream.
- No `CanvasResourceSourceKind` or `CanvasDiagnosticMode` enum.

## 3. Locked Decisions

1. Public readable variants are concrete classes, not discriminator enums.
2. Base factory constructors remain available for existing construction style.
3. `CanvasResourceSource.appKey(String key)` targets
   `CanvasAppKeyResourceSource`.
4. `CanvasDiagnosticPolicy.disabled()` targets `CanvasDiagnosticsDisabled`.
5. `CanvasDiagnosticPolicy.summary()` targets `CanvasDiagnosticsSummary`.
6. `CanvasDiagnosticPolicy.verbose(...)` targets `CanvasDiagnosticsVerbose`.
7. `CanvasDiagnosticsVerbose.maxPreviewLength` and
   `CanvasDiagnosticsVerbose.maxListEntries` are the public readable verbose
   policy limits.
8. The schema v1 JSON `source.kind=appKey` discriminator remains unchanged.

## 4. Result Requirements

1. The public API contract says external resolver code can read
   `CanvasAppKeyResourceSource.key` from `CanvasImageResource.source` through
   the public barrel only.
2. The public API contract says external config-inspection code can identify
   diagnostics policy variants and read verbose limits when applicable.
3. The public API registry lists `CanvasAppKeyResourceSource`,
   `CanvasDiagnosticsDisabled`, `CanvasDiagnosticsSummary`, and
   `CanvasDiagnosticsVerbose`.
4. Verification and index documents map the public readability proof and
   guardrail to the owning sections.
5. The resource contract and resource-resolution diagrams name
   `CanvasAppKeyResourceSource.key` at the app resolver boundary.
6. `audit.md` no longer tracks HOLE-001.
7. `redesign.md` no longer contains the implemented public-union redesign item.

## 5. File Map

### Edited Documentation

- `PLAN.md`
- `plan/step_2_public_readable_union_variants.md`
- `docs/_registry/public_api_v1.yaml`
- `docs/_registry/sections.yaml`
- `docs/contracts/public_api_v1.md`
- `docs/contracts/resources.md`
- `docs/contracts/diagnostics.md`
- `docs/verification/tests.md`
- `docs/verification/guardrails.md`
- `docs/indexes/by_test_area.md`
- `docs/indexes/by_guardrail.md`
- `docs/implementation/p2_public_api_v1_freeze.md`
- `docs/implementation/p3_schema_v1_dto_validation_and_codec_skeleton.md`
- `docs/implementation/p4_runtime_spine.md`
- `docs/implementation/p7_resources_and_images.md`
- `docs/diagrams/dfd_resource_resolution.mmd`
- `docs/diagrams/seq_resource_resolution.mmd`
- `docs/diagrams/state_resource_resolution.mmd`
- `audit.md`
- `redesign.md`

### Files Intentionally Not Edited

- `lib/**`
- `test/**`
- `tool/**`

## 6. Vertical Slices

### Slice 1. [x] Public API Contract And Registry

- Public-readable resource and diagnostics variants are named in
  `docs/contracts/public_api_v1.md`.
- Public-readable concrete variant names are listed in
  `docs/_registry/public_api_v1.yaml`.
- Private in-scope variant names are absent from the public API contract.

### Slice 2. [x] Verification And Phase Mapping

- `test.api_contract.public_readable_union_variants` is listed in the test
  registry, test index, resource contract, and relevant section mappings.
- `api.resource_source_app_key_publicly_readable` is listed in guardrail docs,
  guardrail index, and relevant section mappings.
- P2, P3, P4, and P7 phase documents refer to the public-readable variant names.

### Slice 3. [x] Resource Diagrams

- The DFD, sequence diagram, and state diagram for resource resolution name
  `CanvasAppKeyResourceSource.key` at the public app resolver boundary.

### Slice 4. [x] Audit And Redesign Retirement

- HOLE-001 is removed from `audit.md`.
- The implemented public-union redesign item is removed from `redesign.md`.
- This plan step is marked complete in `PLAN.md`.

## 7. Verification

- `dart run docs/tool/check_docs.dart`
- `rg -n "HOLE-001|CanvasResourceSource\\.appKey.*недоступен|Публичные union-типы|_CanvasAppKeyResourceSource|_CanvasDiagnostic(Disabled|Summary|Verbose)|CanvasResourceSourceKind|CanvasDiagnosticMode" audit.md redesign.md docs/contracts/public_api_v1.md docs/_registry/public_api_v1.yaml docs/contracts/resources.md docs/contracts/diagnostics.md docs/verification docs/indexes docs/_registry/sections.yaml docs/diagrams/dfd_resource_resolution.mmd docs/diagrams/seq_resource_resolution.mmd docs/diagrams/state_resource_resolution.mmd`
- `rg -l "CanvasAppKeyResourceSource\\.key" docs/diagrams/dfd_resource_resolution.mmd docs/diagrams/seq_resource_resolution.mmd docs/diagrams/state_resource_resolution.mmd | wc -l`
- `git diff --check`

## 8. Acceptance Criteria

- `CanvasAppKeyResourceSource`, `CanvasDiagnosticsDisabled`,
  `CanvasDiagnosticsSummary`, and `CanvasDiagnosticsVerbose` are documented as
  exported public API names.
- External app-read resource and diagnostics policy unions are documented as
  publicly readable through concrete variants.
- Existing base factory construction remains documented.
- Existing diagnostic verbose validation behavior remains documented.
- Existing schema v1 resource source JSON shape remains documented.
- Resource-resolution diagrams show the app resolver receives a descriptor whose
  source is publicly readable as `CanvasAppKeyResourceSource.key`.
- `audit.md` no longer tracks HOLE-001.
- `redesign.md` no longer contains the implemented public-union item.
