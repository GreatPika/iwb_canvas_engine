# Change Contract

Contract Mode: FULL
Contract Profile: BEHAVIOR_CHANGE
Contract Obligations: SEAM_MIGRATION

## 1. Mandate and Boundary

### Mandate

Implement P3 schema v1 DTO validation and codec skeleton so external schema v1
JSON is validated at the codec boundary, public DTOs expose frozen
`CanvasMetadata`, encode/decode use only schema v1, diagnostics remain
sanitized, and the mandatory P3 guardrails have executable proof.

### In Scope

- Complete public schema v1 decode and encode behavior for `CanvasDocument`
  entrypoints that are already part of Public API v1.
- Validate schema v1 root, primitive, metadata, resource, layer, element,
  duplicate-id, missing-reference, count, and public DTO limit rules before DTO
  exposure.
- Materialize metadata from schema JSON into `CanvasMetadata` and project
  `CanvasMetadata` back to canonical JSON object values on encode.
- Create the internal validated import draft boundary for already validated
  document facts before future load/runtime materialization.
- Add focused codec, diagnostics, and guardrail proof tests required by the P3
  phase document.
- Make P3 guardrail IDs executable through the existing guardrail runner when
  the runner is the selected owner for that proof.
- Update roadmap checkboxes in this step file and root `PLAN.md` only after the
  implementation step is actually complete.

### Out of Scope

- Runtime store, edit kernel, load-document behavior, resource resolver behavior,
  frame behavior, Flutter surface behavior, and document projection cache
  implementation beyond proving codec no-runtime-side-effect boundaries.
- New schema versions, legacy schema read/write, legacy SceneCodec structure, or
  compatibility with legacy public DTO shapes.
- Public API signature changes, public export renames, or raw map metadata
  exposure from public DTOs.
- New mandatory guardrail IDs unless an implementation blocker proves an
  unrepresented invariant; if that happens, stop and update the source-of-truth
  guardrail pattern map before adding the ID.

## 2. Evidence Map

### Baseline Evidence

These facts describe repository state before execution. They are evidence for
the change, not target-state requirements.

- `docs/implementation/p3_schema_v1_dto_validation_and_codec_skeleton.md`
  defines the P3 purpose, scope, donors, required tests, guardrails, risks, and
  exit gate for schema v1 validation and codec skeleton work.
- `docs/contracts/schema_v1.md` owns schema v1 field shape, unknown-field policy,
  primitive encodings, resource JSON, element JSON, and guardrails
  `codec.schema_v1_exact` and `codec.known_fields_validated`.
- `docs/contracts/codec_boundary.md` owns the public codec entrypoints,
  decode/encode algorithms, schema version constants, metadata projection, and
  no-runtime-side-effect policy.
- `docs/contracts/validation_limits.md` owns shared validation limits for public
  DTO construction, schema decode, metadata, diagnostics verbose limits, and id
  validation.
- `docs/contracts/diagnostics.md` owns internal diagnostics policy, disabled
  hot-path allocation constraints, and public sanitized exception projection.
- `docs/verification/guardrail_design_patterns.md` already maps the P3 guardrail
  IDs to allowed guardrail patterns.
- `docs/diagrams/dfd_schema_v1_import_encode.mmd` and
  `docs/diagrams/seq_schema_v1_import_encode_order.mmd` show codec failures
  flowing from `CodecBoundary` to `DiagnosticsHub` before public
  `CanvasDataException` projection.
- `docs/diagrams/dfd_diagnostics_error_projection.mmd` is listed by the P3
  phase as a diagnostics diagram to read or update for error projection work.
- There is currently no `lib/src/diagnostics/**` production owner, even though
  `docs/contracts/diagnostics.md` defines internal `DiagnosticsHub` and
  `DiagnosticRecord` behavior.

### Entry Paths

- Public callers enter through `encodeCanvasDocument`,
  `encodeCanvasDocumentToJson`, `decodeCanvasDocument`, and
  `decodeCanvasDocumentFromJson` in `lib/src/api/canvas_codec.dart`.
- Schema decode implementation currently enters `lib/src/codec/schema_v1_decoder.dart`.
- Root schema validation currently enters `lib/src/codec/schema_v1_validation.dart`.
- Guardrail execution enters `dart run tool/guardrails/run.dart`, with runner
  inventory in `tool/guardrails/src/guardrail_registry.dart` and proof dispatch
  in `tool/guardrails/src/guardrail_executor.dart`.

### Current Owners

- Public API names and export completeness are owned by
  `docs/contracts/public_api_v1.md`, `docs/_registry/public_api_v1.yaml`, and
  `lib/iwb_canvas_engine.dart`.
