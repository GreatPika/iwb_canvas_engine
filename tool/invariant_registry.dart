/// Canonical list of active project invariants.
///
/// This file is intentionally machine-readable and stable to parse.
/// Tooling uses it as the single source of truth for invariant ids and their
/// explicit proof surfaces under `tool/**` or `test/**`.
///
/// Invariant ID naming convention:
/// - Pattern: `INV-<DOMAIN>-<RULE>`
/// - `DOMAIN` is one of: `G`, `ENG`, `SER`
/// - `RULE` uses UPPER-KEBAB-CASE (`A-Z`, `0-9`, `-`)
/// - Underscores are forbidden in ids
///
/// Proof contract:
/// - `proofPath` must point to a concrete `tool/**` or `test/**` Dart file
/// - that file must contain a matching navigation marker `// INV:<id>`
/// - navigation markers outside the declared `proofPath` are allowed, but they
///   do not count as invariant coverage on their own
library;

class Invariant {
  const Invariant({
    required this.id,
    required this.scope,
    required this.title,
    required this.proofPath,
  });

  final String id;
  final String scope;
  final String title;
  final String proofPath;
}

const List<Invariant> invariants = <Invariant>[
  Invariant(
    id: 'INV-G-LAYER-DAG',
    scope: 'layering',
    title: 'lib/src layer DAG is explicit and enforced',
    proofPath: 'tool/check_import_boundaries.dart',
  ),
  Invariant(
    id: 'INV-G-LAYER-BOUNDARIES',
    scope: 'layering',
    title: 'layer boundaries and import contracts are enforced',
    proofPath: 'tool/check_import_boundaries.dart',
  ),
  Invariant(
    id: 'INV-G-PUBLIC-ENTRYPOINTS',
    scope: 'public-api',
    title:
        'public entrypoint is single iwb_canvas_engine.dart (advanced.dart forbidden)',
    proofPath: 'tool/check_public_api_surface.dart',
  ),
  Invariant(
    id: 'INV-G-NODEID-UNIQUE',
    scope: 'behavior',
    title: 'NodeId stays unique across all scene layers',
    proofPath: 'test/controller/scene_invariants_test.dart',
  ),
  Invariant(
    id: 'INV-G-LAYERID-UNIQUE',
    scope: 'behavior',
    title: 'LayerId stays unique across content layers',
    proofPath: 'test/controller/scene_invariants_test.dart',
  ),
  Invariant(
    id: 'INV-G-LAYER-Z-ORDER-BY-LIST',
    scope: 'behavior',
    title: 'content layer z-order is defined by scene.layers list order',
    proofPath: 'test/core/hit_test_test.dart',
  ),
  Invariant(
    id: 'INV-ENG-NO-EXTERNAL-MUTATION',
    scope: 'engine-api',
    title: 'public snapshots/specs do not expose mutable internals',
    proofPath: 'test/public_api/snapshot_immutability_test.dart',
  ),
  Invariant(
    id: 'INV-ENG-WRITE-ONLY-MUTATION',
    scope: 'engine-controller',
    title: 'mutations are routed via write*/txn* APIs',
    proofPath: 'tool/check_guardrails.dart',
  ),
  Invariant(
    id: 'INV-ENG-SAFE-TXN-API',
    scope: 'engine-controller',
    title:
        'public transaction API does not expose mutable scene escape hatches',
    proofPath: 'tool/check_guardrails.dart',
  ),
  Invariant(
    id: 'INV-ENG-TXN-WRITER-LIFETIME',
    scope: 'engine-controller',
    title:
        'transaction writer remains valid only during the active write callback',
    proofPath:
        'test/controller/core/scene_controller_commit_atomicity_test.dart',
  ),
  Invariant(
    id: 'INV-ENG-TXN-ATOMIC-COMMIT',
    scope: 'engine-controller',
    title: 'transaction commit remains atomic',
    proofPath:
        'test/controller/core/scene_controller_commit_atomicity_test.dart',
  ),
  Invariant(
    id: 'INV-ENG-TXN-COPY-ON-WRITE',
    scope: 'engine-controller',
    title:
        'transactions use scene/layer/node copy-on-write and avoid full scene deep clone',
    proofPath:
        'test/controller/core/scene_controller_commit_atomicity_test.dart',
  ),
  Invariant(
    id: 'INV-ENG-SIGNALS-AFTER-COMMIT',
    scope: 'engine-controller',
    title:
        'committed signals are delivered only after store commit is finalized',
    proofPath:
        'test/controller/core/scene_controller_signals_delivery_test.dart',
  ),
  Invariant(
    id: 'INV-ENG-ID-INDEX-FROM-SCENE',
    scope: 'engine-controller',
    title:
        'allNodeIds/nodeLocator match committed scene and id-generator counters stay monotonic (lower-bounded by scene)',
    proofPath: 'test/controller/scene_invariants_test.dart',
  ),
  Invariant(
    id: 'INV-ENG-INSTANCE-REVISION-MONOTONIC',
    scope: 'engine-controller',
    title:
        'scene nodes keep instanceRevision >= 1 and committed runtime revision state stays within the composite epoch/revision contract',
    proofPath: 'test/controller/scene_invariants_test.dart',
  ),
  Invariant(
    id: 'INV-ENG-WRITE-NUMERIC-GUARDS',
    scope: 'engine-controller',
    title: 'writer rejects non-finite or invalid numeric write inputs',
    proofPath: 'test/controller/internal/scene_writer_test.dart',
  ),
  Invariant(
    id: 'INV-ENG-DISPOSE-FAIL-FAST',
    scope: 'engine-controller',
    title:
        'mutating/effectful core APIs fail fast after dispose and keep state/effects unchanged',
    proofPath:
        'test/controller/core/scene_controller_core_dispose_fail_fast_test.dart',
  ),
  Invariant(
    id: 'INV-ENG-TEXT-SIZE-DERIVED',
    scope: 'engine-controller',
    title: 'TextNode.size is always derived from text layout inputs',
    proofPath:
        'test/controller/core/scene_controller_commit_atomicity_test.dart',
  ),
  Invariant(
    id: 'INV-ENG-EVENTS-IMMUTABLE',
    scope: 'engine-runtime',
    title: 'published events expose immutable nodeIds/payload snapshots',
    proofPath: 'test/core/action_events_test.dart',
  ),
  Invariant(
    id: 'INV-ENG-CORE-ARCHITECTURE-BOUNDARY',
    scope: 'engine-structure',
    title:
        'core node-family, node-support, and leaf-support owners remain structurally split after step 37 closure',
    proofPath: 'test/core/nodes_test.dart',
  ),
  Invariant(
    id: 'INV-ENG-INTERACTIVE-ASYNC-DELIVERY',
    scope: 'engine-runtime',
    title:
        'interactive actions/editTextRequests are asynchronous; interactive listener notifications are microtask-deferred and coalesced per event-loop tick',
    proofPath:
        'test/interactive/core/scene_controller_interactive_basics_test.dart',
  ),
  Invariant(
    id: 'INV-ENG-INTERACTIVE-POINTER-FINITE',
    scope: 'engine-runtime',
    title:
        'interactive pointer entrypoints drop non-finite down/move input and preserve terminal up/cancel only when a last finite pointer position exists',
    proofPath:
        'test/interactive/core/scene_controller_interactive_invalid_pointer_input_test.dart',
  ),
  Invariant(
    id: 'INV-ENG-POINTER-SETTINGS-VALIDATION',
    scope: 'engine-runtime',
    title:
        'pointer input settings reject non-finite/negative thresholds at runtime boundaries',
    proofPath: 'test/core/pointer_input_test.dart',
  ),
  Invariant(
    id: 'INV-ENG-INTERACTIVE-SINGLE-ACTIVE-POINTER',
    scope: 'engine-runtime',
    title:
        'interactive gestures keep a single active pointer and ignore parallel pointer ids until gesture end',
    proofPath:
        'test/interactive/core/scene_controller_interactive_single_pointer_policy_test.dart',
  ),
  Invariant(
    id: 'INV-ENG-INTERACTIVE-GESTURE-BUFFER-SOFT-CAP',
    scope: 'engine-runtime',
    title:
        'interactive stroke/eraser active gesture buffers are soft-capped with endpoint-preserving pruning and validated limits',
    proofPath:
        'test/interactive/core/scene_controller_interactive_guardrails_stroke_test.dart',
  ),
  Invariant(
    id: 'INV-ENG-INTERACTIVE-CANCEL-STATE-RESET',
    scope: 'engine-runtime',
    title:
        'interactive pointer cancel resets active gesture state (preview/pending buffers) without committing scene mutations',
    proofPath:
        'test/interactive/core/scene_controller_interactive_move_preview_invariants_test.dart',
  ),
  Invariant(
    id: 'INV-ENG-INTERACTIVE-PREVIEW-COMMIT-ON-UP',
    scope: 'engine-runtime',
    title:
        'interactive move/draw preview remains ephemeral and does not mutate committed scene before pointer up commit',
    proofPath:
        'test/interactive/core/scene_controller_interactive_move_preview_invariants_test.dart',
  ),
  Invariant(
    id: 'INV-ENG-INTERACTIVE-RESOLVER-PURITY',
    scope: 'engine-runtime',
    title:
        'moveCommitDeltaResolver cannot call public stateful/effectful interactive controller entrypoints',
    proofPath: 'tool/check_guardrails.dart',
  ),
  Invariant(
    id: 'INV-ENG-INTERACTIVE-PUBLIC-MUTATION-EXCLUSIVITY',
    scope: 'engine-runtime',
    title:
        'public controller.selection.* and controller.scene.* mutations stay gesture-exclusive during active move/draw ownership except setCameraOffset(...) and replaceScene(...), which reset only after preflight confirms the boundary mutation will proceed',
    proofPath:
        'test/interactive/core/scene_controller_interactive_single_pointer_policy_test.dart',
  ),
  Invariant(
    id: 'INV-ENG-INTERACTIVE-ARCHITECTURE-BOUNDARY',
    scope: 'engine-runtime',
    title:
        'interactive capability/runtime/event/write-side owners remain structurally split, keep SceneController as the committed render-state boundary, stay model-free under lib/src/interactive/**, and do not reabsorb deleted residual seams',
    proofPath:
        'test/interactive/core/scene_controller_architecture_boundary_test.dart',
  ),
  Invariant(
    id: 'INV-ENG-MODEL-ARCHITECTURE-BOUNDARY',
    scope: 'engine-structure',
    title:
        'model facade/internal-owner boundaries remain part-free and downstream code imports only canonical model facades',
    proofPath: 'tool/check_guardrails.dart',
  ),
  Invariant(
    id: 'INV-ENG-CONTRACT-ARCHITECTURE-BOUNDARY',
    scope: 'engine-structure',
    title:
        'contract layer remains part-free and downstream non-contract code imports only canonical contract surfaces',
    proofPath: 'tool/check_guardrails.dart',
  ),
  Invariant(
    id: 'INV-ENG-VIEW-POINTER-SLOT-LIFECYCLE',
    scope: 'view-runtime',
    title:
        'SceneView pointer-slot allocator releases slots on up/cancel and reuses the minimum free slot id',
    proofPath: 'test/view/scene_view_pointer_router_test.dart',
  ),
  Invariant(
    id: 'INV-ENG-VIEW-ACTIVE-POINTER-GATE',
    scope: 'view-runtime',
    title:
        'SceneView pointer signal tracking gates by a single active pointer and releases gate on up/cancel',
    proofPath: 'test/view/scene_view_pointer_router_test.dart',
  ),
  Invariant(
    id: 'INV-ENG-VIEW-POINTER-SETTINGS-LIVE-APPLY',
    scope: 'view-runtime',
    title:
        'SceneView keeps pointer-settings live-apply behavior on the same controller without re-owning tracker/pending-setting state in the host shell',
    proofPath: 'test/view/scene_view_interactive_test.dart',
  ),
  Invariant(
    id: 'INV-ENG-VIEW-POINTER-SEMANTICS-BOUNDARY',
    scope: 'engine-structure',
    title:
        'the local SceneView pointer-semantics seam stays closed: view shell files may consume only controller-private internal access, while concrete pointer-semantics ownership remains outside view/**',
    proofPath: 'tool/check_import_boundaries.dart',
  ),
  Invariant(
    id: 'INV-ENG-VIEW-RENDER-READ-STATE-BOUNDARY',
    scope: 'engine-structure',
    title:
        'interactive view/render shell files consume one controller-owned render read-state, keep overlay ownership outside the render surface, and do not reopen helper-based read-side seams through view/**',
    proofPath:
        'test/interactive/core/scene_controller_architecture_boundary_test.dart',
  ),
  Invariant(
    id: 'INV-ENG-EPOCH-INVALIDATION',
    scope: 'engine-runtime',
    title: 'replace-scene lifecycle preserves epoch invalidation',
    proofPath: 'test/render/scene_render_caches_test.dart',
  ),
  Invariant(
    id: 'INV-ENG-RENDER-GEOMETRY-KEY-STABLE',
    scope: 'engine-runtime',
    title:
        'render geometry cache keys use stable scalar/revision inputs (no collection identity)',
    proofPath: 'test/render/render_geometry_cache_test.dart',
  ),
  Invariant(
    id: 'INV-ENG-SPATIAL-INDEX-REBUILD-ON-INVALID',
    scope: 'engine-runtime',
    title: 'invalid spatial index always transitions to rebuild-required state',
    proofPath: 'test/controller/internal/spatial_index_cache_test.dart',
  ),
  Invariant(
    id: 'INV-ENG-TIMESTAMP-MS-MONOTONIC',
    scope: 'engine-runtime',
    title:
        'interactive action timestamps stay monotonic even when caller hints go backwards or are omitted',
    proofPath:
        'test/interactive/core/scene_controller_interactive_basics_test.dart',
  ),
  Invariant(
    id: 'INV-ENG-PATH-NODE-CACHE-INVALIDATION',
    scope: 'engine-runtime',
    title:
        'PathNode local-path cache invalidates whenever svgPathData or fillRule changes',
    proofPath: 'test/core/nodes_test.dart',
  ),
  Invariant(
    id: 'INV-ENG-CLEAR-SCENE-RESULT-REMOVED-NODE-IDS-IMMUTABLE',
    scope: 'engine-controller',
    title: 'ClearSceneResult.removedNodeIds is an immutable defensive snapshot',
    proofPath: 'test/controller/internal/scene_writer_test.dart',
  ),
  Invariant(
    id: 'INV-ENG-COMMANDS-NO-PART',
    scope: 'controller-structure',
    title: 'controller/commands/** must not use part/part of',
    proofPath: 'tool/check_import_boundaries.dart',
  ),
  Invariant(
    id: 'INV-ENG-COMMANDS-NO-SCENE-CONTROLLER',
    scope: 'controller-structure',
    title: 'controller/commands/** must not import controller entrypoint',
    proofPath: 'tool/check_import_boundaries.dart',
  ),
  Invariant(
    id: 'INV-ENG-COMMANDS-NO-CROSS-IMPORTS',
    scope: 'controller-structure',
    title: 'controller/commands/** must not import other command groups',
    proofPath: 'tool/check_import_boundaries.dart',
  ),
  Invariant(
    id: 'INV-ENG-INTERNAL-NO-SCENE-CONTROLLER',
    scope: 'controller-structure',
    title: 'controller/internal/** must not import controller entrypoint',
    proofPath: 'tool/check_import_boundaries.dart',
  ),
  Invariant(
    id: 'INV-ENG-INTERNAL-NO-COMMANDS-IMPORTS',
    scope: 'controller-structure',
    title: 'controller/internal/** must not import controller/commands/**',
    proofPath: 'tool/check_import_boundaries.dart',
  ),
  Invariant(
    id: 'INV-ENG-SHARED-CONTROLLER-HELPERS',
    scope: 'controller-structure',
    title:
        'shared controller helpers stay in core/** or controller/internal/**',
    proofPath: 'tool/check_import_boundaries.dart',
  ),
  Invariant(
    id: 'INV-SER-JSON-NUMERIC-VALIDATION',
    scope: 'serialization',
    title: 'JSON numeric fields are finite and validated',
    proofPath: 'test/serialization/scene_codec_validation_test.dart',
  ),
  Invariant(
    id: 'INV-SER-JSON-GRID-PALETTE-CONTRACTS',
    scope: 'serialization',
    title: 'JSON grid/palette contracts are enforced',
    proofPath: 'test/serialization/scene_codec_validation_test.dart',
  ),
  Invariant(
    id: 'INV-SER-TYPED-LAYER-SPLIT',
    scope: 'serialization',
    title:
        'serialization keeps optional backgroundLayer separate from content layers',
    proofPath: 'test/serialization/scene_codec_validation_test.dart',
  ),
  Invariant(
    id: 'INV-SER-CANONICAL-BACKGROUND-LAYER',
    scope: 'serialization',
    title:
        'snapshot/JSON boundaries canonicalize missing backgroundLayer to a single dedicated background layer',
    proofPath: 'test/serialization/scene_codec_validation_test.dart',
  ),
  Invariant(
    id: 'INV-SER-SCHEMA-VERSION-CONTRACT',
    scope: 'serialization',
    title:
        'schema write version stays readable and schemaVersion decoding accepts only the declared read set',
    proofPath: 'test/serialization/scene_codec_validation_test.dart',
  ),
  Invariant(
    id: 'INV-SER-UNSUPPORTED-SCHEMA-VERSION-CODE',
    scope: 'serialization',
    title:
        'unsupported schemaVersion decode failures report SceneDataErrorCode.unsupportedSchemaVersion',
    proofPath: 'test/serialization/scene_codec_validation_test.dart',
  ),
];
