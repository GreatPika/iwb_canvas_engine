# Change Contract

Contract Mode: FULL
Contract Profile: SOURCE_OF_TRUTH_DOCS
Contract Obligations: BUG_FIX, SEAM_MIGRATION, PUBLIC_API_CHANGE

## 1. Mandate and Boundary

### Mandate

Make the operation matrix and edit contracts the active source of truth for
field-granular `CanvasEdit.updateElement` effects, complete the public
operation coverage tracked by HOLE-002, and retire the now-stale problem notes
from `redesign.md` and `audit.md`.

### In Scope

- Add a normative element update field-effect taxonomy for every common and
  family field declared by `CanvasElementUpdate` subclasses.
- Route `CanvasEdit.updateElement` matrix behavior through that taxonomy instead
  of the coarse `update visual only` and `update geometry/transform` rows.
- Complete operation matrix row or explicit alias-row coverage for the public
  operations named by HOLE-002.
- Separate public `CanvasRuntimeState` revision effects from internal revision
  facts where the matrix needs both.
- State no-op and rollback behavior for matrix rows and aliases.
- Update guardrail, test, index, and release-gate wording so the matrix remains
  mechanically checkable.
- Remove the operation-matrix field taxonomy problem section from `redesign.md`
  after the accepted contract owns it.
- Remove the HOLE-002 problem/checklist entries from `audit.md` after the active
  operation matrix and verification mappings close them.

### Out of Scope

- Runtime Dart implementation of an effect compiler.
- New exported public API signatures or schema v1 format changes.
- Reworking unrelated operation matrix rows that already have exact accepted
  effects.
- Resolving the separate non-invertible transform fallback redesign note.
- Running `dart analyze`, `dcm analyze .`, or `dcm calculate-metrics .`, because
  this step is documentation-only.

## 2. Evidence Map

### Baseline Evidence

These facts describe repository state before execution. They are evidence for
the change, not target-state requirements.

- `docs/contracts/operation_matrix.md:46` defines the current operation matrix
  columns as operation, touched state, revisions, spatial, projection, repaint,
  and events.
- `docs/contracts/operation_matrix.md:50` and
  `docs/contracts/operation_matrix.md:51` still model updates as coarse
  `update visual only` and `update geometry/transform` rows.
- `docs/contracts/operation_matrix.md:56`, `docs/contracts/operation_matrix.md:70`,
  and `docs/contracts/operation_matrix.md:71` already group selection, resource
  dirty, and interaction setting operations, while `audit.md:47` through
  `audit.md:57` still track several of those public operations as unchecked.
- `docs/contracts/operation_matrix.md:81` through
  `docs/contracts/operation_matrix.md:84` already cover text double-tap and
  guarded `commitTextEdit`; `audit.md:58` marks that topic complete.
- `docs/contracts/operation_matrix.md:106` says no-op operations publish no new
  public state snapshot, but the matrix rows do not yet carry an explicit
  per-row no-op behavior dimension.
- `docs/contracts/edit_kernel.md:123` through `docs/contracts/edit_kernel.md:150`
  define `TouchedSet`, `CommitCompiler`, typed `CommitPlan` effects, and the
  rule that generic global invalidation is forbidden except
  `documentReplaced`.
- `docs/contracts/public_api_v1.md:959` through
  `docs/contracts/public_api_v1.md:1148` declare the common and family
  `CanvasElementUpdate` fields that the taxonomy must cover.
- `docs/contracts/public_api_v1.md:1151` through
  `docs/contracts/public_api_v1.md:1164` define update semantics: kind mismatch
  throws before draft mutation, no-op returns false with no action, changed
  updates increment element revision, and changed updates invalidate only typed
  touched sets.
- `docs/contracts/public_api_v1.md:1175` through
  `docs/contracts/public_api_v1.md:1194` declare the edit operations including
  `updateElement`, `removeUnusedResource`, and `replaceDraftDocument`.
- `docs/contracts/public_api_v1.md:1294` through
  `docs/contracts/public_api_v1.md:1300` declare the selection operations named
  by HOLE-002.
