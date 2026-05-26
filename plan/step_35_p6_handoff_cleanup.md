# Change Contract

## Goal

Close the two remaining P6 handoff cleanup findings without changing public
runtime behavior or schema compatibility: make the `CanvasSurface.build`
placeholder guardrail structural instead of source-text dependent, remove the
misleading unused schema root-field registry, delete the now-empty handoff
file, and close the roadmap step when verification is complete.

## Evidence

- `P6_HANDOFF_FINDINGS.md` / remaining handoff scope: finding 3 names the raw
  substring `CanvasSurface.build` detector and finding 5 names the unused
  `canvasSchemaV1RootFields` constant -> the step is limited to these two P3
  cleanup findings, and the handoff file has no remaining durable purpose after
  they are closed.
- `.research/2026-05-26-p6-handoff-findings-closure.md` / factual research:
  current behavior maps the placeholder guardrail, schema contracts, and tests
  with exact references -> this step uses the research artifact as the evidence
  handoff for owner, boundary, and compatibility constraints.
- `test/api_contract/public_api_no_unapproved_placeholders_test.dart` / public
  placeholder guardrail: exported `UnimplementedError` placeholders are detected
  through analyzer AST, while `_surfacePlaceholders()` reads
  `canvas_surface.dart` and matches the exact
  `Widget build(BuildContext context) => const SizedBox.shrink();` text -> the
  surface placeholder detector must become analyzer-AST based.
- `lib/src/api/canvas_surface.dart` / surface placeholder implementation:
  `CanvasSurface` is public, but the current empty `build` is implemented in
  private `_CanvasSurfaceState` -> the structural proof must recognize the
  private `State<CanvasSurface>` build method and report the public declaration
  id `CanvasSurface.build`.
- `tool/guardrails/src/public_api_placeholder_allowlist.dart` / placeholder
  allowlist: `CanvasSurface.build` remains allowlisted with owner phase `P13`
  and a rendering removal condition -> this step must not implement the P13
  surface renderer or remove the allowlist entry while the placeholder remains.
- `docs/contracts/schema_v1.md` / schema compatibility contract: known schema v1
  fields are validated, unknown non-metadata fields are ignored on decode, and
  unknown non-metadata fields are not preserved by canonical encode -> this step
  must not convert unknown root fields into decode failures.
- `test/codec/schema_v1/known_fields_validation_test.dart` and
  `test/codec/constructor_and_schema_limits_test.dart` / executable schema
  compatibility: unknown root fields currently decode successfully -> this step
  must preserve that behavior.
- `lib/src/codec/schema_v1_validation.dart` / schema root validation:
  `canvasSchemaV1RootFields` is declared beside `validateSchemaV1Root()`, while
  root validation reads only `schemaVersion` -> the misleading constant should
  be retired rather than made into a new compatibility-affecting registry.
- `PLAN.md` / plan workflow: completed step contracts must update both the plan
  index and linked step document in the same change -> this step must include
  final roadmap checkbox closure after implementation verification passes.

## Boundaries

Owner:

The API contract test owns the structural placeholder detection proof. The
schema v1 validation file owns schema root version validation, but not a root
field registry. `P6_HANDOFF_FINDINGS.md` owns the temporary handoff list.

In Scope:

- Replace the `CanvasSurface.build` raw substring detector in
  `test/api_contract/public_api_no_unapproved_placeholders_test.dart` with an
  analyzer AST detector that recognizes the private `State<CanvasSurface>`
  `build` method returning `const SizedBox.shrink()` and reports
  `CanvasSurface.build`.
- Add focused detector coverage proving the surface placeholder detector is not
  tied to the exact current one-line source text and still participates in the
  allowlist exact-set behavior.
- Remove `canvasSchemaV1RootFields` from `lib/src/codec/schema_v1_validation.dart`
  without introducing a replacement schema root-field registry.
- Preserve schema v1 unknown-field behavior: unknown non-metadata fields remain
  ignored on decode and omitted on canonical encode.
- Delete `P6_HANDOFF_FINDINGS.md` after findings 3 and 5 are closed, because no
  remaining handoff findings remain.
- Mark Step 35 complete in `PLAN.md` and mark the execution-unit checkboxes in
  this step file complete after the implementation checks pass.

Out of Scope:

- Implementing `CanvasSurface` rendering, attachment, listeners, pointer
  routing, or any P13 surface behavior.
- Removing the `CanvasSurface.build` allowlist entry while the empty surface
  placeholder remains.
- Changing public codec entrypoints, schema version constants, schema JSON
  shape, canonical encode root keys, or unknown-field compatibility behavior.
- Creating a new schema root-field source of truth, generated schema registry,
  or broad codec refactor.
