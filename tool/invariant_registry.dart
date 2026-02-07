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
    id: 'INV-RENDER-GRID-SAFETY-LIMITS',
    scope: 'render',
    title:
        'Grid rendering/input enforce safety limits (min cell size clamp, max line cap skip)',
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
    id: 'INV-SELECTION-SETSELECTION-COALESCED',
    scope: 'selection',
    title: 'setSelection defaults to coalesced repaint (not immediate notify)',
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

  // Serialization.
  Invariant(
    id: 'INV-SER-JSON-NUMERIC-VALIDATION',
    scope: 'serialization',
    title: 'Scene JSON numeric fields are finite and within valid ranges',
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
        'PathNode hit-test selects the union of fill and stroke (stroke uses coarse AABB stage A).',
  ),
  Invariant(
    id: 'INV-CORE-PATH-HITTEST-STROKE-NO-DOUBLECOUNT',
    scope: 'hit-test',
    title:
        'PathNode stroke hit-test inflates boundsWorld only by hitPadding + kHitSlop (strokeWidth is already included in bounds).',
  ),
  Invariant(
    id: 'INV-CORE-PATH-HITTEST-INVALID-NONINTERACTIVE',
    scope: 'hit-test',
    title:
        'PathNode with invalid/unbuildable local path is non-interactive in hit-testing.',
  ),
  Invariant(
    id: 'INV-CORE-HITTEST-FALLBACK-INFLATED-AABB',
    scope: 'hit-test',
    title:
        'When inverse transform is unavailable, hit-test falls back to boundsWorld inflated by hitPadding + kHitSlop',
  ),
  Invariant(
    id: 'INV-CORE-HITTEST-TOP-SKIPS-BACKGROUND',
    scope: 'hit-test',
    title: 'hitTestTopNode skips layers marked as isBackground',
  ),
];
