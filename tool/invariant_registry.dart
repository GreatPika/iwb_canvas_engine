/// Canonical list of active project invariants.
///
/// This file is intentionally machine-readable and stable to parse.
/// Tooling uses it to ensure every invariant has at least one enforcement
/// marker in `tool/**` or `test/**`.
///
/// To reference an invariant from a test/tool, add a marker comment:
///   // INV:INV-EXAMPLE
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
    title: 'public entrypoints remain stable (basic/advanced)',
  ),
  Invariant(
    id: 'INV-G-NODEID-UNIQUE',
    scope: 'behavior',
    title: 'NodeId stays unique across all scene layers',
  ),
  Invariant(
    id: 'INV-V2-NO-EXTERNAL-MUTATION',
    scope: 'engine-api',
    title: 'public snapshots/specs do not expose mutable internals',
  ),
  Invariant(
    id: 'INV-V2-WRITE-ONLY-MUTATION',
    scope: 'engine-controller',
    title: 'mutations are routed via write*/txn* APIs',
  ),
  Invariant(
    id: 'INV-V2-TXN-ATOMIC-COMMIT',
    scope: 'engine-controller',
    title: 'transaction commit remains atomic',
  ),
  Invariant(
    id: 'INV-V2-EPOCH-INVALIDATION',
    scope: 'engine-runtime',
    title: 'replace-scene lifecycle preserves epoch invalidation',
  ),
  Invariant(
    id: 'INV-SLICE-NO-PART',
    scope: 'input-slices',
    title: 'input/slices/** must not use part/part of',
  ),
  Invariant(
    id: 'INV-SLICE-NO-SCENE_CONTROLLER',
    scope: 'input-slices',
    title: 'input/slices/** must not import controller entrypoint',
  ),
  Invariant(
    id: 'INV-SLICE-NO-CROSS_SLICE_IMPORTS',
    scope: 'input-slices',
    title: 'input/slices/** must not import other slices',
  ),
  Invariant(
    id: 'INV-INTERNAL-NO-SCENE_CONTROLLER',
    scope: 'input-slices',
    title: 'input/internal/** must not import controller entrypoint',
  ),
  Invariant(
    id: 'INV-INTERNAL-NO-SLICES_IMPORTS',
    scope: 'input-slices',
    title: 'input/internal/** must not import input/slices/**',
  ),
  Invariant(
    id: 'INV-SHARED-INPUT-IN-INTERNAL',
    scope: 'input-slices',
    title: 'shared input helpers stay in core/** or input/internal/**',
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
    id: 'INV-SER-BACKGROUND-SINGLE-AT-ZERO',
    scope: 'serialization',
    title: 'decode canonicalizes single background layer at index 0',
  ),
];
