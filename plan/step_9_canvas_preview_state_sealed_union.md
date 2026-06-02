# Change Contract

Contract Mode: FULL
Contract Profile: SOURCE_OF_TRUTH_DOCS
Contract Obligations: BUG_FIX, SEAM_MIGRATION, PUBLIC_API_CHANGE

## 1. Mandate and Boundary

### Mandate

Make the normative preview-state API a public sealed union whose variants encode
only possible preview states, including an intermediate `CanvasStrokePreview`
owner for shared pencil and marker preview facts.

### In Scope

- Replace the documented nullable-bag `CanvasPreviewState` public contract with
  a sealed hierarchy.
- Keep `CanvasPreviewKind` values stable: `none`, `marquee`, `selectedMove`,
  `pencilStroke`, `markerStroke`, `pendingLineStart`, `linePreview`, and
  `eraser`.
- Export public-readable preview variants through the public API registry.
- Add source-of-truth verification mappings for the future executable proof that
  public preview variants are sealed, exported, and publicly readable.
- Align interaction and frame documentation so producers and consumers describe
  preview variants rather than cross-kind nullable fields.
- Retire accepted preview sealed-union notes from `redesign.md` and verify
  `audit.md` has no matching preview sealed-union block after the successor
  contract and verification mapping exist.
- Mark this plan step complete in `PLAN.md` and in this step document when the
  step is executed.

### Out of Scope

- No production Dart implementation under `lib/**`.
- No executable Dart test implementation under `test/**`.
- No `tool/**` scaffolding.
- No changes to `CanvasPreviewKind` enum values or spelling.
- No new `CanvasDrawTool`-discriminated generic stroke preview variant.
- No public selected-id, pointer-token, active-pointer, or interaction-session
  fields in preview variants.
- No change to committed document, selection, resource, cache, repaint, or
  action-event runtime behavior.

## 2. Evidence Map

### Baseline Evidence

- `docs/contracts/public_api_v1.md` currently documents
  `CanvasPreviewState` as one `final class` with required `kind` and nullable or
  optional facts for pointer/session ids, selected move, marquee, stroke, line,
  and eraser data.
- `docs/contracts/public_api_v1.md` currently documents `CanvasPreviewKind`
  values as `none`, `marquee`, `selectedMove`, `pencilStroke`, `markerStroke`,
  `pendingLineStart`, `linePreview`, and `eraser`.
- `docs/contracts/public_api_v1.md` says preview state is immutable, pointer
  preview updates create a small new snapshot or reuse the previous unchanged
  snapshot, pending line start is epoch-bound, successful `loadDocument` clears
  preview, failed `loadDocument` preserves preview, and selected move preview is
  main-scene preview.
- `docs/_registry/public_api_v1.yaml` currently lists only
  `CanvasPreviewState` and `CanvasPreviewKind` for preview public exports.
- `redesign.md` contains a preview sealed-union proposal, but its sketch uses
  kind names that do not match the current public enum for pending line and line
  preview, models stroke as one tool-discriminated shape, and includes selected
  ids on selected move preview.

### Entry Paths

- `CanvasRuntime.preview` in `docs/contracts/public_api_v1.md` is the public
  read entry for current preview details.
- `state.revisions.preview` in `CanvasRuntimeRevisions` is the public revision
  domain for preview changes.
- `docs/contracts/interaction_engine.md` routes pointer and line interactions
  into preview publication and defines the selected-move versus overlay repaint
  split.
- `docs/contracts/frame_rendering.md` captures preview state once for overlay
  frames and captures selected move delta for main frames.

### Current Owners

- `docs/contracts/public_api_v1.md` owns public preview API semantics,
  declaration shape, equality policy, and public signature rules.
- `docs/_registry/public_api_v1.yaml` owns the machine-readable exported-name
  inventory.
- Interaction documentation owns preview production, cleanup, and repaint
  routing.
- Frame and cache documentation own preview consumption and the exclusion of
  preview delta from ordinary paint-plan cache keys and values.

### Existing Checks

- `docs/verification/tests.md` already maps
  `test.interaction.preview_public_state` to preview-only publication and
  no-op cleanup silence.
- `docs/verification/guardrails.md` already maps
  `preview.selected_move_main_repaint` to selected move repaint ownership.
- `docs/verification/guardrails.md` already maps
  `frame.paint_plan_excludes_preview_delta` to PaintPlanCache exclusion of
  selected-move and preview deltas.