- Public DTOs, ids, errors, metadata, diagnostics policy, and value validators
  are owned by `lib/src/api/**`.
- Schema v1 codec logic is owned by `lib/src/codec/**`; it may construct public
  DTOs but must not own runtime/store state.
- `lib/src/codec/validated_import_draft.dart` does not exist yet; section 3
  proposes it as the new internal P3 owner for validated import draft handoff
  facts.
- Internal diagnostics hub allocation policy is not implemented yet; P3 must add
  `lib/src/diagnostics/diagnostics_hub.dart` as the owner for
  `DiagnosticRecord` allocation gates and disabled diagnostics behavior.
- Guardrail metadata, suites, and dispatcher routing are owned by
  `tool/guardrails/**`; simple proof tests may live under `test/**` when no
  reusable scanner is needed.

### Existing Checks

- `test/codec/constructor_and_schema_limits_test.dart` already covers public
  constructor limits and some schema boundary validations through the public
  package entrypoints.
- `test/diagnostics/sanitizer_and_public_projection_test.dart` already covers
  public exception detail sanitization and deep immutability.
- `test/api_contract/id_validation_no_extension_type_escape_test.dart` already
  covers id validation and extension-type escape prevention.
- `test/guardrails/blocking_suite_test.dart` currently expects
  `api.id_validation_no_extension_type_escape` and
  `codec.known_fields_validated` in the runner inventory, but not yet the full
  P3 guardrail set.

### Valid Precedents

- Public API guardrails use a thin runner dispatch to existing proof tests or
  tool-owned structural checks instead of duplicating test logic inside the
  runner.
- Public consumer fixture tests under `test/api_contract/**` compile temporary
  Flutter packages against only the root public barrel for public API proof.
- Existing schema decode code imports public value owners directly and delegates
  shared limits to `lib/src/api/canvas_value_validators.dart`.
- Existing documentation maps guardrail IDs to tests in
  `docs/indexes/by_guardrail.md` and `docs/indexes/by_test_area.md`.

### Repository Rules

- Root `PLAN.md` is the active roadmap, and a completed plan step must update
  both root `PLAN.md` and its linked step document in the same change.
- Documentation says P3 must run after P0, P1, and P2 foundation gates are green.
- Code changes must be verified with `dart analyze`, `dcm analyze .`, and
  `dcm calculate-metrics .` from the repository root.
- Documentation-only changes do not require the code verification commands.
- Mandatory guardrails must choose their pattern from
  `docs/verification/guardrail_design_patterns.md` before executable proof is
  added.

### Misleading Patterns

- `lib/src/api/canvas_codec.dart` currently contains `UnimplementedError` encode
  skeletons; this is a placeholder, not an accepted runtime behavior.
- `lib/src/codec/schema_v1_decoder.dart` may look like the complete P3 owner,
  but P3 also requires encode behavior, full-contract tests, guardrail runner
  proof, and diagnostics proof.
- `test/codec/constructor_and_schema_limits_test.dart` contains some schema
  validation assertions, but it is not a substitute for the named P3 schema v1
  field, resource, element kind, roundtrip, and side-effect tests.
- `diagnostics.disabled_no_alloc_hot_path` is documented for P3/P14, but P3
  cannot prove pointer-move or paint hot paths before those owners exist; P3 may
  only add the executable proof that is meaningful for the current diagnostics
  and codec boundaries, and must leave later hot-path proof explicitly deferred.

## 3. Architecture Decision

### Selected Form

P3 uses a public codec API backed by a schema v1-only codec boundary. Decode
accepts a raw JSON-compatible `Map<String, Object?>` or JSON string, validates
schema v1 and shared limits before DTO exposure, and returns an immutable
`CanvasDocument`. Encode accepts a public `CanvasDocument`, revalidates public
DTO facts that matter at the wire boundary, and returns canonical schema v1 JSON
as a map or string. Guardrail proof is attached to the existing guardrail runner
only where a P3 invariant is intended to be selectable as a blocking guardrail.

### Ownership

`lib/src/codec/**` owns schema v1 wire-shape parsing, canonical writing, field
access, diagnostic paths, and the internal validated import draft boundary.
`lib/src/codec/validated_import_draft.dart` is the internal P3 owner for
validated import facts before future P6 runtime materialization; it is not
public API and does not own load installation. `lib/src/api/**` continues to own
public DTO constructors, id types, metadata freezing, error projection, and
shared value limits. New internal file `lib/src/diagnostics/diagnostics_hub.dart`
owns the P3 diagnostics-disabled allocation gate and `DiagnosticRecord`
allocation policy foundation; it is internal and must not become public API.
`tool/guardrails/**` owns executable guardrail inventory and dispatch. `test/**`
owns behavioral proof at public or owner seams.

