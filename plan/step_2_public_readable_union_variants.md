# Change Contract

If `4B. Architecture Decision Gate` is filled, stop after section 4.

## 1. Change Mandate

Close the public readable union gap by making the app-read `CanvasResourceSource`
and `CanvasDiagnosticPolicy` variants public, exported, test-proven, and no
longer tracked as open audit or redesign work.

## 2. Change Boundary

### Included in the Change

- Replace private concrete variants for `CanvasResourceSource.appKey` with the
  exported public `CanvasAppKeyResourceSource`.
- Replace private concrete variants for `CanvasDiagnosticPolicy.disabled`,
  `CanvasDiagnosticPolicy.summary`, and `CanvasDiagnosticPolicy.verbose` with
  exported public diagnostics policy variants.
- Preserve existing base factory entrypoints on `CanvasResourceSource` and
  `CanvasDiagnosticPolicy`.
- Preserve `CanvasDiagnosticPolicy.verbose` validation and public readable
  verbose limit fields.
- Add an executable external-consumer proof that imports only
  `package:iwb_canvas_engine/iwb_canvas_engine.dart` and reads the app key from
  a resolver-owned `CanvasImageResource`.
- Add an executable public diagnostics policy proof that imports only the public
  barrel and reads the public diagnostics variants and verbose limits.
- Update the public API contract, public export registry, related verification
  mappings, resource contract, and diagnostics contract to match the public
  readable variants.
- Update the resource-resolution diagrams that currently describe the
  app-facing appKey descriptor without naming the public readable source
  variant.
- After the proofs pass, remove the HOLE-001 entries from `audit.md` and remove
  the corresponding public-union redesign item from `redesign.md`.

### Not Included in the Change

- No resource source kind beyond `appKey`.
- No schema v1 JSON shape change for `"source": { "kind": "appKey" }`.
- No engine IO, asset-bundle, file, or network resource loading.
- No public diagnostics stream.
- No change to diagnostics sanitization, disabled hot-path allocation policy, or
  diagnostic record ownership.
- No rewrite of other sealed types such as `CanvasOptional`. If implementation
  evidence shows another sealed type belongs to the same app-read gap, stop and
  update this contract before changing that type.
- No implementation of P7 resource lifecycle behavior beyond API readability.

## 3. Surrounding Code Review

### Inspected Artifacts

- `audit.md` - records HOLE-001 as Red, requires a public API shape that lets an
  app resolver read the source key without importing `src/**`, and requires the
  `api.resource_source_app_key_publicly_readable` proof.
- `redesign.md` - proposes public concrete variants for app-read public unions
  and names `CanvasResourceSource.appKey` plus diagnostics policy as the
  examples to retire after implementation; its enum/getter examples are a
  proposal, not an already accepted contract.
- `docs/contracts/public_api_v1.md` - owns public API semantics, currently says
  factory target classes are private implementation details, currently defines
  `_CanvasAppKeyResourceSource`, `_CanvasDiagnosticDisabled`,
  `_CanvasDiagnosticSummary`, and `_CanvasDiagnosticVerbose`, and lists
  `CanvasResourceSource and its variants` plus `CanvasDiagnosticPolicy and its
  variants` under required value equality.
- `docs/_registry/public_api_v1.yaml` - is the machine-readable exported-name
  inventory and currently lists only the sealed base types, not their concrete
  public variants.
- `docs/architecture/02_package_boundaries.md` - defines `lib/iwb_canvas_engine.dart`
  as the only public barrel and `lib/src/api/**` as the only exported public API
  source area.
- `docs/contracts/resources.md` - owns resource lifecycle rules and appKey-only
  resource behavior, but does not yet state the public concrete source variant
  or resolver readability requirement.
- `docs/contracts/diagnostics.md` - owns diagnostics behavior, states
  `DiagnosticsHub` is internal, and requires verbose preview and list-entry
  limits to be validated at policy construction and runtime config
  materialization.
- `docs/contracts/validation_limits.md` - owns diagnostic verbose defaults and
  ranges: preview length default `256` in `[1, 4096]`, list entries default `32`
  in `[1, 128]`.
- `docs/implementation/p2_public_api_v1_freeze.md` - owns P2 public API freeze,
  including exported public classes, public equality, constructor validation,
  and `CanvasDiagnosticPolicy.verbose` limit checks.
