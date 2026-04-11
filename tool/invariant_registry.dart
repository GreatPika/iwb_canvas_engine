/// Canonical list of active project invariants.
///
/// This file is intentionally machine-readable and stable to parse.
/// Tooling uses it as the single source of truth for invariant ids and their
/// explicit proof surfaces.
///
/// Invariant ID naming convention:
/// - Pattern: `INV-<DOMAIN>-<RULE>`
/// - `DOMAIN` is one of: `G`, `ENG`, `SER`
/// - `RULE` uses UPPER-KEBAB-CASE (`A-Z`, `0-9`, `-`)
/// - Underscores are forbidden in ids
///
/// Proof contract:
/// - every invariant declares exactly one `primaryProof`
/// - `primaryProof.path` must point to an executable `test/**/*_test.dart`
/// - tool-backed invariants additionally declare `toolProof`
/// - `toolProof.enforcementPath` must point to a top-level `tool/*.dart`
/// - `toolProof.regressionPath` must point to an executable
///   `test/tool/**/*_test.dart`
/// - every declared proof file must contain a matching `// INV:<id>` marker
/// - navigation markers outside declared proof surfaces are allowed, but they
///   do not count as invariant coverage on their own
library;

class Invariant {
  const Invariant({
    required this.id,
    required this.scope,
    required this.title,
    required this.primaryProof,
    this.toolProof,
  });

  final String id;
  final String scope;
  final String title;
  final PrimaryProof primaryProof;
  final ToolProof? toolProof;
}

class PrimaryProof {
  const PrimaryProof({this.path});

  final String? path;
}

class ToolProof {
  const ToolProof({this.enforcementPath, this.regressionPath});

  final String? enforcementPath;
  final String? regressionPath;
}