### Seam

The seam is the public codec boundary plus its internal validated-import exit:

```text
external JSON <-> public codec API <-> schema v1 codec owner <-> immutable public DTOs
                                                     |
                                                     -> internal validated import draft
```

The seam exposes only public DTOs, JSON-compatible maps/strings, and
`CanvasDataException`; it does not expose runtime/store state, partial decode
drafts, raw metadata maps as DTO metadata, or legacy schema adapters. The
validated import draft is internal codec/load handoff data for future P6; public
decode still returns `CanvasDocument`.

### Dependency Direction

Public codec entrypoints in `lib/src/api/canvas_codec.dart` may delegate to
`lib/src/codec/**`. Codec code may depend on public API value owners and shared
validators under `lib/src/api/**`. Codec code must not import `lib/src/runtime/**`
or future store/edit/frame/surface owners. Guardrail tool code may inspect
repository files and dispatch proof tests, but production code must not depend on
`tool/guardrails/**` or `test/**`.
`lib/src/codec/**` may import `lib/src/diagnostics/diagnostics_hub.dart` for
codec failure projection and disabled diagnostics allocation gates.
`lib/src/diagnostics/diagnostics_hub.dart` may depend on public error and
diagnostic policy value owners under `lib/src/api/**`, but must not import
`lib/src/codec/**`, runtime, store, edit, frame, or surface owners. Public API
code must not depend on internal diagnostics records.

### State and Data Ownership

Schema JSON maps and parsed JSON values are boundary data owned by codec code
until validation succeeds. `CanvasMetadata` owns public metadata after
materialization and must be deeply frozen. `CanvasDocument` owns immutable public
DTO state after materialization. `ValidatedImportDraft` owns only validated
import facts derived from that DTO and schema boundary checks. Runtime/store
state is not owned, read, or mutated by P3 codec operations.

### Entry and Exit Boundaries

Decode exits with either a fully materialized `CanvasDocument` or a
`CanvasDataException`; no partial DTO or runtime side effect may escape. Encode
exits with canonical schema v1 JSON-compatible data or a `CanvasDataException`.
Unknown non-metadata fields may be ignored during decode but must not be
preserved by canonical encode. Metadata is the only schema v1 extension area
that roundtrips. Internal validated import draft construction exits with an
immutable draft wrapping validated document facts for future load materialization
or throws `CanvasDataException`; it must not install the document into runtime.

### Verification Strategy

Verification is split by owner: schema v1 tests prove wire contract behavior;
API contract tests prove public DTO/limit behavior; diagnostics tests prove
sanitized public projection; guardrail tests and runner selection prove blocking
guardrail executability; import/structural checks prove codec does not take
runtime/store dependencies. Final closure uses the repository's required code
checks plus the focused proof set below.

### Decision Ledger

| ID | Decision | Owner | Proof |
|---|---|---|---|
| D1 | P3 implements schema v1 only; no alternate schema version or legacy codec path is allowed. | `lib/src/codec/**` and `lib/src/api/canvas_codec.dart` | `P1`, `P5`, `P6`, `P7` |
| D2 | Metadata roundtrips only through `CanvasMetadata` at the public DTO boundary and canonical JSON object values at the schema boundary. | `lib/src/api/canvas_metadata.dart`, shared validators, and `lib/src/codec/**` | `P2` |
| D3 | P3 guardrail executable proof must use the locked pattern table below; implementers must not choose a new pattern during implementation. | `docs/verification/guardrail_design_patterns.md`, `tool/guardrails/**`, and focused tests | `P5`, `P6`, `P7`, `P8`, `P9` |

### Guardrail Pattern Lock

When P3 adds executable proof, runner dispatch, or new tests for these guardrail
IDs, the implementation must use the following forms from
`docs/verification/guardrail_design_patterns.md`:

