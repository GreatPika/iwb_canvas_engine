typedef VmOwnershipTerminalPredicate = bool Function(VmRetentionSource source);

final class VmRetentionObservation {
  const VmRetentionObservation({
    required this.targetId,
    required this.retainingPathLength,
    required this.retainingPathRoot,
    required this.retainingPathSources,
    required this.retainingPathComplete,
    required this.retainingPathIncompleteReasons,
    required this.inboundOwnershipPaths,
    required this.inboundTraversalComplete,
    required this.inboundTraversalLimitReasons,
  });

  final String targetId;
  final int retainingPathLength;
  final String retainingPathRoot;
  final List<VmRetentionSource> retainingPathSources;
  final bool retainingPathComplete;
  final List<String> retainingPathIncompleteReasons;
  final List<VmOwnershipPath> inboundOwnershipPaths;
  final bool inboundTraversalComplete;
  final List<String> inboundTraversalLimitReasons;

  Iterable<VmRetentionSource> get inboundOwnershipSources sync* {
    for (final path in inboundOwnershipPaths) {
      yield* path.sources;
    }
  }
}

final class VmOwnershipPath {
  const VmOwnershipPath(this.sources);

  final List<VmRetentionSource> sources;
}

final class VmRetentionSource {
  const VmRetentionSource({
    required this.objectId,
    required this.className,
    required this.libraryUri,
  });

  final String objectId;
  final String className;
  final String libraryUri;
}

final class VmRetentionSourceResolution {
  const VmRetentionSourceResolution.resolved(this.source)
    : incompleteReason = null;

  const VmRetentionSourceResolution.unresolved(this.incompleteReason)
    : source = null;

  final VmRetentionSource? source;
  final String? incompleteReason;
}

final class VmRetainingPathObservation {
  const VmRetainingPathObservation({
    required this.length,
    required this.root,
    required this.sources,
    required this.incompleteReasons,
  });

  final int length;
  final String root;
  final List<VmRetentionSource> sources;
  final List<String> incompleteReasons;
}

final class VmInboundOwnershipTraversal {
  const VmInboundOwnershipTraversal({
    required this.paths,
    required this.limitReasons,
  });

  final List<VmOwnershipPath> paths;
  final List<String> limitReasons;

  bool get complete => limitReasons.isEmpty;
}

final class VmTypedDataInstance {
  const VmTypedDataInstance({
    required this.objectId,
    required this.classId,
    required this.identityHashCode,
    required this.bytes,
  });

  final String objectId;
  final String? classId;
  final int identityHashCode;
  final String? bytes;
}

final class VmTypedDataCensus {
  const VmTypedDataCensus({
    required this.anchor,
    required this.matchingInstances,
  });

  final VmTypedDataInstance anchor;
  final List<VmTypedDataInstance> matchingInstances;
}