- No inspected source-of-truth document currently defines a dedicated
  `CanvasPreviewState` sealed-union public API proof.

### Valid Precedents

- `docs/contracts/public_api_v1.md` documents `CanvasResourceSource` and
  `CanvasDiagnosticPolicy` as public-readable sealed unions with exported
  concrete variants.
- `docs/contracts/public_api_v1.md` documents `CanvasFieldUpdate<T>` as a
  sealed public union that makes invalid nullable update states statically
  unrepresentable.
- `plan/step_2_public_readable_union_variants.md` is the precedent for moving
  public-readable concrete variants into the registry and verification mapping
  without production Dart implementation in that plan step.

### Repository Rules

- `PLAN.md` is the active roadmap and source of truth for planned work.
- Public API declarations must compile as written, use explicit Dart 3 subtype
  policy modifiers, avoid nullable async/container returns, and use the public
  registry as the exported-name inventory.
- Source-of-truth documentation changes must update related registries,
  indexes, guardrails, and verification mappings when they change public
  contract meaning.
- Documentation-only changes do not require `dart analyze`,
  `dcm analyze .`, or `dcm calculate-metrics .`.

### Misleading Patterns

- The current nullable-bag `CanvasPreviewState` shape is the defect source, not
  a compatibility pattern to preserve.
- The `redesign.md` sketch is target-direction evidence only; it is not
  authoritative for enum names, selected-id exposure, or stroke decomposition.
- Existing references to `selectedMoveDelta`, `marqueeRect`, or
  `strokePoints` in diagrams may be domain-language labels rather than public
  field names; implementation must update only references that describe the
  public API seam.
- `audit.md` currently contains preview wording for `interactive=false`; that
  is not the preview sealed-union audit block and must not be removed for this
  step.

## 3. Architecture Decision

### Selected Form

`CanvasPreviewState` becomes a sealed public base with factory constructors for
the public preview variants and a `CanvasPreviewKind get kind` discriminator for
stable enum compatibility. The exported concrete hierarchy is:

- `CanvasNoPreview extends CanvasPreviewState`;
- `CanvasMarqueePreview extends CanvasPreviewState`;
- `CanvasSelectedMovePreview extends CanvasPreviewState`;
- `CanvasStrokePreview extends CanvasPreviewState`;
- `CanvasPencilStrokePreview extends CanvasStrokePreview`;
- `CanvasMarkerStrokePreview extends CanvasStrokePreview`;
- `CanvasPendingLineStartPreview extends CanvasPreviewState`;
- `CanvasLinePreview extends CanvasPreviewState`;
- `CanvasEraserPreview extends CanvasPreviewState`.

`CanvasStrokePreview` is the intermediate public owner for shared stroke preview
facts: `points`, `color`, `thickness`, and `opacity`. It is not directly used as
the only concrete stroke variant; pencil and marker remain distinct concrete
variants so `kind` stays exact and no invalid `CanvasDrawTool.line` or
`CanvasDrawTool.eraser` stroke state is representable.

The public API contract must document these exact construction signatures:

```dart
sealed class CanvasPreviewState {
  const CanvasPreviewState();

  const factory CanvasPreviewState.none() = CanvasNoPreview;
  const factory CanvasPreviewState.marquee({
    required Rect rect,
  }) = CanvasMarqueePreview;
  const factory CanvasPreviewState.selectedMove({
    required Offset delta,
  }) = CanvasSelectedMovePreview;
  factory CanvasPreviewState.pencilStroke({
    required Iterable<Offset> points,
    required Color color,
    required double thickness,
    required double opacity,
  }) = CanvasPencilStrokePreview;
  factory CanvasPreviewState.markerStroke({
    required Iterable<Offset> points,
    required Color color,
    required double thickness,
    required double opacity,
  }) = CanvasMarkerStrokePreview;
  const factory CanvasPreviewState.pendingLineStart({
    required Offset start,
    required int timestampMs,
    required Color color,
    required double thickness,
  }) = CanvasPendingLineStartPreview;
  const factory CanvasPreviewState.linePreview({
    required Offset start,
    required Offset end,
    required Color color,
    required double thickness,
  }) = CanvasLinePreview;
  factory CanvasPreviewState.eraser({
    required Iterable<Offset> corridor,
    required double thickness,
  }) = CanvasEraserPreview;

  CanvasPreviewKind get kind;
}

final class CanvasNoPreview extends CanvasPreviewState {
  const CanvasNoPreview();

  @override
  CanvasPreviewKind get kind => CanvasPreviewKind.none;
}

final class CanvasMarqueePreview extends CanvasPreviewState {
  const CanvasMarqueePreview({required this.rect});
  final Rect rect;

  @override
  CanvasPreviewKind get kind => CanvasPreviewKind.marquee;
}

final class CanvasSelectedMovePreview extends CanvasPreviewState {
  const CanvasSelectedMovePreview({required this.delta});
  final Offset delta;

  @override
  CanvasPreviewKind get kind => CanvasPreviewKind.selectedMove;
}

sealed class CanvasStrokePreview extends CanvasPreviewState {
  const CanvasStrokePreview();
  List<Offset> get points;
  Color get color;
  double get thickness;
  double get opacity;
}

final class CanvasPencilStrokePreview extends CanvasStrokePreview {
  CanvasPencilStrokePreview({
    required Iterable<Offset> points,
    required this.color,
    required this.thickness,
    required this.opacity,
  }) : points = List.unmodifiable(points);

  @override
  final List<Offset> points;
  @override
  final Color color;
  @override
  final double thickness;
  @override
  final double opacity;

  @override
  CanvasPreviewKind get kind => CanvasPreviewKind.pencilStroke;
}

final class CanvasMarkerStrokePreview extends CanvasStrokePreview {
  CanvasMarkerStrokePreview({
    required Iterable<Offset> points,
    required this.color,
    required this.thickness,
    required this.opacity,
  }) : points = List.unmodifiable(points);

  @override
  final List<Offset> points;
  @override
  final Color color;
  @override
  final double thickness;
  @override
  final double opacity;

  @override
  CanvasPreviewKind get kind => CanvasPreviewKind.markerStroke;
}

final class CanvasPendingLineStartPreview extends CanvasPreviewState {
  const CanvasPendingLineStartPreview({
    required this.start,
    required this.timestampMs,
    required this.color,
    required this.thickness,
  });

  final Offset start;
  final int timestampMs;
  final Color color;
  final double thickness;

  @override
  CanvasPreviewKind get kind => CanvasPreviewKind.pendingLineStart;
}

final class CanvasLinePreview extends CanvasPreviewState {
  const CanvasLinePreview({
    required this.start,
    required this.end,
    required this.color,
    required this.thickness,
  });

  final Offset start;
  final Offset end;
  final Color color;
  final double thickness;

  @override
  CanvasPreviewKind get kind => CanvasPreviewKind.linePreview;
}

final class CanvasEraserPreview extends CanvasPreviewState {
  CanvasEraserPreview({
    required Iterable<Offset> corridor,
    required this.thickness,
  }) : corridor = List.unmodifiable(corridor);

  final List<Offset> corridor;
  final double thickness;

  @override
  CanvasPreviewKind get kind => CanvasPreviewKind.eraser;
}
```

No constructor has optional cross-kind preview fields or default payloads other
than the empty `CanvasNoPreview` marker.

`CanvasPreviewState` and every preview variant use Dart default identity
equality. They must remain in the default-identity equality list as
`CanvasPreviewState and preview family types`; no preview variant is added to
the required value-equality list.

### Ownership

The public API contract owns the variant names, constructor signatures, field
names, equality policy, and compatibility note. The public export registry owns
which variant names must be exported. Interaction remains the runtime owner of
preview state creation, replacement, and cleanup. Frame remains the consumer of
captured preview snapshots.

### Seam

The retired public seam is the single `CanvasPreviewState` constructor plus
cross-kind nullable fields. The successor public seam is type-based matching on
sealed `CanvasPreviewState` variants, with `CanvasPreviewKind` retained as a
read-only compatibility discriminator.

### Dependency Direction

Public API declarations and registry define the app-facing type surface.
Interaction documentation may reference and produce those public variants.
Frame documentation may consume those public variants. Selection-owned ids,
pointer tokens, active pointer ids, and interaction session ids do not flow into
the public preview variant payload.

### State and Data Ownership

Preview variant instances are immutable snapshots. Constructors that accept
caller-owned iterables must defensively copy them into unmodifiable lists.
Selected ids remain owned by selection state and frame capture. Pointer/session
facts remain owned by InteractionEngine. The selected move preview public
payload is only the delta needed for the main-scene supplement path.

