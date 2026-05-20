# Change Contract

Contract Mode: FULL
Contract Profile: BEHAVIOR_CHANGE
Contract Obligations: BUG_FIX, SEAM_MIGRATION, PUBLIC_API_CHANGE

## 1. Mandate and Boundary

### Mandate

Harden the P1 public API draft before P2 public API freeze. The step must make
P2-owned exported behavior safe and executable, make deferred later-phase
placeholders explicit through tooling, strengthen public API proof beyond
exported-name availability, and prevent public API import cycles from
reappearing after the current ownership cycles are removed.

### In Scope

- `CanvasDataException` public details sanitization, bounding, and immutable
  exposure according to `docs/contracts/public_api_v1.md` and
  `docs/contracts/diagnostics.md`.
- Public id admission behavior for leading and trailing whitespace.
- P2-owned public value behavior for `CanvasTransform` construction, rotation,
  TRS composition, multiplication, point/rect application, inversion, matrix
  conversion, and JSON projection.
- A public placeholder policy that removes P2-owned `UnimplementedError` stubs
  and allowlists only later-phase exported placeholders with owner phase,
  reason, and removal condition. `CanvasRuntime.state`,
  `CanvasRuntimeState`, `CanvasRuntimeRevisions`, and
  `CanvasRuntimeSummary` are P2-owned runtime observation surface and are not
  eligible for the placeholder allowlist.
- Stronger public API compile proof that instantiates and calls the normative
  P2-owned public v1 contract surface.
- Guardrail and documentation alignment for dartdoc and public class modifier
  checks that P2 currently lists as release proof.
- Public API ownership-cycle repair for metadata ownership and transform
  validation ownership.
- A lightweight `api.no_public_api_import_cycles` guardrail implemented through
  parsed Dart import directives, repo-relative import resolution, graph
  construction, and Tarjan SCC detection over public API source files.
- The full P2 phase proof set, including existing `CanvasFieldUpdate`, preview
  sealed union, runtime observation compile, external app adapter compile, DTO
  immutability, equality, validation, signature, codec known-field, and
  guardrail checks, creating missing phase-proof tests where the phase already
  names the obligation but the file is not present yet.
- Updates to the exact source-of-truth and generated documentation files named
  in the slices when newly executable guardrails change inventories.
- Final planning checkbox closure in `PLAN.md` and this step file after the
  implementation gate is green.

### Out of Scope

- Full runtime, edit, selection, resource, frame, interaction, or Flutter
  surface behavior owned by P4 and later phases.
- Full schema v1 encoder/decoder behavior owned by P3. This step does not
  implement `encodeCanvasDocument` or `encodeCanvasDocumentToJson`; it makes
  those exported placeholders explicit and blocking-removable before P3 closes.
- A repository-wide `core.no_import_cycles` guardrail.
- Legacy API compatibility, legacy public facades, or wrapping the old runtime.
- Broad documentation rewrites unrelated to P2 freeze proof, guardrail
  inventory, or the source-of-truth contradictions repaired by this step.

## 2. Evidence Map

### Baseline Evidence

These facts describe repository state before execution. They are evidence for
the change, not target-state requirements.

- P2 is the public API freeze phase and requires public DTOs, ids, errors,
  validation rules, equality, dartdoc, class modifiers, and signature-shape
  guardrails before later runtime phases consume the surface:
  `docs/implementation/p2_public_api_v1_freeze.md`.
- P2 also lists `CanvasFieldUpdate`, preview sealed union, runtime observation,
  app-adapter compile fixture, DTO immutability, equality, id validation,
  known-field validation, and public guardrails as phase proof:
  `docs/implementation/p2_public_api_v1_freeze.md`.
- The public API contract specifies `CanvasDataException` as a public factory
  that sanitizes `details` before exposure:
  `docs/contracts/public_api_v1.md`.
- The current implementation exposes a const `CanvasDataException` constructor
  and stores caller-provided `details` directly:
  `lib/src/api/canvas_errors.dart`.
- The diagnostics contract requires public exceptions to expose sanitized
  bounded details only:
  `docs/contracts/diagnostics.md`.
- The current public codec exports `encodeCanvasDocument` and
  `encodeCanvasDocumentToJson`, but both throw `UnimplementedError`:
  `lib/src/api/canvas_codec.dart`.
- `CanvasRuntime` is publicly constructible and its public entrypoints throw
  `UnimplementedError`; `CanvasSurface` currently renders an empty widget:
  `lib/src/api/canvas_runtime.dart` and `lib/src/api/canvas_surface.dart`.
- `CanvasTransform` is exported as a public value object, but rotation, TRS,
  multiplication, application, inversion, matrix conversion, and JSON projection
  helpers throw `UnimplementedError`: `lib/src/api/canvas_geometry.dart`.
- `test/api_contract/public_api_v1_compiles_as_written_test.dart` currently
  emits `_use($name)` for registry names, proving exported-name availability
  without proving constructor, parameter, getter, method, default, or return
  shapes as written.
- `docs/verification/tests.md` says
  `public_api_v1_compiles_as_written_test.dart` verifies dartdoc summaries and
  explicit public class modifiers, while the guardrail registry does not list
  `api.exported_dartdoc_complete` or `api.public_class_modifiers_explicit` as
  executable runner entries: `tool/guardrails/src/guardrail_registry.dart`.
