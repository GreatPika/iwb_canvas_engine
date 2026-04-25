/// Canonical list of active project invariants.
///
/// This file is intentionally machine-readable and stable to parse.
/// Tooling uses it as the single source of truth for invariant ids and their
/// role-based proof surfaces.
///
/// Invariant ID naming convention:
/// - Pattern: `INV-<DOMAIN>-<RULE>`
/// - `DOMAIN` is one of: `G`, `ENG`, `SER`
/// - `RULE` uses UPPER-KEBAB-CASE (`A-Z`, `0-9`, `-`)
/// - Underscores are forbidden in ids
///
/// Proof contract:
/// - every invariant declares one or more `requiredProofs`
/// - `requiredProofs.path` must point to an executable `test/**/*_test.dart`
///   or a top-level `tool/*.dart` proof surface
/// - every `requiredProofs.stepId` must reference a real verification step
///   reachable from `required_code_change`
/// - `regressionProofs.path` must point to an executable
///   `test/**/*_test.dart` regression surface
/// - every declared proof file must contain a matching `// INV:<id>` marker
/// - navigation markers outside declared proof surfaces are allowed, but they
///   do not count as invariant coverage on their own
library;

class Invariant {
  const Invariant({
    required this.id,
    required this.scope,
    required this.title,
    required this.requiredProofs,
    this.regressionProofs = const <RegressionProof>[],
  });

  final String id;
  final String scope;
  final String title;
  final List<RequiredProof> requiredProofs;
  final List<RegressionProof> regressionProofs;
}

class RequiredProof {
  const RequiredProof({required this.path, required this.stepId});

  final String path;
  final String stepId;
}

class RegressionProof {
  const RegressionProof({required this.path});

  final String path;
}