- `docs/implementation/p3_schema_v1_dto_validation_and_codec_skeleton.md` -
  connects schema and diagnostics validation, including diagnostic verbose
  constructor and schema limit tests.
- `docs/implementation/p4_runtime_spine.md` - requires runtime config
  materialization to preserve already-validated verbose diagnostic limits.
- `docs/implementation/p7_resources_and_images.md` - depends on the frozen P2
  public resource API and the `CanvasResourceSource.appKey` only contract.
- `docs/contracts/schema_v1.md` - owns the JSON resource source discriminator
  shape and already requires `source.kind=appKey` plus `key`.
- `docs/diagrams/dfd_resource_resolution.mmd` - currently describes the appKey
  descriptor flow without naming the public app-facing source variant that the
  resolver must read.
- `docs/diagrams/seq_resource_resolution.mmd` - currently describes the
  resolver receiving a `CanvasImageResource appKey descriptor` without naming
  the public readable source variant.
- `docs/diagrams/state_resource_resolution.mmd` - currently describes the
  appKey descriptor available state and appKey facts without naming the public
  readable source variant.
- `docs/verification/tests.md`, `docs/indexes/by_test_area.md`,
  `docs/indexes/by_guardrail.md`, and `docs/_registry/sections.yaml` - own test,
  guardrail, and section mappings that must list any new public API proof.
- `PLAN.md` - is the active roadmap index and must link this step.
- `plan/step_1_package_skeleton_and_hard_boundaries.md` - confirms P0 creates
  `lib/src/api/**`, `lib/iwb_canvas_engine.dart`, and the guardrail runner
  before later API implementation steps.

### Current Entry Path

- Application code enters resource resolution through
  `CanvasResourceResolver.resolveImage(CanvasImageResource resource)` from the
  public barrel.
- Application code can read runtime configuration through
  `CanvasRuntimeConfig.diagnosticPolicy`.
- Package consumers import only `package:iwb_canvas_engine/iwb_canvas_engine.dart`.

### Current Owner

- Public API declaration shape is owned by `docs/contracts/public_api_v1.md`
  and implemented under `lib/src/api/**` after P0.
- Exported public names are owned by `docs/_registry/public_api_v1.yaml`.
- Resource lifecycle semantics are owned by `docs/contracts/resources.md`.
- Diagnostics behavior is owned by `docs/contracts/diagnostics.md`; the public
  policy shape remains owned by the public API contract.

### Adjacent Abstractions

- `CanvasResource`, `CanvasImageResource`, and `CanvasResourceResolver` are the
  adjacent public resource API abstractions.
- `CanvasRuntimeConfig` is the adjacent public config abstraction that carries
  `CanvasDiagnosticPolicy`.
- `CanvasMoveResolution`, `CanvasMoveCommit`, and `CanvasMoveCancel` are the
  closest existing public sealed union with public concrete variants in the
  public API contract.
- `CanvasOptional` is an adjacent sealed value type with private variants, but
  it is an update construction type, not the app resolver read boundary for
  this gap.

### Existing Tests

- Root `test/**` does not exist before P0.
- `docs/verification/tests.md` already names public API contract tests,
  resource appKey schema tests, diagnostics projection tests, and constructor
  limit tests that this change must integrate with.
- `audit.md` requires a new `api.resource_source_app_key_publicly_readable`
  executable proof.

### Analogous Implementation Path

- `CanvasMoveResolution` with public `CanvasMoveCommit` and `CanvasMoveCancel`
  is the nearest valid public sealed-union precedent because app code must
  return and may inspect the concrete outcomes.
- The external compile proof expected by
  `test.api_contract.public_api_v1_compiles_as_written` is the nearest proof
  style for public import-only API validation after P0 creates it.

### Governing Repository Rules

- `AGENTS.md` - documentation is written in English, user communication is in
  Russian, repository-specific knowledge must be updated in the repository
  source of truth, and code changes require `dart analyze`, `dcm analyze .`, and
  `dcm calculate-metrics .`.
- `docs/contracts/public_api_v1.md` - owns the public API declaration contract,
  public equality policy, class modifier policy, signature shape, and exported
  public names through the registry.
- `docs/architecture/02_package_boundaries.md` - the public barrel exports only
  `src/api/**`; application code must not import `src/**`.
- `docs/contracts/resources.md` - v1 supports appKey resource descriptors only,
  with no engine IO and synchronous app-owned resolution.