- `docs/contracts/public_api_v1.md:1386` through
  `docs/contracts/public_api_v1.md:1395` declare the tool setting operations
  named by HOLE-002.
- `docs/contracts/public_api_v1.md:1446` through
  `docs/contracts/public_api_v1.md:1451` declare `markResourceDirty` and
  `markAllResourcesDirty`.
- `docs/architecture/03_data_model.md:119` through
  `docs/architecture/03_data_model.md:129` define internal revision families
  including document, structural, resource, resourceVisual, bounds,
  elementVisual, projection, and preview.
- `docs/architecture/03_data_model.md:132` through
  `docs/architecture/03_data_model.md:137` state that public runtime state
  exposes only stable public revision domains and keeps internal
  cache/projection revisions private.
- `docs/architecture/03_data_model.md:162` through
  `docs/architecture/03_data_model.md:175` define no-op publication behavior,
  preview cleanup no-op behavior, interaction revision behavior, and
  resourceVisual dirty-resource behavior.
- `docs/contracts/resources.md:126` through
  `docs/contracts/resources.md:134` define `removeUnusedResource` success and
  false-return behavior.
- `docs/contracts/resources.md:146` through
  `docs/contracts/resources.md:169` define dirty-resource and
  `markAllResourcesDirty` effects.
- `docs/contracts/load_document.md:105` through
  `docs/contracts/load_document.md:112` distinguish
  `CanvasEdit.replaceDraftDocument` from external `loadDocument`.
- `redesign.md:3` through `redesign.md:66` currently contain the field-effect
  taxonomy problem and proposal outside the active contracts.
- `audit.md:37` through `audit.md:72` currently contain the HOLE-002 problem
  statement and checklist.

### Entry Paths

- Documentation entry path: `PLAN.md` links this step file as the roadmap item.
- Contract entry paths: `docs/contracts/edit_kernel.md` owns the edit compiler
  and typed effect contract; `docs/contracts/operation_matrix.md` owns
  operation-level effect behavior.
- Public API entry path: `docs/contracts/public_api_v1.md` owns the public
  update DTO fields and public operation names that the operation matrix must
  cover.
- Verification entry path: `docs/verification/guardrails.md`,
  `docs/verification/tests.md`, `docs/indexes/by_guardrail.md`,
  `docs/indexes/by_test_area.md`, and `docs/verification/release_gates.md` own
  the executable matrix mapping.

### Current Owners

- `CommitCompiler` in the edit contract owns typed invalidation and repaint
  effect compilation.
- The operation matrix owns public operation-level rows and aliases.
- Public API v1 owns field names, update DTO shape, no-op contract, and public
  operation names.
- Resource, load, selection, and interaction contracts own subsystem facts that
  matrix rows must reference rather than redefine.
- `redesign.md` and `audit.md` are backlog/problem trackers, not the final owner
  for accepted contract behavior.

### Existing Checks

- `docs/verification/guardrails.md:162` defines `edit.operation_matrix_complete`
  as the guardrail requiring executable assertions for every operation matrix
  row.
- `docs/indexes/by_test_area.md:448` through `docs/indexes/by_test_area.md:453`
  map `test.edit.operation_matrix_effects` to
  `test/edit/operation_matrix_effects_test.dart`, section 13, and
  `edit.operation_matrix_complete`.
- `docs/verification/release_gates.md:183` requires operation matrix and exact
  touched invalidation tests to be green.
- No existing check was found that proves every field declared on
  `CanvasElementUpdate` subclasses has a field-effect taxonomy entry.

### Valid Precedents

- `docs/contracts/operation_matrix.md:84` already uses a conditional row for
  changed text commits: bounds and spatial effects depend on whether text layout
  bounds change.
- `docs/contracts/operation_matrix.md:56` already uses grouped public operation
  rows where operations share the same effect shape.
- `docs/contracts/operation_matrix.md:91` through
  `docs/contracts/operation_matrix.md:123` already use notes to define shared
  row semantics such as atomic state publication, no-op publication, and text
  request behavior.