const List<Invariant> invariants = <Invariant>[
  Invariant(
    id: 'INV-G-LAYER-DAG',
    scope: 'layering',
    title: 'lib/src layer DAG is explicit and enforced',
    requiredProofs: <RequiredProof>[
      RequiredProof(
        path: 'tool/check_import_boundaries.dart',
        stepId: 'import_boundaries',
      ),
    ],
    regressionProofs: <RegressionProof>[
      RegressionProof(
        path:
            'test/tool/import_boundaries/import_boundaries_layer_dag_tool_test.dart',
      ),
    ],
  ),
  Invariant(
    id: 'INV-G-LAYER-BOUNDARIES',
    scope: 'layering',
    title: 'layer boundaries and import contracts are enforced',
    requiredProofs: <RequiredProof>[
      RequiredProof(
        path: 'tool/check_import_boundaries.dart',
        stepId: 'import_boundaries',
      ),
    ],
    regressionProofs: <RegressionProof>[
      RegressionProof(
        path:
            'test/tool/import_boundaries/import_boundaries_layout_tool_test.dart',
      ),
    ],
  ),
  Invariant(
    id: 'INV-G-PUBLIC-ENTRYPOINTS',
    scope: 'public-api',
    title:
        'public entrypoint is single iwb_canvas_engine.dart and exported top-level symbol set stays stable (advanced.dart forbidden)',
    requiredProofs: <RequiredProof>[
      RequiredProof(
        path: 'tool/check_public_api_surface.dart',
        stepId: 'public_api_surface',
      ),
    ],
    regressionProofs: <RegressionProof>[
      RegressionProof(
        path:
            'test/tool/guardrails/guardrails_layout_and_entrypoints_tool_test.dart',
      ),
    ],
  ),
  Invariant(
    id: 'INV-G-NODEID-UNIQUE',
    scope: 'behavior',
    title: 'NodeId stays unique across all scene layers',
    requiredProofs: <RequiredProof>[
      RequiredProof(
        path: 'test/controller/scene_invariants_test.dart',
        stepId: 'scope_controller',
      ),
    ],
  ),
  Invariant(
    id: 'INV-G-LAYERID-UNIQUE',
    scope: 'behavior',
    title: 'LayerId stays unique across content layers',
    requiredProofs: <RequiredProof>[
      RequiredProof(
        path: 'test/controller/scene_invariants_test.dart',
        stepId: 'scope_controller',
      ),
    ],
  ),
  Invariant(
    id: 'INV-G-LAYER-Z-ORDER-BY-LIST',
    scope: 'behavior',
    title: 'content layer z-order is defined by scene.layers list order',
    requiredProofs: <RequiredProof>[
      RequiredProof(path: 'test/core/hit_test_test.dart', stepId: 'scope_core'),
    ],
  ),
  Invariant(
    id: 'INV-ENG-NO-EXTERNAL-MUTATION',
    scope: 'engine-api',
    title: 'public snapshots/specs do not expose mutable internals',
    requiredProofs: <RequiredProof>[
      RequiredProof(
        path: 'test/public_api/snapshot_immutability_test.dart',
        stepId: 'scope_model_contract',
      ),
    ],
  ),
  Invariant(
    id: 'INV-ENG-PUBLIC-SNAPSHOT-GLOBAL-VALIDITY',
    scope: 'engine-api',
    title:
        'public SceneSnapshot remains the canonical document boundary, ordinary public construction is globally valid by construction, and raw malformed snapshot assembly stays internal-only',
    requiredProofs: <RequiredProof>[
      RequiredProof(
        path: 'test/public_api/validated_boundary_value_test.dart',
        stepId: 'scope_model_contract',
      ),
    ],
  ),
  Invariant(
    id: 'INV-ENG-SHARED-SCENE-METADATA-CONTRACT',
    scope: 'engine-api',
    title:
        'scene metadata values use one eager contract across public constructors, runtime owners, and import/decode paths, while raw malformed metadata assembly stays internal-only',
    requiredProofs: <RequiredProof>[
      RequiredProof(
        path: 'test/public_api/validated_boundary_value_test.dart',
        stepId: 'scope_model_contract',
      ),
    ],
  ),
  Invariant(
    id: 'INV-ENG-WRITE-ONLY-MUTATION',
    scope: 'engine-controller',
    title: 'mutations are routed via write*/txn* APIs',
    requiredProofs: <RequiredProof>[
      RequiredProof(path: 'tool/check_guardrails.dart', stepId: 'guardrails'),
    ],
    regressionProofs: <RegressionProof>[
      RegressionProof(
        path: 'test/tool/guardrails/guardrails_controller_api_tool_test.dart',
      ),
    ],
  ),
  Invariant(
    id: 'INV-ENG-CONTROLLER-NO-FULL-VIEW-RENDER-STATE',
    scope: 'engine-structure',
    title:
        'SceneStoreController remains committed-store-only on the read side, while SceneViewMainSceneRenderRead and SceneViewOverlayPreviewRead stay assembled on the interactive runtime path',
    requiredProofs: <RequiredProof>[
      RequiredProof(
        path: 'test/contract/runtime_contract_interfaces_test.dart',
        stepId: 'scope_model_contract',
      ),
      RequiredProof(path: 'tool/check_guardrails.dart', stepId: 'guardrails'),
    ],
    regressionProofs: <RegressionProof>[
      RegressionProof(
        path: 'test/tool/guardrails/guardrails_controller_api_tool_test.dart',
      ),
    ],
  ),
  Invariant(
    id: 'INV-ENG-SAFE-TXN-API',
    scope: 'engine-controller',
    title:
        'public transaction API and exported contract members do not expose scene escape hatches or signal/internal materialization helpers',
    requiredProofs: <RequiredProof>[
      RequiredProof(path: 'tool/check_guardrails.dart', stepId: 'guardrails'),
    ],
    regressionProofs: <RegressionProof>[
      RegressionProof(
        path: 'test/tool/guardrails/guardrails_public_surface_tool_test.dart',
      ),
    ],
  ),
  Invariant(
    id: 'INV-ENG-PREPARED-REPLACE-SCENE-BOUNDARY-HERMETICITY',
    scope: 'engine-controller',
    title:
        'prepared replace-scene payloads stay controller-private, while controller and interactive replace-scene boundaries expose only single-verb snapshot entrypoints',
    requiredProofs: <RequiredProof>[
      RequiredProof(path: 'tool/check_guardrails.dart', stepId: 'guardrails'),
    ],
    regressionProofs: <RegressionProof>[
      RegressionProof(
        path: 'test/tool/guardrails/guardrails_controller_api_tool_test.dart',
      ),
      RegressionProof(
        path: 'test/tool/guardrails/guardrails_interactive_api_tool_test.dart',
      ),
    ],
  ),
  Invariant(
    id: 'INV-ENG-PUBLIC-SURFACE-NO-MUTABLE-TYPES',
    scope: 'engine-api',
    title:
        'exported public contract and runtime signatures do not expose mutable core or runtime owner types',
    requiredProofs: <RequiredProof>[
      RequiredProof(path: 'tool/check_guardrails.dart', stepId: 'guardrails'),
    ],
    regressionProofs: <RegressionProof>[
      RegressionProof(
        path:
            'test/tool/guardrails/guardrails_public_signature_hermeticity_tool_test.dart',
      ),
    ],
  ),
  Invariant(
    id: 'INV-ENG-PUBLIC-SIGNATURE-HERMETICITY',
    scope: 'engine-api',
    title:
        'exported public signatures do not expose internal, non-exported, or forbidden mutable boundary types',
    requiredProofs: <RequiredProof>[
      RequiredProof(path: 'tool/check_guardrails.dart', stepId: 'guardrails'),
    ],
    regressionProofs: <RegressionProof>[
      RegressionProof(
        path:
            'test/tool/guardrails/guardrails_public_signature_hermeticity_tool_test.dart',
      ),
    ],
  ),
  Invariant(
    id: 'INV-ENG-TXN-WRITER-LIFETIME',
    scope: 'engine-controller',
    title:
        'transaction writer remains valid only during the active write callback',
    requiredProofs: <RequiredProof>[
      RequiredProof(
        path:
            'test/controller/core/scene_controller_writer_lifecycle_test.dart',
        stepId: 'scope_controller',
      ),
    ],
  ),
  Invariant(
    id: 'INV-ENG-TXN-ATOMIC-COMMIT',
    scope: 'engine-controller',
    title: 'transaction commit remains atomic',
    requiredProofs: <RequiredProof>[
      RequiredProof(
        path:
            'test/controller/core/scene_controller_commit_atomicity_test.dart',
        stepId: 'scope_controller',
      ),
    ],
  ),
  Invariant(
    id: 'INV-ENG-COMMITTED-SELECTION-REVISION-ALIGNMENT',
    scope: 'engine-controller',
    title:
        'committed selectionRevision changes only when committed selection membership changes, and both remain aligned at the controller commit boundary',
    requiredProofs: <RequiredProof>[
      RequiredProof(
        path: 'test/controller/scene_invariants_test.dart',
        stepId: 'scope_controller',
      ),
    ],
  ),
  Invariant(
    id: 'INV-ENG-TXN-FINALIZED-BEFORE-COMMIT-PLAN',
    scope: 'engine-controller',
    title:
        'transaction state is finalized before commit planning and before the write callback regains control',
    requiredProofs: <RequiredProof>[
      RequiredProof(
        path:
            'test/controller/core/scene_controller_writer_lifecycle_test.dart',
        stepId: 'scope_controller',
      ),
    ],
  ),
  Invariant(
    id: 'INV-ENG-TXN-COPY-ON-WRITE',
    scope: 'engine-controller',
    title:
        'transactions use scene/layer/node copy-on-write and avoid full scene deep clone',
    requiredProofs: <RequiredProof>[
      RequiredProof(
        path:
            'test/controller/core/scene_controller_commit_atomicity_test.dart',
        stepId: 'scope_controller',
      ),
    ],
  ),
  Invariant(
    id: 'INV-ENG-WRITE-PROTOCOL',
    scope: 'engine-controller',
    title:
        'write(...) rejects nested writes, async callbacks, and dispose during the active callback without poisoning later writes',
    requiredProofs: <RequiredProof>[
      RequiredProof(
        path:
            'test/controller/core/scene_controller_writer_lifecycle_test.dart',
        stepId: 'scope_controller',
      ),
    ],
  ),
  Invariant(
    id: 'INV-ENG-SIGNALS-AFTER-COMMIT',
    scope: 'engine-controller',
    title:
        'committed signals are delivered only after store commit is finalized',
    requiredProofs: <RequiredProof>[
      RequiredProof(
        path:
            'test/controller/core/scene_controller_signals_delivery_test.dart',
        stepId: 'scope_controller',
      ),
    ],
  ),
  Invariant(
    id: 'INV-ENG-ID-INDEX-FROM-SCENE',
    scope: 'engine-controller',
    title:
        'allNodeIds/nodeLocator match committed scene and id-generator counters stay monotonic (lower-bounded by scene)',
    requiredProofs: <RequiredProof>[
      RequiredProof(
        path: 'test/controller/scene_invariants_test.dart',
        stepId: 'scope_controller',
      ),
    ],
  ),
  Invariant(
    id: 'INV-ENG-INSTANCE-REVISION-MONOTONIC',
    scope: 'engine-controller',
    title:
        'scene nodes keep instanceRevision >= 1 and committed runtime revision state stays within the composite epoch/revision contract',
    requiredProofs: <RequiredProof>[
      RequiredProof(
        path: 'test/controller/scene_invariants_test.dart',
        stepId: 'scope_controller',
      ),
    ],
  ),
  Invariant(
    id: 'INV-ENG-WRITE-NUMERIC-GUARDS',
    scope: 'engine-controller',
    title:
        'writer rejects invalid numeric writes instead of clamping or repair-normalizing them later',
    requiredProofs: <RequiredProof>[
      RequiredProof(
        path: 'test/controller/internal/scene_writer_test.dart',
        stepId: 'scope_controller_internal',
      ),
    ],
  ),
  Invariant(
    id: 'INV-ENG-RUNTIME-SCENE-STRUCTURE-OWNER',
    scope: 'engine-controller',
    title:
        'runtime content-layer and node-budget enforcement stays model-owned, and controller code must not reintroduce direct scene.layers add/insert ownership',
    requiredProofs: <RequiredProof>[
      RequiredProof(
        path: 'test/controller/internal/change_set_txn_context_test.dart',
        stepId: 'scope_controller_internal',
      ),
      RequiredProof(path: 'tool/check_guardrails.dart', stepId: 'guardrails'),
    ],
    regressionProofs: <RegressionProof>[
      RegressionProof(
        path:
            'test/tool/guardrails/guardrails_model_architecture_tool_test.dart',
      ),
    ],
  ),
  Invariant(
    id: 'INV-ENG-COMMITTED-STORE-METADATA-CONTRACT',
    scope: 'engine-controller',
    title:
        'committed-store invariant sweeps enforce the shared runtime scene metadata contract for camera, grid, and palette values',
    requiredProofs: <RequiredProof>[
      RequiredProof(
        path: 'test/controller/scene_invariants_test.dart',
        stepId: 'scope_controller',
      ),
    ],
  ),
  Invariant(
    id: 'INV-ENG-RUNTIME-SCENE-VALIDITY-BACKSTOP',
    scope: 'engine-controller',
    title:
        'the committed-store invariant gate rejects invalid runtime scene candidates before store apply, while the release critical path stays scoped to changed runtime surfaces',
    requiredProofs: <RequiredProof>[
      RequiredProof(
        path: 'test/controller/core/scene_controller_commit_failures_test.dart',
        stepId: 'scope_controller',
      ),
    ],
  ),
  Invariant(
    id: 'INV-ENG-STROKE-RUNTIME-GEOMETRY-OWNER',
    scope: 'engine-core',
    title:
        'runtime stroke geometry stays hermetic: StrokeNode.points is read-only, StrokeNode.replacePoints owns pointsRevision updates, and public SceneSnapshot/JSON document boundaries do not carry runtime stroke revision metadata',
    requiredProofs: <RequiredProof>[
      RequiredProof(path: 'test/core/nodes_test.dart', stepId: 'scope_core'),
    ],
  ),
  Invariant(
    id: 'INV-ENG-PALETTE-RUNTIME-VALUE-OWNER',
    scope: 'engine-core',
    title:
        'runtime palette state is replacement-only: Scene.palette stays replaceable, while ScenePalette defensively copies and freezes nested lists after construction',
    requiredProofs: <RequiredProof>[
      RequiredProof(
        path: 'test/model/document_model_test.dart',
        stepId: 'scope_model_contract',
      ),
    ],
  ),
  Invariant(
    id: 'INV-ENG-RUNTIME-NODE-VALUE-OWNERS',
    scope: 'engine-core',
    title:
        'constrained runtime node fields mutate only through validated owners, and patch-based writes inherit the same boundary contract',
    requiredProofs: <RequiredProof>[
      RequiredProof(
        path: 'test/model/document_model_test.dart',
        stepId: 'scope_model_contract',
      ),
      RequiredProof(path: 'tool/check_guardrails.dart', stepId: 'guardrails'),
    ],
    regressionProofs: <RegressionProof>[
      RegressionProof(
        path:
            'test/tool/guardrails/guardrails_model_architecture_tool_test.dart',
      ),
    ],
  ),
  Invariant(
    id: 'INV-ENG-DISPOSE-FAIL-FAST',
    scope: 'engine-controller',
    title:
        'mutating/effectful core APIs fail fast after dispose and keep state/effects unchanged',
    requiredProofs: <RequiredProof>[
      RequiredProof(
        path:
            'test/controller/core/scene_controller_core_dispose_fail_fast_test.dart',
        stepId: 'scope_controller',
      ),
    ],
  ),
  Invariant(
    id: 'INV-ENG-CONTROLLER-COMMIT-RUNTIME-BOUNDARY',
    scope: 'engine-structure',
    title:
        'SceneStoreController stays a thin public facade over SceneControllerCommitRuntime and does not re-own commit planning or post-commit helpers',
    requiredProofs: <RequiredProof>[
      RequiredProof(
        path:
            'test/controller/core/scene_controller_commit_runtime_contract_test.dart',
        stepId: 'scope_controller',
      ),
    ],
  ),
  Invariant(
    id: 'INV-ENG-SCENE-WRITE-TXN-ADAPTER-BOUNDARY',
    scope: 'engine-structure',
    title:
        'public write callbacks consume only the dedicated SceneWriteTxn adapter while SceneWriter remains the internal transactional owner',
    requiredProofs: <RequiredProof>[
      RequiredProof(
        path:
            'test/controller/internal/scene_write_txn_public_adapter_test.dart',
        stepId: 'scope_controller_internal',
      ),
    ],
  ),
  Invariant(
    id: 'INV-ENG-TEXT-SIZE-DERIVED',
    scope: 'engine-controller',
    title:
        'text bounds are derived from layout inputs and never cross typed or JSON boundaries as stored size data',
    requiredProofs: <RequiredProof>[
      RequiredProof(
        path:
            'test/controller/core/scene_controller_commit_atomicity_test.dart',
        stepId: 'scope_controller',
      ),
    ],
  ),
  Invariant(
    id: 'INV-ENG-EVENTS-IMMUTABLE',
    scope: 'engine-runtime',
    title: 'published events expose immutable nodeIds/payload snapshots',
    requiredProofs: <RequiredProof>[
      RequiredProof(
        path: 'test/core/action_events_test.dart',
        stepId: 'scope_core',
      ),
    ],
  ),
  Invariant(
    id: 'INV-ENG-CORE-ARCHITECTURE-BOUNDARY',
    scope: 'engine-structure',
    title:
        'core node-family, node-support, and leaf-support owners remain structurally split after step 37 closure',
    requiredProofs: <RequiredProof>[
      RequiredProof(path: 'test/core/nodes_test.dart', stepId: 'scope_core'),
    ],
  ),
  Invariant(
    id: 'INV-ENG-INTERACTIVE-ASYNC-DELIVERY',
    scope: 'engine-runtime',
    title:
        'interactive actions/editTextRequests are asynchronous; interactive listener notifications are microtask-deferred and coalesced per event-loop tick',
    requiredProofs: <RequiredProof>[
      RequiredProof(
        path:
            'test/interactive/core/scene_controller_interactive_basics_test.dart',
        stepId: 'scope_interactive',
      ),
    ],
  ),
  Invariant(
    id: 'INV-ENG-INTERACTIVE-PUBLIC-LISTENER-REPAINT-INDEPENDENCE',
    scope: 'engine-runtime',
    title:
        'interactive public listener delivery stays aligned with public state changes regardless of whether internal repaint routes through the scene or overlay channel',
    requiredProofs: <RequiredProof>[
      RequiredProof(
        path:
            'test/interactive/core/scene_controller_public_listener_contract_test.dart',
        stepId: 'scope_interactive',
      ),
    ],
  ),
  Invariant(
    id: 'INV-ENG-INTERACTIVE-HANDLE-POINTER-NON-REENTRANT',
    scope: 'engine-runtime',
    title:
        'public handlePointer(...) rejects same-stack reentrancy and unwinds cleanly after the active dispatch returns',
    requiredProofs: <RequiredProof>[
      RequiredProof(
        path:
            'test/interactive/core/scene_controller_interactive_basics_test.dart',
        stepId: 'scope_interactive',
      ),
    ],
  ),
  Invariant(
    id: 'INV-ENG-INTERACTIVE-POINTER-FINITE',
    scope: 'engine-runtime',
    title:
        'interactive pointer entrypoints drop non-finite down/move input and preserve terminal up/cancel only when a last finite pointer position exists',
    requiredProofs: <RequiredProof>[
      RequiredProof(
        path:
            'test/interactive/core/scene_controller_interactive_invalid_pointer_input_test.dart',
        stepId: 'scope_interactive',
      ),
    ],
  ),
  Invariant(
    id: 'INV-ENG-POINTER-SETTINGS-VALIDATION',
    scope: 'engine-runtime',
    title:
        'pointer input settings reject non-finite/negative thresholds at runtime boundaries',
    requiredProofs: <RequiredProof>[
      RequiredProof(
        path: 'test/core/pointer_input_test.dart',
        stepId: 'scope_core',
      ),
    ],
  ),
  Invariant(
    id: 'INV-ENG-INTERACTIVE-SINGLE-ACTIVE-POINTER',
    scope: 'engine-runtime',
    title:
        'interactive gestures keep a single active pointer and ignore parallel pointer ids until gesture end',
    requiredProofs: <RequiredProof>[
      RequiredProof(
        path:
            'test/interactive/core/scene_controller_interactive_single_pointer_policy_test.dart',
        stepId: 'scope_interactive',
      ),
    ],
  ),
  Invariant(
    id: 'INV-ENG-INTERACTIVE-GESTURE-BUFFER-SOFT-CAP',
    scope: 'engine-runtime',
    title:
        'interactive stroke/eraser active gesture buffers are soft-capped with endpoint-preserving pruning and validated limits',
    requiredProofs: <RequiredProof>[
      RequiredProof(
        path:
            'test/interactive/core/scene_controller_interactive_guardrails_stroke_test.dart',
        stepId: 'scope_interactive',
      ),
    ],
  ),
  Invariant(
    id: 'INV-ENG-INTERACTIVE-CANCEL-STATE-RESET',
    scope: 'engine-runtime',
    title:
        'interactive pointer cancel resets active gesture state (preview/pending buffers) without committing scene mutations',
    requiredProofs: <RequiredProof>[
      RequiredProof(
        path:
            'test/interactive/core/scene_controller_interactive_move_preview_invariants_test.dart',
        stepId: 'scope_interactive',
      ),
    ],
  ),
  Invariant(
    id: 'INV-ENG-INTERACTIVE-INTERRUPTION-SEMANTICS',
    scope: 'engine-runtime',
    title:
        'interactive interruption and owning-session teardown remain distinct non-committing lifecycle reasons that release preview/baseline state without widening the pointer-cancel-specific contract',
    requiredProofs: <RequiredProof>[
      RequiredProof(
        path:
            'test/interactive/core/scene_controller_interactive_move_preview_invariants_test.dart',
        stepId: 'scope_interactive',
      ),
    ],
  ),
  Invariant(
    id: 'INV-ENG-INTERACTIVE-PREVIEW-COMMIT-ON-UP',
    scope: 'engine-runtime',
    title:
        'interactive move/draw preview remains ephemeral and does not mutate committed scene before pointer up commit',
    requiredProofs: <RequiredProof>[
      RequiredProof(
        path:
            'test/interactive/core/scene_controller_interactive_move_preview_invariants_test.dart',
        stepId: 'scope_interactive',
      ),
    ],
  ),
  Invariant(
    id: 'INV-ENG-INTERACTIVE-RESOLVER-PURITY',
    scope: 'engine-runtime',
    title:
        'moveCommitDeltaResolver cannot call public stateful/effectful interactive controller entrypoints',
    requiredProofs: <RequiredProof>[
      RequiredProof(
        path:
            'test/interactive/core/scene_controller_interactive_actions_effects_test.dart',
        stepId: 'scope_interactive',
      ),
      RequiredProof(path: 'tool/check_guardrails.dart', stepId: 'guardrails'),
    ],
    regressionProofs: <RegressionProof>[
      RegressionProof(
        path: 'test/tool/guardrails/guardrails_interactive_api_tool_test.dart',
      ),
    ],
  ),
  Invariant(
    id: 'INV-ENG-INTERACTIVE-MOVE-COMMIT-RESOLVER-NON-REENTRANT',
    scope: 'engine-runtime',
    title:
        'moveCommitDeltaResolver rejects reentrancy and always clears resolver-owned gesture state after failure before the next gesture starts',
    requiredProofs: <RequiredProof>[
      RequiredProof(
        path:
            'test/interactive/core/scene_controller_interactive_actions_effects_test.dart',
        stepId: 'scope_interactive',
      ),
    ],
  ),
  Invariant(
    id: 'INV-ENG-INTERACTIVE-PUBLIC-MUTATION-EXCLUSIVITY',
    scope: 'engine-runtime',
    title:
        'public controller.selection.* and controller.scene.* mutations stay gesture-exclusive during active move/draw ownership except setCameraOffset(...) and replaceScene(...), which reset only after preflight confirms the boundary mutation will proceed',
    requiredProofs: <RequiredProof>[
      RequiredProof(
        path:
            'test/interactive/core/scene_controller_interactive_single_pointer_policy_test.dart',
        stepId: 'scope_interactive',
      ),
    ],
  ),
  Invariant(
    id: 'INV-ENG-INTERACTIVE-ARCHITECTURE-BOUNDARY',
    scope: 'engine-runtime',
    title:
        'interactive composition, capability, runtime, event, and write-side owners remain structurally split; SceneController stays a thin public facade over the graph handle, the interaction owner uses explicit constructor dependencies instead of an access bag, and move preview exits only through InteractiveMovePreviewRead without a runtime move-session leak',
    requiredProofs: <RequiredProof>[
      RequiredProof(
        path:
            'test/interactive/core/scene_controller_architecture_boundary_test.dart',
        stepId: 'scope_interactive',
      ),
      RequiredProof(path: 'tool/check_guardrails.dart', stepId: 'guardrails'),
    ],
    regressionProofs: <RegressionProof>[
      RegressionProof(
        path: 'test/tool/guardrails/guardrails_interactive_api_tool_test.dart',
      ),
    ],
  ),
  Invariant(
    id: 'INV-ENG-INTERACTIVE-MUTATION-BOUNDARY',
    scope: 'engine-runtime',
    title:
        'SceneControllerMutationBoundary remains the only interactive owner that performs committed scene/selection/draw writes and clear/delete action projection, while committed mutation access owns replace-scene boundary sequencing and direct public/runtime callers route into that boundary without intermediate shells',
    requiredProofs: <RequiredProof>[
      RequiredProof(
        path:
            'test/interactive/core/scene_controller_mutation_boundary_test.dart',
        stepId: 'scope_interactive',
      ),
      RequiredProof(path: 'tool/check_guardrails.dart', stepId: 'guardrails'),
    ],
    regressionProofs: <RegressionProof>[
      RegressionProof(
        path: 'test/tool/guardrails/guardrails_interactive_api_tool_test.dart',
      ),
    ],
  ),
  Invariant(
    id: 'INV-ENG-MODEL-ARCHITECTURE-BOUNDARY',
    scope: 'engine-structure',
    title:
        'model facade/internal-owner boundaries remain part-free, internal draft/import owners stay model-only, and downstream code imports only canonical model facades',
    requiredProofs: <RequiredProof>[
      RequiredProof(path: 'tool/check_guardrails.dart', stepId: 'guardrails'),
    ],
    regressionProofs: <RegressionProof>[
      RegressionProof(
        path:
            'test/tool/guardrails/guardrails_model_architecture_tool_test.dart',
      ),
    ],
  ),
  Invariant(
    id: 'INV-ENG-VALIDATED-IMPORT-MATERIALIZATION-BOUNDARY',
    scope: 'engine-structure',
    title:
        'scene import materialization accepts only ValidatedSceneImportDraft, ScenePolicy remains the only import-proof minting owner, and validated import/draft validation paths stay off raw snapshot materialization',
    requiredProofs: <RequiredProof>[
      RequiredProof(path: 'tool/check_guardrails.dart', stepId: 'guardrails'),
    ],
    regressionProofs: <RegressionProof>[
      RegressionProof(
        path:
            'test/tool/guardrails/guardrails_model_architecture_tool_test.dart',
      ),
    ],
  ),
  Invariant(
    id: 'INV-ENG-CONTRACT-ARCHITECTURE-BOUNDARY',
    scope: 'engine-structure',
    title:
        'contract layer remains part-free, snapshot/spec/patch families keep validated-only helper surfaces with separate unsafe raw owners, and downstream non-contract code imports only canonical contract surfaces',
    requiredProofs: <RequiredProof>[
      RequiredProof(path: 'tool/check_guardrails.dart', stepId: 'guardrails'),
    ],
    regressionProofs: <RegressionProof>[
      RegressionProof(
        path:
            'test/tool/guardrails/guardrails_contract_architecture_tool_test.dart',
      ),
    ],
  ),
  Invariant(
    id: 'INV-ENG-BOUNDARY-HERMETIC-CONCRETE-TYPES',
    scope: 'engine-api',
    title:
        'public boundary admission canonicalizes supported values to exact built-in contract types and rejects unsupported subtypes before the strict fallback/backing seams, which still reject non-exact boundary runtime types',
    requiredProofs: <RequiredProof>[
      RequiredProof(
        path: 'test/contract/validated_fast_path_contract_test.dart',
        stepId: 'scope_model_contract',
      ),
    ],
  ),
  Invariant(
    id: 'INV-ENG-VIEW-POINTER-SLOT-LIFECYCLE',
    scope: 'view-runtime',
    title:
        'SceneView pointer-slot allocator releases slots on up/cancel, including terminal dispatch exceptions, and reuses the minimum free slot id',
    requiredProofs: <RequiredProof>[
      RequiredProof(
        path: 'test/view/scene_view_pointer_router_test.dart',
        stepId: 'scope_render_view',
      ),
    ],
  ),
  Invariant(
    id: 'INV-ENG-VIEW-ACTIVE-POINTER-GATE',
    scope: 'view-runtime',
    title:
        'SceneView pointer signal tracking gates by a single active pointer and releases gate on up/cancel',
    requiredProofs: <RequiredProof>[
      RequiredProof(
        path: 'test/view/scene_view_pointer_router_test.dart',
        stepId: 'scope_render_view',
      ),
    ],
  ),
  Invariant(
    id: 'INV-ENG-VIEW-POINTER-SETTINGS-LIVE-APPLY',
    scope: 'view-runtime',
    title:
        'SceneView keeps pointer-settings live-apply behavior on the same controller, including idle terminal release after dispatch exceptions, without re-owning tracker/pending-setting state in the host shell',
    requiredProofs: <RequiredProof>[
      RequiredProof(
        path: 'test/view/scene_view_interactive_test.dart',
        stepId: 'scope_render_view',
      ),
    ],
  ),
  Invariant(
    id: 'INV-ENG-INTERACTIVE-POINTER-SESSION-LIFECYCLE',
    scope: 'engine-runtime',
    title:
        'interactive runtime owns live pointer-session epoch reset and disposal deactivation, while same-session tap tracking remains session-local and terminal cleanup stays exception-safe across the view host/session boundary',
    requiredProofs: <RequiredProof>[
      RequiredProof(
        path:
            'test/interactive/core/scene_controller_interaction_contract_test.dart',
        stepId: 'scope_interactive',
      ),
      RequiredProof(
        path: 'test/view/scene_view_interactive_test.dart',
        stepId: 'scope_render_view',
      ),
      RequiredProof(path: 'tool/check_guardrails.dart', stepId: 'guardrails'),
    ],
    regressionProofs: <RegressionProof>[
      RegressionProof(
        path: 'test/tool/guardrails/guardrails_interactive_api_tool_test.dart',
      ),
    ],
  ),
  Invariant(
    id: 'INV-ENG-INTERACTIVE-DRAW-STYLE-SNAPSHOT',
    scope: 'engine-runtime',
    title:
        'active draw preview and pending two-tap line state use gesture-start style snapshots with owner-scoped pending-line provenance',
    requiredProofs: <RequiredProof>[
      RequiredProof(
        path:
            'test/interactive/core/scene_controller_interactive_line_tool_flow_test.dart',
        stepId: 'scope_interactive',
      ),
    ],
  ),
  Invariant(
    id: 'INV-ENG-VIEW-RUNTIME-HOST-DEBUG-PROBES',
    scope: 'view-runtime',
    title:
        'debugSceneViewInteractive* and debugSceneViewRuntimeHost* helpers are stable test probes for runtime-host cache and raw-pointer diagnostics and fail fast outside the mounted host boundary',
    requiredProofs: <RequiredProof>[
      RequiredProof(
        path: 'test/view/scene_view_interactive_test.dart',
        stepId: 'scope_render_view',
      ),
    ],
  ),
  Invariant(
    id: 'INV-ENG-VIEW-POINTER-SESSION-DETACH',
    scope: 'view-runtime',
    title:
        'SceneView runtime hosts detach opaque pointer sessions before dispose or router reset, and detach remains the terminal controller-unbind step before idempotent dispose',
    requiredProofs: <RequiredProof>[
      RequiredProof(
        path: 'test/view/scene_view_interactive_test.dart',
        stepId: 'scope_render_view',
      ),
    ],
  ),
  Invariant(
    id: 'INV-ENG-VIEW-POINTER-SEMANTICS-BOUNDARY',
    scope: 'engine-structure',
    title:
        'SceneView reaches interactive only through SceneViewRuntime, and only scene_view_interactive.dart may adapt SceneController into that runtime boundary',
    requiredProofs: <RequiredProof>[
      RequiredProof(
        path: 'tool/check_import_boundaries.dart',
        stepId: 'import_boundaries',
      ),
    ],
    regressionProofs: <RegressionProof>[
      RegressionProof(
        path:
            'test/tool/import_boundaries/import_boundaries_layer_dag_tool_test.dart',
      ),
    ],
  ),
  Invariant(
    id: 'INV-ENG-VIEW-RENDER-READ-STATE-BOUNDARY',
    scope: 'engine-structure',
    title:
        'interactive view/render shell files consume one assembled SceneViewRuntime boundary, route SceneViewMainSceneRenderRead only to the render surface, route SceneViewOverlayPreviewRead only to overlay consumers, and do not reopen concrete-controller seams through view/**',
    requiredProofs: <RequiredProof>[
      RequiredProof(
        path:
            'test/interactive/core/scene_controller_architecture_boundary_test.dart',
        stepId: 'scope_interactive',
      ),
      RequiredProof(path: 'tool/check_guardrails.dart', stepId: 'guardrails'),
    ],
    regressionProofs: <RegressionProof>[
      RegressionProof(
        path: 'test/tool/guardrails/guardrails_interactive_api_tool_test.dart',
      ),
    ],
  ),
  Invariant(
    id: 'INV-ENG-EPOCH-INVALIDATION',
    scope: 'engine-runtime',
    title: 'replace-scene lifecycle preserves epoch invalidation',
    requiredProofs: <RequiredProof>[
      RequiredProof(
        path: 'test/render/scene_render_caches_test.dart',
        stepId: 'scope_render_view',
      ),
    ],
  ),
  Invariant(
    id: 'INV-ENG-PERFORMANCE-PROOF-CONTOUR',
    scope: 'engine-runtime',
    title:
        'required performance proof stays deterministic on committed spatial and render owners, while diagnostic benchmark policy remains a regression surface',
    requiredProofs: <RequiredProof>[
      RequiredProof(
        path: 'test/controller/internal/spatial_index_cache_test.dart',
        stepId: 'scope_controller_internal',
      ),
      RequiredProof(
        path: 'test/render/scene_render_caches_test.dart',
        stepId: 'scope_render_view',
      ),
      RequiredProof(
        path: 'test/render/scene_painter_test.dart',
        stepId: 'scope_render_view',
      ),
      RequiredProof(
        path: 'test/render/scene_painter_bounds_contract_test.dart',
        stepId: 'scope_render_view',
      ),
    ],
    regressionProofs: <RegressionProof>[
      RegressionProof(path: 'test/tool/bench_diff_load_profiles_test.dart'),
      RegressionProof(path: 'test/tool/bench_run_load_profiles_test.dart'),
    ],
  ),
  Invariant(
    id: 'INV-ENG-RENDER-HIT-BOUNDS-PARITY',
    scope: 'engine-runtime',
    title:
        'render hit candidate bounds stay derived from the same render worldBounds contract as core hit-test bounds',
    requiredProofs: <RequiredProof>[
      RequiredProof(
        path: 'test/render/render_hit_bounds_parity_test.dart',
        stepId: 'scope_render_view',
      ),
    ],
  ),
  Invariant(
    id: 'INV-ENG-RENDER-GEOMETRY-KEY-STABLE',
    scope: 'engine-runtime',
    title:
        'render geometry cache keys use canonical public geometry owners instead of linear point scans',
    requiredProofs: <RequiredProof>[
      RequiredProof(
        path: 'test/render/render_geometry_cache_test.dart',
        stepId: 'scope_render_view',
      ),
    ],
  ),
  Invariant(
    id: 'INV-ENG-RENDER-CACHE-SCAN-RESISTANT',
    scope: 'engine-runtime',
    title:
        'hot render caches share one scan-resistant retention owner so stable ordered over-capacity scans keep steady-state reuse',
    requiredProofs: <RequiredProof>[
      RequiredProof(
        path: 'test/render/scene_render_caches_test.dart',
        stepId: 'scope_render_view',
      ),
      RequiredProof(
        path: 'test/render/render_cache_policy_contract_test.dart',
        stepId: 'scope_render_view',
      ),
    ],
    regressionProofs: <RegressionProof>[
      RegressionProof(path: 'test/render/render_geometry_cache_test.dart'),
      RegressionProof(path: 'test/render/scene_text_layout_cache_test.dart'),
      RegressionProof(path: 'test/render/scene_stroke_path_cache_test.dart'),
      RegressionProof(path: 'test/render/scene_path_metrics_cache_test.dart'),
    ],
  ),
  Invariant(
    id: 'INV-ENG-SELECTION-BOUNDED-COMPOSITING',
    scope: 'engine-runtime',
    title:
        'main-scene selection halo compositing keeps masked halo semantics while every halo saveLayer uses geometry-derived non-null tight bounds on the render owner seam',
    requiredProofs: <RequiredProof>[
      RequiredProof(
        path: 'test/render/scene_painter_bounds_contract_test.dart',
        stepId: 'scope_render_view',
      ),
    ],
    regressionProofs: <RegressionProof>[
      RegressionProof(path: 'test/render/scene_painter_test.dart'),
    ],
  ),
  Invariant(
    id: 'INV-ENG-GRID-BOUNDED-ITERATION',
    scope: 'engine-runtime',
    title:
        'dense grid rendering uses one bounded axis plan so planned work, draw work, and static-cache recorded work stay aligned on the render owner seam',
    requiredProofs: <RequiredProof>[
      RequiredProof(
        path: 'test/render/scene_grid_renderer_contract_test.dart',
        stepId: 'scope_render_view',
      ),
    ],
    regressionProofs: <RegressionProof>[
      RegressionProof(path: 'test/render/scene_grid_renderer_test.dart'),
      RegressionProof(path: 'test/render/scene_static_layer_cache_test.dart'),
    ],
  ),
  Invariant(
    id: 'INV-ENG-SCENE-PAINTER-FRAME-RESOLUTION',
    scope: 'engine-structure',
    title:
        'ScenePainter captures one atomic frame read, keeps one frame snapshot authority plus one frozen frame-preview authority distinct from the live public controller preview seam, carries controller-owned selectionRevision invalidation with that frame read, uses controller-owned viewport-first ordinary paint admission only while the active frame snapshot matches the committed controller snapshot, widens admission only for selected-node supplements, preserves background/content paint order regardless of supplement source, deduplicates node emission once per frame, culls by paint bounds before render resolution, and falls back to active-frame enumeration when the committed snapshot diverges',
    requiredProofs: <RequiredProof>[
      RequiredProof(
        path: 'test/render/scene_painter_frame_contract_test.dart',
        stepId: 'scope_render_view',
      ),
      RequiredProof(
        path: 'test/render/scene_painter_bounds_contract_test.dart',
        stepId: 'scope_render_view',
      ),
    ],
    regressionProofs: <RegressionProof>[
      RegressionProof(path: 'test/render/scene_painter_test.dart'),
    ],
  ),
  Invariant(
    id: 'INV-ENG-PAINT-ADMISSION-BOUNDS-SOURCE',
    scope: 'engine-runtime',
    title:
        'paint-candidate admission consumes explicit committed or snapshot-local paint-bounds sources, keeping text layout and SVG path parsing out of admission modules while render geometry resolves later',
    requiredProofs: <RequiredProof>[
      RequiredProof(
        path: 'test/render/scene_painter_bounds_contract_test.dart',
        stepId: 'scope_render_view',
      ),
      RequiredProof(
        path: 'test/render/scene_painter_frame_contract_test.dart',
        stepId: 'scope_render_view',
      ),
      RequiredProof(
        path: 'test/core/snapshot_paint_admission_bounds_test.dart',
        stepId: 'scope_core',
      ),
    ],
    regressionProofs: <RegressionProof>[
      RegressionProof(path: 'test/tool/bench_run_load_profiles_test.dart'),
    ],
  ),
  Invariant(
    id: 'INV-ENG-SCENE-PAINTER-MODULE-BOUNDARY',
    scope: 'engine-structure',
    title:
        'ScenePainterShell stays orchestration-only and painter-local modules communicate through resolved contracts without part coupling or cache re-entry',
    requiredProofs: <RequiredProof>[
      RequiredProof(
        path: 'test/render/scene_painter_bounds_contract_test.dart',
        stepId: 'scope_render_view',
      ),
    ],
  ),
  Invariant(
    id: 'INV-ENG-SPATIAL-INDEX-REBUILD-ON-INVALID',
    scope: 'engine-runtime',
    title: 'invalid spatial index always transitions to rebuild-required state',
    requiredProofs: <RequiredProof>[
      RequiredProof(
        path: 'test/controller/internal/spatial_index_cache_test.dart',
        stepId: 'scope_controller_internal',
      ),
    ],
  ),
  Invariant(
    id: 'INV-ENG-COMMITTED-SPATIAL-ADMISSION-ALIGNMENT',
    scope: 'engine-runtime',
    title:
        'committed mutation dirty-tracking and committed spatial storage share one coarse spatial admission contract',
    requiredProofs: <RequiredProof>[
      RequiredProof(
        path:
            'test/controller/internal/node_mutation_spatial_admission_contract_test.dart',
        stepId: 'scope_controller_internal',
      ),
      RequiredProof(
        path: 'test/controller/core/scene_controller_spatial_index_test.dart',
        stepId: 'scope_controller',
      ),
    ],
  ),
  Invariant(
    id: 'INV-ENG-TIMESTAMP-MS-MONOTONIC',
    scope: 'engine-runtime',
    title:
        'interactive action timestamps stay monotonic even when caller hints go backwards or are omitted',
    requiredProofs: <RequiredProof>[
      RequiredProof(
        path:
            'test/interactive/core/scene_controller_interactive_basics_test.dart',
        stepId: 'scope_interactive',
      ),
    ],
  ),
  Invariant(
    id: 'INV-ENG-PATH-NODE-CACHE-INVALIDATION',
    scope: 'engine-runtime',
    title:
        'PathNode local-path cache invalidates whenever svgPathData or fillRule changes',
    requiredProofs: <RequiredProof>[
      RequiredProof(path: 'test/core/nodes_test.dart', stepId: 'scope_core'),
    ],
  ),
  Invariant(
    id: 'INV-ENG-CLEAR-SCENE-RESULT-REMOVED-NODE-IDS-IMMUTABLE',
    scope: 'engine-controller',
    title: 'ClearSceneResult.removedNodeIds is an immutable defensive snapshot',
    requiredProofs: <RequiredProof>[
      RequiredProof(
        path: 'test/controller/internal/scene_writer_test.dart',
        stepId: 'scope_controller_internal',
      ),
    ],
  ),
  Invariant(
    id: 'INV-G-SELECTION-NORMALIZED',
    scope: 'behavior',
    title:
        'committed selectedNodeIds stay normalized against the current scene interaction policy',
    requiredProofs: <RequiredProof>[
      RequiredProof(
        path: 'test/controller/scene_invariants_test.dart',
        stepId: 'scope_controller',
      ),
    ],
  ),
  Invariant(
    id: 'INV-G-GRID-ENABLE-CELL-SIZE-RELATION',
    scope: 'behavior',
    title:
        'runtime grid ownership keeps grid.isEnabled compatible with grid.cellSize and rejects invalid enable/size transitions eagerly',
    requiredProofs: <RequiredProof>[
      RequiredProof(
        path: 'test/controller/scene_invariants_test.dart',
        stepId: 'scope_controller',
      ),
    ],
  ),
  Invariant(
    id: 'INV-ENG-VIEW-RENDER-SURFACE-DEBUG-PROBES',
    scope: 'view-runtime',
    title:
        'debugSceneViewRenderCachesOf is a stable render-surface test probe for cache ownership and mounted-surface fail-fast diagnostics',
    requiredProofs: <RequiredProof>[
      RequiredProof(
        path: 'test/view/scene_view_test.dart',
        stepId: 'scope_render_view',
      ),
    ],
  ),
  Invariant(
    id: 'INV-ENG-COMMANDS-NO-PART',
    scope: 'controller-structure',
    title: 'controller/commands/** must not use part/part of',
    requiredProofs: <RequiredProof>[
      RequiredProof(
        path: 'tool/check_import_boundaries.dart',
        stepId: 'import_boundaries',
      ),
    ],
    regressionProofs: <RegressionProof>[
      RegressionProof(
        path:
            'test/tool/import_boundaries/import_boundaries_controller_structure_tool_test.dart',
      ),
    ],
  ),
  Invariant(
    id: 'INV-ENG-COMMANDS-NO-SCENE-CONTROLLER',
    scope: 'controller-structure',
    title: 'controller/commands/** must not import controller entrypoint',
    requiredProofs: <RequiredProof>[
      RequiredProof(
        path: 'tool/check_import_boundaries.dart',
        stepId: 'import_boundaries',
      ),
    ],
    regressionProofs: <RegressionProof>[
      RegressionProof(
        path:
            'test/tool/import_boundaries/import_boundaries_controller_structure_tool_test.dart',
      ),
    ],
  ),
  Invariant(
    id: 'INV-ENG-COMMANDS-NO-CROSS-IMPORTS',
    scope: 'controller-structure',
    title: 'controller/commands/** must not import other command groups',
    requiredProofs: <RequiredProof>[
      RequiredProof(
        path: 'tool/check_import_boundaries.dart',
        stepId: 'import_boundaries',
      ),
    ],
    regressionProofs: <RegressionProof>[
      RegressionProof(
        path:
            'test/tool/import_boundaries/import_boundaries_controller_structure_tool_test.dart',
      ),
    ],
  ),
  Invariant(
    id: 'INV-ENG-INTERNAL-NO-SCENE-CONTROLLER',
    scope: 'controller-structure',
    title: 'controller/internal/** must not import controller entrypoint',
    requiredProofs: <RequiredProof>[
      RequiredProof(
        path: 'tool/check_import_boundaries.dart',
        stepId: 'import_boundaries',
      ),
    ],
    regressionProofs: <RegressionProof>[
      RegressionProof(
        path:
            'test/tool/import_boundaries/import_boundaries_controller_structure_tool_test.dart',
      ),
    ],
  ),
  Invariant(
    id: 'INV-ENG-INTERNAL-NO-COMMANDS-IMPORTS',
    scope: 'controller-structure',
    title: 'controller/internal/** must not import controller/commands/**',
    requiredProofs: <RequiredProof>[
      RequiredProof(
        path: 'tool/check_import_boundaries.dart',
        stepId: 'import_boundaries',
      ),
    ],
    regressionProofs: <RegressionProof>[
      RegressionProof(
        path:
            'test/tool/import_boundaries/import_boundaries_controller_structure_tool_test.dart',
      ),
    ],
  ),
  Invariant(
    id: 'INV-ENG-SHARED-CONTROLLER-HELPERS',
    scope: 'controller-structure',
    title:
        'shared controller helpers stay in core/** or controller/internal/**',
    requiredProofs: <RequiredProof>[
      RequiredProof(
        path: 'tool/check_import_boundaries.dart',
        stepId: 'import_boundaries',
      ),
    ],
    regressionProofs: <RegressionProof>[
      RegressionProof(
        path:
            'test/tool/import_boundaries/import_boundaries_controller_structure_tool_test.dart',
      ),
    ],
  ),
  Invariant(
    id: 'INV-SER-JSON-NUMERIC-VALIDATION',
    scope: 'serialization',
    title: 'JSON numeric fields are finite and validated',
    requiredProofs: <RequiredProof>[
      RequiredProof(
        path: 'test/serialization/scene_codec_validation_test.dart',
        stepId: 'scope_model_contract',
      ),
    ],
  ),
  Invariant(
    id: 'INV-SER-IMPORT-DIAGNOSTIC-SURFACE',
    scope: 'serialization',
    title:
        'import/build entrypoints select one model-owned diagnostic path surface so JSON line/stroke range failures keep localA/localB/localPoints while typed snapshots keep start/end/points',
    requiredProofs: <RequiredProof>[
      RequiredProof(
        path: 'test/public_api/scene_builder_test.dart',
        stepId: 'scope_model_contract',
      ),
      RequiredProof(
        path: 'test/model/scene_validation_path_surface_contract_test.dart',
        stepId: 'scope_model_contract',
      ),
    ],
    regressionProofs: <RegressionProof>[
      RegressionProof(
        path:
            'test/tool/guardrails/guardrails_model_architecture_tool_test.dart',
      ),
    ],
  ),
  Invariant(
    id: 'INV-SER-JSON-GRID-PALETTE-CONTRACTS',
    scope: 'serialization',
    title:
        'JSON scene-metadata contracts are enforced for camera, grid, background, and palette values',
    requiredProofs: <RequiredProof>[
      RequiredProof(
        path: 'test/serialization/scene_codec_validation_test.dart',
        stepId: 'scope_model_contract',
      ),
    ],
  ),
  Invariant(
    id: 'INV-SER-SHARED-STROKE-POINT-LIMIT',
    scope: 'model',
    title:
        'stroke point-count invariant is shared across typed, decode, and encode paths',
    requiredProofs: <RequiredProof>[
      RequiredProof(
        path: 'test/serialization/scene_codec_validation_test.dart',
        stepId: 'scope_model_contract',
      ),
    ],
  ),
  Invariant(
    id: 'INV-SER-SHARED-PALETTE-ITEM-LIMIT',
    scope: 'model',
    title:
        'palette item-count invariant is shared across typed, decode, and encode paths',
    requiredProofs: <RequiredProof>[
      RequiredProof(
        path: 'test/serialization/scene_codec_validation_test.dart',
        stepId: 'scope_model_contract',
      ),
    ],
  ),
  Invariant(
    id: 'INV-SER-TEXT-DIRECTION-EXPLICIT',
    scope: 'model',
    title:
        'text node textDirection is explicit in model/serialization and decode requires it in the current schema',
    requiredProofs: <RequiredProof>[
      RequiredProof(
        path: 'test/serialization/scene_codec_validation_test.dart',
        stepId: 'scope_model_contract',
      ),
    ],
  ),
  Invariant(
    id: 'INV-SER-TYPED-LAYER-SPLIT',
    scope: 'serialization',
    title:
        'serialization keeps optional backgroundLayer separate from content layers',
    requiredProofs: <RequiredProof>[
      RequiredProof(
        path: 'test/serialization/scene_codec_validation_test.dart',
        stepId: 'scope_model_contract',
      ),
    ],
  ),
  Invariant(
    id: 'INV-SER-CANONICAL-BACKGROUND-LAYER',
    scope: 'serialization',
    title:
        'snapshot/JSON boundaries canonicalize missing backgroundLayer to a single dedicated background layer',
    requiredProofs: <RequiredProof>[
      RequiredProof(
        path: 'test/serialization/scene_codec_validation_test.dart',
        stepId: 'scope_model_contract',
      ),
    ],
  ),
  Invariant(
    id: 'INV-SER-SCHEMA-VERSION-CONTRACT',
    scope: 'serialization',
    title:
        'schema write version stays readable and schemaVersion decoding accepts only the declared read set',
    requiredProofs: <RequiredProof>[
      RequiredProof(
        path: 'test/serialization/scene_codec_validation_test.dart',
        stepId: 'scope_model_contract',
      ),
    ],
  ),
  Invariant(
    id: 'INV-SER-UNSUPPORTED-SCHEMA-VERSION-CODE',
    scope: 'serialization',
    title:
        'unsupported schemaVersion decode failures report SceneDataErrorCode.unsupportedSchemaVersion',
    requiredProofs: <RequiredProof>[
      RequiredProof(
        path: 'test/serialization/scene_codec_validation_test.dart',
        stepId: 'scope_model_contract',
      ),
    ],
  ),
  Invariant(
    id: 'INV-ENG-COMMITTED-READ-SIDE-HERMETICITY',
    scope: 'engine-controller',
    title:
        'committed read-side controller and interactive callback contracts expose immutable snapshots/request objects instead of live runtime scene graph types or raw callback-parameter collection leaks, shared paint admission includes backgroundLayer, hit-test admission stays content-only, every committed query candidate shape is resolvable through the paired snapshot helper surface, and stale committed spatial candidates from older structural revisions are rejected before location lookup',
    requiredProofs: <RequiredProof>[
      RequiredProof(path: 'tool/check_guardrails.dart', stepId: 'guardrails'),
    ],
    regressionProofs: <RegressionProof>[
      RegressionProof(
        path: 'test/tool/guardrails/guardrails_controller_api_tool_test.dart',
      ),
      RegressionProof(
        path:
            'test/tool/guardrails/guardrails_public_signature_hermeticity_tool_test.dart',
      ),
      RegressionProof(
        path:
            'test/controller/core/scene_controller_spatial_candidate_resolution_test.dart',
      ),
    ],
  ),
];