| Guardrail id | P3 implementation action | Primary pattern | Secondary pattern | Locked proof shape |
|---|---|---|---|---|
| `codec.schema_v1_exact` | Make executable for P3 if not already selectable. | `registry_parity` | `behavioral_seam_test` | Compare public codec constants/entrypoints with the v1-only contract and prove no alternate version path is accepted or emitted. |
| `codec.known_fields_validated` | Extend existing executable proof. | `behavioral_seam_test` | `registry_parity` | Public codec tests reject invalid known fields, unknown element/resource source kinds, and ensure canonical encode writes only accepted v1 fields. |
| `codec.no_runtime_side_effects` | Make executable for P3. | `behavioral_seam_test` | `resolved_element_identity` | Public codec tests prove encode/decode do not mutate runtime state, and structural proof blocks codec imports of runtime/store/edit/frame/surface mutation owners. |
| `diagnostics.disabled_no_alloc_hot_path` | Add only the P3-meaningful executable subset and document later hot-path proof as deferred. | `budget_probe` | `behavioral_seam_test` | Schema/codec success paths must not allocate diagnostic records; pointer/paint hot-path proof remains deferred until those owners exist. |
| `diagnostics.sanitized_public_projection` | Keep or extend executable proof. | `behavioral_seam_test` | `resolved_public_surface` | Public tests prove bounded sanitized details, and public surface proof prevents runtime objects from leaking through public diagnostics signatures. |
| `api.id_validation_no_extension_type_escape` | Keep existing executable proof green while schema decode adopts id validation. | `behavioral_seam_test` | `resolved_public_surface`, `parsed_ast_directive` | Public id construction and schema-created ids reject invalid values without exposing unchecked extension-type construction. |

If implementation discovers a needed guardrail ID not listed here, it must stop
before adding that ID and first update `docs/verification/guardrail_design_patterns.md`
and the guardrail source-of-truth documents with an explicit pattern decision.

### Donor Reuse Lock

Implementation must follow the P3 donor decisions from
`docs/implementation/p3_schema_v1_dto_validation_and_codec_skeleton.md`; donor
reuse is not an implementation-time choice.

| Donor id | Decision | Target owner |
|---|---|---|
| `direct_structure_validation` | `copy/adapt` | DTO and schema structure validation |
| `foundation_transform2d` | `copy/adapt` | `CanvasTransform` and geometry math |
| `foundation_contract_limits` | `copy/adapt` | Validation limits and public constructors |
| `foundation_error_contract` | `copy/adapt` | `CanvasDataException` and `DiagnosticsHub` |
| `foundation_validators` | `adapt` | Public DTO, `CanvasMetadata`, and schema validators |
| `dto_boundary_schema` | `adapt` | Typed and JSON schema field groups |
| `dto_scene_value_validation` | `adapt/rewrite` | Runtime/model validation adapters |
| `dto_node_boundary_mapping` | `adapt` | Codec and store mapping families |
| `codec_guards` | `copy/adapt` | `CodecBoundary` raw JSON guards |
| `codec_json_require` | `copy/adapt` | Schema v1 strict field access |
| `codec_json_parse` | `adapt` | Schema v1 primitive parsers |
| `codec_metadata_decode` | `adapt` | Schema v1 metadata codec |
| `codec_layer_decode` | `adapt` | Layer schema codec |
| `codec_node_common_decode` | `adapt` | Element common schema codec |
| `codec_family_decode` | `adapt` | Element family codecs |
| `codec_scene_codec_flow` | `adapt/rewrite` | `CodecBoundary` codec reference |
| `codec_validation_path_surface` | `copy/adapt` | Diagnostic path projection |
| `validated_import_draft` | `adapt` | Validated document import draft |

Forbidden donor structures must not be copied into P3:

| Donor id | Decision |
|---|---|
| `avoid_scene_controller_facades` | `avoid` |
| `avoid_interactive_runtime_whole` | `avoid` |
| `avoid_scene_builder_public_architecture` | `avoid` |
| `avoid_scene_codec_whole` | `avoid` |
| `avoid_scene_store_controller_whole` | `avoid` |

### Rejected Alternatives

- Do not decode directly into runtime/store structures; that would spread
  external shape validation into later phases and break the P3 boundary.
- Do not preserve unknown non-metadata fields through canonical encode; the
  schema v1 contract names metadata as the only extension area.
- Do not implement legacy schema compatibility or version negotiation; public
  constants and contracts require write version `1` and read versions `{1}`.
- Do not create a separate guardrail runner or bespoke one-off checker when the
  existing runner can dispatch the proof.
- Do not use prose-only guardrail claims for P3 invariants that can be proven by
  public tests, structural checks, or runner inventory.

## 4. Execution Guardrails

### Required Order

1. Add or update failing focused tests for schema v1 exactness, known-field
   validation, metadata projection, encode roundtrip, resource/element rejection,
   no-runtime-side-effect behavior, diagnostics projection, and guardrail runner
   inventory before relying on implementation changes.
2. Complete codec decode/encode implementation at the schema boundary while
   reusing public DTO constructors and shared validators.