- `docs/contracts/cache_policy.md:42` through
  `docs/contracts/cache_policy.md:51` is a precedent for keeping document,
  paint-plan, image-resolve, selection, and spatial invalidation facts in
  owner-specific rows rather than one undifferentiated revision bucket.

### Repository Rules

- `PLAN.md` is the active roadmap and must link the step contract.
- New plan steps must be authored with the change-contract structure and later
  validated before implementation.
- After completing a plan step, both the root `PLAN.md` checkbox and linked step
  checkboxes must be updated in the same change.
- Documentation should be written in English unless the document explicitly
  specifies a different language.
- For documentation-only changes, do not run `dart analyze`, `dcm analyze .`,
  or `dcm calculate-metrics .`.

### Misleading Patterns

- `redesign.md` currently names `UpdateEffectCompiler`, but the active edit
  contract already names `CommitCompiler` as the compiler owner. The target
  design must not create a competing source of truth.
- The `redesign.md` example omits that changed persisted element fields also
  change committed document state and invalidate public document projection.
- Grouped rows in the current operation matrix look like coverage for HOLE-002,
  but `audit.md` still requires either explicit rows or explicit alias rows and
  per-row facts for no-op, rollback, resource, and revision effects.
- External `loadDocument` success/failure rows do not prove
  `CanvasEdit.replaceDraftDocument`, because the load contract states that
  `replaceDraftDocument` is an edit-session operation with different ordering.

## 3. Architecture Decision

### Selected Form

Create a documentation-only taxonomy under the edit contract named
`Element update field-effect taxonomy`. The taxonomy is the accepted contract
for converting a changed `CanvasElementUpdate` field into typed effects. The
operation matrix keeps one `CanvasEdit.updateElement` row that points to the
taxonomy for field-specific effects instead of duplicating every field in the
operation table.

The taxonomy must cover every common field and every concrete family field from
`CanvasElementUpdate` subclasses. Field entries must use class-qualified field
tokens such as `CanvasElementUpdate.transform` and
`CanvasTextElementUpdate.fontSize`. If a row intentionally groups inseparable
fields, the group heading or body must still include every class-qualified field
token covered by that group. For each field or inseparable field group, it must
state:

- public `state.revisions.document` effect for changed persisted document
  fields;
- internal revision effects, including structural, bounds, element visual,
  resource, projection, background, grid, and document replacement only where
  applicable;
- spatial effect;
- projection effect;
- resource validation or resource descriptor effect;
- repaint target;
- selection normalization effect;
- no-op behavior.

The operation matrix must add explicit operation rows or alias rows for every
public operation named by HOLE-002. Matrix rows and aliases must expose these
dimensions in their own row text or a directly referenced row-detail table:

- touched state;
- public `CanvasRuntimeState` revision effects;
- internal revision effects;
- spatial effect;
- projection effect;
- resource effect;
- repaint target;
- user-action notification behavior;
- no-op behavior;
- rollback behavior.

The operation matrix must include a machine-checkable `Operation row details`
section. Each HOLE-002 operation must have a heading in the exact form
`#### <operationName>` under that section, even when the operation is an alias
of a grouped row. Each block must contain the exact labels `Touched state:`,
`Public state revisions:`, `Internal revisions:`, `Spatial effect:`,
`Projection effect:`, `Resource effect:`, `Repaint target:`,
`User-action notification:`, `No-op behavior:`, and `Rollback behavior:`.

### Ownership

`docs/contracts/edit_kernel.md` owns field-effect taxonomy and compiler
semantics because `CommitCompiler` already owns typed invalidation effects.
`docs/contracts/operation_matrix.md` owns operation-level row and alias
coverage. `docs/contracts/public_api_v1.md` owns only public field and operation
shape, plus any non-breaking wording needed to point update semantics at the
edit-kernel taxonomy.

### Seam