- `canvas_value_validators.dart` imports `canvas_geometry.dart`, while
  `canvas_geometry.dart` imports `canvas_value_validators.dart`.
- `canvas_element.dart` imports `canvas_document.dart` only for
  `CanvasMetadata`, while `canvas_document.dart` imports element and resource
  owners.
- `canvas_element_update.dart` imports `canvas_document.dart` and uses
  `CanvasMetadata`, making it another active consumer of the document-owned
  metadata seam.
- `schema_v1_decoder.dart` imports `../api/canvas_document.dart` and uses
  `CanvasMetadata` while materializing schema metadata.
- `validateCanvasIdValue` trims and returns id values, allowing public ids with
  boundary whitespace to become different stored ids silently:
  `lib/src/api/canvas_value_validators.dart`.

### Entry Paths

- P2 phase contract:
  `docs/implementation/p2_public_api_v1_freeze.md`.
- Public API contract:
  `docs/contracts/public_api_v1.md`.
- Diagnostics contract:
  `docs/contracts/diagnostics.md`.
- Codec boundary contract:
  `docs/contracts/codec_boundary.md`.
- Guardrail source of truth:
  `docs/verification/guardrails.md`,
  `docs/verification/guardrail_design_patterns.md`, and
  `docs/_registry/sections.yaml`.
- Public API compile proof:
  `test/api_contract/public_api_v1_compiles_as_written_test.dart`.
- Guardrail runner inventory and dispatch:
  `tool/guardrails/src/guardrail_registry.dart`,
  `tool/guardrails/src/guardrail_executor.dart`, and
  `test/guardrails/blocking_suite_test.dart`.

### Current Owners

- Public API semantics and public compatibility decisions are owned by
  `docs/contracts/public_api_v1.md`.
- Diagnostic public projection semantics are owned by
  `docs/contracts/diagnostics.md`.
- Codec entrypoint semantics are owned by `docs/contracts/codec_boundary.md`,
  with full schema v1 codec behavior scheduled by
  `docs/implementation/p3_schema_v1_dto_validation_and_codec_skeleton.md`.
- Exported public declarations are owned by `lib/src/api/**` and exported
  through `lib/iwb_canvas_engine.dart`.
- Public API executable proof is owned by `test/api_contract/**` and the
  guardrail runner under `tool/guardrails/**`.
- Mandatory guardrail ids are owned by `docs/verification/guardrails.md` and
  `docs/_registry/sections.yaml`; implementation patterns are owned by
  `docs/verification/guardrail_design_patterns.md`.

### Existing Checks

- `api.public_exports_complete` compares the public registry with the resolved
  public barrel.
- `api.public_types_complete` and `api.no_undefined_public_type_references`
  inspect exported public signature references.
- `api.public_signature_shape` is an executable runner entry for broader
  public signature constraints.
- `api.dto_immutability`, `api.equality_policy_explicit`, and
  `api.id_validation_no_extension_type_escape` already provide behavioral API
  proof for selected public value constraints.
- `core.import_boundaries`, `core.no_legacy_imports`, and
  `core.no_unapproved_part_files` already use parsed/resolved Dart source
  inspection for import/export/part rules, but they do not detect cycles inside
  `lib/src/api/**`.
- No executable guardrail currently rejects public API import cycles.
- No executable guardrail currently rejects unapproved exported public
  placeholders.

### Valid Precedents

- `tool/guardrails/src/core_boundary_checks.dart` already parses Dart
  directives and resolves production import/export/part boundary rules.
- `test/guardrails/core_boundary_negative_fixtures_test.dart` uses targeted
  negative fixture content to prove structural guardrail failures.
- `test/guardrails/blocking_suite_test.dart` locks guardrail runner inventory,
  suite membership, and dry-run selection.
- `docs/verification/guardrail_design_patterns.md` selects
  `parsed_ast_directive` for import/export/part directive checks and
  `resolved_public_surface` for exported public surface checks.
- `test/api_contract/public_readable_union_variants_test.dart` proves external
  public-barrel use through concrete consumer code, which is the right model for
  stronger public API compile snippets.

### Repository Rules

- The root public barrel may export only `lib/src/api/**`.
- P2 must freeze only the new package public API; legacy API compatibility and
  legacy public facades remain forbidden.
- Important invariants should be enforced through repository-local tests,
  guardrails, or tooling rather than prose-only reminders.
- Public constructors accepting caller-provided validated or sanitized values
  must be non-const factories except approved marker, empty, default, or private
  storage forms.
- Documentation-only claims about guardrails must match executable runner
  inventory or be rewritten as future intent.

### Misleading Patterns

- `_use($name)` in an empty consumer proves exported-name availability, not the
  public contract as written.
- A compile-green app fixture can still hide public API placeholders because
  analyzer proof does not execute methods.
- A broad `core.no_import_cycles` would be a larger architectural rule than the
  current P2 defect requires and would need separate ownership decisions for
  every future internal layer.
- Dart tolerating import cycles is not proof that the cycles are acceptable
  ownership boundaries.
- Leaving public placeholder status only in phase prose would recreate the false
  readiness this step is meant to remove.

## 3. Architecture Decision

### Selected Form

Implement a targeted P2 hardening pass over the exported public API seam. Public
value and error behavior that P2 owns becomes executable behavior with
behavioral tests. Later-phase exported placeholders remain deferred, but only
through an executable allowlist in `tool/guardrails/src/public_api_placeholder_allowlist.dart`.
The allowlist must contain declaration id, owning phase, reason, and removal
condition for each placeholder.

