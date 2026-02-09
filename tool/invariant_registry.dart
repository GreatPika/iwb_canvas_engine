/// Canonical list of project invariants.
///
/// This file is intentionally machine-readable and stable to parse.
/// It is used by tooling to ensure every invariant has automated enforcement
/// (a test and/or a tool check).
///
/// To reference an invariant from a test/tool, add a marker comment:
///   // INV:INV-EXAMPLE
library;

class Invariant {
  const Invariant({required this.id, required this.title, required this.scope});

  final String id;
  final String title;

  /// A short scope label to make reports easier to read.
  /// Example: "global", "layering", "input-slices", "repaint".
  final String scope;
}

const List<Invariant> invariants = <Invariant>[
  // Global / layering.
  Invariant(
    id: 'INV-G-CORE-NO-LAYER-DEPS',
    scope: 'layering',
    title: 'core/** must not import input/render/view/serialization',
  ),
  Invariant(
    id: 'INV-G-LAYER-BOUNDARIES',
    scope: 'layering',
    title:
        'layer boundaries (core/input/render/serialization/view) are enforced',
  ),
  Invariant(
    id: 'INV-G-PUBLIC-ENTRYPOINTS',
    scope: 'public-api',
    title: 'public entrypoints remain source-compatible (basic/advanced)',
  ),
  Invariant(
    id: 'INV-G-NOTIFY-SEMANTICS',
    scope: 'behavior',
    title: 'input notifications preserve immediate vs coalesced semantics',
  ),
  Invariant(
    id: 'INV-G-NODEID-UNIQUE',
    scope: 'behavior',
    title: 'NodeId is unique across all scene layers (commands + decode)',
  ),
  Invariant(
    id: 'INV-V2-NO-EXTERNAL-MUTATION',
    scope: 'v2-api',
    title:
        'v2 public API is read-only for scene state and does not expose mutable engine internals',
  ),
  Invariant(
    id: 'INV-V2-WRITE-ONLY-MUTATION',
    scope: 'v2-controller',
    title:
        'v2 scene mutations are routed only through write/txn-prefixed transaction entrypoints',
  ),
  Invariant(
    id: 'INV-V2-TXN-ATOMIC-COMMIT',
    scope: 'v2-controller',
    title:
        'v2 transaction commit is atomic: one write boundary, one commit flush boundary',
  ),
  Invariant(
    id: 'INV-V2-EPOCH-INVALIDATION',
    scope: 'v2-runtime',
    title:
        'v2 replace-scene/controller lifecycle preserves epoch-based invalidation contracts',
  ),

  // Input slice boundaries.
  Invariant(
    id: 'INV-SLICE-NO-PART',
    scope: 'input-slices',
    title: 'input/slices/** must not use part/part of',
  ),
  Invariant(
    id: 'INV-SLICE-NO-SCENE_CONTROLLER',
    scope: 'input-slices',
    title: 'input/slices/** must not import scene_controller.dart',
  ),
  Invariant(
    id: 'INV-SLICE-NO-CROSS_SLICE_IMPORTS',
    scope: 'input-slices',
    title: 'input/slices/** must not import other slices outside current slice',
  ),
  Invariant(
    id: 'INV-INTERNAL-NO-SCENE_CONTROLLER',
    scope: 'input-slices',
    title: 'input/internal/** must not import scene_controller.dart',
  ),
  Invariant(
    id: 'INV-INTERNAL-NO-SLICES_IMPORTS',
    scope: 'input-slices',
    title: 'input/internal/** must not import input/slices/**',
  ),
  Invariant(
    id: 'INV-SHARED-INPUT-IN-INTERNAL',
    scope: 'input-slices',
    title: 'shared reusable input code lives in input/internal/** (or core/**)',
  ),

  // Slice invariants.
  Invariant(
    id: 'INV-REPAINT-ONE-PER-FRAME',
    scope: 'repaint',
    title: 'requestRepaintOncePerFrame schedules at most one frame',
  ),
  Invariant(
    id: 'INV-REPAINT-TOKEN-CANCELS',
    scope: 'repaint',
    title: 'repaint tokening prevents stale scheduled callbacks from firing',
  ),
  Invariant(
    id: 'INV-REPAINT-NOTIFYNOW-CLEARS',
    scope: 'repaint',
    title: 'notifyNow clears needs-notify flag and cancels scheduled repaint',
  ),
  Invariant(
    id: 'INV-REPAINT-NOTIFYNOW-AFTER-DISPOSE-SAFE',
    scope: 'repaint',
    title: 'notifyNow is a safe no-op after dispose',
  ),
  Invariant(
    id: 'INV-RENDER-GRID-SAFETY-LIMITS',
    scope: 'render',
    title:
        'Grid rendering/input enforce safety limits (min cell size clamp, max line cap via density degradation)',
  ),
  Invariant(
    id: 'INV-RENDER-TEXT-DIRECTION-ALIGNMENT',
    scope: 'render',
    title:
        'SceneView/ScenePainter/SceneTextLayoutCache honor TextDirection for TextAlign.start/end layout and painting.',
  ),
  Invariant(
    id: 'INV-RENDER-PATH-SELECTION-FILLRULE',
    scope: 'render',
    title:
        'PathNode selection highlight uses node.fillRule (evenOdd/nonZero) consistently for closed contours.',
  ),
  Invariant(
    id: 'INV-RENDER-THIN-LINE-SNAP-ELIGIBILITY',
    scope: 'render',
    title:
        'Thin-line pixel snapping is applied only for axis-aligned, unit-scale transforms and thin screen-space strokes.',
  ),
  Invariant(
    id: 'INV-RENDER-TEXT-LAYOUT-CACHE-KEY',
    scope: 'render',
    title:
        'Text layout cache key excludes non-semantic identity/geometry fields while preserving cached TextPainter paint-style correctness.',
  ),
  Invariant(
    id: 'INV-RENDER-STATIC-CACHE-CAMERA-INDEPENDENT',
    scope: 'render',
    title:
        'Static layer grid cache key is camera-independent; camera pan applies translation at draw time without cache rebuild and remains clipped to the scene bounds.',
  ),
  Invariant(
    id: 'INV-SIGNALS-BROADCAST-SYNC',
    scope: 'signals',
    title: 'signal streams stay broadcast(sync: true)',
  ),
  Invariant(
    id: 'INV-SIGNALS-ACTIONID-FORMAT',
    scope: 'signals',
    title: 'ActionCommitted.actionId format stays a{counter++}',
  ),
  Invariant(
    id: 'INV-SIGNALS-DROP-AFTER-DISPOSE',
    scope: 'signals',
    title: 'signals emitted after dispatcher dispose are dropped safely',
  ),
  Invariant(
    id: 'INV-INPUT-TIMESTAMP-MONOTONIC',
    scope: 'input',
    title:
        'ActionCommitted/EditTextRequested timestamps are normalized from hints into a strictly monotonic internal timeline',
  ),
  Invariant(
    id: 'INV-INPUT-CAMERA-OFFSET-FINITE',
    scope: 'input',
    title:
        'SceneController.setCameraOffset rejects non-finite offsets and preserves scene state on rejection',
  ),
  Invariant(
    id: 'INV-INPUT-DRAW-COMMIT-FAILSAFE',
    scope: 'input',
    title:
        'StrokeTool/LineTool commit paths are fail-safe: normalize failures abort without crashes and without action emission',
  ),
  Invariant(
    id: 'INV-INPUT-MOVE-DRAG-ROLLBACK',
    scope: 'input',
    title:
        'Move drag is transactional: cancel and mode switch rollback moved node transforms and emit no transform action',
  ),
  Invariant(
    id: 'INV-INPUT-ERASER-COMMIT-ON-UP',
    scope: 'input',
    title:
        'Eraser mutates scene only on pointer up; cancel and mode switch produce no deletions/actions',
  ),
  Invariant(
    id: 'INV-INPUT-LINE-PENDING-TIMER',
    scope: 'input',
    title:
        'Line two-tap pending start expires by an internal 10s timer even without new pointer events',
  ),
  Invariant(
    id: 'INV-INPUT-SIGNALS-ACTIVE-POINTER-ONLY',
    scope: 'input',
    title:
        'while a gesture is active, SceneView routes tap/double-tap candidates only from the active pointer id',
  ),
  Invariant(
    id: 'INV-INPUT-DOUBLETAP-BY-POINTERID',
    scope: 'input',
    title:
        'pending/double-tap correlation is keyed by pointerId (not PointerDeviceKind)',
  ),
  Invariant(
    id: 'INV-INPUT-PENDING-TAP-SINGLE-TIMER',
    scope: 'input',
    title:
        'SceneView maintains at most one pending-tap flush timer and only while pending taps exist',
  ),
  Invariant(
    id: 'INV-INPUT-MARQUEE-EMIT-ON-CHANGE',
    scope: 'input',
    title:
        'marquee commit emits ActionType.selectMarquee only when selection changes',
  ),
  Invariant(
    id: 'INV-INPUT-CONSTRUCTOR-SCENE-VALIDATION',
    scope: 'input',
    title:
        'SceneController constructor validates scene invariants, canonicalizes recoverable background cases, and rejects unrecoverable cases',
  ),
  Invariant(
    id: 'INV-INPUT-NODEID-INDEX-CONSISTENT',
    scope: 'input',
    title:
        'SceneController node-id index is kept consistent with scene structure and is used for O(1) membership checks in newNodeId/notifySceneChanged paths',
  ),
  Invariant(
    id: 'INV-INPUT-BACKGROUND-NONINTERACTIVE-NONDELETABLE',
    scope: 'input',
    title:
        'Background layer nodes are non-interactive and non-deletable across selection, marquee, and delete paths',
  ),
  Invariant(
    id: 'INV-INPUT-ERASER-SELECTION-NORMALIZED',
    scope: 'input',
    title:
        'Eraser removes deleted node ids from selection before publishing scene changes and actions',
  ),
  Invariant(
    id: 'INV-SELECTION-SETSELECTION-COALESCED',
    scope: 'selection',
    title: 'setSelection defaults to coalesced repaint (not immediate notify)',
  ),
  Invariant(
    id: 'INV-SELECTION-STRICT-INTERACTIVE-IDS',
    scope: 'selection',
    title:
        'selection normalization keeps only interactive ids (existing, non-background, visible, selectable)',
  ),
  Invariant(
    id: 'INV-SELECTION-UNORDERED-SET',
    scope: 'selection',
    title: 'selection storage is order-insensitive (unordered set semantics)',
  ),
  Invariant(
    id: 'INV-SELECTION-CLEARSELECTION-IMMEDIATE',
    scope: 'selection',
    title: 'clearSelection remains an immediate notify',
  ),
  Invariant(
    id: 'INV-COMMANDS-STRUCTURAL-NOTIFYSCENECHANGED',
    scope: 'commands',
    title:
        'structural mutations call notifySceneChanged() and return immediately',
  ),
  Invariant(
    id: 'INV-COMMANDS-MUTATE-STRUCTURAL-EXPLICIT',
    scope: 'commands',
    title:
        'structural scene edits must use mutateStructural(); mutate() is geometry-only and asserts on structural changes in debug',
  ),
  Invariant(
    id: 'INV-COMMANDS-ADDNODE-DEFAULT-NONBACKGROUND',
    scope: 'commands',
    title:
        'addNode default target layer is the first non-background layer (created when absent)',
  ),
  Invariant(
    id: 'INV-COMMANDS-CLEARSCENE-KEEP-ONLY-BACKGROUND',
    scope: 'commands',
    title:
        'clearScene keeps exactly one background layer at index 0 and removes all non-background layers',
  ),
  Invariant(
    id: 'INV-COMMANDS-FLIP-SELECTION-AXES',
    scope: 'commands',
    title:
        'flipSelectionHorizontal reflects across the vertical center axis; flipSelectionVertical reflects across the horizontal center axis',
  ),

  // Serialization.
  Invariant(
    id: 'INV-SER-JSON-NUMERIC-VALIDATION',
    scope: 'serialization',
    title: 'Scene JSON numeric fields are finite and within valid ranges',
  ),
  Invariant(
    id: 'INV-SER-JSON-GRID-PALETTE-CONTRACTS',
    scope: 'serialization',
    title:
        'Scene JSON enforces non-empty palettes and conditional grid.cellSize validation (enabled: > 0, disabled: finite)',
  ),
  Invariant(
    id: 'INV-SER-BACKGROUND-SINGLE-AT-ZERO',
    scope: 'serialization',
    title:
        'Decode canonicalizes to exactly one background layer at index 0; multiple background layers are rejected',
  ),

  // Core.
  Invariant(
    id: 'INV-CORE-NORMALIZE-PRECONDITIONS',
    scope: 'core',
    title:
        'normalizeToLocalCenter requires identity transform and finite geometry (validated at runtime)',
  ),
  Invariant(
    id: 'INV-CORE-TRS-DECOMPOSITION-CANONICAL-FLIP',
    scope: 'core',
    title:
        'TRS convenience accessors provide a canonical decomposition for flips (scaleX ≥ 0, reflection encoded via scaleY sign + rotationDeg).',
  ),
  Invariant(
    id: 'INV-CORE-TRANSFORM-APPLYTORECT-DEGENERATE',
    scope: 'core',
    title: 'Transform2D.applyToRect preserves translation for degenerate rects',
  ),
  Invariant(
    id: 'INV-CORE-NUMERIC-ROBUSTNESS',
    scope: 'core',
    title:
        'Core transform/geometry helpers are robust to near-zero and never emit NaN/Infinity from finite inputs',
  ),
  Invariant(
    id: 'INV-CORE-RUNTIME-NUMERIC-SANITIZATION',
    scope: 'core',
    title:
        'Runtime bounds/hit-test/render sanitize non-finite numeric parameters (no NaN/Infinity propagation)',
  ),
  Invariant(
    id: 'INV-CORE-OPACITY-RUNTIME-CLAMP01',
    scope: 'core',
    title:
        'SceneNode.opacity normalizes runtime writes (`!finite -> 1`, clamp to `[0,1]`)',
  ),
  Invariant(
    id: 'INV-CORE-PATHNODE-LINEAR-PATHS',
    scope: 'core',
    title:
        'PathNode accepts non-zero-length SVG paths even if bounds are degenerate (line)',
  ),
  Invariant(
    id: 'INV-CORE-SCENE-LAYER-DEFENSIVE-LISTS',
    scope: 'core',
    title:
        'Scene/Layer constructors defensively copy list arguments (no external aliasing)',
  ),
  Invariant(
    id: 'INV-CORE-PATHNODE-BUILDLOCALPATH-DIAGNOSTICS',
    scope: 'core',
    title:
        'PathNode.buildLocalPath records a failure reason when diagnostics are enabled',
  ),
  Invariant(
    id: 'INV-CORE-PATHNODE-LOCALPATH-DEFENSIVE-COPY',
    scope: 'core',
    title:
        'PathNode.buildLocalPath returns a defensive copy by default (external mutation does not corrupt cache)',
  ),
  Invariant(
    id: 'INV-CORE-RECTNODE-BOUNDS-INCLUDE-STROKE',
    scope: 'core',
    title: 'RectNode.localBounds includes strokeWidth/2 when stroked',
  ),
  Invariant(
    id: 'INV-CORE-NONNEGATIVE-WIDTHS-CLAMP',
    scope: 'core',
    title:
        'Runtime width-like fields (thickness/strokeWidth/hitPadding) soft-normalize negative/non-finite values to non-negative finite values in bounds/hit-test/render.',
  ),
  Invariant(
    id: 'INV-CORE-CONVENIENCE-SETTERS-REJECT-SHEAR',
    scope: 'core',
    title:
        'rotationDeg/scaleX/scaleY setters reject non-TRS (sheared) transforms',
  ),
  Invariant(
    id: 'INV-CORE-LINE-HITPADDING-SLOP-SCENE',
    scope: 'hit-test',
    title:
        'LineNode hit-test applies hitPadding + kHitSlop in scene units (scale-aware)',
  ),
  Invariant(
    id: 'INV-CORE-STROKE-HITPADDING-SLOP-SCENE',
    scope: 'hit-test',
    title:
        'StrokeNode hit-test applies hitPadding + kHitSlop in scene units (scale-aware)',
  ),
  Invariant(
    id: 'INV-CORE-PATH-HITTEST-FILL-OR-STROKE',
    scope: 'hit-test',
    title:
        'PathNode hit-test selects the union of fill and stroke (stroke uses precise distance-to-path checks).',
  ),
  Invariant(
    id: 'INV-CORE-PATH-HITTEST-STROKE-NO-DOUBLECOUNT',
    scope: 'hit-test',
    title:
        'PathNode stroke hit-test tolerance is strokeWidth/2 + hitPadding + kHitSlop in scene units (scale-aware).',
  ),
  Invariant(
    id: 'INV-CORE-PATH-HITTEST-INVALID-NONINTERACTIVE',
    scope: 'hit-test',
    title:
        'PathNode with invalid/unbuildable local path is non-interactive in hit-testing.',
  ),
  Invariant(
    id: 'INV-CORE-PATH-HITTEST-FILL-REQUIRES-INVERSE',
    scope: 'hit-test',
    title:
        'PathNode fill/stroke hit-testing requires an invertible transform; degenerate transforms are non-clickable.',
  ),
  Invariant(
    id: 'INV-CORE-HITTEST-FALLBACK-INFLATED-AABB',
    scope: 'hit-test',
    title:
        'When inverse transform is unavailable, non-PathNode hit-test falls back to boundsWorld inflated by hitPadding + kHitSlop',
  ),
  Invariant(
    id: 'INV-CORE-HITTEST-TOP-SKIPS-BACKGROUND',
    scope: 'hit-test',
    title: 'hitTestTopNode skips layers marked as isBackground',
  ),
];