The successor seam is the edit contract boundary:
`CanvasElementUpdate` field diff -> `CommitCompiler` field-effect taxonomy ->
typed `CommitPlan` effects. The retired seam is the pair of coarse operation
matrix rows `update visual only` and `update geometry/transform` as the
accepted source of truth for update effects.

`UpdateEffectCompiler` may appear only as the name of an internal pure
subroutine inside the `CommitCompiler` contract. It must not become a competing
top-level source-of-truth owner separate from `CommitCompiler`.

### Dependency Direction

Public API docs define DTO field names and operation names. The edit contract
consumes those names to define field effects. The operation matrix consumes the
edit taxonomy for `CanvasEdit.updateElement` and subsystem contracts for
resource, load, selection, and interaction rows. Verification docs consume the
operation matrix and do not define behavior independently.

### State and Data Ownership

Changed persisted element fields are committed document changes unless the
taxonomy explicitly says the field is not persisted document state. Therefore
changed persisted element fields advance public document revision and invalidate
public document projection. Field-specific taxonomy controls additional effects:
bounds, element visual, spatial touched update, resource validation, resource
descriptor invalidation, repaint target, and selection normalization.

Selection normalization remains owned by the selection owner and must be
published atomically with document effects when an element update makes selected
ids ineligible. Resource descriptor mutation remains edit-owned; dirty-resource
visual invalidation remains resource-port-owned and does not become an element
update side effect unless a changed element field references a resource and
needs validation or repaint.

### Public API Compatibility

This is a non-breaking public contract clarification. The public API owner is
`docs/contracts/public_api_v1.md`, and this step may clarify
`CanvasEdit.updateElement` semantics, but it must not change exported
signatures, public type names, schema v1 shape, constructor parameters, or
compatibility promises outside the operation/effect behavior being documented.

No migration or versioning path is required because consumers keep the same API
surface. `docs/_registry/public_api_v1.yaml` must remain unchanged unless a
separate public signature change contract is opened.

### Entry and Exit Boundaries

The entry boundary is a public edit or runtime operation documented in the
operation matrix. For `CanvasEdit.updateElement`, validation and diffing happen
before draft mutation effects are accepted. The exit boundary is a typed effect
plan and operation matrix row that can be asserted by guardrail tests.

No-op operations exit without public state publication, repaint, spatial,
projection, resource, or event effects unless the operation row explicitly
documents a stateful no-op such as known request retirement. Rollback exits with
the rollback contract from `EditKernel`: no committed document, selection,
resource, spatial, projection, repaint, event, or public state publication
effects.

### Verification Strategy

Use source-of-truth documentation proofs, not production tests. The final proof
must show that active contracts contain the taxonomy and complete public
operation coverage, retired coarse update rows and stale problem notes are
absent, and guardrail/test/release-gate mapping names the expanded matrix
dimensions.

### Decision Ledger

| ID | Decision | Owner | Proof |
|---|---|---|---|
| D1 | Field-granular `updateElement` effects are owned by the edit contract taxonomy and consumed by the operation matrix. | `docs/contracts/edit_kernel.md`, `docs/contracts/operation_matrix.md` | P1 |
| D2 | HOLE-002 operations must be covered by explicit matrix rows or alias rows with no-op and rollback behavior. | `docs/contracts/operation_matrix.md` | P2 |
| D3 | The accepted source-of-truth migration retires the field taxonomy problem from `redesign.md` and HOLE-002 from `audit.md`. | `redesign.md`, `audit.md` | P3 |
| D4 | Verification docs must require executable operation matrix assertions for resource, no-op, and rollback dimensions in addition to the existing revision/spatial/projection/repaint/event dimensions. | verification docs and indexes | P4 |

### Rejected Alternatives

- Keep `update visual only` and `update geometry/transform` as the accepted
  operation matrix rows. Rejected because the public update DTO is
  field-granular and those rows cannot express `hitPadding`, `isSelectable`,
  `resourceId`, `metadata`, or text layout effects without hidden policy.
- Expand the operation matrix into one row per update field. Rejected because it
  duplicates compiler behavior in the operation table and makes field additions
  easy to update in one surface but not the other.
