final class RevisionState {
  const RevisionState({
    this.documentRevision = 0,
    this.projectionRevision = 0,
    this.structuralRevision = 0,
  });

  final int documentRevision;
  final int projectionRevision;
  final int structuralRevision;
}
