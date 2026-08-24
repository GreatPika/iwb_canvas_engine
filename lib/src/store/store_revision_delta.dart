import 'revision_state.dart';

// Revision deltas keep the store install contract explicit; the named
// constructors mirror operation-matrix families and are clearer than bit flags
// assembled at call sites.
// ignore: number-of-methods
final class StoreRevisionDelta {
  const StoreRevisionDelta({
    this.document = false,
    this.projection = false,
    this.structural = false,
    this.bounds = false,
    this.elementVisual = false,
    this.background = false,
    this.grid = false,
    this.resource = false,
  });

  const StoreRevisionDelta.structural()
    : this(
        document: true,
        projection: true,
        structural: true,
        bounds: true,
        elementVisual: true,
      );

  const StoreRevisionDelta.layerStructural()
    : this(document: true, projection: true, structural: true);

  const StoreRevisionDelta.elementBounds()
    : this(document: true, projection: true, bounds: true, elementVisual: true);

  const StoreRevisionDelta.elementBoundsOnly()
    : this(document: true, projection: true, bounds: true);

  const StoreRevisionDelta.elementVisual()
    : this(document: true, projection: true, elementVisual: true);

  const StoreRevisionDelta.background()
    : this(document: true, projection: true, background: true);

  const StoreRevisionDelta.grid()
    : this(document: true, projection: true, grid: true);

  const StoreRevisionDelta.resource()
    : this(document: true, projection: true, resource: true);

  const StoreRevisionDelta.projectionOnly()
    : this(document: true, projection: true);

  const StoreRevisionDelta.documentReplacement()
    : this(
        document: true,
        projection: true,
        structural: true,
        bounds: true,
        elementVisual: true,
        background: true,
        grid: true,
        resource: true,
      );

  final bool document;
  final bool projection;
  final bool structural;
  final bool bounds;
  final bool elementVisual;
  final bool background;
  final bool grid;
  final bool resource;

  bool get hasChanges {
    return document ||
        projection ||
        structural ||
        bounds ||
        elementVisual ||
        background ||
        grid ||
        resource;
  }

  StoreRevisionDelta merge(StoreRevisionDelta other) {
    return StoreRevisionDelta(
      document: document || other.document,
      projection: projection || other.projection,
      structural: structural || other.structural,
      bounds: bounds || other.bounds,
      elementVisual: elementVisual || other.elementVisual,
      background: background || other.background,
      grid: grid || other.grid,
      resource: resource || other.resource,
    );
  }

  RevisionState advance(RevisionState current) {
    return RevisionState(
      documentRevision: _advance(current.documentRevision, document),
      projectionRevision: _advance(current.projectionRevision, projection),
      structuralRevision: _advance(current.structuralRevision, structural),
      boundsRevision: _advance(current.boundsRevision, bounds),
      elementVisualRevision: _advance(
        current.elementVisualRevision,
        elementVisual,
      ),
      backgroundRevision: _advance(current.backgroundRevision, background),
      gridRevision: _advance(current.gridRevision, grid),
      resourceRevision: _advance(current.resourceRevision, resource),
    );
  }
}

int _advance(int current, bool changed) => changed ? current + 1 : current;
