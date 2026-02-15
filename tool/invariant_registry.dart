/// Canonical list of active project invariants.
///
/// This file is intentionally machine-readable and stable to parse.
/// Tooling uses it to ensure every invariant has at least one enforcement
/// marker in `tool/**` or `test/**`.
///
/// Invariant ID naming convention:
/// - Pattern: `INV-<DOMAIN>-<RULE>`
/// - `DOMAIN` is one of: `G`, `ENG`, `SER`
/// - `RULE` uses UPPER-KEBAB-CASE (`A-Z`, `0-9`, `-`)
/// - Do not use underscores in IDs
///
/// To reference an invariant from a test/tool, add a marker comment:
library;

class Invariant {
  const Invariant({required this.id, required this.title, required this.scope});

  final String id;
  final String title;

  /// A short scope label to make reports easier to read.
  final String scope;
}

const List<Invariant> invariants = <Invariant>[
  Invariant(
    id: 'INV-G-CORE-NO-LAYER-DEPS',
    scope: 'layering',
    title: 'core/** must not depend on higher layers',
  ),
  Invariant(
    id: 'INV-G-LAYER-BOUNDARIES',
    scope: 'layering',
    title: 'layer boundaries and import contracts are enforced',
  ),
  Invariant(
    id: 'INV-G-PUBLIC-ENTRYPOINTS',
    scope: 'public-api',
    title:
        'public entrypoint is single iwb_canvas_engine.dart (advanced.dart forbidden)',
  ),
  Invariant(
    id: 'INV-G-NODEID-UNIQUE',
    scope: 'behavior',
    title: 'NodeId stays unique across all scene layers',
  ),
  Invariant(
    id: 'INV-ENG-NO-EXTERNAL-MUTATION',
    scope: 'engine-api',
    title: 'public snapshots/specs do not expose mutable internals',
  ),
  Invariant(
    id: 'INV-ENG-WRITE-ONLY-MUTATION',
    scope: 'engine-controller',
    title: 'mutations are routed via write*/txn* APIs',
  ),
  Invariant(
    id: 'INV-ENG-SAFE-TXN-API',
    scope: 'engine-controller',
    title:
        'public transaction API does not expose mutable scene escape hatches',
  ),
  Invariant(
    id: 'INV-ENG-TXN-WRITER-LIFETIME',
    scope: 'engine-controller',
    title:
        'transaction writer remains valid only during the active write callback',
  ),
  Invariant(
    id: 'INV-ENG-TXN-ATOMIC-COMMIT',
    scope: 'engine-controller',
    title: 'transaction commit remains atomic',
  ),
  Invariant(
    id: 'INV-ENG-TXN-COPY-ON-WRITE',
    scope: 'engine-controller',
    title:
        'transactions use scene/layer/node copy-on-write and avoid full scene deep clone',
  ),
  Invariant(
    id: 'INV-ENG-SIGNALS-AFTER-COMMIT',
    scope: 'engine-controller',
    title:
        'committed signals are delivered only after store commit is finalized',
  ),
  Invariant(
    id: 'INV-ENG-ID-INDEX-FROM-SCENE',
    scope: 'engine-controller',
    title:
        'allNodeIds/nodeLocator match committed scene and nodeIdSeed is monotonic (lower-bounded by scene)',
  ),
  Invariant(
    id: 'INV-ENG-INSTANCE-REVISION-MONOTONIC',
    scope: 'engine-controller',
    title:
        'scene nodes keep instanceRevision >= 1 and nextInstanceRevision stays monotonic (lower-bounded by scene)',
  ),
  Invariant(
    id: 'INV-ENG-WRITE-NUMERIC-GUARDS',
    scope: 'engine-controller',
    title: 'writer rejects non-finite or invalid numeric write inputs',
  ),
  Invariant(
    id: 'INV-ENG-DISPOSE-FAIL-FAST',
    scope: 'engine-controller',
    title:
        'mutating/effectful core APIs fail fast after dispose and keep state/effects unchanged',
  ),
  Invariant(
    id: 'INV-ENG-TEXT-SIZE-DERIVED',
    scope: 'engine-controller',
    title: 'TextNode.size is always derived from text layout inputs',
  ),
  Invariant(
    id: 'INV-ENG-EVENTS-IMMUTABLE',
    scope: 'engine-runtime',
    title: 'published events expose immutable nodeIds/payload snapshots',
  ),
  Invariant(
    id: 'INV-ENG-EPOCH-INVALIDATION',
    scope: 'engine-runtime',
    title: 'replace-scene lifecycle preserves epoch invalidation',
  ),
  Invariant(
    id: 'INV-ENG-RENDER-GEOMETRY-KEY-STABLE',
    scope: 'engine-runtime',
    title:
        'render geometry cache keys use stable scalar/revision inputs (no collection identity)',
  ),
  Invariant(
    id: 'INV-ENG-SPATIAL-INDEX-REBUILD-ON-INVALID',
    scope: 'engine-runtime',
    title: 'invalid spatial index always transitions to rebuild-required state',
  ),
  Invariant(
    id: 'INV-ENG-COMMANDS-NO-PART',
    scope: 'controller-structure',
    title: 'controller/commands/** must not use part/part of',
  ),
  Invariant(
    id: 'INV-ENG-COMMANDS-NO-SCENE_CONTROLLER',
    scope: 'controller-structure',
    title: 'controller/commands/** must not import controller entrypoint',
  ),
  Invariant(
    id: 'INV-ENG-COMMANDS-NO-CROSS_IMPORTS',
    scope: 'controller-structure',
    title: 'controller/commands/** must not import other command groups',
  ),
  Invariant(
    id: 'INV-ENG-INTERNAL-NO-SCENE_CONTROLLER',
    scope: 'controller-structure',
    title: 'controller/internal/** must not import controller entrypoint',
  ),
  Invariant(
    id: 'INV-ENG-INTERNAL-NO-COMMANDS-IMPORTS',
    scope: 'controller-structure',
    title: 'controller/internal/** must not import controller/commands/**',
  ),
  Invariant(
    id: 'INV-ENG-SHARED-CONTROLLER-HELPERS',
    scope: 'controller-structure',
    title:
        'shared controller helpers stay in core/** or controller/internal/**',
  ),
  Invariant(
    id: 'INV-SER-JSON-NUMERIC-VALIDATION',
    scope: 'serialization',
    title: 'JSON numeric fields are finite and validated',
  ),
  Invariant(
    id: 'INV-SER-JSON-GRID-PALETTE-CONTRACTS',
    scope: 'serialization',
    title: 'JSON grid/palette contracts are enforced',
  ),
  Invariant(
    id: 'INV-SER-TYPED-LAYER-SPLIT',
    scope: 'serialization',
    title:
        'serialization keeps optional backgroundLayer separate from content layers',
  ),
  Invariant(
    id: 'INV-SER-CANONICAL-BACKGROUND-LAYER',
    scope: 'serialization',
    title:
        'snapshot/JSON boundaries canonicalize missing backgroundLayer to a single dedicated background layer',
  ),
];