- `docs/contracts/diagnostics.md` - `DiagnosticsHub` stays internal and public
  diagnostics are projected only through `CanvasDataException` and test-only or
  internal sinks.

### Rejected Misleading Local Patterns

- Private factory target classes in `docs/contracts/public_api_v1.md` - valid
  only for intentionally opaque construction-only values, but wrong for app-read
  boundary values that carry payloads the app must inspect.
- `CanvasOptional` private variants - not evidence that app-read unions may hide
  payload variants, because update construction does not require resolver-style
  external state inspection.
- Schema v1 `source.kind` - remains the JSON discriminator and must not be
  mistaken for a required Dart public enum.
- `docs/diagrams/dfd_resource_resolution.mmd` wording around `source.kind` -
  describes descriptor semantics, not a mandate to add a Dart
  `CanvasResourceSourceKind` enum.
- Frame and schema diagrams that mention `appKey descriptor` or
  `source.kind = appKey` - describe unchanged frame facts or JSON
  discriminators and are not part of this change's required edit set.
- Internal `DiagnosticsHub` records - own diagnostic provenance and sanitization,
  not public policy variant readability.

## 4. Architecture

### 4A. Locked Architectural Form

#### Problem Ownership Level

- The gap is owned at the public API declaration and export boundary, not by
  ResourceKernel, DiagnosticsHub, runtime config materialization, or app-side
  resolver code.

#### Selected Architectural Form

- Keep the sealed base types and public base factories.
- Put each public concrete variant in the same API file as its sealed base type.
- Export the concrete variants through the public barrel by adding them to the
  public API registry.
- `CanvasResourceSource.appKey(String key)` returns
  `CanvasAppKeyResourceSource`.
- `CanvasDiagnosticPolicy.disabled()` returns `CanvasDiagnosticsDisabled`.
- `CanvasDiagnosticPolicy.summary()` returns `CanvasDiagnosticsSummary`.
- `CanvasDiagnosticPolicy.verbose(...)` returns `CanvasDiagnosticsVerbose`.
- `CanvasDiagnosticsVerbose` owns public readable `maxPreviewLength` and
  `maxListEntries` fields and validates the existing limits during construction.
- Do not add `CanvasResourceSourceKind` or `CanvasDiagnosticMode` in this step.
  Public concrete variants are the readable Dart API.

#### Owning Layer or Module

- `lib/src/api/canvas_resource.dart` owns `CanvasResourceSource`,
  `CanvasAppKeyResourceSource`, `CanvasResource`, `CanvasImageResource`, and
  `CanvasResourceResolver`.
- `lib/src/api/canvas_diagnostics.dart` owns `CanvasDiagnosticPolicy`,
  `CanvasDiagnosticsDisabled`, `CanvasDiagnosticsSummary`,
  and `CanvasDiagnosticsVerbose`.
- `lib/src/api/canvas_errors.dart` owns `CanvasDataException` and
  `CanvasDataErrorCode`; this step must not move error declarations into the
  diagnostics policy file.
- `lib/iwb_canvas_engine.dart` is the only public export boundary.

#### Dependency Direction

- Public API files may depend on validators and public value types in the API
  layer, but must not import resource, diagnostics, runtime, codec, frame,
  store, interaction, Flutter bridge, or legacy internals.
- Resource runtime code consumes public descriptors later; it must not own the
  public variant naming or add resolver-side casts that bypass the public
  contract.
- Diagnostics runtime code consumes the public policy later; it must not expose
  `DiagnosticsHub` records or provenance as public policy variants.
- Tests for external readability compile through the public package import only.

#### State and Data Ownership

- `CanvasAppKeyResourceSource.key` is the single public source of the app-owned
  resource key in Dart API descriptors.
- Schema v1 continues to own the JSON `source.kind=appKey` and `key` fields.
- `CanvasDiagnosticsVerbose.maxPreviewLength` and
  `CanvasDiagnosticsVerbose.maxListEntries` are the single public readable
  verbose policy limits.
- Diagnostic record source, severity, correlation id, and raw failure context
  remain internal to DiagnosticsHub.

#### Entry and Exit Boundaries

- Entry boundary: package consumers import `package:iwb_canvas_engine/iwb_canvas_engine.dart`.
- Resource read exit: app resolver can pattern match or type-test
  `resource.source` as `CanvasAppKeyResourceSource` and read `key`.