3. Add guardrail runner inventory/dispatch updates only after the proof tests or
   structural checks they dispatch exist.
4. Run the focused proof set, then the repository-required code checks.
5. Mark this step complete in root `PLAN.md` and this step file only after all
   proof and final gates pass.

### Cross-Slice Constraints

- Every new or changed P3 guardrail proof must follow the Guardrail Pattern Lock
  table in section 3.
- Every donor-derived implementation must follow the Donor Reuse Lock table in
  section 3; forbidden donor structures are not reference architectures.
- Codec production code must remain free of runtime/store/edit/frame/surface
  imports.
- Schema paths in public errors must remain bounded public data; tests should
  assert stable path shape only where the contract requires it.
- `CanvasMetadata` remains the only public metadata DTO shape; raw maps may
  appear only at JSON and diagnostic projection boundaries.
- `DiagnosticsHub` and `DiagnosticRecord` stay internal under
  `lib/src/diagnostics/diagnostics_hub.dart`; public exceptions continue to use
  `CanvasDataException` and sanitized public details.
- Existing P0-P2 public API, import-boundary, id-validation, DTO immutability,
  and equality checks must stay green.

### Seam Migration

P3 creates the internal validated import draft handoff seam for future P6 load
materialization. The existing public codec API names remain stable; no public
consumer migration is allowed in P3.

| Seam | Status | Consumers and order | References | Retirement gate |
|---|---|---|---|---|
| `lib/src/codec/validated_import_draft.dart` | New successor seam for validated document import facts. | P3 creates and tests the internal seam first; P6 `loadDocument` may consume it later before runtime materialization. Runtime/store consumers do not consume it in P3. | `docs/implementation/p3_schema_v1_dto_validation_and_codec_skeleton.md`, `docs/_registry/donors.yaml`, `docs/contracts/load_document.md` | `P2` proves the seam exists and does not install runtime state; `P4` proves it is not public API; `P7` proves codec boundary imports remain clean. |
| Legacy import draft naming and structure from donor `validated_import_draft` | Retired as copied structure and public/API naming. | No consumers migrate to legacy `SceneImportDraft` or `scene_import_draft` names. | `docs/_registry/donors.yaml` `do_not_copy` for `validated_import_draft` | `P4` public API proof and targeted negative search show legacy import draft names are absent from public exports and active production code. |

### Forbidden Moves

- Do not add schema v2+, schema v7, legacy SceneCodec, SceneController,
  SceneBuilder, NodeSpec, NodePatch, or PatchField compatibility paths.
- Do not add public APIs or public exports unless a separate public API contract
  update is approved first.
- Do not move validation limits out of the shared public validator owner into
  ad hoc codec-only constants.
- Do not add sync glue between duplicated metadata representations; metadata is
  converted once at the schema boundary.
- Do not satisfy DCM metrics by splitting cohesive codec logic without improving
  ownership or readability.

### Deferred Broad Verification

`diagnostics.disabled_no_alloc_hot_path` includes future pointer-move and paint
hot paths that are not implemented in P3. P3 must add an executable
P3-meaningful subset for diagnostics-disabled schema/codec success paths and
leave later pointer/paint hot-path allocation proof to the phase that introduces
those owners.

## 5. Proof Plan

### P1. Schema v1 Exactness and Codec Contract

Proves public codec constants, unsupported schema versions, canonical version
write behavior, and no alternate schema path.

```sh
dart test test/codec/schema_v1
```

Expected signal: schema v1 codec tests pass, including exact version read/write
coverage and rejection of unsupported schema versions.

### P2. Metadata, Roundtrip, and Validated Import Draft

Proves metadata materializes as `CanvasMetadata`, is not exposed as raw public
maps, encodes back to canonical JSON object values, and can be wrapped in an
internal validated import draft without runtime materialization.

```sh
dart test test/codec/schema_v1 test/codec/constructor_and_schema_limits_test.dart
dart test test/codec/validated_import_draft_test.dart
```

Expected signal: metadata projection, roundtrip, limits, and constructor/schema
limit tests pass, and validated import draft tests prove the internal draft
contains validated immutable document facts without installing them into runtime.

### P3. Diagnostics Public Projection and Disabled P3 Allocation Probe

Proves public diagnostic/error details are sanitized, bounded, and deeply
immutable, and proves the P3-meaningful disabled diagnostics subset does not
allocate diagnostic records on successful schema/codec paths.

```sh
dart test test/diagnostics/sanitizer_and_public_projection_test.dart
dart test test/diagnostics/disabled_no_alloc_hot_path_test.dart
```