The contract profile is `BEHAVIOR_CHANGE` because the dominant owned result is
changed exported public API behavior before freeze. The new structural
guardrails are included as enforcement proof for that public behavior, not as a
separate analyzer-rule migration.

Add `api.no_public_api_import_cycles` as a lightweight public API guardrail. It
will parse Dart import directives, resolve relative and same-package imports to
repo-relative file paths, build a directed graph for public API implementation
files, detect strongly connected components with Tarjan, and report every cycle
with stable sorted file paths. This step permits no active public API
import-cycle allowlist entries.

### Ownership

- `CanvasDataException` owns public error projection safety once, not each
  call site that throws it.
- Diagnostic details sanitization lives in
  `lib/src/api/canvas_error_details_sanitizer.dart`, a non-exported API-local
  sanitizer used by `CanvasDataException`.
- `CanvasTransform` owns public transform math and conversion behavior once.
- Transform-specific element admission validation lives in
  `lib/src/api/canvas_transform_admission.dart`, a non-exported API-local
  helper that may import `canvas_geometry.dart` and primitive validators.
  `canvas_value_validators.dart` must not import `canvas_geometry.dart`.
- `CanvasMetadata` moves to `lib/src/api/canvas_metadata.dart`, the
  cross-cutting metadata DTO value owner.
- `api.no_public_api_import_cycles` is owned by
  `tool/guardrails/src/public_api_import_cycle_checks.dart`, with proof under
  `test/guardrails/public_api_import_cycles_test.dart`.
- Public API consumer snippets are owned by
  `test/api_contract/public_api_v1_compiles_as_written_test.dart`; they must
  exercise public calls through `package:iwb_canvas_engine/iwb_canvas_engine.dart`.

### Seam

The public seam is `package:iwb_canvas_engine/iwb_canvas_engine.dart`. P2
freeze is blocked until this seam exposes working P2-owned behavior and all
remaining later-phase placeholders are explicit, bounded, and scheduled for
removal by their owning phase.

### Dependency Direction

- Public API files under `lib/src/api/**` must form an acyclic import graph
  after this step.
- Metadata-bearing DTOs import `canvas_metadata.dart`; `canvas_metadata.dart`
  does not import document, element, resource, runtime, codec, or surface
  owners.
- `canvas_geometry.dart` may import primitive validators from
  `canvas_value_validators.dart`; `canvas_value_validators.dart` must not import
  geometry DTOs.
- `canvas_element.dart` may import `canvas_transform_admission.dart` for
  transform admission; `canvas_transform_admission.dart` must stay non-exported.
- Guardrail tooling may inspect production source and docs. Production API code
  must not depend on guardrail, test, docs, or legacy source.
- Tests and external consumer fixtures must import only the root public barrel
  when proving public API contract use.

### State and Data Ownership

- `CanvasDataException.details` stores only sanitized, bounded,
  deeply-unmodifiable JSON-like public data. Raw application objects, runtime
  objects, handles, closures, images, canvases, full document dumps, and mutable
  caller maps never become public exception state.
- Public ids preserve source truth by rejecting non-canonical boundary
  whitespace instead of silently trimming and storing a different value.
- Public placeholder allowlist data is tooling-owned data and does not affect
  production behavior.
- `api.no_public_api_import_cycles` has no active allowlist data at final
  closure.

### Entry and Exit Boundaries

- Entry points are public constructors, exported public functions, exported
  public methods/getters, public API tests, guardrail runner selection, and
  documentation checks.
- Exit signals are passing behavioral API tests, passing guardrail runner
  entries, an acyclic public API import graph, aligned source-of-truth docs, the
  full P2 phase proof set, and no unapproved exported public placeholders.

### Public API Compatibility

This is a pre-freeze draft hardening step. Changing `CanvasDataException` from a
public const constructor to a public factory with private storage constructor is
breaking for draft code that used const exception construction, but it matches
the accepted v1 contract and is allowed before P2 freeze because the package is
not yet a stable published API. Rejecting id boundary whitespace is a breaking
draft behavior change for non-canonical ids and is accepted because it prevents
silent identity normalization before freeze. Moving `CanvasMetadata` to
`canvas_metadata.dart` is non-breaking for root-barrel consumers as long as
`CanvasMetadata` remains exported and present in `docs/_registry/public_api_v1.yaml`.
The placeholder allowlist is not a public API promise; it is a release-blocking
tooling mechanism. Any public API change after P2 must use a new
`PUBLIC_API_CHANGE` contract with migration or versioning notes.
`CanvasRuntime.state` is not part of the deferred runtime placeholder policy:
P2 requires a readable public observation surface even though edit, command,
resource, camera, tool, interaction, and surface behavior remains owned by later
phases.

### Verification Strategy

Use owner-level behavioral tests for public error projection, id admission,
transform value behavior, public consumer compile snippets, and P2 phase
regression tests. Use structural guardrails for public placeholders, public API
import cycles, dartdoc/modifier runner inventory, and docs/registry alignment.
Finish with the repository code checks required after code changes:
`dart analyze`, `dcm analyze .`, and `dcm calculate-metrics .`.

### Decision Ledger