- Diagnostics read exit: app code can pattern match or type-test
  `CanvasRuntimeConfig.diagnosticPolicy` as one of the exported diagnostics
  policy variants and read verbose limits when applicable.
- Exit boundary: no external proof imports `package:iwb_canvas_engine/src/**`.

#### Permitted Extension Seam

- Future readable public union variants may be added as public final classes in
  the same API file as their sealed base, then added to
  `docs/_registry/public_api_v1.yaml` and covered by public import-only tests.
- Future resource source kinds require a separate contract because they change
  schema, resource lifecycle, codec, and resolver behavior.
- Future diagnostics modes require a separate contract because they change
  DiagnosticsHub behavior and public policy semantics.

#### Rejected Alternatives

- Keep private variants and add an app-side helper or cast - rejected because it
  keeps the readable payload outside the public type system.
- Add only a discriminator enum and generic accessor - rejected because it adds
  duplicate state and a weaker payload contract than public concrete variants.
- Add `CanvasResourceSourceKind` and `CanvasDiagnosticMode` now - rejected
  because the sealed public variants are sufficient and keep the public API
  smaller; the enum/getter portion of `redesign.md` item 1 is deliberately
  replaced by this contract's public-concrete-variant form.
- Fix only `CanvasResourceSource` - rejected because the redesign item being
  retired also names diagnostics policy as a public readable union case.
- Move the key read into ResourceKernel - rejected because the app resolver is
  the code that receives `CanvasImageResource` and must read the descriptor.
- Expose DiagnosticsHub records - rejected because diagnostics policy
  readability is separate from internal diagnostic record projection.

#### Why This Level Is Correct

- The failure is visible before runtime behavior: an external resolver cannot
  read the payload type from the public API contract.
- Fixing the public API owner solves the problem for every current and future
  resolver call site without resource-kernel glue.
- Keeping schema discriminators separate from Dart concrete variants avoids
  syncing duplicate Dart state with JSON state.

### 4B. Architecture Decision Gate

## 5. Locked Decisions

1. Public readable variants are concrete classes, not discriminator enums.
2. Base factory constructors remain available for existing construction style.
3. `CanvasDiagnosticsVerbose` keeps `maxPreviewLength` and `maxListEntries` as
   public readable fields.
4. Verbose diagnostics limits continue to be validated at policy construction
   and runtime config materialization.
5. Public value equality applies to the new concrete variants according to the
   existing public equality policy.
6. The schema v1 JSON `source.kind` discriminator remains unchanged.
7. Audit and redesign cleanup happens only after the public import-only proofs
   pass.

## 6. Result Requirements

1. External resolver code can read an app key from `CanvasImageResource.source`
   without importing `src/**`.
2. External config-inspection code can read which diagnostics policy variant is
   present and can read verbose limits when the variant is verbose.
3. The public barrel exports the new concrete variants and no implementation
   uses private concrete variants for the two in-scope app-read unions.
4. Public equality treats independently-created equivalent in-scope variants as
   equal with matching hash codes.
5. Existing diagnostics verbose limit acceptance and rejection behavior remains
   unchanged.
6. The resource schema continues to accept only `appKey` source descriptors in
   v1.
7. `audit.md` and `redesign.md` no longer contain the retired HOLE-001 or
   public-readable-union tracking item after proof passes.

## 7. Execution Order and Gates

### Required Order

- Complete Step 1 first so `lib/src/api/**`, `lib/iwb_canvas_engine.dart`, and
  the guardrail runner exist.
- Add the external public-readability reproducer and diagnostics guard tests
  before changing API implementation.
- Update `docs/contracts/public_api_v1.md` and `docs/_registry/public_api_v1.yaml`
  before implementing the exported concrete variants.
- Implement the minimum public API owner changes under `lib/src/api/**` and the
  public barrel.
- Create or update value equality and constructor-limit proofs in the proof
  files owned by this step.
- Update resource, diagnostics, verification, and index mappings after the
  public API shape is locked.
- Remove HOLE-001 and redesign item 1 only after targeted tests pass.

### Successor Seam and Retirement Gates

- Successor seam: public concrete variants exported by
  `package:iwb_canvas_engine/iwb_canvas_engine.dart`.