Expected signal: diagnostics sanitizer/public projection tests pass, and the
disabled-allocation probe observes `lib/src/diagnostics/diagnostics_hub.dart`
to prove successful schema/codec paths take only the disabled branch without
creating `DiagnosticRecord` instances. Pointer-move and paint allocation proof
is not claimed by this command.

### P4. API Contract Regression

Proves existing public API, id validation, DTO immutability, equality, and
public barrel checks remain green after codec changes.

```sh
dart test test/api_contract
! rg -n "SceneImportDraft|scene_import_draft" lib docs/_registry/public_api_v1.yaml
```

Expected signal: API contract tests pass without public signature or export
regressions, and the negated targeted search exits successfully with no matches
so legacy import draft names are absent from public exports and active production
code.

### P5. Schema Codec Guardrail Runner Proof

Proves schema v1 codec guardrail IDs closed by Slice 1 are selectable through
the project-owned guardrail runner and dispatch the intended schema proof.

```sh
dart run tool/guardrails/run.dart --guardrail=codec.schema_v1_exact
dart run tool/guardrails/run.dart --guardrail=codec.known_fields_validated
```

Expected signal: schema v1 exactness and known-field guardrail selections
succeed through the runner.

### P6. Codec No-Runtime Guardrail Runner Proof

Proves the no-runtime-side-effect guardrail closed by Slice 3 is selectable
through the project-owned guardrail runner and dispatches the intended behavior
and structural proof.

```sh
dart run tool/guardrails/run.dart --guardrail=codec.no_runtime_side_effects
```

Expected signal: the no-runtime-side-effect guardrail selection succeeds through
the runner.

### P7. Codec Structural Boundary Proof

Proves codec code keeps the locked dependency direction and does not import
runtime/store/edit/frame/surface mutation owners.

```sh
dart test test/guardrails/codec_no_runtime_imports_test.dart
```

Expected signal: the structural import test proves codec code does not import
runtime/store/edit/frame/surface dependencies. The runner-level
`codec.no_runtime_side_effects` guardrail in `P6` dispatches this proof without
owning the structural scan twice.

### P8. Diagnostics and API Guardrail Runner Proof

Proves diagnostics and id-validation guardrail IDs required by P3 are selectable
through the project-owned guardrail runner and dispatch the intended proof.

```sh
dart run tool/guardrails/run.dart --guardrail=diagnostics.disabled_no_alloc_hot_path
dart run tool/guardrails/run.dart --guardrail=diagnostics.sanitized_public_projection
dart run tool/guardrails/run.dart --guardrail=api.id_validation_no_extension_type_escape
dart test test/guardrails/blocking_suite_test.dart
```

Expected signal: diagnostics and id-validation guardrail selections succeed
through the runner, and the blocking suite test expects the P3 executable
guardrail inventory. `diagnostics.disabled_no_alloc_hot_path` dispatches only
the P3 schema/codec subset until pointer and paint owners exist.

### P9. Diagnostics Structural Boundary Proof

Proves the new internal diagnostics hub keeps the locked dependency direction.

```sh
dart run tool/guardrails/run.dart --suite=core
```

Expected signal: the core suite checks `lib/src/diagnostics/diagnostics_hub.dart`
does not import codec, runtime, store, edit, frame, or surface owners, and the
core import-boundary and hard-boundary guardrails remain green.

### P10. Repository Code Checks

Proves the completed code change satisfies the repository-required analyzer and
DCM checks.

```sh
dart analyze
dcm analyze .
dcm calculate-metrics .
```

Expected signal: all three commands pass, or any intentional local metric
suppression is documented next to the suppressed declaration as required by the
repository rules.

## 6. Vertical Slices

### Slice 1. [x] Lock schema v1 exactness tests and constants

#### Implements

D1

#### Files

- New verification file: `test/codec/schema_v1/known_fields_validation_test.dart` -
  owns schema v1 known-field validation proof moved out of the broad constructor
  limits test where needed.
- New verification file: `test/codec/schema_v1/reject_unknown_element_kind_test.dart` -
  owns unknown element kind rejection proof.
- New verification file: `test/codec/schema_v1/reject_unknown_resource_source_kind_test.dart` -
  owns unknown resource source kind rejection proof.
- New verification file: `test/codec/schema_v1/resources_appkey_only_test.dart` -
  owns app-key-only resource schema proof.
- Production file: `lib/src/api/canvas_codec.dart` - owns public constants and
  public codec entrypoint delegation.
- Production files: `lib/src/codec/**` - own schema v1 field validation and
  schema-version enforcement.