| ID | Decision | Owner | Proof |
|---|---|---|---|
| D1 | Public exception details are sanitized and deep-frozen by `CanvasDataException` through `canvas_error_details_sanitizer.dart`, not by throw sites. | `lib/src/api/canvas_errors.dart` | `P1`, `P10` |
| D2 | Public ids reject leading or trailing whitespace instead of trimming to a different stored id. | `lib/src/api/canvas_value_validators.dart` | `P2`, `P10` |
| D3 | P2-owned exported public value behavior cannot remain a throwing stub; later-phase public placeholders are allowed only through `public_api_placeholder_allowlist.dart`. | `lib/src/api/**`, `tool/guardrails/**` | `P3`, `P10` |
| D4 | Public API ownership cycles are forbidden by `api.no_public_api_import_cycles`, using parsed import directives and Tarjan SCC detection over resolved repo-relative public API files. | `tool/guardrails/src/public_api_import_cycle_checks.dart` | `P4`, `P5`, `P6`, `P10` |
| D5 | P2 freeze proof includes the full P2 phase proof set, not only the new hardening checks. | `docs/implementation/p2_public_api_v1_freeze.md` | `P8`, `P9`, `P10` |
| D6 | `CanvasRuntime.state` and its public snapshot DTOs are executable P2 observation surface and cannot be allowlisted as later-phase placeholders. | `lib/src/api/canvas_runtime.dart` | `P3`, `P8`, `P10` |

### Rejected Alternatives

- Do nothing until P3/P4: rejected because P2 would freeze a public seam whose
  safety and behavior are contradicted by executable code.
- Implement full codec/runtime/surface behavior in this step: rejected because
  P3 and later phases own that behavior; this step only makes deferred public
  placeholders explicit and release-blocking.
- Rely on analyzer success alone: rejected because analyzer success does not
  prove method bodies, mutability safety, runtime throws, or ownership cycles.
- Add a broad `core.no_import_cycles` now: rejected for this step because it
  would require layer-wide architecture decisions beyond the observed P2 public
  API ownership defect.
- Keep `CanvasMetadata` document-owned and add sync imports around it: rejected
  because metadata is a cross-cutting DTO value, not document state.
- Keep id trimming and document it as convenience: rejected because it hides bad
  input and changes identity/reference facts before encode/debug projection.

## 4. Execution Guardrails

### Required Order

1. Add failing reproducer tests or fixtures for `CanvasDataException.details`,
   id whitespace admission, P2-owned transform stubs, public placeholders,
   name-only public API proof, and public API import cycles before the
   owner-side repair for each defect.
2. For each reproducer, add 1 to 3 neighboring guard cases in the same proof
   file before broadening the implementation.
3. Fix owner-side behavior at the shared owner, not by patching individual call
   sites or consumer snippets.
4. Break the current metadata and transform validator import cycles before
   registering `api.no_public_api_import_cycles` as a blocking runner entry.
5. Register new or repaired guardrails only after positive and negative proof
   exists.
6. Align source-of-truth docs after executable behavior and runner inventory are
   accurate.
7. Run final code, guardrail, and documentation checks after all slices are
   complete.

### Cross-Slice Constraints

- Do not broaden public API beyond the v1 contract to make tests convenient.
- Do not satisfy DCM metrics by splitting cohesive public value objects without
  improving ownership or readability.
- Do not add a public import-cycle allowlist entry in this step.
- Do not leave documentation claiming a guardrail exists unless the runner can
  execute it or the wording explicitly marks it as future.
- Do not use string-only import scans for `api.no_public_api_import_cycles`.
- Do not remove existing P2 proof coverage while adding hardening checks.

### Seam Migration

| Retired seam | Successor seam | Consumer migration order | Retirement gate |
|---|---|---|---|
| Document-owned `CanvasMetadata` access through `canvas_document.dart` imports | `lib/src/api/canvas_metadata.dart` exported by the root barrel | Move metadata declaration, export metadata file, update document, element, element-update, resource, codec, and API imports, run public API and import-cycle proof | No `lib/src/api/**` file imports `canvas_document.dart` only for metadata, root-barrel consumers still see `CanvasMetadata`, and `api.no_public_api_import_cycles` is green |
| Name-only public API compile proof | Public consumer snippets plus existing registry-name availability proof | Add snippets for P2-owned constructors/methods/getters/defaults, keep registry availability, update docs wording | A consumer package fails on intentional signature drift and passes on the locked public surface |
| Prose-only public placeholder awareness | `test/api_contract/public_api_no_unapproved_placeholders_test.dart` plus `tool/guardrails/src/public_api_placeholder_allowlist.dart` | Add structural proof, remove P2-owned stubs, allowlist only later-phase placeholders with owner phase/removal condition | No unapproved exported public `UnimplementedError` or known empty-surface placeholder remains |

### Forbidden Moves

- Do not move sanitizer responsibility into codec/runtime/diagnostic throw
  sites while leaving `CanvasDataException` unsafe.
- Do not keep `CanvasDataException` as a public const constructor when
  caller-provided `details` require runtime sanitization.
- Do not implement runtime or surface behavior by copying legacy controller or
  old runtime architecture.
- Do not make the import-cycle guardrail depend on LSP, IDE state, or a
  manually maintained dependency list.
- Do not add broad `core.no_import_cycles` documentation or runner entries as a
  substitute for the targeted public API cycle proof.

