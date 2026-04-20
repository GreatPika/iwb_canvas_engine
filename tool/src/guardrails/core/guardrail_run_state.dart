import 'guardrail_rule_metadata.dart';
import 'guardrail_violation.dart';

final class GuardrailRunState {
  static const String exportedSurfacesArtifact = 'exportedSurfaces';

  final Map<String, Object> _artifacts = <String, Object>{};
  _ActiveRuleScope? _activeRuleScope;

  Future<T> runWithRuleContract<T>({
    required GuardrailRuleMetadata metadata,
    required Future<T> Function() action,
  }) async {
    final activeScope = _activeRuleScope;
    if (activeScope != null) {
      throw _toolFailure(
        'guardrail rule ${metadata.id} cannot start while '
        '${activeScope.metadata.id} is still active.',
      );
    }

    _ensureDeclaredReadArtifactsExist(metadata);
    final scope = _ActiveRuleScope(metadata: metadata);
    _activeRuleScope = scope;
    try {
      final result = await action();
      _validateConsumedArtifacts(scope);
      return result;
    } finally {
      _activeRuleScope = null;
    }
  }

  void writeArtifact({required String artifactId, required Object value}) {
    final scope = _requireActiveRuleScope();
    if (!scope.metadata.writesStateArtifacts.contains(artifactId)) {
      throw _toolFailure(
        'guardrail rule ${scope.metadata.id} wrote undeclared runner '
        'artifact $artifactId.',
      );
    }
    scope.writtenArtifacts.add(artifactId);
    _artifacts[artifactId] = value;
  }

  T requireArtifact<T>({
    required String artifactId,
    required String readerRuleId,
  }) {
    final scope = _requireActiveRuleScope();
    if (scope.metadata.id != readerRuleId) {
      throw _toolFailure(
        'guardrail rule ${scope.metadata.id} attempted to read runner '
        'artifact $artifactId using mismatched reader id $readerRuleId.',
      );
    }
    if (!scope.metadata.readsStateArtifacts.contains(artifactId)) {
      throw _toolFailure(
        'guardrail rule $readerRuleId read undeclared runner artifact '
        '$artifactId.',
      );
    }
    scope.readArtifacts.add(artifactId);

    final value = _artifacts[artifactId];
    if (value == null) {
      throw _toolFailure(
        'guardrail rule $readerRuleId requires runner artifact $artifactId '
        'before execution.',
      );
    }
    if (value is! T) {
      throw _toolFailure(
        'guardrail rule $readerRuleId expected runner artifact $artifactId '
        'as ${T.toString()}.',
      );
    }
    return value as T;
  }

  void _ensureDeclaredReadArtifactsExist(GuardrailRuleMetadata metadata) {
    for (final artifactId in metadata.readsStateArtifacts) {
      if (_artifacts.containsKey(artifactId)) {
        continue;
      }
      throw _toolFailure(
        'guardrail rule ${metadata.id} declares runner artifact '
        '$artifactId as required input before it exists.',
      );
    }
  }

  void _validateConsumedArtifacts(_ActiveRuleScope scope) {
    final unreadArtifacts = _missingArtifacts(
      declaredArtifacts: scope.metadata.readsStateArtifacts,
      actualArtifacts: scope.readArtifacts,
    );
    if (unreadArtifacts.isNotEmpty) {
      throw _toolFailure(
        'guardrail rule ${scope.metadata.id} declared unread runner '
        'artifacts ${unreadArtifacts.join(', ')}.',
      );
    }

    final unwrittenArtifacts = _missingArtifacts(
      declaredArtifacts: scope.metadata.writesStateArtifacts,
      actualArtifacts: scope.writtenArtifacts,
    );
    if (unwrittenArtifacts.isNotEmpty) {
      throw _toolFailure(
        'guardrail rule ${scope.metadata.id} declared unwritten runner '
        'artifacts ${unwrittenArtifacts.join(', ')}.',
      );
    }
  }

  List<String> _missingArtifacts({
    required List<String> declaredArtifacts,
    required Set<String> actualArtifacts,
  }) {
    return declaredArtifacts
        .where((artifactId) => !actualArtifacts.contains(artifactId))
        .toList(growable: false);
  }

  _ActiveRuleScope _requireActiveRuleScope() {
    final scope = _activeRuleScope;
    if (scope == null) {
      throw _toolFailure(
        'runner artifacts may only be accessed while a guardrail rule is active.',
      );
    }
    return scope;
  }

  GuardrailToolFailure _toolFailure(String message) {
    return GuardrailToolFailure(
      GuardrailViolation(
        filePath: '/tool/src/guardrails/guardrail_rule_inventory.dart',
        line: 1,
        message: 'tool failure: $message',
      ),
    );
  }
}

final class _ActiveRuleScope {
  _ActiveRuleScope({required this.metadata});

  final GuardrailRuleMetadata metadata;
  final Set<String> readArtifacts = <String>{};
  final Set<String> writtenArtifacts = <String>{};
}