- Guardrail tool files: `tool/guardrails/src/guardrail_registry.dart` and
  `tool/guardrails/src/guardrail_executor.dart` - own runner inventory and
  dispatch for `codec.schema_v1_exact` and `codec.known_fields_validated`.

#### Change

Add focused tests for the P3 schema v1 exactness surface, then make the public
decode path reject unsupported versions, validate known v1 fields, reject
unknown resource source and element kinds, and keep constants at write `1` and
read `{1}`. Reuse donor material only according to the locked
`direct_structure_validation`, `codec_guards`, `codec_json_require`,
`codec_json_parse`, `codec_layer_decode`, `codec_node_common_decode`,
`codec_family_decode`, and `codec_validation_path_surface` decisions.

#### Proof

Run `P1` and `P5`.

#### Closure

The schema v1 exactness tests fail before the owner-side implementation where
coverage is new, then pass after the codec owner enforces D1.

### Slice 2. [x] Implement canonical schema v1 encode and metadata projection

#### Implements

D1, D2

#### Obligations Covered

SEAM_MIGRATION

#### Files

- Production file: `lib/src/api/canvas_codec.dart` - owns public encode
  entrypoint delegation and removal of encode placeholders.
- Production files: `lib/src/codec/**` - own canonical schema v1 writing,
  color/offset/size/transform codecs, resource/element JSON codecs, and
  metadata projection.
- New production file: `lib/src/codec/validated_import_draft.dart` - owns the
  internal validated import draft boundary before future runtime materialization.
- Verification files: `test/codec/schema_v1/**` - own roundtrip, canonical
  encode, metadata projection, and unknown-field non-preservation proof.
- New verification file: `test/codec/validated_import_draft_test.dart` - owns
  validated import draft behavior proof without runtime installation.
- Existing verification file: `test/codec/constructor_and_schema_limits_test.dart` -
  remains the owner for constructor/schema shared limit coverage and is adjusted
  only when assertions belong to shared limit proof rather than schema-specific
  proof.
- Guardrail tool file: `tool/guardrails/src/core_boundary_checks.dart` - owns
  the structural import proof that codec code, including the validated import
  draft seam, does not import runtime/store/edit/frame/surface mutation owners.
- New verification file: `test/guardrails/codec_no_runtime_imports_test.dart` -
  owns the direct structural proof used by `P7`.

#### Change

Implement canonical encode for public `CanvasDocument` DTOs, including all
common element fields, uppercase color strings, app-key resource descriptors,
order preservation, nullable optional field policy, and metadata projection from
`CanvasMetadata` to JSON-compatible object values. Add the internal validated
import draft wrapper for already validated document facts, without adding
runtime installation or public API. Reuse donor material only according to the
locked `foundation_transform2d`, `foundation_contract_limits`,
`foundation_validators`, `dto_boundary_schema`, `dto_node_boundary_mapping`,
`codec_metadata_decode`, `codec_scene_codec_flow`, and `validated_import_draft`
decisions.

#### Proof

Run `P1`, `P2`, `P4`, and `P7`.

#### Closure

Encode entrypoints no longer throw placeholders, metadata roundtrips only
through `CanvasMetadata`, canonical encode omits unknown non-metadata input
fields, and an internal validated import draft exists without runtime
materialization, legacy public import draft naming, or forbidden codec imports.

### Slice 3. [x] Prove codec no-runtime-side-effect boundary

#### Implements

D1

#### Files

- New verification file: `test/codec/decode_encode_no_runtime_side_effects_test.dart` -
  owns public behavior proof that encode/decode do not mutate runtime state.
- Production files: `lib/src/codec/**` - remain the codec owner and are adjusted
  only to remove dependency or side-effect violations found by proof.
- Guardrail tool files: `tool/guardrails/src/guardrail_registry.dart` and
  `tool/guardrails/src/guardrail_executor.dart` - own runner inventory and
  dispatch for `codec.no_runtime_side_effects` if it becomes executable in P3.
- Verify-only guardrail tool file: `tool/guardrails/src/core_boundary_checks.dart` -
  provides the structural import check reused by `P7`.
- Verify-only verification file: `test/guardrails/codec_no_runtime_imports_test.dart` -
  provides the direct structural proof reused by `P7`.

#### Change

Add a test that uses public `CanvasRuntime` with an initial public
`CanvasDocument`, captures public state and `readDocument()` results before and
after public codec decode/encode operations, and proves those public runtime
observations are unchanged. Add the runner entry only after the behavioral test
exists, and dispatch to that proof rather than duplicating runtime assertions in
the runner.