### Deferred Broad Verification

Full schema v1 codec roundtrip, runtime behavior, interaction behavior,
resource resolver behavior, frame rendering, and Flutter surface behavior remain
owned by their later phase contracts. This step only hardens the public freeze
boundary and P2-owned public value behavior required before those phases.

## 5. Proof Plan

### P1. Public Error Projection Safety

```sh
dart test test/diagnostics/sanitizer_and_public_projection_test.dart
```

Expected signal: failing cases first prove raw mutable maps and unsupported
objects currently escape through `CanvasDataException.details`; passing cases
then prove sanitized, bounded, deeply-unmodifiable public data and neighboring
allowed scalar/list/map details.

### P2. Public Id Admission

```sh
dart test test/api_contract/id_validation_no_extension_type_escape_test.dart
```

Expected signal: failing cases first prove leading/trailing whitespace ids are
accepted or normalized today; passing cases then prove empty ids, whitespace
ids, control-character ids, over-limit ids, and valid canonical ids are handled
through public construction paths.

### P3. Public Contract Shape and Placeholder Policy

```sh
dart test test/api_contract/public_api_v1_compiles_as_written_test.dart
dart test test/api_contract/public_api_no_unapproved_placeholders_test.dart
dart test test/api/canvas_transform_test.dart
dart test test/runtime/runtime_state_publication_test.dart
```

Expected signal: consumer snippets compile against normative P2-owned
constructors, methods, getters, parameter defaults, and return types; exported
public API code has no unapproved placeholders; `CanvasTransform` behavior is
covered for rotation, TRS, multiplication, point/rect application, inversion,
matrix conversion, and JSON projection; `CanvasRuntime.state.value` is readable
after construction and returns P2 public snapshot DTOs while later runtime
ports remain deferred.

### P4. Public API Import-Cycle Fixture Proof

```sh
dart test test/guardrails/public_api_import_cycles_test.dart --name "fixture import-cycle detection"
```

Expected signal: cycle fixtures fail with stable diagnostics, acyclic fixtures
pass, relative and same-package imports resolve to repo-relative paths, and no
allowlist entry is accepted without reason/removal-condition structure.

### P5. Public API Import-Cycle Live Source and Metadata Seam Proof

```sh
dart test test/guardrails/public_api_import_cycles_test.dart --name "live source graph and metadata seam are clean"
```

Expected signal: the live `lib/src/api/**` import graph is acyclic, and no
public API file or schema v1 decoder imports document ownership only to access
`CanvasMetadata`, before the guardrail is registered as a blocking runner
entry.

### P6. Public API Import-Cycle Runner Proof

```sh
dart run tool/guardrails/run.dart --guardrail=api.no_public_api_import_cycles
```

Expected signal: the live `lib/src/api/**` import graph is acyclic and the
guardrail is selectable through the runner.

### P7. Guardrail Runner Inventory

```sh
dart test test/guardrails/blocking_suite_test.dart
```

Expected signal: `api.no_public_api_import_cycles`,
`api.exported_dartdoc_complete`, and `api.public_class_modifiers_explicit`
runner status matches source-of-truth documentation and suite membership.

### P8. P2 API Contract Proof

```sh
dart test test/api_contract/public_readable_union_variants_test.dart
dart test test/api_contract/preview_state_sealed_union_test.dart
dart test test/api_contract/canvas_field_update_static_semantics_test.dart
dart test test/api_contract/no_undefined_public_type_references_test.dart
dart test test/api_contract/no_legacy_public_symbols_test.dart
dart test test/api_contract/dto_immutability_test.dart
dart test test/api_contract/public_equality_policy_test.dart
dart test test/api_contract/app_next_engine_adapter_compile_fixture_test.dart
dart test test/runtime/runtime_state_publication_test.dart
```

Expected signal: P2 public API obligations for readable unions, preview sealed
state, field update static semantics, public type references, legacy bans, DTO
immutability, equality, runtime observation, and external app-adapter compile
are present and green.

### P9. P2 API and Codec Behavior Proof

```sh
dart test test/api/canvas_field_update_test.dart
dart test test/api/typed_action_payloads_test.dart
dart test test/codec/constructor_and_schema_limits_test.dart
dart run tool/guardrails/run.dart --suite=api
dart run tool/guardrails/run.dart --suite=codec
```

Expected signal: P2 field updates, typed actions, constructor/schema limits,
API guardrails, and codec known-field validation are present and green.

### P10. Final Repository Checks

```sh
dart analyze
dcm analyze .
dcm calculate-metrics .
dart run tool/guardrails/run.dart --suite=core
dart run docs/tool/check_docs.dart
```

Expected signal: analyzer, DCM, core guardrails, and documentation structure all
pass after the public freeze hardening changes.

## 6. Vertical Slices

### Slice 1. [x] Sanitize Public Error Details

#### Implements

D1

#### Obligations Covered

BUG_FIX, PUBLIC_API_CHANGE

#### Files

- Reproducer and behavioral proof: proposed
  `test/diagnostics/sanitizer_and_public_projection_test.dart` — create the
  diagnostics test area for the existing diagnostics contract and first add
  failing cases for mutable caller maps and unsupported object details, plus
  neighboring cases for accepted scalar, list, and nested map details.
- Primary public error owner: `lib/src/api/canvas_errors.dart` — replace the
  raw const public constructor with a public factory and private storage
  constructor that stores sanitized immutable details.