- Retire `_CanvasAppKeyResourceSource`, `_CanvasDiagnosticDisabled`,
  `_CanvasDiagnosticSummary`, and `_CanvasDiagnosticVerbose` only when their
  public replacements are exported, value-equality tested, and import-only
  consumer tests pass.
- Retire `audit.md` HOLE-001 references only when
  `api.resource_source_app_key_publicly_readable` passes and no resolver proof
  imports `src/**`.
- Retire `redesign.md` item 1 only when both resource source and diagnostics
  policy public variant proofs pass.

### Deferred Broad Verification

- Full `dart analyze`, `dcm analyze .`, and `dcm calculate-metrics .` are final
  code-change gates, not required for the initial failing reproducer slice.
- Full guardrail suite is reserved for the final gate; targeted API and docs
  checks run earlier.

## 8. File Map

### Implementation Files

- `lib/src/api/canvas_resource.dart`
- `lib/src/api/canvas_errors.dart`
- `lib/src/api/canvas_diagnostics.dart`
- `lib/iwb_canvas_engine.dart`

### Test Files

- `test/api_contract/public_readable_union_variants_test.dart` - create in this
  step for public import-only resource and diagnostics readability.
- `test/api_contract/public_api_v1_compiles_as_written_test.dart` - create in
  this step to prove the updated public API declarations compile as written.
- `test/api_contract/public_equality_policy_test.dart` - create in this step to
  prove value equality for the new public concrete variants.
- `test/codec/constructor_and_schema_limits_test.dart` - create in this step to
  prove diagnostics verbose limit acceptance and rejection still match the
  validation-limits contract.

### Fixtures and Supporting Data

- Temporary external consumer package sources owned inside
  `test/api_contract/public_readable_union_variants_test.dart`.

### Diagram Files

- `docs/diagrams/dfd_resource_resolution.mmd` - update the app resolver edge and
  appKey descriptor node so the app-facing descriptor explicitly exposes
  `CanvasAppKeyResourceSource.key` through public API.
- `docs/diagrams/seq_resource_resolution.mmd` - update the resolver call and/or
  note so `resolveImage` receives a `CanvasImageResource` whose source is
  publicly readable as `CanvasAppKeyResourceSource`.
- `docs/diagrams/state_resource_resolution.mmd` - update the appKey descriptor
  state note so the readable app-owned identity is
  `CanvasAppKeyResourceSource.key`.

### Registry, Inventory, and Workflow Files

- `PLAN.md`
- `plan/step_2_public_readable_union_variants.md`
- `docs/_registry/public_api_v1.yaml`
- `docs/_registry/sections.yaml`
- `docs/contracts/public_api_v1.md`
- `docs/contracts/resources.md`
- `docs/contracts/diagnostics.md`
- `docs/verification/tests.md`
- `docs/indexes/by_test_area.md`
- `docs/indexes/by_guardrail.md`
- `docs/implementation/p2_public_api_v1_freeze.md`
- `docs/implementation/p3_schema_v1_dto_validation_and_codec_skeleton.md`
- `docs/implementation/p4_runtime_spine.md`
- `docs/implementation/p7_resources_and_images.md`
- `audit.md`
- `redesign.md`

### Analysis Area

- None.

### Verification Entrypoints Not Edited

- `tool/guardrails/run.dart` - created by Step 1 and invoked by this step only as
  a verification command.

## 9. Implementation Rules

### Protected Invariants

- Public package consumers must not import `src/**`.
- Public app-read union payloads must be readable through exported public
  concrete variants.
- `CanvasResourceSource` remains appKey-only in v1.
- DiagnosticsHub remains internal.
- Diagnostic verbose limits keep the existing defaults and ranges.
- Public API value equality stays aligned with `docs/contracts/public_api_v1.md`.

### Required Proof

- behavioral proof: an external consumer resolver imports only the public barrel,
  receives `CanvasImageResource`, reads `CanvasAppKeyResourceSource.key`, and
  compiles.
- behavioral proof: an external consumer imports only the public barrel, reads
  diagnostics policy variants, reads verbose limits, and observes existing
  verbose limit validation.
- structural proof: public export registry includes the concrete variants and
  the public barrel exports them.
- structural proof: the in-scope base factory targets are public concrete
  classes and no `_CanvasAppKeyResourceSource` or `_CanvasDiagnostic*` private
  variant remains in `lib/src/api/**`.