### Entry and Exit Boundaries

Preview entry starts from normalized pointer, candidate, draw, line, and eraser
facts at the interaction boundary. Preview exit is `CanvasRuntime.preview`,
`state.revisions.preview`, frame capture, and repaint routing. Cleanup exits
through `CanvasNoPreview` and advances `state.revisions.preview` only when an
active preview changed.

### Verification Strategy

Verification is documentation-first: prove the public contract and registry name
the sealed hierarchy, prove retired nullable-bag seam text is absent from active
source-of-truth surfaces, prove verification mappings cover the new public API
shape, and run the documentation structural checker.

### Decision Ledger

| ID | Decision | Owner | Proof |
|---|---|---|---|
| D1 | `CanvasPreviewState` is a sealed public union with exported concrete variants and retained `kind`. | Public API contract | P2 |
| D2 | `CanvasPreviewKind` enum values keep current spelling. | Public API contract | P2 |
| D3 | `CanvasStrokePreview` is an intermediate public sealed owner for shared pencil/marker stroke preview getters. | Public API contract | P2 |
| D4 | Selected ids, pointer tokens, active pointer ids, and session ids are not public preview payload. | Public API contract, Interaction docs | P2 |
| D5 | Caller-owned preview iterables are copied into unmodifiable lists. | Public API contract | P2 |
| D6 | Selected move remains main-scene preview; all other preview variants remain overlay preview. | Interaction and Frame docs | P3 |
| D7 | Preview state and all preview variants use Dart default identity equality. | Public API contract | P2 |

### Rejected Alternatives

- Keep one nullable-bag class and add constructor validation. Rejected because
  consumers would still read nullable cross-kind fields and exhaustive matching
  would not be available.
- Use one concrete `CanvasStrokePreview` with `CanvasDrawTool tool`. Rejected
  because it admits invalid `line` and `eraser` tool values unless runtime
  checks reintroduce the invalid-state problem.
- Rename enum values to `stroke`, `pendingLine`, or `line`. Rejected because
  current source-of-truth already owns stable public enum names for pencil,
  marker, pending line start, and line preview.
- Add `selectedIds` to `CanvasSelectedMovePreview`. Rejected because selected
  ids are already owned by selection state and frame capture.
- Preserve public pointer/session ids on preview variants. Rejected because no
  inspected consumer requires them, and they leak Interaction-owned routing
  state into an app-facing preview-rendering snapshot.

## 4. Execution Guardrails

### Required Order

1. Run the BUG_FIX baseline reproducer before editing source-of-truth files:
   `rg -n "final class CanvasPreviewState|this\\.activePointerId|this\\.sessionId|this\\.marqueeRect|this\\.strokeColor|this\\.lineStart|this\\.eraserThickness" docs/contracts/public_api_v1.md redesign.md audit.md`.
2. Run the neighboring guard proof before the owner-side fix:
   `rg -n "test\\.interaction\\.preview_public_state|preview\\.selected_move_main_repaint|frame\\.paint_plan_excludes_preview_delta" docs/verification docs/indexes docs/_registry/sections.yaml`.
3. Update the public API contract and registry before changing downstream
   interaction, frame, verification, or cleanup documents.
4. Add verification and index mappings after the public API contract names the
   successor seam.
5. Align interaction and frame source-of-truth documents after D1-D6 are present
   in the public contract.
6. Remove accepted preview sealed-union notes from `redesign.md` and verify
   `audit.md` has no matching preview sealed-union block only after the
   successor seam and verification mappings exist.
7. Mark this step complete in `PLAN.md` and this step document only after every
   slice proof and the final gate pass.

### Cross-Slice Constraints

- Do not add production Dart files, executable tests, or tooling in this step.
- Do not remove unrelated preview lifecycle requirements, especially
  `interactive=false` preservation and cleanup semantics.
- Do not broaden public preview state with selection, pointer-token, active
  pointer, or session-owned fields.
- Do not add sync glue between preview variants and selection state.
- Preserve selected move repaint routing and PaintPlanCache preview-delta
  exclusion.

### Seam Migration

