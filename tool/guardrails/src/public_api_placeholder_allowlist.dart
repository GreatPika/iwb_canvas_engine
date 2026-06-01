final class PublicApiPlaceholder {
  const PublicApiPlaceholder({
    required this.declarationId,
    required this.ownerPhase,
    required this.reason,
    required this.removalCondition,
  });

  final String declarationId;
  final String ownerPhase;
  final String reason;
  final String removalCondition;
}

const publicApiPlaceholderAllowlist = <PublicApiPlaceholder>[];