- structural proof: `rg -n "_CanvasAppKeyResourceSource|_CanvasDiagnostic(Disabled|Summary|Verbose)" lib/src/api docs/contracts/public_api_v1.md`
  returns no matches after the owner fix.
- for bug fixes, regressions, false positives, false negatives, and
  invariant-enforcement gaps: one failing reproducer first, plus 1 to 3 guard
  tests for neighboring branches of the same contract.

### Allowed Change Surface

- Public API declarations for resource sources and diagnostics policy.
- Public export registry entries for the new concrete variant names.
- Public API contract wording that currently allows private factory targets for
  app-read unions.
- Test and verification mapping updates needed to make the new proof visible.
- Audit and redesign retirement edits after proof passes.

### Forbidden Moves

- Do not add app resolver imports of `package:iwb_canvas_engine/src/**`.
- Do not add resource or diagnostics runtime glue to compensate for an unreadable
  public API shape.
- Do not add `CanvasResourceSourceKind` or `CanvasDiagnosticMode` in this step.
- Do not change schema v1 resource JSON.
- Do not expose DiagnosticsHub records, diagnostic sources, or raw failure
  context.
- Do not rewrite unrelated sealed unions.

### Optional: Recognition Forms That Must Be Supported

- `if (source case CanvasAppKeyResourceSource(:final key)) { ... }`
- `if (source is CanvasAppKeyResourceSource) { source.key; }`
- `if (policy case CanvasDiagnosticsVerbose(:final maxPreviewLength, :final maxListEntries)) { ... }`
- `if (policy is CanvasDiagnosticsDisabled) { ... }`
- `if (policy is CanvasDiagnosticsSummary) { ... }`

### Optional: Allowed Forms That Are Not Violations

- Keeping base factories as the preferred construction spelling.
- Keeping private constructors behind validating public factories when needed for
  invariant enforcement, as long as external code can construct through the
  public class or base factory and read the public variant fields.

### Optional: Resolution Rules

- Public variant names are stable exported API names once added to
  `docs/_registry/public_api_v1.yaml`.
- If implementation discovers an existing Step 1 compile-fixture helper, the new
  test may use it without creating a second helper.

## 10. Vertical Slices

### Slice 1. [ ] Public Readability Reproducer

#### Slice Contract

Add the failing external-consumer proofs before changing implementation.

#### Change

- Add `test/api_contract/public_readable_union_variants_test.dart`.
- Add or extend the verification mappings for
  `api.resource_source_app_key_publicly_readable` and diagnostics public variant
  readability.

#### Behavioral Verification

- `dart test test/api_contract/public_readable_union_variants_test.dart`
  initially fails against the private variant API because external code cannot
  name and read the in-scope concrete variants.

#### Structural Verification

- The same test inspects or compiles through only
  `package:iwb_canvas_engine/iwb_canvas_engine.dart` and fails if the fixture
  imports `src/**`.

#### Fixtures Used

- Test-owned temporary external consumer package sources.

#### Positive Scenarios

- External resolver reads `CanvasAppKeyResourceSource.key`.
- External config reader identifies disabled, summary, and verbose diagnostics
  policy variants.
- External config reader reads verbose diagnostic limits.

#### Negative Scenarios

- External fixture imports `package:iwb_canvas_engine/src/**`.
- In-scope base factories target private concrete variant names.

#### Closure Evidence

- Failing test output is captured before implementation changes.

### Slice 2. [ ] Public Variant API Owner Fix

#### Slice Contract

Make the in-scope app-read variants public at the API owner and prove they are
exported, readable, validated, and value-equal.

#### Change

- Replace private resource and diagnostics policy variant declarations with the
  public concrete variants locked in section 4.
- Update the base factories to return those public variants.
- Add the public variant names to `docs/_registry/public_api_v1.yaml`.
- Update `docs/contracts/public_api_v1.md`, `docs/contracts/resources.md`,
  `docs/contracts/diagnostics.md`, and implementation phase references.
- Update `docs/diagrams/dfd_resource_resolution.mmd`,
  `docs/diagrams/seq_resource_resolution.mmd`, and
  `docs/diagrams/state_resource_resolution.mmd` so app-facing appKey descriptor
  wording names the public readable source variant.
- Create the public API compile, equality, and diagnostics verbose limit proof
  files listed in section 8.

#### Behavioral Verification