const List<Invariant> invariants = <Invariant>[
  Invariant(
    id: 'INV-G-LAYER-DAG',
    scope: 'layering',
    title: 'lib/src layer DAG is explicit and enforced',
    primaryProof: PrimaryProof(
      path:
          'test/tool/import_boundaries/import_boundaries_layer_dag_tool_test.dart',
    ),
    toolProof: ToolProof(
      enforcementPath: 'tool/check_import_boundaries.dart',
      regressionPath:
          'test/tool/import_boundaries/import_boundaries_layer_dag_tool_test.dart',
    ),
  ),
  Invariant(
    id: 'INV-G-LAYER-BOUNDARIES',
    scope: 'layering',
    title: 'layer boundaries and import contracts are enforced',
    primaryProof: PrimaryProof(
      path:
          'test/tool/import_boundaries/import_boundaries_layout_tool_test.dart',
    ),
    toolProof: ToolProof(
      enforcementPath: 'tool/check_import_boundaries.dart',
      regressionPath:
          'test/tool/import_boundaries/import_boundaries_layout_tool_test.dart',
    ),
  ),
  Invariant(
    id: 'INV-G-PUBLIC-ENTRYPOINTS',
    scope: 'public-api',
    title:
        'public entrypoint is single iwb_canvas_engine.dart and exported top-level symbol set stays stable (advanced.dart forbidden)',
    primaryProof: PrimaryProof(
      path:
          'test/tool/guardrails/guardrails_layout_and_entrypoints_tool_test.dart',
    ),
    toolProof: ToolProof(
      enforcementPath: 'tool/check_public_api_surface.dart',
      regressionPath:
          'test/tool/guardrails/guardrails_layout_and_entrypoints_tool_test.dart',
    ),
  ),
  Invariant(
    id: 'INV-G-NODEID-UNIQUE',
    scope: 'behavior',
    title: 'NodeId stays unique across all scene layers',
    primaryProof: PrimaryProof(
      path: 'test/controller/scene_invariants_test.dart',
    ),
  ),
  Invariant(
    id: 'INV-G-LAYERID-UNIQUE',
    scope: 'behavior',
    title: 'LayerId stays unique across content layers',
    primaryProof: PrimaryProof(
      path: 'test/controller/scene_invariants_test.dart',
    ),
  ),
  Invariant(
    id: 'INV-G-LAYER-Z-ORDER-BY-LIST',
    scope: 'behavior',
    title: 'content layer z-order is defined by scene.layers list order',
    primaryProof: PrimaryProof(path: 'test/core/hit_test_test.dart'),
  ),
  Invariant(
    id: 'INV-ENG-NO-EXTERNAL-MUTATION',
    scope: 'engine-api',
    title: 'public snapshots/specs do not expose mutable internals',
    primaryProof: PrimaryProof(
      path: 'test/public_api/snapshot_immutability_test.dart',
    ),
  ),
  Invariant(
    id: 'INV-ENG-PUBLIC-SNAPSHOT-GLOBAL-VALIDITY',
    scope: 'engine-api',
    title:
        'public SceneSnapshot remains the canonical document boundary, ordinary public construction is globally valid by construction, and raw malformed snapshot assembly stays internal-only',
    primaryProof: PrimaryProof(
      path: 'test/public_api/validated_boundary_value_test.dart',
    ),
  ),
  Invariant(
    id: 'INV-ENG-SHARED-SCENE-METADATA-CONTRACT',
    scope: 'engine-api',
    title:
        'scene metadata values use one eager contract across public constructors, runtime owners, and import/decode paths, while raw malformed metadata assembly stays internal-only',
    primaryProof: PrimaryProof(
      path: 'test/public_api/validated_boundary_value_test.dart',
    ),
  ),
  Invariant(
    id: 'INV-ENG-WRITE-ONLY-MUTATION',
    scope: 'engine-controller',
    title: 'mutations are routed via write*/txn* APIs',
    primaryProof: PrimaryProof(
      path: 'test/tool/guardrails/guardrails_controller_api_tool_test.dart',
    ),
    toolProof: ToolProof(
      enforcementPath: 'tool/check_guardrails.dart',
      regressionPath:
          'test/tool/guardrails/guardrails_controller_api_tool_test.dart',
    ),
  ),
  Invariant(
    id: 'INV-ENG-CONTROLLER-NO-FULL-VIEW-RENDER-STATE',
    scope: 'engine-structure',
    title:
        'SceneStoreController remains committed-store-only on the read side, while full SceneViewRenderState stays on the assembled interactive runtime path',
    primaryProof: PrimaryProof(
      path: 'test/contract/runtime_contract_interfaces_test.dart',
    ),
    toolProof: ToolProof(
      enforcementPath: 'tool/check_guardrails.dart',
      regressionPath:
          'test/tool/guardrails/guardrails_controller_api_tool_test.dart',
    ),
  ),
  Invariant(
    id: 'INV-ENG-SAFE-TXN-API',
    scope: 'engine-controller',
    title:
        'public transaction API and exported contract members do not expose scene escape hatches or signal/internal materialization helpers',
    primaryProof: PrimaryProof(
      path: 'test/tool/guardrails/guardrails_public_surface_tool_test.dart',
    ),
    toolProof: ToolProof(
      enforcementPath: 'tool/check_guardrails.dart',
      regressionPath:
          'test/tool/guardrails/guardrails_public_surface_tool_test.dart',
    ),
  ),
  Invariant(
    id: 'INV-ENG-PUBLIC-SURFACE-NO-MUTABLE-TYPES',
    scope: 'engine-api',
    title:
        'exported public contract and runtime signatures do not expose mutable core or runtime owner types',
    primaryProof: PrimaryProof(
      path: 'test/tool/guardrails/guardrails_mutable_type_leaks_tool_test.dart',
    ),
    toolProof: ToolProof(
      enforcementPath: 'tool/check_guardrails.dart',
      regressionPath:
          'test/tool/guardrails/guardrails_mutable_type_leaks_tool_test.dart',
    ),
  ),
  Invariant(
    id: 'INV-ENG-PUBLIC-SIGNATURE-HERMETICITY',
    scope: 'engine-api',
    title:
        'exported public signatures do not expose internal or non-exported helper types',
    primaryProof: PrimaryProof(
      path:
          'test/tool/guardrails/guardrails_public_signature_hermeticity_tool_test.dart',
    ),
    toolProof: ToolProof(
      enforcementPath: 'tool/check_guardrails.dart',
      regressionPath:
          'test/tool/guardrails/guardrails_public_signature_hermeticity_tool_test.dart',
    ),
  ),
  Invariant(
    id: 'INV-ENG-TXN-WRITER-LIFETIME',
    scope: 'engine-controller',
    title:
        'transaction writer remains valid only during the active write callback',
    primaryProof: PrimaryProof(
      path: 'test/controller/core/scene_controller_commit_atomicity_test.dart',
    ),
  ),
  Invariant(
    id: 'INV-ENG-TXN-ATOMIC-COMMIT',
    scope: 'engine-controller',
    title: 'transaction commit remains atomic',
    primaryProof: PrimaryProof(
      path: 'test/controller/core/scene_controller_commit_atomicity_test.dart',
    ),
  ),
  Invariant(
    id: 'INV-ENG-TXN-FINALIZED-BEFORE-COMMIT-PLAN',
    scope: 'engine-controller',
    title:
        'transaction state is finalized before commit planning and before the write callback regains control',
    primaryProof: PrimaryProof(
      path: 'test/controller/core/scene_controller_writer_lifecycle_test.dart',
    ),
  ),
  Invariant(
    id: 'INV-ENG-TXN-COPY-ON-WRITE',
    scope: 'engine-controller',
    title:
        'transactions use scene/layer/node copy-on-write and avoid full scene deep clone',
    primaryProof: PrimaryProof(
      path: 'test/controller/core/scene_controller_commit_atomicity_test.dart',
    ),
  ),
  Invariant(
    id: 'INV-ENG-WRITE-PROTOCOL',
    scope: 'engine-controller',
    title:
        'write(...) rejects nested writes, async callbacks, and dispose during the active callback without poisoning later writes',
    primaryProof: PrimaryProof(
      path: 'test/controller/core/scene_controller_writer_lifecycle_test.dart',
    ),
  ),
  Invariant(
    id: 'INV-ENG-SIGNALS-AFTER-COMMIT',
    scope: 'engine-controller',
    title:
        'committed signals are delivered only after store commit is finalized',
    primaryProof: PrimaryProof(
      path: 'test/controller/core/scene_controller_signals_delivery_test.dart',
    ),
  ),
  Invariant(
    id: 'INV-ENG-ID-INDEX-FROM-SCENE',
    scope: 'engine-controller',
    title:
        'allNodeIds/nodeLocator match committed scene and id-generator counters stay monotonic (lower-bounded by scene)',
    primaryProof: PrimaryProof(
      path: 'test/controller/scene_invariants_test.dart',
    ),
  ),
  Invariant(
    id: 'INV-ENG-INSTANCE-REVISION-MONOTONIC',
    scope: 'engine-controller',
    title:
        'scene nodes keep instanceRevision >= 1 and committed runtime revision state stays within the composite epoch/revision contract',
    primaryProof: PrimaryProof(
      path: 'test/controller/scene_invariants_test.dart',
    ),
  ),
  Invariant(
    id: 'INV-ENG-WRITE-NUMERIC-GUARDS',
    scope: 'engine-controller',
    title:
        'writer rejects invalid numeric writes instead of clamping or repair-normalizing them later',
    primaryProof: PrimaryProof(
      path: 'test/controller/internal/scene_writer_test.dart',
    ),
  ),
  Invariant(
    id: 'INV-ENG-COMMITTED-STORE-METADATA-CONTRACT',
    scope: 'engine-controller',
    title:
        'committed-store invariant sweeps enforce the shared runtime scene metadata contract for camera, grid, and palette values',
    primaryProof: PrimaryProof(
      path: 'test/controller/scene_invariants_test.dart',
    ),
  ),
  Invariant(
    id: 'INV-ENG-STROKE-RUNTIME-GEOMETRY-OWNER',
    scope: 'engine-core',
    title:
        'runtime stroke geometry stays hermetic: StrokeNode.points is read-only, StrokeNode.replacePoints owns pointsRevision updates, and public SceneSnapshot/JSON document boundaries do not carry runtime stroke revision metadata',
    primaryProof: PrimaryProof(path: 'test/core/nodes_test.dart'),
  ),
  Invariant(
    id: 'INV-ENG-PALETTE-RUNTIME-VALUE-OWNER',
    scope: 'engine-core',
    title:
        'runtime palette state is replacement-only: Scene.palette stays replaceable, while ScenePalette defensively copies and freezes nested lists after construction',
    primaryProof: PrimaryProof(path: 'test/model/document_model_test.dart'),
  ),
  Invariant(
    id: 'INV-ENG-DISPOSE-FAIL-FAST',
    scope: 'engine-controller',
    title:
        'mutating/effectful core APIs fail fast after dispose and keep state/effects unchanged',
    primaryProof: PrimaryProof(
      path:
          'test/controller/core/scene_controller_core_dispose_fail_fast_test.dart',
    ),
  ),
  Invariant(
    id: 'INV-ENG-CONTROLLER-COMMIT-RUNTIME-BOUNDARY',
    scope: 'engine-structure',
    title:
        'SceneStoreController stays a thin public facade over SceneControllerCommitRuntime and does not re-own commit planning or post-commit helpers',
    primaryProof: PrimaryProof(
      path:
          'test/controller/core/scene_controller_commit_runtime_contract_test.dart',
    ),
  ),
  Invariant(
    id: 'INV-ENG-SCENE-WRITE-TXN-ADAPTER-BOUNDARY',
    scope: 'engine-structure',
    title:
        'public write callbacks consume only the dedicated SceneWriteTxn adapter while SceneWriter remains the internal transactional owner',
    primaryProof: PrimaryProof(
      path: 'test/controller/internal/scene_write_txn_public_adapter_test.dart',
    ),
  ),
  Invariant(
    id: 'INV-ENG-TEXT-SIZE-DERIVED',
    scope: 'engine-controller',
    title:
        'text bounds are derived from layout inputs and never cross typed or JSON boundaries as stored size data',
    primaryProof: PrimaryProof(
      path: 'test/controller/core/scene_controller_commit_atomicity_test.dart',
    ),
  ),
  Invariant(
    id: 'INV-ENG-EVENTS-IMMUTABLE',
    scope: 'engine-runtime',
    title: 'published events expose immutable nodeIds/payload snapshots',
    primaryProof: PrimaryProof(path: 'test/core/action_events_test.dart'),
  ),
  Invariant(
    id: 'INV-ENG-CORE-ARCHITECTURE-BOUNDARY',
    scope: 'engine-structure',
    title:
        'core node-family, node-support, and leaf-support owners remain structurally split after step 37 closure',
    primaryProof: PrimaryProof(path: 'test/core/nodes_test.dart'),
  ),
  Invariant(
    id: 'INV-ENG-INTERACTIVE-ASYNC-DELIVERY',
    scope: 'engine-runtime',
    title:
        'interactive actions/editTextRequests are asynchronous; interactive listener notifications are microtask-deferred and coalesced per event-loop tick',
    primaryProof: PrimaryProof(
      path:
          'test/interactive/core/scene_controller_interactive_basics_test.dart',
    ),
  ),
  Invariant(
    id: 'INV-ENG-INTERACTIVE-PUBLIC-LISTENER-REPAINT-INDEPENDENCE',
    scope: 'engine-runtime',
    title:
        'interactive public listener delivery stays aligned with public state changes regardless of whether internal repaint routes through the scene or overlay channel',
    primaryProof: PrimaryProof(
      path:
          'test/interactive/core/scene_controller_public_listener_contract_test.dart',
    ),
  ),
  Invariant(
    id: 'INV-ENG-INTERACTIVE-HANDLE-POINTER-NON-REENTRANT',
    scope: 'engine-runtime',
    title:
        'public handlePointer(...) rejects same-stack reentrancy and unwinds cleanly after the active dispatch returns',
    primaryProof: PrimaryProof(
      path:
          'test/interactive/core/scene_controller_interactive_basics_test.dart',
    ),
  ),
  Invariant(
    id: 'INV-ENG-INTERACTIVE-POINTER-FINITE',
    scope: 'engine-runtime',
    title:
        'interactive pointer entrypoints drop non-finite down/move input and preserve terminal up/cancel only when a last finite pointer position exists',
    primaryProof: PrimaryProof(
      path:
          'test/interactive/core/scene_controller_interactive_invalid_pointer_input_test.dart',
    ),
  ),
  Invariant(
    id: 'INV-ENG-POINTER-SETTINGS-VALIDATION',
    scope: 'engine-runtime',
    title:
        'pointer input settings reject non-finite/negative thresholds at runtime boundaries',
    primaryProof: PrimaryProof(path: 'test/core/pointer_input_test.dart'),
  ),
  Invariant(
    id: 'INV-ENG-INTERACTIVE-SINGLE-ACTIVE-POINTER',
    scope: 'engine-runtime',
    title:
        'interactive gestures keep a single active pointer and ignore parallel pointer ids until gesture end',
    primaryProof: PrimaryProof(
      path:
          'test/interactive/core/scene_controller_interactive_single_pointer_policy_test.dart',
    ),
  ),
  Invariant(
    id: 'INV-ENG-INTERACTIVE-GESTURE-BUFFER-SOFT-CAP',
    scope: 'engine-runtime',
    title:
        'interactive stroke/eraser active gesture buffers are soft-capped with endpoint-preserving pruning and validated limits',
    primaryProof: PrimaryProof(
      path:
          'test/interactive/core/scene_controller_interactive_guardrails_stroke_test.dart',
    ),
  ),
  Invariant(
    id: 'INV-ENG-INTERACTIVE-CANCEL-STATE-RESET',
    scope: 'engine-runtime',
    title:
        'interactive pointer cancel resets active gesture state (preview/pending buffers) without committing scene mutations',
    primaryProof: PrimaryProof(
      path:
          'test/interactive/core/scene_controller_interactive_move_preview_invariants_test.dart',
    ),
  ),
  Invariant(
    id: 'INV-ENG-INTERACTIVE-INTERRUPTION-SEMANTICS',
    scope: 'engine-runtime',
    title:
        'interactive interruption and owning-session teardown remain distinct non-committing lifecycle reasons that release preview/baseline state without widening the pointer-cancel-specific contract',
    primaryProof: PrimaryProof(
      path:
          'test/interactive/core/scene_controller_interactive_move_preview_invariants_test.dart',
    ),
  ),
  Invariant(
    id: 'INV-ENG-INTERACTIVE-PREVIEW-COMMIT-ON-UP',
    scope: 'engine-runtime',
    title:
        'interactive move/draw preview remains ephemeral and does not mutate committed scene before pointer up commit',
    primaryProof: PrimaryProof(
      path:
          'test/interactive/core/scene_controller_interactive_move_preview_invariants_test.dart',
    ),
  ),
  Invariant(
    id: 'INV-ENG-INTERACTIVE-RESOLVER-PURITY',
    scope: 'engine-runtime',
    title:
        'moveCommitDeltaResolver cannot call public stateful/effectful interactive controller entrypoints',
    primaryProof: PrimaryProof(
      path: 'test/tool/guardrails/guardrails_interactive_api_tool_test.dart',
    ),
    toolProof: ToolProof(
      enforcementPath: 'tool/check_guardrails.dart',
      regressionPath:
          'test/tool/guardrails/guardrails_interactive_api_tool_test.dart',
    ),
  ),
  Invariant(
    id: 'INV-ENG-INTERACTIVE-MOVE-COMMIT-RESOLVER-NON-REENTRANT',
    scope: 'engine-runtime',
    title:
        'moveCommitDeltaResolver rejects reentrancy and always clears resolver-owned gesture state after failure before the next gesture starts',
    primaryProof: PrimaryProof(
      path:
          'test/interactive/core/scene_controller_interactive_actions_effects_test.dart',
    ),
  ),
  Invariant(
    id: 'INV-ENG-INTERACTIVE-PUBLIC-MUTATION-EXCLUSIVITY',
    scope: 'engine-runtime',
    title:
        'public controller.selection.* and controller.scene.* mutations stay gesture-exclusive during active move/draw ownership except setCameraOffset(...) and replaceScene(...), which reset only after preflight confirms the boundary mutation will proceed',
    primaryProof: PrimaryProof(
      path:
          'test/interactive/core/scene_controller_interactive_single_pointer_policy_test.dart',
    ),
  ),
  Invariant(
    id: 'INV-ENG-INTERACTIVE-ARCHITECTURE-BOUNDARY',
    scope: 'engine-runtime',
    title:
        'interactive capability/runtime/event/write-side owners remain structurally split, keep SceneController as the committed render-state boundary, stay model-free under lib/src/interactive/**, and do not reabsorb deleted residual seams',
    primaryProof: PrimaryProof(
      path:
          'test/interactive/core/scene_controller_architecture_boundary_test.dart',
    ),
  ),
  Invariant(
    id: 'INV-ENG-INTERACTIVE-MUTATION-BOUNDARY',
    scope: 'engine-runtime',
    title:
        'SceneControllerMutationBoundary remains the only interactive owner that performs committed scene/selection/draw writes and clear/delete action projection, while its committed mutation seam is narrowed to one controller-private access contract and scene/selection shells stay routing-only',
    primaryProof: PrimaryProof(
      path:
          'test/interactive/core/scene_controller_mutation_boundary_test.dart',
    ),
    toolProof: ToolProof(
      enforcementPath: 'tool/check_guardrails.dart',
      regressionPath:
          'test/tool/guardrails/guardrails_interactive_api_tool_test.dart',
    ),
  ),
  Invariant(
    id: 'INV-ENG-MODEL-ARCHITECTURE-BOUNDARY',
    scope: 'engine-structure',
    title:
        'model facade/internal-owner boundaries remain part-free, internal draft/import owners stay model-only, and downstream code imports only canonical model facades',
    primaryProof: PrimaryProof(
      path: 'test/tool/guardrails/guardrails_model_architecture_tool_test.dart',
    ),
    toolProof: ToolProof(
      enforcementPath: 'tool/check_guardrails.dart',
      regressionPath:
          'test/tool/guardrails/guardrails_model_architecture_tool_test.dart',
    ),
  ),
  Invariant(
    id: 'INV-ENG-CONTRACT-ARCHITECTURE-BOUNDARY',
    scope: 'engine-structure',
    title:
        'contract layer remains part-free and downstream non-contract code imports only canonical contract surfaces',
    primaryProof: PrimaryProof(
      path:
          'test/tool/guardrails/guardrails_contract_architecture_tool_test.dart',
    ),
    toolProof: ToolProof(
      enforcementPath: 'tool/check_guardrails.dart',
      regressionPath:
          'test/tool/guardrails/guardrails_contract_architecture_tool_test.dart',
    ),
  ),
  Invariant(
    id: 'INV-ENG-BOUNDARY-HERMETIC-CONCRETE-TYPES',
    scope: 'engine-api',
    title:
        'public boundary fallback/backing seam helpers accept only the built-in concrete boundary types and reject unsupported subtypes, including public subclasses of known boundary types',
    primaryProof: PrimaryProof(
      path: 'test/contract/validated_fast_path_contract_test.dart',
    ),
  ),
  Invariant(
    id: 'INV-ENG-VIEW-POINTER-SLOT-LIFECYCLE',
    scope: 'view-runtime',
    title:
        'SceneView pointer-slot allocator releases slots on up/cancel and reuses the minimum free slot id',
    primaryProof: PrimaryProof(
      path: 'test/view/scene_view_pointer_router_test.dart',
    ),
  ),
  Invariant(
    id: 'INV-ENG-VIEW-ACTIVE-POINTER-GATE',
    scope: 'view-runtime',
    title:
        'SceneView pointer signal tracking gates by a single active pointer and releases gate on up/cancel',
    primaryProof: PrimaryProof(
      path: 'test/view/scene_view_pointer_router_test.dart',
    ),
  ),
  Invariant(
    id: 'INV-ENG-VIEW-POINTER-SETTINGS-LIVE-APPLY',
    scope: 'view-runtime',
    title:
        'SceneView keeps pointer-settings live-apply behavior on the same controller without re-owning tracker/pending-setting state in the host shell',
    primaryProof: PrimaryProof(
      path: 'test/view/scene_view_interactive_test.dart',
    ),
  ),
  Invariant(
    id: 'INV-ENG-INTERACTIVE-DRAW-STYLE-SNAPSHOT',
    scope: 'engine-runtime',
    title:
        'active draw preview and pending two-tap line state use gesture-start style snapshots with owner-scoped pending-line provenance',
    primaryProof: PrimaryProof(
      path:
          'test/interactive/core/scene_controller_interactive_line_tool_flow_test.dart',
    ),
  ),
  Invariant(
    id: 'INV-ENG-VIEW-RUNTIME-HOST-DEBUG-PROBES',
    scope: 'view-runtime',
    title:
        'debugSceneViewInteractive* and debugSceneViewRuntimeHost* helpers are stable test probes for runtime-host cache and raw-pointer diagnostics and fail fast outside the mounted host boundary',
    primaryProof: PrimaryProof(
      path: 'test/view/scene_view_interactive_test.dart',
    ),
  ),
  Invariant(
    id: 'INV-ENG-VIEW-POINTER-SESSION-DETACH',
    scope: 'view-runtime',
    title:
        'SceneView runtime hosts detach opaque pointer sessions before dispose or router reset, and detach remains the terminal controller-unbind step before idempotent dispose',
    primaryProof: PrimaryProof(
      path: 'test/view/scene_view_interactive_test.dart',
    ),
  ),
  Invariant(
    id: 'INV-ENG-VIEW-POINTER-SEMANTICS-BOUNDARY',
    scope: 'engine-structure',
    title:
        'SceneView reaches interactive only through SceneViewRuntime, and only scene_view_interactive.dart may adapt SceneController into that runtime boundary',
    primaryProof: PrimaryProof(
      path:
          'test/tool/import_boundaries/import_boundaries_layer_dag_tool_test.dart',
    ),
    toolProof: ToolProof(
      enforcementPath: 'tool/check_import_boundaries.dart',
      regressionPath:
          'test/tool/import_boundaries/import_boundaries_layer_dag_tool_test.dart',
    ),
  ),
  Invariant(
    id: 'INV-ENG-VIEW-RENDER-READ-STATE-BOUNDARY',
    scope: 'engine-structure',
    title:
        'interactive view/render shell files consume one assembled SceneViewRuntime boundary, keep overlay ownership outside the render surface, split scene and overlay repaint channels inside one controller-owned render-state family, and do not reopen concrete-controller seams through view/**',
    primaryProof: PrimaryProof(
      path:
          'test/interactive/core/scene_controller_architecture_boundary_test.dart',
    ),
  ),
  Invariant(
    id: 'INV-ENG-EPOCH-INVALIDATION',
    scope: 'engine-runtime',
    title: 'replace-scene lifecycle preserves epoch invalidation',
    primaryProof: PrimaryProof(
      path: 'test/render/scene_render_caches_test.dart',
    ),
  ),
  Invariant(
    id: 'INV-ENG-RENDER-HIT-BOUNDS-PARITY',
    scope: 'engine-runtime',
    title:
        'render hit candidate bounds stay derived from the same render worldBounds contract as core hit-test bounds',
    primaryProof: PrimaryProof(
      path: 'test/render/render_hit_bounds_parity_test.dart',
    ),
  ),
  Invariant(
    id: 'INV-ENG-RENDER-GEOMETRY-KEY-STABLE',
    scope: 'engine-runtime',
    title:
        'render geometry cache keys use canonical public geometry owners instead of linear point scans',
    primaryProof: PrimaryProof(
      path: 'test/render/render_geometry_cache_test.dart',
    ),
  ),
  Invariant(
    id: 'INV-ENG-SCENE-PAINTER-FRAME-RESOLUTION',
    scope: 'engine-structure',
    title:
        'ScenePainterFrameOwner owns one render-local visibility budget, keeps ordinary controller candidate enumeration viewport-first, supplements only selected edge nodes through the budgeted visibility rect, and resolves preview delta plus one canonical ResolvedTextLayout plus geometry only for those candidates before render-local consumers apply final culling',
    primaryProof: PrimaryProof(
      path: 'test/render/scene_painter_frame_contract_test.dart',
    ),
  ),
  Invariant(
    id: 'INV-ENG-SCENE-PAINTER-MODULE-BOUNDARY',
    scope: 'engine-structure',
    title:
        'ScenePainterShell stays orchestration-only and painter-local modules communicate through resolved contracts without part coupling or cache re-entry',
    primaryProof: PrimaryProof(
      path: 'test/render/scene_painter_bounds_contract_test.dart',
    ),
  ),
  Invariant(
    id: 'INV-ENG-SPATIAL-INDEX-REBUILD-ON-INVALID',
    scope: 'engine-runtime',
    title: 'invalid spatial index always transitions to rebuild-required state',
    primaryProof: PrimaryProof(
      path: 'test/controller/internal/spatial_index_cache_test.dart',
    ),
  ),
  Invariant(
    id: 'INV-ENG-TIMESTAMP-MS-MONOTONIC',
    scope: 'engine-runtime',
    title:
        'interactive action timestamps stay monotonic even when caller hints go backwards or are omitted',
    primaryProof: PrimaryProof(
      path:
          'test/interactive/core/scene_controller_interactive_basics_test.dart',
    ),
  ),
  Invariant(
    id: 'INV-ENG-PATH-NODE-CACHE-INVALIDATION',
    scope: 'engine-runtime',
    title:
        'PathNode local-path cache invalidates whenever svgPathData or fillRule changes',
    primaryProof: PrimaryProof(path: 'test/core/nodes_test.dart'),
  ),
  Invariant(
    id: 'INV-ENG-CLEAR-SCENE-RESULT-REMOVED-NODE-IDS-IMMUTABLE',
    scope: 'engine-controller',
    title: 'ClearSceneResult.removedNodeIds is an immutable defensive snapshot',
    primaryProof: PrimaryProof(
      path: 'test/controller/internal/scene_writer_test.dart',
    ),
  ),
  Invariant(
    id: 'INV-G-SELECTION-NORMALIZED',
    scope: 'behavior',
    title:
        'committed selectedNodeIds stay normalized against the current scene interaction policy',
    primaryProof: PrimaryProof(
      path: 'test/controller/scene_invariants_test.dart',
    ),
  ),
  Invariant(
    id: 'INV-G-GRID-ENABLE-CELL-SIZE-RELATION',
    scope: 'behavior',
    title:
        'runtime grid ownership keeps grid.isEnabled compatible with grid.cellSize and rejects invalid enable/size transitions eagerly',
    primaryProof: PrimaryProof(
      path: 'test/controller/scene_invariants_test.dart',
    ),
  ),
  Invariant(
    id: 'INV-ENG-VIEW-RENDER-SURFACE-DEBUG-PROBES',
    scope: 'view-runtime',
    title:
        'debugSceneViewRenderCachesOf is a stable render-surface test probe for cache ownership and mounted-surface fail-fast diagnostics',
    primaryProof: PrimaryProof(path: 'test/view/scene_view_test.dart'),
  ),
  Invariant(
    id: 'INV-ENG-COMMANDS-NO-PART',
    scope: 'controller-structure',
    title: 'controller/commands/** must not use part/part of',
    primaryProof: PrimaryProof(
      path:
          'test/tool/import_boundaries/import_boundaries_controller_structure_tool_test.dart',
    ),
    toolProof: ToolProof(
      enforcementPath: 'tool/check_import_boundaries.dart',
      regressionPath:
          'test/tool/import_boundaries/import_boundaries_controller_structure_tool_test.dart',
    ),
  ),
  Invariant(
    id: 'INV-ENG-COMMANDS-NO-SCENE-CONTROLLER',
    scope: 'controller-structure',
    title: 'controller/commands/** must not import controller entrypoint',
    primaryProof: PrimaryProof(
      path:
          'test/tool/import_boundaries/import_boundaries_controller_structure_tool_test.dart',
    ),
    toolProof: ToolProof(
      enforcementPath: 'tool/check_import_boundaries.dart',
      regressionPath:
          'test/tool/import_boundaries/import_boundaries_controller_structure_tool_test.dart',
    ),
  ),
  Invariant(
    id: 'INV-ENG-COMMANDS-NO-CROSS-IMPORTS',
    scope: 'controller-structure',
    title: 'controller/commands/** must not import other command groups',
    primaryProof: PrimaryProof(
      path:
          'test/tool/import_boundaries/import_boundaries_controller_structure_tool_test.dart',
    ),
    toolProof: ToolProof(
      enforcementPath: 'tool/check_import_boundaries.dart',
      regressionPath:
          'test/tool/import_boundaries/import_boundaries_controller_structure_tool_test.dart',
    ),
  ),
  Invariant(
    id: 'INV-ENG-INTERNAL-NO-SCENE-CONTROLLER',
    scope: 'controller-structure',
    title: 'controller/internal/** must not import controller entrypoint',
    primaryProof: PrimaryProof(
      path:
          'test/tool/import_boundaries/import_boundaries_controller_structure_tool_test.dart',
    ),
    toolProof: ToolProof(
      enforcementPath: 'tool/check_import_boundaries.dart',
      regressionPath:
          'test/tool/import_boundaries/import_boundaries_controller_structure_tool_test.dart',
    ),
  ),
  Invariant(
    id: 'INV-ENG-INTERNAL-NO-COMMANDS-IMPORTS',
    scope: 'controller-structure',
    title: 'controller/internal/** must not import controller/commands/**',
    primaryProof: PrimaryProof(
      path:
          'test/tool/import_boundaries/import_boundaries_controller_structure_tool_test.dart',
    ),
    toolProof: ToolProof(
      enforcementPath: 'tool/check_import_boundaries.dart',
      regressionPath:
          'test/tool/import_boundaries/import_boundaries_controller_structure_tool_test.dart',
    ),
  ),
  Invariant(
    id: 'INV-ENG-SHARED-CONTROLLER-HELPERS',
    scope: 'controller-structure',
    title:
        'shared controller helpers stay in core/** or controller/internal/**',
    primaryProof: PrimaryProof(
      path:
          'test/tool/import_boundaries/import_boundaries_controller_structure_tool_test.dart',
    ),
    toolProof: ToolProof(
      enforcementPath: 'tool/check_import_boundaries.dart',
      regressionPath:
          'test/tool/import_boundaries/import_boundaries_controller_structure_tool_test.dart',
    ),
  ),
  Invariant(
    id: 'INV-SER-JSON-NUMERIC-VALIDATION',
    scope: 'serialization',
    title: 'JSON numeric fields are finite and validated',
    primaryProof: PrimaryProof(
      path: 'test/serialization/scene_codec_validation_test.dart',
    ),
  ),
  Invariant(
    id: 'INV-SER-JSON-GRID-PALETTE-CONTRACTS',
    scope: 'serialization',
    title:
        'JSON scene-metadata contracts are enforced for camera, grid, background, and palette values',
    primaryProof: PrimaryProof(
      path: 'test/serialization/scene_codec_validation_test.dart',
    ),
  ),
  Invariant(
    id: 'INV-SER-SHARED-STROKE-POINT-LIMIT',
    scope: 'model',
    title:
        'stroke point-count invariant is shared across typed, decode, and encode paths',
    primaryProof: PrimaryProof(
      path: 'test/serialization/scene_codec_validation_test.dart',
    ),
  ),
  Invariant(
    id: 'INV-SER-SHARED-PALETTE-ITEM-LIMIT',
    scope: 'model',
    title:
        'palette item-count invariant is shared across typed, decode, and encode paths',
    primaryProof: PrimaryProof(
      path: 'test/serialization/scene_codec_validation_test.dart',
    ),
  ),
  Invariant(
    id: 'INV-SER-TEXT-DIRECTION-EXPLICIT',
    scope: 'model',
    title:
        'text node textDirection is explicit in model/serialization and decode requires it in the current schema',
    primaryProof: PrimaryProof(
      path: 'test/serialization/scene_codec_validation_test.dart',
    ),
  ),
  Invariant(
    id: 'INV-SER-TYPED-LAYER-SPLIT',
    scope: 'serialization',
    title:
        'serialization keeps optional backgroundLayer separate from content layers',
    primaryProof: PrimaryProof(
      path: 'test/serialization/scene_codec_validation_test.dart',
    ),
  ),
  Invariant(
    id: 'INV-SER-CANONICAL-BACKGROUND-LAYER',
    scope: 'serialization',
    title:
        'snapshot/JSON boundaries canonicalize missing backgroundLayer to a single dedicated background layer',
    primaryProof: PrimaryProof(
      path: 'test/serialization/scene_codec_validation_test.dart',
    ),
  ),
  Invariant(
    id: 'INV-SER-SCHEMA-VERSION-CONTRACT',
    scope: 'serialization',
    title:
        'schema write version stays readable and schemaVersion decoding accepts only the declared read set',
    primaryProof: PrimaryProof(
      path: 'test/serialization/scene_codec_validation_test.dart',
    ),
  ),
  Invariant(
    id: 'INV-SER-UNSUPPORTED-SCHEMA-VERSION-CODE',
    scope: 'serialization',
    title:
        'unsupported schemaVersion decode failures report SceneDataErrorCode.unsupportedSchemaVersion',
    primaryProof: PrimaryProof(
      path: 'test/serialization/scene_codec_validation_test.dart',
    ),
  ),
];