- Sanitizer owner: proposed
  `lib/src/api/canvas_error_details_sanitizer.dart` — own bounded public
  diagnostic detail projection for `CanvasDataException`.
- Public contract alignment: `docs/contracts/public_api_v1.md` — keep the
  documented factory/private-storage shape aligned with implementation.
- Diagnostics contract alignment: `docs/contracts/diagnostics.md` — keep
  public projection wording aligned with the sanitizer behavior.

#### Change

Make `CanvasDataException` the single boundary that sanitizes and deep-freezes
public `details`, preserving `code`, `message`, and `path` semantics while
preventing raw object leakage and caller mutation drift.

#### Proof

Run `P1`.

#### Closure

Slice closes when `CanvasDataException.details` cannot expose mutable caller
maps, application/runtime objects, or unbounded nested details through public
exception state.

### Slice 2. [x] Reject Non-Canonical Public Id Whitespace

#### Implements

D2

#### Obligations Covered

BUG_FIX, PUBLIC_API_CHANGE

#### Files

- Reproducer and behavioral proof:
  `test/api_contract/id_validation_no_extension_type_escape_test.dart` — first
  add failing cases for leading and trailing whitespace ids, plus neighboring
  cases for empty, control-character, over-limit, and valid canonical ids.
- Primary validation owner: `lib/src/api/canvas_value_validators.dart` — change
  id admission from trim-and-store to reject leading/trailing whitespace while
  preserving the accepted stored id exactly.
- Public id wrappers: `lib/src/api/canvas_ids.dart` — keep all public id
  constructors routed through the shared validator.
- Public contract alignment: `docs/contracts/public_api_v1.md` — record
  reject-not-trim id semantics.
- Validation contract alignment: `docs/contracts/validation_limits.md` — record
  reject-not-trim id boundary validation behavior.

#### Change

Public id construction rejects non-canonical whitespace instead of silently
normalizing ids to a different stored value.

#### Proof

Run `P2`.

#### Closure

Slice closes when public id constructors reject boundary-whitespace ids and all
accepted ids preserve their original value exactly.

### Slice 3. [x] Remove False Public Placeholder Readiness

#### Implements

D3, D6

#### Obligations Covered

BUG_FIX, PUBLIC_API_CHANGE

#### Files

- Reproducer and structural proof:
  `test/api_contract/public_api_no_unapproved_placeholders_test.dart` —
  proposed new test that first fails on current exported public
  `UnimplementedError` stubs and empty `CanvasSurface` placeholder behavior,
  plus neighboring cases for approved later-phase placeholders, private helpers,
  and ordinary implemented methods.
- Placeholder allowlist owner: proposed
  `tool/guardrails/src/public_api_placeholder_allowlist.dart` — list only
  later-phase exported placeholders with declaration id, owner phase, reason,
  and removal condition.
- P2 value behavior owner: `lib/src/api/canvas_geometry.dart` — implement
  exported `CanvasTransform` public value helpers owned by P2.
- Transform behavior proof: proposed `test/api/canvas_transform_test.dart` —
  cover rotation, TRS, multiplication, point/rect application, inversion,
  matrix conversion, JSON projection, and invalid non-finite or non-invertible
  construction.
- Runtime observation proof: proposed
  `test/runtime/runtime_state_publication_test.dart` — create the runtime test
  area for P2 observation proof and cover `CanvasRuntime.state.value`,
  `CanvasRuntimeState`, `CanvasRuntimeRevisions`, and `CanvasRuntimeSummary`
  readability after construction without requiring later edit/command/resource
  behavior.
- Runtime observation owner: `lib/src/api/canvas_runtime.dart` — implement
  `CanvasRuntime.state` enough to expose an initial public snapshot and keep
  snapshot DTO value semantics executable.
- Codec public seam: `lib/src/api/canvas_codec.dart` — keep
  `encodeCanvasDocument` and `encodeCanvasDocumentToJson` deferred and listed
  with P3 removal condition in the placeholder allowlist.
- Runtime public seam: `lib/src/api/canvas_runtime.dart` — keep later-phase
  runtime behavior placeholders deferred and listed with P4/P5/P7/P10/P11/P12
  owner phases in the placeholder allowlist by declaration, excluding
  `CanvasRuntime.state`, `CanvasRuntimeState`, `CanvasRuntimeRevisions`, and
  `CanvasRuntimeSummary`.
- Surface public seam: `lib/src/api/canvas_surface.dart` — keep surface
  rendering placeholder deferred and listed with P13 removal condition in the
  placeholder allowlist.

#### Change

P2-owned public value methods become working public behavior. Remaining
later-phase exported placeholders become explicit release-blocking tooling data
instead of invisible false readiness.

#### Proof

Run `P3`.

#### Closure

Slice closes when no exported public placeholder remains outside
`public_api_placeholder_allowlist.dart`, `CanvasRuntime.state.value` is readable
and not allowlisted, and `CanvasTransform` public value helpers are fully
covered by behavior tests.

### Slice 4. [x] Prove Public API Contract Shape As Written

#### Implements

D3, D5

#### Obligations Covered

BUG_FIX, PUBLIC_API_CHANGE

#### Files