- `dart test test/api_contract/public_readable_union_variants_test.dart`
- `dart test test/api_contract/public_equality_policy_test.dart`
- `dart test test/codec/constructor_and_schema_limits_test.dart`

#### Structural Verification

- `dart test test/api_contract/public_api_v1_compiles_as_written_test.dart`
- `dart run tool/guardrails/run.dart --suite=api`
- `rg -l "CanvasAppKeyResourceSource\\.key" docs/diagrams/dfd_resource_resolution.mmd docs/diagrams/seq_resource_resolution.mmd docs/diagrams/state_resource_resolution.mmd | wc -l`
  prints `3`.
- `rg -n "_CanvasAppKeyResourceSource|_CanvasDiagnostic(Disabled|Summary|Verbose)" lib/src/api docs/contracts/public_api_v1.md`
  returns no matches.

#### Fixtures Used

- Test-owned temporary external consumer package sources.

#### Positive Scenarios

- Base factories still construct valid values.
- Direct public variant construction works for appKey, disabled, summary, and
  verbose diagnostics policy.
- Resource-resolution diagrams name `CanvasAppKeyResourceSource.key` as the
  public readable app-owned identity at the app resolver boundary.
- Verbose defaults and boundary values are accepted.

#### Negative Scenarios

- Invalid verbose preview length and list-entry limits are rejected.
- Public API registry omits one of the new concrete variants.
- Resource-resolution diagrams keep describing an opaque appKey descriptor
  without the public readable source variant.

#### Closure Evidence

- Targeted API, equality, constructor-limit, and API guardrail checks pass.

### Slice 3. [ ] Audit And Redesign Retirement

#### Slice Contract

Remove stale tracking only after the public API proofs from Slice 2 pass.

#### Change

- Remove HOLE-001 from `audit.md` execution order, API freeze blockers,
  resources/surface lifecycle blockers, and detailed HOLE-001 section.
- Remove `redesign.md` item 1 for public union variants.
- Mark this plan step complete in `PLAN.md` and this file when the
  implementation is done.

#### Behavioral Verification

- `dart test test/api_contract/public_readable_union_variants_test.dart`

#### Structural Verification

- `rg -n "HOLE-001|CanvasResourceSource\\.appKey.*недоступен|Публичные union-типы" audit.md redesign.md` returns no matches.
- `dart run docs/tool/check_docs.dart`

#### Fixtures Used

- None.

#### Positive Scenarios

- Audit no longer lists the resolved resource-source readability gap.
- Redesign no longer carries the implemented public-readable-union note.

#### Negative Scenarios

- HOLE-001 remains in any `audit.md` checklist.
- Redesign item 1 remains after the public proofs pass.

#### Closure Evidence

- Targeted proof still passes after retirement edits and docs check passes.

## 11. Final Verification

- `dart test test/api_contract/public_readable_union_variants_test.dart`
- `dart test test/api_contract/public_api_v1_compiles_as_written_test.dart`
- `dart test test/api_contract/public_equality_policy_test.dart`
- `dart test test/codec/constructor_and_schema_limits_test.dart`
- `dart run tool/guardrails/run.dart --suite=api`
- `rg -l "CanvasAppKeyResourceSource\\.key" docs/diagrams/dfd_resource_resolution.mmd docs/diagrams/seq_resource_resolution.mmd docs/diagrams/state_resource_resolution.mmd | wc -l`
  prints `3`.
- `dart run docs/tool/check_docs.dart`
- `dart analyze`
- `dcm analyze .`
- `dcm calculate-metrics .`

## 12. Acceptance Criteria

- `CanvasAppKeyResourceSource`, `CanvasDiagnosticsDisabled`,
  `CanvasDiagnosticsSummary`, and `CanvasDiagnosticsVerbose` are exported public
  API names.
- External resolver code can read the app key through public API only.
- External config code can read diagnostics policy variants and verbose limits
  through public API only.
- Existing base factory construction remains available.
- Existing diagnostic verbose validation behavior is preserved.
- Existing schema v1 resource source JSON shape is preserved.
- Resource-resolution diagrams show the app resolver receives a descriptor whose
  source is publicly readable as `CanvasAppKeyResourceSource.key`.
- Public equality covers the new concrete variants.
- `audit.md` no longer tracks HOLE-001.
- `redesign.md` no longer contains the implemented public-union item.