- Editing generated documentation, architecture graph YAML, diagrams, or phase
  contracts beyond the temporary handoff file.

Source of Truth:

- Public placeholder policy remains enforced by
  `test/api_contract/public_api_no_unapproved_placeholders_test.dart` and
  `tool/guardrails/src/public_api_placeholder_allowlist.dart`.
- Schema v1 compatibility remains defined by `docs/contracts/schema_v1.md`,
  `docs/contracts/codec_boundary.md`, and the existing schema v1 tests.
- `P6_HANDOFF_FINDINGS.md` is only the temporary input for this cleanup and is
  removed by this step after its two findings are closed.
- Roadmap closure state remains owned by `PLAN.md` and this linked step file.

Compatibility:

The implementation must preserve the public API placeholder allowlist semantics
and the schema v1 compatibility contract. Unknown root fields that are not
metadata must continue to decode without failure and must not be preserved by
canonical encode.

Order Constraints:

Replace and prove the structural surface detector before relying on it to close
finding 3. Retire the unused schema root-field constant only after confirming no
production or test consumer depends on it. Update `P6_HANDOFF_FINDINGS.md` only
by deleting it after both executable surfaces are repaired. Mark `PLAN.md` and
this step file complete only after all implementation verification commands
pass.

## Execution Units

### [ ] Unit 1: Structural CanvasSurface Placeholder Detection

Owner:

`test/api_contract/public_api_no_unapproved_placeholders_test.dart`

Boundary:

Only the public API placeholder guardrail test and its local detector helpers.

Change:

Replace `_surfacePlaceholders()` source-text matching with analyzer AST parsing
that identifies the private `State<CanvasSurface>` implementation and detects a
`build` method whose body returns `const SizedBox.shrink()`. Keep the reported
placeholder id as `CanvasSurface.build` so the existing allowlist entry remains
the exact public tracking id.

Completion Check:

`dart test test/api_contract/public_api_no_unapproved_placeholders_test.dart`
passes with focused detector coverage that constructs a source fixture where
the `CanvasSurface` state `build` method is structurally equivalent to the
current empty surface placeholder without matching the old exact one-line
substring.

Depends On:

None.

### [ ] Unit 2: Retire Misleading Schema Root Field Registry

Owner:

`lib/src/codec/schema_v1_validation.dart`

Boundary:

Only the schema v1 validation surface and schema v1 executable proofs needed to
show behavior is unchanged.

Change:

Remove `canvasSchemaV1RootFields` without adding a replacement root-field
registry or using root-field membership to reject unknown fields. Keep
`validateSchemaV1Root()` focused on the `schemaVersion` compatibility gate.

Completion Check:

`rg "canvasSchemaV1RootFields" lib test tool` returns no active code, test, or
tool references; `dart test test/codec/schema_v1 test/codec/constructor_and_schema_limits_test.dart`
passes, including the existing unknown-root-field decode cases.

Depends On:

None.

### [ ] Unit 3: Delete Retired P6 Handoff File

Owner:

`P6_HANDOFF_FINDINGS.md`

Boundary:

Only the temporary handoff file.

Change:

Delete `P6_HANDOFF_FINDINGS.md` after Units 1 and 2 are complete because the
file contains only the two findings closed by this step.

Completion Check:

`test ! -e P6_HANDOFF_FINDINGS.md` succeeds, and the final verification for the
step includes
`dart test test/api_contract/public_api_no_unapproved_placeholders_test.dart test/codec/schema_v1 test/codec/constructor_and_schema_limits_test.dart`.

Depends On:

Units 1 and 2.

### [ ] Unit 4: Close Roadmap Step State

Owner:

`PLAN.md` and `plan/step_35_p6_handoff_cleanup.md`

Boundary:

Only roadmap completion state for Step 35.

Change:

After Units 1-3 are implemented and all step verification commands pass, mark
Step 35 as complete in `PLAN.md` and mark each execution-unit checkbox in this
step file complete.

Completion Check:

`PLAN.md` lists Step 35 with `[x]`, this file marks Units 1-4 with `[x]`, and
the implementer's final report names the successful verification commands from
`Step Verification`.

Depends On:

Units 1, 2, and 3.

## Step Verification

Run from the repository root after implementation:

```bash
dart analyze
dcm analyze .
dcm calculate-metrics .
dart test test/api_contract/public_api_no_unapproved_placeholders_test.dart test/codec/schema_v1 test/codec/constructor_and_schema_limits_test.dart
```

Architecture graph checks are not part of this cleanup gate because the scoped
implementation removes an unconsumed schema root-field constant and does not
change graph-owned imports, sensitive throws, placeholders, documented
architecture edges, architecture documentation, generated graph views, or phase
closure state. If implementation expands into any graph-checkable architecture
surface, stop and update this contract before continuing.