| Retired seam | Successor seam | Consumer migration order | Retirement gate |
|---|---|---|---|
| `CanvasPreviewState({required kind, ... nullable cross-kind fields ...})` and nullable getters such as `marqueeRect`, `strokeColor`, `lineStart`, and `eraserThickness`. | Sealed `CanvasPreviewState` variants and exported concrete classes, with `CanvasStrokePreview` as the common pencil/marker stroke base. | Public API contract and registry first; verification/index mappings second; interaction/frame docs third; audit/redesign cleanup last. | P2 and P4 prove the nullable-bag declaration, rejected redesign sketch, and matching audit block are absent from active source-of-truth surfaces. |

This is a breaking pre-freeze public-contract correction. Migration guidance is
pattern matching or type testing on concrete preview variants instead of reading
nullable fields from one shared class.

### Forbidden Moves

- Do not satisfy the public API proof by documenting private concrete variants.
- Do not replace type safety with runtime-only validation.
- Do not let `CanvasStrokePreview` become the only concrete stroke variant.
- Do not remove `CanvasPreviewKind`; it remains the stable public discriminator.
- Do not delete `audit.md` preview wording that belongs to `interactive=false`
  rather than sealed preview state.

### Deferred Broad Verification

Production Dart checks and executable tests are deferred until a later
implementation step creates `lib/**` and `test/**` artifacts. This step proves
the source-of-truth contract, registry, and documentation structure only.

## 5. Proof Plan

| ID | Purpose | Command or Check |
|---|---|---|
| P0 | Prove the BUG_FIX baseline and neighboring guard coverage before owner-side edits. | Run the Required Order baseline reproducer and neighboring guard proof before Slice 1 edits. |
| P1 | Prove documentation structure, registries, indexes, and catalog wiring are valid. | `dart run docs/tool/check_docs.dart` |
| P2 | Prove the public API contract names the sealed preview hierarchy, exact construction signatures, identity equality policy, immutable list copies, stable enum names, exported variants, and retired nullable-bag seam. | Targeted `rg`/`awk` checks over `docs/contracts/public_api_v1.md` and `docs/_registry/public_api_v1.yaml` for the locked public API shape and retired nullable-bag terms. |
| P3 | Prove interaction and frame source-of-truth documents preserve selected-move main repaint, overlay preview admission, and PaintPlanCache preview-delta exclusion while using variant terminology at the public preview seam. | Targeted `rg` checks over `docs/contracts/interaction_engine.md`, `docs/contracts/frame_rendering.md`, `docs/contracts/cache_policy.md`, and preview diagrams. |
| P4 | Prove accepted redesign/audit work items for this issue have been retired and no matching stale preview sealed-union block remains. | Targeted `rg` checks over `audit.md` and `redesign.md` for `CanvasPreviewState`, `CanvasStrokePreview`, `selectedIds`, `pendingLine`, `line`, and nullable preview-state issue wording. |

## 6. Vertical Slices

### Slice 1. [x] Public Preview Contract And Registry

#### Implements

D1, D2, D3, D4, D5, D7

#### Obligations Covered

BUG_FIX, SEAM_MIGRATION, PUBLIC_API_CHANGE

#### Files

- Update `docs/contracts/public_api_v1.md` as public preview API owner:
  replace the nullable-bag preview contract with the sealed hierarchy,
  concrete variant signatures, identity equality policy, and migration note.
- Update `docs/_registry/public_api_v1.yaml` as public export inventory:
  add every public preview variant and intermediate `CanvasStrokePreview`
  required by the successor seam.

#### Change

Replace the current preview-state section with the sealed union, concrete
variants, intermediate `CanvasStrokePreview`, variant payload rules, equality
policy, and migration note. Add every public preview variant name to the export
registry.

#### Proof

Prove the BUG_FIX preconditions with P0 before editing. Prove D1-D5, D7, exact
public signatures, equality policy, and the public registry with P2:

```sh
rg -n "sealed class CanvasPreviewState|CanvasNoPreview|CanvasMarqueePreview|CanvasSelectedMovePreview|sealed class CanvasStrokePreview|CanvasPencilStrokePreview|CanvasMarkerStrokePreview|CanvasPendingLineStartPreview|CanvasLinePreview|CanvasEraserPreview|CanvasPreviewKind" docs/contracts/public_api_v1.md docs/_registry/public_api_v1.yaml
rg -n "const factory CanvasPreviewState\\.none\\(\\) = CanvasNoPreview|const factory CanvasPreviewState\\.marquee|required Rect rect|const factory CanvasPreviewState\\.selectedMove|required Offset delta|factory CanvasPreviewState\\.pencilStroke|factory CanvasPreviewState\\.markerStroke|required Iterable<Offset> points|required Color color|required double thickness|required double opacity|const factory CanvasPreviewState\\.pendingLineStart|required int timestampMs|const factory CanvasPreviewState\\.linePreview|required Offset end|factory CanvasPreviewState\\.eraser|required Iterable<Offset> corridor|List\\.unmodifiable\\(points\\)|List\\.unmodifiable\\(corridor\\)" docs/contracts/public_api_v1.md
rg -n "  - CanvasNoPreview$|  - CanvasMarqueePreview$|  - CanvasSelectedMovePreview$|  - CanvasStrokePreview$|  - CanvasPencilStrokePreview$|  - CanvasMarkerStrokePreview$|  - CanvasPendingLineStartPreview$|  - CanvasLinePreview$|  - CanvasEraserPreview$" docs/_registry/public_api_v1.yaml
awk '/Default identity equality:/{flag=1} /These runtime-owned objects/{flag=0} flag' docs/contracts/public_api_v1.md | rg -n "CanvasPreviewState and preview family types"
! awk '/Required value equality:/{flag=1} /For these types/{flag=0} flag' docs/contracts/public_api_v1.md | rg -n "CanvasPreviewState|CanvasNoPreview|CanvasMarqueePreview|CanvasSelectedMovePreview|CanvasStrokePreview|CanvasPencilStrokePreview|CanvasMarkerStrokePreview|CanvasPendingLineStartPreview|CanvasLinePreview|CanvasEraserPreview"
! awk '/### 4\.18 Preview state/{flag=1} /### 4\.19 Action and text events/{flag=0} flag' docs/contracts/public_api_v1.md | rg -n "final class CanvasPreviewState|activePointerId|sessionId|selectedIds|CanvasDrawTool tool|CanvasPreviewKind\\.(stroke|pendingLine|line)($|[^A-Za-z0-9_])"
! awk '/### 4\.18 Preview state/{flag=1} /### 4\.19 Action and text events/{flag=0} flag' docs/contracts/public_api_v1.md | rg -n "selectedMoveDelta|marqueeRect|strokePoints|strokeColor|strokeThickness|strokeOpacity|lineStart|lineEnd|lineTimestampMs|lineColor|lineThickness|eraserCorridor|eraserThickness"
```

The first command must find the successor hierarchy and registry entries. The
second command must find the locked factory names, required payload parameters,
and immutable list-copy requirements. The third command must find every concrete
preview export in the registry. The fourth and fifth commands must prove
preview family identity equality and absence from required value equality. The
sixth command is bounded to the preview-state section and must find no retired
nullable-bag declaration, no public pointer/session/selected-id payload, no
tool-discriminated stroke variant, and no renamed preview enum values. The
seventh command must find no retired preview-section field or constructor
payload names in the bounded preview-state section.

#### Closure

The public API contract and registry agree on the sealed preview hierarchy and
the retired nullable-bag seam is absent from those files.

### Slice 2. [x] Verification And Index Mapping

#### Implements

D1, D2, D3, D4, D6

#### Obligations Covered

BUG_FIX, SEAM_MIGRATION, PUBLIC_API_CHANGE

#### Files

- Update `docs/verification/tests.md` as test registry owner: add the future
  `test.api_contract.preview_state_sealed_union` proof and its behavioral
  focus.
- Update `docs/verification/guardrails.md` as guardrail registry owner: add
  `api.preview_state_sealed_union_publicly_readable` for exported readable
  preview variants.
- Update `docs/verification/release_gates.md` as release proof owner: include
  the sealed preview-state public API proof in the relevant public API gate.
- Update `docs/indexes/by_test_area.md` as generated-style test index owner:
  map the new preview sealed-union test to public API, interaction, frame, and
  guardrail sections.
- Update `docs/indexes/by_guardrail.md` as generated-style guardrail index
  owner: map the new preview sealed-union guardrail to its owning sections and
  tests.
- Update `docs/_registry/sections.yaml` as section catalog owner: wire the new
  test and guardrail to the public API section and dependent interaction/frame
  sections.

#### Change

Add the future proof `test.api_contract.preview_state_sealed_union` and the
guardrail `api.preview_state_sealed_union_publicly_readable`. Map them to the
public API section and the interaction/frame sections that depend on preview
variant semantics.

#### Proof

Prove verification mapping exists and is indexed:

