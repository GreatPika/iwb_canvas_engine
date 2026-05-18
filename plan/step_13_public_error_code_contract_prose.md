# Change Contract

Contract Mode: FULL
Contract Profile: DOCUMENTATION
Contract Obligations: BUG_FIX, PUBLIC_API_CHANGE

## 1. Mandate and Boundary

### Mandate

Close HOLE-007 by making public error-code prose in
`docs/contracts/public_api_v1.md` use only stable `CanvasDataErrorCode` enum
values.

### In Scope

- Correct the edit-contract prose for `CanvasEdit.addElement` error codes in
  `docs/contracts/public_api_v1.md`.
- Prove that the old shorthand codes `duplicateId` and `missingReference` are
  retired from active public API contract prose.

### Out of Scope

- Adding a Markdown-prose parsing test or guardrail for this rule.
- Changing the exported `CanvasDataErrorCode` enum values.
- Adding alias enum values for `duplicateId` or `missingReference`.
- Changing runtime, DTO, codec, edit-kernel, diagnostics, or resource behavior.
- Editing legacy package files.

## 2. Evidence Map

### Baseline Evidence

These facts describe repository state before execution. They are evidence for
the change, not target-state requirements.

- `docs/contracts/public_api_v1.md:73` states that Public API v1 declarations
  are normative and must compile against the documented names and semantics.
- `docs/contracts/public_api_v1.md:79` through
  `docs/contracts/public_api_v1.md:84` make
  `docs/_registry/public_api_v1.yaml` the exported-name inventory while keeping
  public semantics and declaration contracts in
  `docs/contracts/public_api_v1.md`.
- `docs/contracts/public_api_v1.md:1227` currently says `addElement with id
  collision throws CanvasDataException duplicateId`.
- `docs/contracts/public_api_v1.md:1228` currently says `addElement with
  missing resource reference throws CanvasDataException missingReference`.
- `docs/contracts/public_api_v1.md:2063` through
  `docs/contracts/public_api_v1.md:2084` declare the normative
  `CanvasDataErrorCode` enum.
- `docs/contracts/public_api_v1.md:2076` declares `duplicateElementId`;
  `docs/contracts/public_api_v1.md:2077` declares `duplicateLayerId`;
  `docs/contracts/public_api_v1.md:2078` declares `duplicateResourceId`;
  `docs/contracts/public_api_v1.md:2079` declares
  `missingResourceReference`.
- `docs/contracts/public_api_v1.md:2094` types `CanvasDataException.code` as
  `CanvasDataErrorCode`.

### Entry Paths

- The implementation entrypoint is the public API contract prose under
  `docs/contracts/public_api_v1.md`.
- The planning entrypoint is the root roadmap entry in `PLAN.md`, which links
  this step file.

### Current Owners

- `docs/contracts/public_api_v1.md` owns public API semantics, signature rules,
  and declaration contracts.
- `CanvasDataErrorCode` in `docs/contracts/public_api_v1.md` owns the stable
  public error-code names.

### Repository Rules

- Root `PLAN.md:5` through `PLAN.md:8` require every roadmap step to have a
  linked step document.
- Root `PLAN.md:18` through `PLAN.md:19` require the plan index and linked step
  document to be updated together when a step is completed.
- Documentation-only changes do not require Dart analyzer or DCM checks.
- Public API error codes are part of the compatibility promise because they are
  declared public enum values and exposed through `CanvasDataException.code`.

### Misleading Patterns

- The shorthand prose names `duplicateId` and `missingReference` look like
  friendly summaries, but they are not declared public enum values and cannot be
  treated as stable public codes.
- Adding `duplicateId` or `missingReference` to the enum would make invalid
  shorthand part of the public API instead of correcting the accepted contract.
- A Markdown-prose parsing test is intentionally not part of this step; the
  owner decision is to correct this contract prose without adding a text parser
  guardrail.

## 3. Architecture Decision

### Selected Form

Correct only the public API contract prose so the `CanvasEdit.addElement`
failure cases name the already-declared stable enum values:
`duplicateElementId` and `missingResourceReference`.

### Ownership

`docs/contracts/public_api_v1.md` remains the source of truth for public error
semantics and enum declarations. No new test, guardrail id, registry entry, or
dependency is introduced.

### Compatibility