- Promote `redesign.md` to the long-term owner of field taxonomy. Rejected
  because accepted behavior belongs in active contracts and verification
  mappings, not a redesign backlog note.
- Treat grouped selection, interaction, and resource dirty rows as sufficient
  without explicit aliases. Rejected because HOLE-002 requires public operation
  coverage to be checkable by row or alias.

## 4. Execution Guardrails

### Required Order

1. Before editing active source-of-truth files, run P1, P2, P3, and P4 as the
   targeted failing semantic reproducer for this BUG_FIX obligation and record
   that they fail for the known missing taxonomy, missing per-operation detail,
   stale problem text, and narrow verification mapping. Run P5 and P6 as
   neighboring stability checks before and after edits; they should pass unless
   the workspace already contains unrelated documentation or registry drift.
2. Update the edit contract taxonomy before replacing operation matrix update
   rows, so the matrix can point at a locked owner.
3. Update operation matrix rows and aliases before verification mapping, so the
   guardrail wording describes the final matrix shape.
4. Update public API wording only as a non-breaking semantic clarification after
   the edit and matrix owners are locked.
5. Update verification docs and indexes after the matrix dimensions are final.
6. Remove the stale `redesign.md` and `audit.md` problem text only after the
   active source-of-truth docs and verification mapping contain the replacement
   facts.
7. Mark this step complete in `PLAN.md` and in this step file only after all
   proof in the final gate passes.

### Cross-Slice Constraints

- Do not introduce production Dart code in this step.
- Do not change public API signatures, exported names, or schema v1 JSON shape.
- Do not duplicate the full field taxonomy in both edit kernel and operation
  matrix.
- Do not let the taxonomy omit document/projection effects for changed persisted
  element fields.
- Do not leave stale checked or unchecked HOLE-002 items in `audit.md` after the
  active matrix and verification docs close the hole.
- Do not remove the non-invertible transform fallback note from `redesign.md`.

### Seam Migration

| Retired seam | Successor seam | Consumer migration order | Retirement gate |
|---|---|---|---|
| `update visual only` / `update geometry/transform` as accepted operation matrix update-effect policy | `Element update field-effect taxonomy` consumed by the `CanvasEdit.updateElement` matrix row | edit contract taxonomy first, operation matrix update row second, verification mapping third | P1 proves retired coarse rows are absent from operation matrix and successor taxonomy is present |
| `redesign.md` operation matrix field taxonomy problem note | active edit and operation matrix contracts | active contracts first, verification mapping second, cleanup third | P3 proves the retired redesign problem text is absent |
| `audit.md` HOLE-002 checklist | active operation matrix coverage plus guardrail/test mapping | operation matrix coverage first, verification mapping second, cleanup third | P3 proves HOLE-002 text is absent after P2 and P4 pass |

### Forbidden Moves

- Do not resolve HOLE-002 by only marking audit checkboxes while leaving missing
  matrix rows or aliases.
- Do not hide field-specific behavior in prose-only notes that cannot be found
  by targeted semantic search.
- Do not convert resource dirty behavior into a document revision effect.
- Do not convert selection-only operation behavior into a document revision or
  projection effect.
- Do not claim executable proof through future Dart tests that do not yet exist
  in the root package.

### Deferred Broad Verification

Repository-wide Dart and DCM checks are deferred because this is a
documentation-only source-of-truth step. Future production implementation of
the compiler and tests must run the standard Dart/DCM checks required for code
changes.

## 5. Proof Plan

### P1. Field Taxonomy Replaces Coarse Update Rows

This proves the active contracts contain the successor taxonomy and no longer
use the two coarse update rows as operation matrix policy.