```sh
rg -n "test\\.api_contract\\.preview_state_sealed_union|api\\.preview_state_sealed_union_publicly_readable" docs/verification docs/indexes docs/_registry/sections.yaml
```

Prove no stale test or guardrail name was introduced:

```sh
! rg -n "preview_state_nullable|preview_nullable_bag|preview_state_kind_bag" docs/verification docs/indexes docs/_registry/sections.yaml
```

The first command must find the new proof and guardrail in the active mapping
surfaces. The second command must find no stale or rejected proof names.

#### Closure

The source-of-truth verification surfaces identify the future executable proof
for the sealed preview-state public API and map it to the owning sections.

### Slice 3. [x] Interaction And Frame Alignment

#### Implements

D1, D3, D4, D6

#### Obligations Covered

SEAM_MIGRATION, PUBLIC_API_CHANGE

#### Files

- Update `docs/contracts/interaction_engine.md` as preview producer owner:
  describe interaction publication and cleanup in terms of sealed preview
  variants while preserving repaint targets.
- Update `docs/contracts/frame_rendering.md` as preview consumer owner:
  describe captured preview-state consumption through variants while preserving
  selected-move main-frame handling.
- Verify-only `docs/contracts/cache_policy.md` for PaintPlanCache preview-delta
  exclusion; do not edit it in this step.
- Update `docs/diagrams/dfd_pointer_preview_commit.mmd` as preview data-flow
  owner: route pointer preview facts into sealed preview variants and keep
  cleanup-by-kind routing.
- Update `docs/diagrams/dfd_overlay_frame.mmd` as overlay-frame data-flow
  owner: admit overlay preview variants and continue excluding selected move.
- Update `docs/diagrams/dfd_main_paint_frame.mmd` as main-frame data-flow
  owner: keep selected-move delta capture separate from ordinary paint-plan
  cache data.
- Update `docs/diagrams/seq_overlay_paint.mmd` as overlay paint sequence owner:
  build overlay primitives from captured sealed preview variants.
- Update `docs/diagrams/seq_main_paint.mmd` as main paint sequence owner:
  preserve selected-move supplement staging and PaintPlanCache exclusions.
- Update `docs/diagrams/seq_selected_move_preview_commit.mmd` as selected-move
  preview sequence owner: publish `CanvasSelectedMovePreview` delta without
  public selected ids or session fields.
- Update `docs/diagrams/seq_selected_move_cancel.mmd` as selected-move cleanup
  sequence owner: clear selected-move preview through the sealed no-preview
  state and preserve main repaint cleanup.
- Update `docs/diagrams/seq_marquee_select.mmd` as marquee sequence owner:
  publish and clear `CanvasMarqueePreview` instead of nullable marquee fields.
- Update `docs/diagrams/seq_pencil_marker_commit.mmd` as stroke preview
  sequence owner: publish pencil and marker concrete variants through
  `CanvasStrokePreview` shared facts.
- Update `docs/diagrams/seq_line_two_tap_commit.mmd` as line preview sequence
  owner: publish pending-line-start and line-preview variants with stable enum
  spelling.
- Update `docs/diagrams/seq_eraser_commit.mmd` as eraser preview sequence
  owner: publish eraser corridor preview as `CanvasEraserPreview`.

#### Change

Align producer and consumer descriptions with the sealed preview variants. Keep
selected move as main-scene preview, keep marquee, pencil, marker, pending line
start, line preview, and eraser as overlay previews, and keep preview delta out
of ordinary paint-plan cache keys and values.

#### Proof

Prove selected move and overlay routing still exist:

```sh
rg -n "selected move preview.*main|main-scene preview|overlay preview|PaintPlanCache.*selectedMoveDelta|PaintPlanCache.*previewDelta" docs/contracts/interaction_engine.md docs/contracts/frame_rendering.md docs/contracts/cache_policy.md docs/diagrams
```

Prove rejected public payloads do not leak into preview variant seam wording:

```sh
! rg -n "CanvasSelectedMovePreview.*selectedIds|CanvasSelectedMovePreview.*activePointerId|CanvasSelectedMovePreview.*sessionId|CanvasStrokePreview.*CanvasDrawTool" docs/contracts docs/diagrams
```

The first command must find the preserved routing and cache rules. The second
command must find no rejected public preview payload or tool-discriminated
stroke seam.

#### Closure

