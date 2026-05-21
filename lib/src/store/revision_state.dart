final class RevisionState {
  const RevisionState({
    this.documentRevision = 0,
    this.projectionRevision = 0,
    this.structuralRevision = 0,
    this.boundsRevision = 0,
    this.elementVisualRevision = 0,
    this.backgroundRevision = 0,
    this.gridRevision = 0,
    this.resourceRevision = 0,
  });

  final int documentRevision;
  final int projectionRevision;
  final int structuralRevision;
  final int boundsRevision;
  final int elementVisualRevision;
  final int backgroundRevision;
  final int gridRevision;
  final int resourceRevision;
}