This is a non-breaking public contract correction: no exported enum value is
removed or renamed, no alias is introduced, and the prose is aligned to the
already-declared public enum. No migration or versioning note is required
beyond the corrected contract text because the invalid shorthand values were not
declared API values.

### Rejected Alternatives

- Do not add `duplicateId` or `missingReference` to `CanvasDataErrorCode`; that
  would preserve an ambiguous API shape instead of using the already precise
  public enum values.
- Do not add a Markdown-prose parsing API-contract test for this correction.
- Do not implement this as a `docs/tool/check_docs.dart` rule; that tool is a
  structural documentation checker.
- Do not patch legacy package tests; the root package is the canonical target
  for the architecture rebuild.

## 4. Execution Guardrails

### Required Order

1. Correct the public API contract prose.
2. Run retired-term searches.
3. Run documentation structure validation.
4. Update `PLAN.md` and this step document completion checkboxes.

### Cross-Slice Constraints

- Keep `CanvasDataErrorCode` enum values unchanged unless a separate accepted
  contract explicitly changes the public API shape.
- Preserve the distinction between duplicate element, layer, and resource id
  codes.
- Do not add registry, verification, release-gate, or index entries for a
  Markdown-prose parsing guardrail.

### Seam Migration

No shared seam migration is in scope. The shorthand prose names are invalid
references, not accepted seam names with consumers to migrate. Retirement is
complete when active public API contract prose no longer contains
`CanvasDataException duplicateId` or `CanvasDataException missingReference`.

### Forbidden Moves

- Do not add alias enum values.
- Do not add a general Markdown linter or public-prose parser.
- Do not add new dependencies.
- Do not change public exports or `docs/_registry/public_api_v1.yaml`.
- Do not edit implementation docs, diagrams, runtime code, or legacy files.

## 5. Proof Plan

### P1. Retired shorthand terms are gone from public contract prose

This proves the invalid shorthand public error-code names are no longer present
in active public API contract prose.

```sh
! rg -n "CanvasDataException (duplicateId|missingReference)" docs/contracts/public_api_v1.md
```

Expected signal after prose correction: no matches.

### P2. Documentation structure remains valid

This proves documentation registries, navigation, diagram catalogs, and context
references remain structurally valid after contract edits.

```sh
dart run docs/tool/check_docs.dart
```

Expected signal: exits 0.

## 6. Vertical Slices

### Slice 1. [x] Align public API prose

#### Implements

This slice relies on the locked architecture without separate decision IDs.

#### Obligations Covered

BUG_FIX, PUBLIC_API_CHANGE

#### Files

- Primary public contract edit: `docs/contracts/public_api_v1.md` — replaces
  shorthand prose codes with exact public enum values.
- Export registry explicit non-edit: `docs/_registry/public_api_v1.yaml` —
  remains unchanged because the exported public names `CanvasDataException` and
  `CanvasDataErrorCode` are already the right registry granularity.

#### Change

Replace `CanvasDataException duplicateId` with
`CanvasDataException duplicateElementId`, and replace
`CanvasDataException missingReference` with
`CanvasDataException missingResourceReference`.

#### Proof

- Run P1 and confirm retired shorthand prose names are absent from the public
  API contract.

#### Closure

The slice is complete when public prose references only stable public enum
values for the affected `CanvasEdit.addElement` error cases.

### Slice 2. [x] Run documentation checks

#### Implements

This slice relies on the locked architecture without separate decision IDs.

#### Obligations Covered

BUG_FIX, PUBLIC_API_CHANGE

#### Files

- Verification-only command set: repository root — runs the final
  documentation proof commands without editing additional files.

#### Change

Run documentation checks after the prose correction. Do not add Dart test code,
dependencies, or lockfile changes for this documentation-only correction.

#### Proof

- Run P2.

#### Closure

The slice is complete when the documentation check has been run and its result
is recorded in the implementation report.

## 7. Final Gate

### Run Proof Set

- P1
- P2

### Done When

- the public API contract prose uses `duplicateElementId` and
  `missingResourceReference`;
- no active public API contract prose references `CanvasDataException
  duplicateId` or `CanvasDataException missingReference`;
- `CanvasDataErrorCode` exported values are not broadened with alias shorthand
  values;
- no Markdown-prose parsing test or guardrail is added;
- all referenced proof commands have been run and reported;
- all Contract Obligations are satisfied;
- no out-of-scope files are changed;
- whitespace validation passes.