```sh
bash -lc 'set -euo pipefail
! rg -n --fixed-strings "| update visual only |" docs/contracts/operation_matrix.md
! rg -n --fixed-strings "| update geometry/transform |" docs/contracts/operation_matrix.md
rg -n "Element update field-effect taxonomy" docs/contracts/edit_kernel.md
rg -n "CommitCompiler.*field-effect" docs/contracts/edit_kernel.md
rg -n "CanvasEdit\\.updateElement" docs/contracts/operation_matrix.md
rg -n "Element update field-effect taxonomy" docs/contracts/operation_matrix.md
taxonomy=docs/contracts/edit_kernel.md
while IFS= read -r token; do
  rg -n --fixed-strings "$token" "$taxonomy" >/dev/null || {
    echo "missing taxonomy field token: $token" >&2
    exit 1
  }
done <<'"'"'TOKENS'"'"'
CanvasElementUpdate.transform
CanvasElementUpdate.opacity
CanvasElementUpdate.hitPadding
CanvasElementUpdate.isVisible
CanvasElementUpdate.isSelectable
CanvasElementUpdate.isLocked
CanvasElementUpdate.isDeletable
CanvasElementUpdate.isTransformable
CanvasElementUpdate.metadata
CanvasImageElementUpdate.resourceId
CanvasImageElementUpdate.size
CanvasImageElementUpdate.naturalSize
CanvasPathElementUpdate.svgPathData
CanvasPathElementUpdate.fillColor
CanvasPathElementUpdate.strokeColor
CanvasPathElementUpdate.strokeWidth
CanvasPathElementUpdate.fillRule
CanvasTextElementUpdate.text
CanvasTextElementUpdate.fontSize
CanvasTextElementUpdate.color
CanvasTextElementUpdate.align
CanvasTextElementUpdate.textDirection
CanvasTextElementUpdate.isBold
CanvasTextElementUpdate.isItalic
CanvasTextElementUpdate.isUnderline
CanvasTextElementUpdate.fontFamily
CanvasTextElementUpdate.maxWidth
CanvasTextElementUpdate.lineHeight
CanvasStrokeElementUpdate.points
CanvasStrokeElementUpdate.thickness
CanvasStrokeElementUpdate.color
CanvasLineElementUpdate.start
CanvasLineElementUpdate.end
CanvasLineElementUpdate.thickness
CanvasLineElementUpdate.color
CanvasRectElementUpdate.size
CanvasRectElementUpdate.fillColor
CanvasRectElementUpdate.strokeColor
CanvasRectElementUpdate.strokeWidth
TOKENS
'
```

Expected signal: no coarse update rows remain in the operation matrix; the edit
contract owns the taxonomy; the matrix has a `CanvasEdit.updateElement` row; the
taxonomy names every common and family update field by class-qualified token.

### P2. HOLE-002 Public Operation Coverage

This proves every public operation named by HOLE-002 has an operation matrix row
or explicit alias and that the expanded effect dimensions are present.

```sh
bash -lc 'set -euo pipefail
matrix=docs/contracts/operation_matrix.md
rg -n "^### Operation row details$" "$matrix" >/dev/null
for term in removeUnusedResource replaceDraftDocument toggleSelection clearSelection selectAll setMode setDrawStyle setDrawTool setDrawColor setPointerPolicy markAllResourcesDirty; do
  block="$(
    awk -v heading="#### $term" '"'"'
      $0 == heading {found=1; next}
      found && /^#### / {exit}
      found {print}
    '"'"' "$matrix"
  )"
  if [ -z "$block" ]; then
    echo "missing operation detail block: $term" >&2
    exit 1
  fi
  for label in "Touched state:" "Public state revisions:" "Internal revisions:" "Spatial effect:" "Projection effect:" "Resource effect:" "Repaint target:" "User-action notification:" "No-op behavior:" "Rollback behavior:"; do
    printf "%s\n" "$block" | rg --fixed-strings "$label" >/dev/null || {
      echo "missing $label in operation detail block: $term" >&2
      exit 1
    }
  done
done
'
```

Expected signal: every named public operation is findable in the operation
matrix as a row-detail block, and every block carries all required effect
dimensions.

### P3. Retired Problem Text Removed

This proves the stale design and audit problem notes were removed after the
active contracts became the source of truth.