#### Proof

Run `P6` and `P7`.

#### Closure

The no-runtime-side-effect test passes, codec code has no runtime/store mutation
imports, and the guardrail runner can select the no-side-effect proof when P3
makes it executable.

### Slice 4. [x] Lock diagnostics proof for P3 codec boundaries

#### Implements

D3

#### Files

- Existing verification file: `test/diagnostics/sanitizer_and_public_projection_test.dart` -
  owns public sanitized projection proof and may be extended for P3 error shapes.
- New verification file: `test/diagnostics/disabled_no_alloc_hot_path_test.dart` -
  owns the P3-meaningful diagnostics-disabled allocation probe for successful
  schema/codec paths.
- New production file: `lib/src/diagnostics/diagnostics_hub.dart` - owns
  internal `DiagnosticRecord` allocation gates and disabled diagnostics branch
  behavior observed by the allocation probe.
- Guardrail tool files: `tool/guardrails/src/guardrail_registry.dart` and
  `tool/guardrails/src/guardrail_executor.dart` - own runner inventory and
  dispatch for P3-executable diagnostics guardrails.
- Guardrail tool file: `tool/guardrails/src/core_boundary_checks.dart` - owns
  structural proof that `lib/src/diagnostics/diagnostics_hub.dart` does not
  import codec, runtime, store, edit, frame, or surface owners.
- Verification file: `test/guardrails/blocking_suite_test.dart` - owns inventory
  expectation updates for diagnostics guardrails that are executable in P3.

#### Change

Keep sanitized public projection executable and add only the P3-meaningful
diagnostics disabled-allocation proof. Do not claim pointer-move or paint
hot-path allocation proof until those owners exist. Reuse donor material only
according to the locked `foundation_error_contract` and
`dto_scene_value_validation` decisions.

#### Proof

Run `P3`, `P8`, and `P9`.

#### Closure

Diagnostics public projection remains green, P3 diagnostics guardrail runner
entries dispatch to real proof, the disabled-allocation probe exists for the P3
schema/codec subset, and deferred pointer/paint hot-path proof is explicit
rather than silently claimed.

### Slice 5. [x] Finalize guardrail inventory and roadmap closure

#### Implements

D3

#### Obligations Covered

SEAM_MIGRATION

#### Files

- Guardrail source-of-truth file: `docs/verification/guardrails.md` - alignment
  target only if P3 executable status or notes need source-of-truth updates.
- Guardrail pattern file: `docs/verification/guardrail_design_patterns.md` -
  must be updated before any new guardrail ID is introduced; otherwise remains
  unchanged because the P3 pattern lock already exists.
- Generated or indexed docs: `docs/indexes/by_guardrail.md`,
  `docs/indexes/by_test_area.md`, and `docs/_registry/sections.yaml` - alignment
  targets only if required by source-of-truth updates.
- Roadmap file: `PLAN.md` - owns root checkbox completion for Step 23.
- Step file: `plan/step_23_p3_schema_v1_dto_validation_and_codec_skeleton.md` -
  owns slice checkbox completion evidence for Step 23.

#### Change

Align guardrail inventory, tests, and source-of-truth references after the
executable P3 proof set is known. Confirm the validated import draft seam has no
legacy public naming or production references. Mark roadmap completion only
after all slices and final proof pass.

#### Proof

Run `P4`, `P5`, `P6`, `P7`, `P8`, `P9`, and `P10`.

#### Closure

The guardrail runner and documentation agree about P3 executable guardrails, no
new guardrail pattern is invented outside the locked map, the seam migration
negative proof passes, and roadmap checkboxes are updated in the same completed
change.

## 7. Final Gate

### Run Proof Set

- `P1`
- `P2`
- `P3`
- `P4`
- `P5`
- `P6`
- `P7`
- `P8`
- `P9`
- `P10`

### Done When

- all referenced Decision Ledger decisions have passing proof;
- all Contract Obligations are satisfied;
- all P3 schema v1 roundtrip, metadata, known-field, unknown-kind, resource,
  limit, diagnostics, and no-runtime-side-effect tests pass;
- every P3 guardrail made executable follows the Guardrail Pattern Lock table;
- no new guardrail ID is added without first updating the guardrail pattern
  source of truth;
- no runtime/store/edit/frame/surface implementation is introduced by P3 codec
  work;
- no public API signature, export registry, schema version, or metadata DTO
  compatibility change occurs without a separate approved contract;
- root `PLAN.md` and this step file are marked complete in the same final
  implementation change;
- no out-of-scope files were changed.