- Reproducer and public consumer proof:
  `test/api_contract/public_api_v1_compiles_as_written_test.dart` — first add a
  failing signature-drift-sensitive consumer snippet for current name-only gaps,
  then instantiate and call P2-owned public constructors, factories, getters,
  methods, parameters, defaults, and return types from the v1 contract.
- Dartdoc and modifier check owner: proposed
  `tool/guardrails/src/public_api_declaration_checks.dart` — implement exported
  dartdoc summary and explicit public class modifier checks over the resolved
  public API surface.
- Guardrail registry: `tool/guardrails/src/guardrail_registry.dart` — register
  executable `api.exported_dartdoc_complete` and
  `api.public_class_modifiers_explicit`.
- Guardrail executor: `tool/guardrails/src/guardrail_executor.dart` — route the
  dartdoc and class-modifier guardrails to
  `public_api_declaration_checks.dart`.
- Runner inventory proof: `test/guardrails/blocking_suite_test.dart` — update
  expected API and blocking ids to match executable inventory.
- Tests source-of-truth: `docs/verification/tests.md` — align
  `public_api_v1_compiles_as_written_test.dart` wording with actual proof.
- Guardrail source-of-truth: `docs/verification/guardrails.md` — align dartdoc
  and public class modifier guardrail status with runner reality.
- Guardrail pattern map: `docs/verification/guardrail_design_patterns.md` —
  keep implementation pattern rows aligned with the selected executable form.
- P2 phase proof: `docs/implementation/p2_public_api_v1_freeze.md` — keep the
  phase's test and guardrail list aligned with executable proof.
- Release gate proof: `docs/verification/release_gates.md` — keep public API
  freeze release gates aligned with executable guardrails.
- Registry source-of-truth: `docs/_registry/sections.yaml` — update guardrail
  and test lists when executable status changes.
- Generated indexes: `docs/indexes/by_guardrail.md`,
  `docs/indexes/by_test_area.md`, and `docs/indexes/context_coverage.md` —
  update to reflect the executable dartdoc and class-modifier guardrails.

#### Change

The public API compile guardrail becomes a meaningful consumer proof for the
frozen P2 surface, and P2 documentation no longer claims unregistered guardrails
as executed checks.

#### Proof

Run `P3` and `P7`.

#### Closure

Slice closes when a signature-shape drift in a P2-owned public constructor,
method, getter, default, or return type would fail the public API consumer
proof, and guardrail documentation matches runner inventory.

### Slice 5. [x] Add Public API Import-Cycle Detector

#### Implements

D4

#### Obligations Covered

BUG_FIX

#### Files

- Guardrail implementation: proposed
  `tool/guardrails/src/public_api_import_cycle_checks.dart` — parse import
  directives, resolve relative and same-package public API imports, build the
  graph, run Tarjan SCC detection, and emit stable `GuardrailViolation`
  diagnostics for cycles.
- Guardrail fixture proof: proposed
  `test/guardrails/public_api_import_cycles_test.dart` — add fixture tests
  named `fixture import-cycle detection` that prove acyclic imports pass,
  relative and same-package imports resolve, cycle fixtures fail, and no
  allowlist entries are active.

#### Change

The import-cycle detector exists and is fixture-proven before it is used to
judge the live public API graph or registered in the runner.

#### Proof

Run `P4`.

#### Closure

Slice closes when the detector correctly recognizes acyclic and cyclic public
API import graphs in fixtures without relying on LSP, IDE state, or a manually
maintained dependency inventory.

### Slice 6. [x] Break Public API Ownership Cycles

#### Implements

D4

#### Obligations Covered

BUG_FIX, SEAM_MIGRATION, PUBLIC_API_CHANGE

#### Files

- Metadata owner: proposed `lib/src/api/canvas_metadata.dart` — own
  `CanvasMetadata` as a dedicated cross-cutting DTO value.
- Document consumer: `lib/src/api/canvas_document.dart` — import metadata from
  `canvas_metadata.dart` while retaining document ownership of document, layer,
  camera, background, grid, and palette values.
- Element consumer: `lib/src/api/canvas_element.dart` — import metadata from
  `canvas_metadata.dart` and transform admission from
  `canvas_transform_admission.dart`.
- Element update consumer: `lib/src/api/canvas_element_update.dart` — import
  metadata from `canvas_metadata.dart` instead of relying on document ownership
  for update payload metadata.
- Resource consumer: `lib/src/api/canvas_resource.dart` — import metadata from
  `canvas_metadata.dart` when metadata is needed.
- Codec consumer: `lib/src/codec/schema_v1_decoder.dart` — import and use
  `CanvasMetadata` from `../api/canvas_metadata.dart` after the metadata move
  instead of relying on document ownership for schema metadata materialization.
- Root public barrel: `lib/iwb_canvas_engine.dart` — export
  `src/api/canvas_metadata.dart` so root-barrel consumers still see
  `CanvasMetadata`.
- Public registry: `docs/_registry/public_api_v1.yaml` — keep
  `CanvasMetadata` present as the stable public type name.
- Transform admission owner: proposed
  `lib/src/api/canvas_transform_admission.dart` — own element transform
  admission validation without becoming part of the root public barrel.
- Primitive validation owner: `lib/src/api/canvas_value_validators.dart` —
  retain primitive/id/metadata validators and remove the geometry import.
- Geometry owner: `lib/src/api/canvas_geometry.dart` — own transform DTO
  construction validation using primitive validators without importing element
  or document owners.