```sh
bash -lc 'set -euo pipefail
! rg -n "Operation matrix переводим на field-effect taxonomy|update visual only.*слишком грубые|UpdateEffectCompiler" redesign.md
! rg -n "HOLE-002|Operation matrix не покрывает все публичные операции|removeUnusedResource|replaceDraftDocument|markAllResourcesDirty" audit.md
rg -n "Non-invertible transform fallback" redesign.md
'
```

Expected signal: the operation-matrix field taxonomy problem is absent from
`redesign.md`; HOLE-002 is absent from `audit.md`; the unrelated
non-invertible transform redesign note remains.

### P4. Verification Mapping Covers Expanded Matrix Dimensions

This proves guardrail and test documentation require executable coverage for
the expanded matrix dimensions.

```sh
bash -lc 'set -euo pipefail
for file in docs/verification/guardrails.md docs/indexes/by_guardrail.md docs/verification/tests.md docs/indexes/by_test_area.md docs/verification/release_gates.md; do
  rg -n "test.edit.operation_matrix_effects|edit.operation_matrix_complete|operation matrix" "$file" >/dev/null
  rg -n "expanded operation matrix dimensions" "$file" >/dev/null || {
    echo "missing expanded operation matrix dimensions marker in $file" >&2
    exit 1
  }
  for term in "public state revisions" "internal revisions" "resource effects" "no-op behavior" "rollback behavior"; do
    rg -n "$term" "$file" >/dev/null || {
      echo "missing $term in $file" >&2
      exit 1
    }
  done
done
'
```

Expected signal: every verification owner names the expanded operation matrix
dimensions and keeps the operation matrix guardrail/test/release-gate mapping.

### P5. Documentation Structure And Whitespace

This proves repository documentation structure and whitespace remain valid.

```sh
bash -lc 'set -euo pipefail
dart run docs/tool/check_docs.dart
git diff --check
'
```

Expected signal: documentation checks pass and Git reports no whitespace errors.

### P6. Public API Registry Remains Signature-Stable

This proves the public API clarification did not become an exported signature or
registry change.

```sh
bash -lc 'set -euo pipefail
git diff --exit-code -- docs/_registry/public_api_v1.yaml
rg -n "CanvasElementUpdate" docs/contracts/public_api_v1.md
rg -n "bool updateElement\\(CanvasElementUpdate update\\)" docs/contracts/public_api_v1.md
'
```

Expected signal: the public API registry has no diff, and the existing
`CanvasElementUpdate` plus `updateElement` public signature remain present.

## 6. Vertical Slices

### Slice 1. [ ] Add Element Update Field Taxonomy

#### Implements

D1

#### Obligations Covered

BUG_FIX, SEAM_MIGRATION, PUBLIC_API_CHANGE

#### Files

- Primary contract edit: `docs/contracts/edit_kernel.md` — owns the
  `Element update field-effect taxonomy`, the `CommitCompiler` relationship,
  and field-level effect dimensions.
- Operation matrix alignment: `docs/contracts/operation_matrix.md` — replaces
  coarse update rows with the `CanvasEdit.updateElement` row that consumes the
  taxonomy.
- Public API alignment: `docs/contracts/public_api_v1.md` — clarifies
  `updateElement` effect semantics without changing public signatures.

#### Change

Add the taxonomy under the edit contract and cover all common and family update
fields. Replace operation matrix coarse update rows with a single
`CanvasEdit.updateElement` row that delegates field-specific effects to the
taxonomy while preserving operation-level no-op, rollback, repaint, projection,
spatial, resource, and event behavior.

#### Proof

Run P1 and P6.

#### Closure

The active contracts prove field-level update behavior without relying on
`redesign.md` or duplicated operation matrix field rows.

### Slice 2. [ ] Complete Public Operation Matrix Coverage

#### Implements

D2

#### Obligations Covered

BUG_FIX, PUBLIC_API_CHANGE

#### Files