Interaction and frame source-of-truth documents agree with the sealed preview
variant model and preserve existing repaint/cache behavior.

### Slice 4. [x] Phase Docs, Audit, And Redesign Retirement

#### Implements

D1, D2, D3, D4, D6

#### Obligations Covered

BUG_FIX, SEAM_MIGRATION, PUBLIC_API_CHANGE

#### Files

- Update `docs/implementation/p2_public_api_v1_freeze.md` as API freeze phase
  owner: include the sealed preview-state public API proof and export surface.
- Update `docs/implementation/p10_selection_and_move.md` as selection/move phase
  owner: align selected-move preview scope with `CanvasSelectedMovePreview`
  delta-only payload.
- Update `docs/implementation/p11_draw_tools.md` as draw tools phase owner:
  align pencil, marker, pending line, and line preview wording with sealed
  variants and `CanvasStrokePreview`.
- Update `docs/implementation/p12_eraser_and_context_action_request.md` as eraser/text
  phase owner: align eraser preview wording with `CanvasEraserPreview` and keep
  text request out of preview state.
- Update `docs/implementation/p13_flutter_surface.md` as surface phase owner:
  align Flutter bridge preview capture expectations with the sealed preview
  state contract.
- Update `redesign.md` as accepted redesign backlog owner: remove the accepted
  `CanvasPreviewState` sealed-union block after the successor source-of-truth
  contract exists.
- Verify-only `audit.md`; current evidence shows no matching preview
  sealed-union audit block, and this step must preserve unrelated
  `interactive=false` preview semantics.
- Update `PLAN.md` as roadmap index owner: mark Step 9 complete only after all
  slice proofs and the final gate pass.
- Update `plan/step_9_canvas_preview_state_sealed_union.md` as this step
  contract owner: mark slice checkboxes and the step complete only after all
  slice proofs and the final gate pass.

#### Change

Align phase documentation with the public sealed preview state. Remove the
accepted `CanvasPreviewState` sealed-union block from `redesign.md`. Verify
`audit.md` has no matching preview sealed-union block without removing unrelated
`interactive=false` preview semantics. Mark roadmap and slice checkboxes
complete only after all proofs pass.

#### Proof

Prove phase docs point at the sealed public preview API:

```sh
rg -n "CanvasPreviewState|CanvasStrokePreview|CanvasPencilStrokePreview|CanvasMarkerStrokePreview|CanvasPendingLineStartPreview|CanvasEraserPreview|preview_state_sealed_union" docs/implementation/p2_public_api_v1_freeze.md docs/implementation/p10_selection_and_move.md docs/implementation/p11_draw_tools.md docs/implementation/p12_eraser_and_context_action_request.md docs/implementation/p13_flutter_surface.md
```

Prove redesign and audit retirement:

```sh
! rg -n "CanvasPreviewState.*sealed|sealed-union|invalid preview state|CanvasStrokePreview|selectedIds|CanvasPreviewKind\\.(stroke|pendingLine|line)" redesign.md audit.md
```

The first command must find the successor preview API references in the phase
docs. The second command must find no stale accepted redesign/audit block or
rejected preview sketch terms.

#### Closure

Phase docs, audit cleanup, redesign cleanup, `PLAN.md`, and this step contract
all reflect that the sealed preview-state design is owned by active
source-of-truth documents.

## 7. Final Gate

### Run Proof Set

Run P1:

```sh
dart run docs/tool/check_docs.dart
```

Run the slice-local P2, P3, and P4 commands.

Run final whitespace validation:

```sh
git diff --check
```

### Done When

- `CanvasPreviewState` is documented as a sealed public union.
- Every concrete public preview variant and intermediate `CanvasStrokePreview`
  is listed in the public export registry.
- `CanvasPreviewKind` enum spelling remains unchanged.
- The nullable-bag constructor and cross-kind nullable preview fields are
  retired from the public API contract.
- Selected ids, pointer tokens, active pointer ids, and session ids are not
  public preview payload.
- Verification mappings name the future sealed preview-state proof and guardrail.
- Interaction and frame docs preserve selected move main repaint, overlay
  preview routing, and PaintPlanCache preview-delta exclusion.
- `redesign.md` no longer contains the accepted preview sealed-union block.
- `audit.md` contains no matching preview sealed-union work item while
  preserving unrelated preview lifecycle audit items.
- `PLAN.md` and this step document mark the step complete.