- Live source proof:
  `test/guardrails/public_api_import_cycles_test.dart` — add test named
  `live source graph and metadata seam are clean` that applies the detector
  from Slice 5 to the live `lib/src/api/**` graph and rejects metadata-only
  imports of `canvas_document.dart` from public API files and
  `lib/src/codec/schema_v1_decoder.dart`.

#### Change

Public API DTO ownership becomes acyclic: metadata is no longer document-owned,
and primitive validation no longer depends upward on the transform DTO it helps
admit.

#### Proof

Run `P5`.

#### Closure

Slice closes when the current `canvas_document`/`canvas_element` metadata
cycle, the `canvas_document`/`canvas_element_update` metadata seam, and the
codec decoder metadata seam, and the `canvas_value_validators`/`canvas_geometry`
cycle are gone without changing root-barrel public semantics.

### Slice 7. [x] Register Public API Import-Cycle Guardrail

#### Implements

D4

#### Obligations Covered

BUG_FIX

#### Files

- Runner registry: `tool/guardrails/src/guardrail_registry.dart` — add
  `api.no_public_api_import_cycles` to the API and blocking suites.
- Runner executor: `tool/guardrails/src/guardrail_executor.dart` — route
  `api.no_public_api_import_cycles` to
  `public_api_import_cycle_checks.dart`.
- Runner inventory proof: `test/guardrails/blocking_suite_test.dart` — update
  expected API and blocking ids.
- Guardrail source-of-truth: `docs/verification/guardrails.md` — add
  `api.no_public_api_import_cycles` as a mandatory public API guardrail.
- Guardrail pattern map: `docs/verification/guardrail_design_patterns.md` —
  add the parsed-directive/Tarjan implementation pattern row.
- Registry source-of-truth: `docs/_registry/sections.yaml` — add the guardrail
  to the public API and guardrail sections that own P2 release proof.
- P2 phase proof: `docs/implementation/p2_public_api_v1_freeze.md` — list the
  new guardrail in P2 tests and exit gates.
- Tests source-of-truth: `docs/verification/tests.md` — map
  `test/guardrails/public_api_import_cycles_test.dart` to the new guardrail.
- Release gate proof: `docs/verification/release_gates.md` — include the new
  public API cycle guardrail in public freeze/release gate wording.
- Generated indexes: `docs/indexes/by_guardrail.md`,
  `docs/indexes/by_test_area.md`, and `docs/indexes/context_coverage.md` —
  update to reflect `api.no_public_api_import_cycles`.

#### Change

The fixture-proven and live-green detector becomes a mandatory, selectable API
guardrail in the blocking runner suite.

#### Proof

Run `P6` and `P7`.

#### Closure

Slice closes when `api.no_public_api_import_cycles` is selectable through the
runner, included in the API and blocking suites, passes the live public API
graph, and is documented in the owning source-of-truth files.

### Slice 8. [x] Preserve Full P2 Phase Proof

#### Implements

D5, D6

#### Obligations Covered

PUBLIC_API_CHANGE

#### Files

- P2 phase proof owner: `docs/implementation/p2_public_api_v1_freeze.md` —
  keep the listed tests, guardrails, and exit gate aligned with all executable
  proof required before freeze.
- Existing API contract tests:
  `test/api_contract/public_readable_union_variants_test.dart`,
  `test/api_contract/no_undefined_public_type_references_test.dart`,
  `test/api_contract/no_legacy_public_symbols_test.dart`,
  `test/api_contract/dto_immutability_test.dart`,
  `test/api_contract/public_equality_policy_test.dart`, and
  `test/api_contract/app_next_engine_adapter_compile_fixture_test.dart` —
  verify-only files that must remain green.
- Missing P2 API contract proof: proposed
  `test/api_contract/preview_state_sealed_union_test.dart` — create the phase
  proof named by P2 and cover sealed preview construction, concrete variant
  readability, and immutable collection behavior not already covered by
  `public_readable_union_variants_test.dart`.
- Missing P2 static field-update proof: proposed
  `test/api_contract/canvas_field_update_static_semantics_test.dart` — create
  the static analyzer proof for `CanvasFieldSet(null)` and clear-on-non-nullable
  misuse from the public contract.
- Runtime observation proof: proposed
  `test/runtime/runtime_state_publication_test.dart` — verify-only after Slice
  3 creates it; must remain green as part of P2 phase proof.
- API behavior test area: proposed `test/api/canvas_field_update_test.dart` —
  create the `test/api/` area and cover public `CanvasFieldUpdate` value
  behavior, equality, and valid construction.
- Typed action payload proof: proposed `test/api/typed_action_payloads_test.dart`
  — create the P2 public action payload proof named by the phase contract.
- Codec validation proof: `test/codec/constructor_and_schema_limits_test.dart`
  — verify-only file that must remain green for P2 validation and
  `codec.known_fields_validated` coverage.

#### Change

The new hardening proof creates missing P2 phase-proof files and keeps existing
P2 obligations green instead of narrowing or replacing the phase gate.

#### Proof

Run `P8` and `P9`.

#### Closure

Slice closes when all existing and newly created P2 phase tests and guardrail
suites are present and green after the hardening changes.

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
- all retired seams have negative proof;
- no out-of-scope files were changed;
- `PLAN.md` and this step file mark Step 22 complete only after implementation
  proof is green;
- whitespace validation passes.