- Primary matrix edit: `docs/contracts/operation_matrix.md` — owns explicit
  rows or alias rows for `removeUnusedResource`, `replaceDraftDocument`,
  `toggleSelection`, `clearSelection`, `selectAll`, `setMode`,
  `setDrawStyle`, `setDrawTool`, `setDrawColor`, `setPointerPolicy`, and
  `markAllResourcesDirty`.
- Resource contract evidence: `docs/contracts/resources.md` — verify-only owner
  for `removeUnusedResource`, dirty-resource, and `markAllResourcesDirty`
  semantics; edit only if matrix work exposes an existing contradiction.
- Load contract evidence: `docs/contracts/load_document.md` — verify-only owner
  for `replaceDraftDocument` semantics; edit only if matrix work exposes an
  existing contradiction.
- Runtime data-model evidence: `docs/architecture/03_data_model.md` —
  verify-only owner for public/internal revision meaning; edit only if matrix
  work exposes an existing contradiction.

#### Change

Add missing rows or explicit aliases and expand the matrix shape so every row or
alias states touched state, public revisions, internal revisions, spatial,
projection, resource, repaint, events, no-op, and rollback behavior.

#### Proof

Run P2.

#### Closure

HOLE-002 operation coverage is expressible from active matrix rows or aliases
without consulting the audit checklist.

### Slice 3. [ ] Update Verification Mapping

#### Implements

D4

#### Obligations Covered

BUG_FIX, PUBLIC_API_CHANGE

#### Files

- Guardrail wording: `docs/verification/guardrails.md` — updates
  `edit.operation_matrix_complete` to include expanded dimensions.
- Test catalog wording: `docs/verification/tests.md` — keeps
  `test.edit.operation_matrix_effects` aligned with the matrix contract.
- Guardrail index: `docs/indexes/by_guardrail.md` — mirrors guardrail wording
  and test mapping.
- Test-area index: `docs/indexes/by_test_area.md` — keeps the operation matrix
  test linked to section 13 and the guardrail.
- Release gate: `docs/verification/release_gates.md` — keeps final release
  proof tied to the expanded operation matrix.
- Section registry: `docs/_registry/sections.yaml` — update only if guardrail,
  test, diagram, or section references need to change.

#### Change

Update verification surfaces so executable operation matrix proof includes
resource, no-op, and rollback behavior in addition to revision, spatial,
projection, repaint, and event effects.

#### Proof

Run P4.

#### Closure

The verification map points future implementation tests at the complete matrix
contract instead of the old narrower dimensions.

### Slice 4. [ ] Retire Stale Redesign And Audit Notes

#### Implements

D3

#### Obligations Covered

BUG_FIX, SEAM_MIGRATION

#### Files

- Redesign cleanup: `redesign.md` — removes only the operation-matrix
  field-effect taxonomy problem/proposal after Slice 1 owns the accepted form.
- Audit cleanup: `audit.md` — removes the HOLE-002 top-level item and detailed
  problem/checklist after Slices 2 and 3 close the active contract and
  verification mapping.
- Step finalization: `PLAN.md` — marks Step 11 complete only after the final
  proof set passes.
- Step finalization: `plan/step_11_operation_matrix_field_effect_taxonomy.md`
  — marks completed slice checkboxes only when the corresponding slice proof
  has passed.

#### Change

Delete the stale problem text from design and audit surfaces instead of leaving
completed checklists or duplicate proposals. Preserve unrelated redesign and
audit topics.

#### Proof

Run P3 and P5.

#### Closure

The accepted behavior lives only in active contracts and verification surfaces;
the stale problem trackers no longer repeat the solved operation matrix issue.

## 7. Final Gate

### Run Proof Set

Run P1, P2, P3, P4, P5, and P6.

### Done When

- all referenced Decision Ledger decisions have passing proof;
- all Contract Obligations are satisfied;
- all retired seams have negative proof;
- no out-of-scope files were changed;
- `redesign.md` no longer contains the operation-matrix field taxonomy problem;
- `audit.md` no longer contains HOLE-002;
- `PLAN.md` and this step file mark completed work in the same change;
- whitespace validation passes.
