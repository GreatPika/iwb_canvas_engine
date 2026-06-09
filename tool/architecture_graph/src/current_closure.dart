import 'actual_graph.dart';
import 'architecture_graph.dart';

const _ownerPathPrefixes = {
  'api': ['lib/src/api/', 'lib/iwb_canvas_engine.dart'],
  'contracts_public': ['lib/src/contracts/public/'],
  'contracts_internal': ['lib/src/contracts/internal/'],
  'codec': ['lib/src/codec/'],
  'diagnostics': ['lib/src/diagnostics/'],
  'runtime': ['lib/src/runtime/'],
  'store': ['lib/src/store/'],
  'selection': ['lib/src/selection/'],
  'edit': ['lib/src/edit/'],
  'load_document': ['lib/src/edit/staged_document_load.dart'],
  'resource': ['lib/src/resources/'],
  'spatial': ['lib/src/geometry/'],
  'frame': ['lib/src/frame/'],
  'interaction': ['lib/src/interaction/'],
  'surface': ['lib/src/surface/'],
  'release': ['tool/', 'docs/verification/'],
};

const _architectureSeamSuffixes = [
  'Root',
  'Kernel',
  'Hub',
  'Resolver',
  'Pipeline',
  'Index',
  'Renderer',
  'Engine',
  'Surface',
  'Runtime',
  'Seam',
  'Coordinator',
];

final class ArchitectureClosureViolation {
  const ArchitectureClosureViolation({
    required this.graphId,
    required this.expectedFact,
    required this.actualEvidence,
    required this.path,
    required this.status,
    required this.message,
  });

  final String graphId;
  final String expectedFact;
  final String actualEvidence;
  final String path;
  final String status;
  final String message;
}

final class ArchitectureClosureReport {
  const ArchitectureClosureReport({required this.violations});

  final List<ArchitectureClosureViolation> violations;

  bool get isClosed => violations.isEmpty;
}

ArchitectureClosureReport checkArchitectureClosure({
  required ExpectedArchitectureGraph expected,
  required ActualArchitectureGraph actual,
}) {
  return _ArchitectureClosureRun(expected: expected, actual: actual).check();
}

String formatArchitectureClosureReport(ArchitectureClosureReport report) {
  if (report.isClosed) {
    return 'Architecture graph closure passed.';
  }
  final buffer = StringBuffer()
    ..writeln('Architecture graph closure failed.')
    ..writeln('Violations: ${report.violations.length}');
  for (final violation in report.violations) {
    buffer
      ..writeln()
      ..writeln('[${violation.graphId}] ${violation.status}')
      ..writeln('path: ${violation.path}')
      ..writeln('expected: ${violation.expectedFact}')
      ..writeln('actual: ${violation.actualEvidence}')
      ..writeln('message: ${violation.message}');
  }

  return buffer.toString();
}

final class _ArchitectureClosureRun {
  _ArchitectureClosureRun({
    required ExpectedArchitectureGraph expected,
    required ActualArchitectureGraph actual,
  }) : context = _ArchitectureClosureContext(
         expected: expected,
         actual: actual,
       );

  final _ArchitectureClosureContext context;

  ArchitectureClosureReport check() {
    _RequiredObligationRule(context).check();
    _ForbiddenEdgeRule(context).check();
    _PlaceholderRule(context).check();
    _UnknownArchitectureDeclarationRule(context).check();

    return ArchitectureClosureReport(violations: context.violations);
  }
}

final class _ArchitectureClosureContext {
  _ArchitectureClosureContext({required this.expected, required this.actual})
    : matcher = _ExpectationEvidenceMatcher(expected: expected, actual: actual);

  final ExpectedArchitectureGraph expected;
  final ActualArchitectureGraph actual;
  final _ExpectationEvidenceMatcher matcher;
  final List<ArchitectureClosureViolation> violations = [];

  void add(ArchitectureClosureViolation violation) => violations.add(violation);

  ArchitectureNode? node(String id) {
    for (final node in expected.nodes) {
      if (node.id == id) {
        return node;
      }
    }

    return null;
  }
}

final class _RequiredObligationRule {
  const _RequiredObligationRule(this.context);

  final _ArchitectureClosureContext context;

  void check() {
    _nodes();
    _edges();
  }

  void _nodes() {
    for (final node in context.expected.nodes) {
      final missing = context.matcher.missingForNode(node);
      if (missing.isEmpty) {
        continue;
      }
      context.add(
        ArchitectureClosureViolation(
          graphId: node.id,
          expectedFact: 'required node ${node.label}',
          actualEvidence: 'missing ${missing.join(', ')}',
          path: node.sourceDocs.first.path,
          status: 'missing_required_node',
          message: 'Required architecture node is not implemented.',
        ),
      );
    }
  }

  void _edges() {
    for (final edge in context.expected.edges) {
      final missing = context.matcher.missingForEdge(edge);
      if (missing.isEmpty) {
        continue;
      }
      context.add(
        ArchitectureClosureViolation(
          graphId: edge.id,
          expectedFact: '${edge.from} ${edge.kind} ${edge.to}',
          actualEvidence: 'missing ${missing.join(', ')}',
          path: edge.sourceDocs.first.path,
          status: 'missing_required_edge',
          message: 'Required architecture edge is not implemented.',
        ),
      );
    }
  }
}

final class _ForbiddenEdgeRule {
  const _ForbiddenEdgeRule(this.context);

  final _ArchitectureClosureContext context;

  void check() {
    for (final edge in context.expected.forbiddenEdges) {
      final fromNode = context.node(edge.from);
      final toNode = context.node(edge.to);
      if (fromNode == null || toNode == null) {
        continue;
      }
      _forbiddenImports(edge, fromNode, toNode);
    }
  }

  void _forbiddenImports(
    ArchitectureForbiddenEdge edge,
    ArchitectureNode fromNode,
    ArchitectureNode toNode,
  ) {
    for (final fact in context.actual.imports.where((fact) {
      return _factMatchesNode(fact.path, fromNode) &&
          _uriMatchesNode(fact.uri, toNode);
    })) {
      context.add(
        ArchitectureClosureViolation(
          graphId: edge.id,
          expectedFact: '${edge.from} must not import ${edge.to}',
          actualEvidence: '${fact.path}:${fact.line} imports ${fact.uri}',
          path: fact.path,
          status: 'forbidden_edge',
          message: 'Forbidden architecture dependency is present.',
        ),
      );
    }
  }
}

final class _PlaceholderRule {
  const _PlaceholderRule(this.context);

  final _ArchitectureClosureContext context;

  void check() {
    final expectedByMember = {
      for (final placeholder in context.expected.placeholders)
        placeholder.member: placeholder,
    };
    for (final fact in context.actual.placeholders) {
      final placeholder = expectedByMember[fact.member];
      if (placeholder == null) {
        _untracked(fact);
      } else {
        _tracked(placeholder, fact);
      }
    }
  }

  void _untracked(PlaceholderFact fact) {
    context.add(
      ArchitectureClosureViolation(
        graphId: 'placeholder.untracked.${fact.member}',
        expectedFact: 'public placeholder has graph-owned deferral',
        actualEvidence: '${fact.path}:${fact.line} throws ${fact.throwType}',
        path: fact.path,
        status: 'untracked_placeholder',
        message: 'Public placeholder is not owned by the expected graph.',
      ),
    );
  }

  void _tracked(ArchitecturePlaceholder placeholder, PlaceholderFact fact) {
    _currentPlaceholder(placeholder, fact);
  }

  void _currentPlaceholder(
    ArchitecturePlaceholder placeholder,
    PlaceholderFact fact,
  ) {
    context.add(
      ArchitectureClosureViolation(
        graphId: placeholder.id,
        expectedFact: '${placeholder.member} implemented in current closure',
        actualEvidence: '${fact.path}:${fact.line} throws ${fact.throwType}',
        path: fact.path,
        status: 'current_placeholder',
        message: 'Public placeholder remains in production code.',
      ),
    );
  }
}

final class _UnknownArchitectureDeclarationRule {
  const _UnknownArchitectureDeclarationRule(this.context);

  final _ArchitectureClosureContext context;

  void check() {
    final expectedDeclarations = {
      for (final node in context.expected.nodes) ...node.actual.declarations,
    };
    for (final fact in context.actual.declarations) {
      if (!_isUnknownArchitectureDeclaration(fact, expectedDeclarations)) {
        continue;
      }
      context.add(
        ArchitectureClosureViolation(
          graphId: 'architecture.unknown.${fact.name}',
          expectedFact:
              'architecture declaration is represented in expected graph',
          actualEvidence: '${fact.path}:${fact.line} declares ${fact.name}',
          path: fact.path,
          status: 'unknown_architecture_seam',
          message: 'Covered architecture owner declaration is not graph-owned.',
        ),
      );
    }
  }

  bool _isUnknownArchitectureDeclaration(
    DeclarationFact fact,
    Set<String> expectedDeclarations,
  ) {
    return _isArchitectureOwnerPath(fact.path, context.expected) &&
        fact.kind == 'class' &&
        !fact.name.startsWith('_') &&
        _isArchitectureSeamDeclaration(fact.name) &&
        !expectedDeclarations.contains(fact.name);
  }
}

final class _ExpectationEvidenceMatcher {
  const _ExpectationEvidenceMatcher({
    required this.expected,
    required this.actual,
  });

  final ExpectedArchitectureGraph expected;
  final ActualArchitectureGraph actual;

  List<String> missingForNode(ArchitectureNode node) {
    return _MissingExpectationCollector(
      actual: actual,
      expectation: node.actual,
      fromNode: node,
      matchNode: (path) => _factMatchesNode(path, node),
    ).collect();
  }

  List<String> missingForEdge(ArchitectureEdge edge) {
    return _MissingExpectationCollector(
      actual: actual,
      expectation: edge.actual,
      fromNode: _node(edge.from),
      matchNode: (path) => _matchesFromNode(path, _node(edge.from)),
    ).collect();
  }

  ArchitectureNode? _node(String id) {
    for (final node in expected.nodes) {
      if (node.id == id) {
        return node;
      }
    }

    return null;
  }
}

final class _MissingExpectationCollector {
  const _MissingExpectationCollector({
    required this.actual,
    required this.expectation,
    required this.fromNode,
    required this.matchNode,
  }) : ownerMatcher = const _ExpectationOwnerMatcher();

  final ActualArchitectureGraph actual;
  final ActualExpectation expectation;
  final ArchitectureNode? fromNode;
  final bool Function(String path) matchNode;
  final _ExpectationOwnerMatcher ownerMatcher;

  List<String> collect() {
    final missing = <String>[];
    _declarations(missing);
    _exports(missing);
    _imports(missing);
    _interfaces(missing);
    _composition(missing);
    _delegations(missing);
    _sensitiveThrowOwner(missing);
    missing.addAll(
      _SensitiveThrowExpectationMatcher(
        actual: actual,
        expectation: expectation,
        fromNode: fromNode,
      ).missingRoutes(),
    );

    return missing;
  }

  void _declarations(List<String> missing) {
    for (final declaration in expectation.declarations) {
      if (!actual.declarations.any((fact) {
        return matchNode(fact.path) && fact.name == declaration;
      })) {
        missing.add('declaration:$declaration');
      }
    }
  }

  void _exports(List<String> missing) {
    for (final export in expectation.exports) {
      if (!actual.exports.any((fact) {
        return matchNode(fact.path) && fact.uri == export;
      })) {
        missing.add('export:$export');
      }
    }
  }

  void _imports(List<String> missing) {
    for (final import in expectation.imports) {
      if (!actual.imports.any((fact) {
        return matchNode(fact.path) && fact.uri == import;
      })) {
        missing.add('import:$import');
      }
    }
  }

  void _interfaces(List<String> missing) {
    for (final interface in expectation.implementedInterfaces) {
      if (!actual.implementedInterfaces.any((fact) {
        return ownerMatcher.interfaceMatches(fact, fromNode) &&
            fact.interface == interface;
      })) {
        missing.add('implements:$interface');
      }
    }
  }

  void _composition(List<String> missing) {
    for (final field in expectation.compositionFields) {
      if (!actual.compositionFields.any((fact) {
        return ownerMatcher.compositionMatches(fact, fromNode) &&
            fact.type == field;
      })) {
        missing.add('composition:$field');
      }
    }
  }

  void _delegations(List<String> missing) {
    for (final target in expectation.delegationTargets) {
      if (!actual.delegations.any((fact) {
        return ownerMatcher.delegationMatches(fact, fromNode) &&
            _delegationMemberMatches(fact) &&
            fact.targetType == target;
      })) {
        missing.add('delegation:$target');
      }
    }
  }

  void _sensitiveThrowOwner(List<String> missing) {
    final sensitiveOwner = expectation.sensitiveThrowOwner;
    if (sensitiveOwner != null &&
        !actual.exceptionThrows.any((fact) {
          return matchNode(fact.path) && fact.owner == sensitiveOwner;
        })) {
      missing.add('sensitiveThrowOwner:$sensitiveOwner');
    }
  }

  bool _delegationMemberMatches(DelegationFact fact) {
    return expectation.delegationMembers.isEmpty ||
        expectation.delegationMembers.contains(fact.member);
  }
}

final class _ExpectationOwnerMatcher {
  const _ExpectationOwnerMatcher();

  bool compositionMatches(
    CompositionFieldFact fact,
    ArchitectureNode? fromNode,
  ) {
    return _matchesFromDeclaration(
      path: fact.path,
      declaration: fact.declaration,
      node: fromNode,
    );
  }

  bool delegationMatches(DelegationFact fact, ArchitectureNode? fromNode) {
    final declaration = fact.member.contains('.')
        ? fact.member.split('.').first
        : fact.member;

    return _matchesFromDeclaration(
      path: fact.path,
      declaration: declaration,
      node: fromNode,
    );
  }

  bool interfaceMatches(
    ImplementedInterfaceFact fact,
    ArchitectureNode? fromNode,
  ) {
    return _matchesFromDeclaration(
      path: fact.path,
      declaration: fact.declaration,
      node: fromNode,
    );
  }
}

final class _SensitiveThrowExpectationMatcher {
  const _SensitiveThrowExpectationMatcher({
    required this.actual,
    required this.expectation,
    required this.fromNode,
  });

  final ActualArchitectureGraph actual;
  final ActualExpectation expectation;
  final ArchitectureNode? fromNode;

  List<String> missingRoutes() {
    final sensitiveOwner = expectation.sensitiveThrowOwner;
    if (sensitiveOwner == null || expectation.sensitiveThrowRoutes.isEmpty) {
      return const [];
    }
    final missing = <String>{};
    for (final throwFact in _sensitiveThrows(sensitiveOwner)) {
      for (final route in expectation.sensitiveThrowRoutes) {
        if (!_hasRoute(throwFact, route)) {
          missing.add('sensitiveThrowRoute:${throwFact.member}:$route');
        }
      }
    }

    return missing.toList()..sort();
  }

  Iterable<ExceptionThrowFact> _sensitiveThrows(String sensitiveOwner) {
    return actual.exceptionThrows.where((fact) {
      return _matchesFromNode(fact.path, fromNode) &&
          fact.owner == sensitiveOwner &&
          fact.member != null;
    });
  }

  bool _hasRoute(ExceptionThrowFact throwFact, String route) {
    return actual.memberCalls.any((call) {
      return call.path == throwFact.path &&
          call.member == throwFact.member &&
          call.target == route;
    });
  }
}

bool _isArchitectureOwnerPath(String path, ExpectedArchitectureGraph expected) {
  return expected.coverage.architectureOwners.any((pattern) {
    return _matchesGlob(path, pattern);
  });
}

bool _factMatchesNode(String path, ArchitectureNode node) {
  return _ownerPrefixes(node).any(path.startsWith);
}

bool _uriMatchesNode(String uri, ArchitectureNode node) {
  return _ownerPrefixes(node).any(uri.startsWith);
}

bool _matchesFromNode(String path, ArchitectureNode? node) {
  return node == null || _factMatchesNode(path, node);
}

bool _matchesFromDeclaration({
  required String path,
  required String? declaration,
  required ArchitectureNode? node,
}) {
  if (!_matchesFromNode(path, node)) {
    return false;
  }
  if (node == null || node.actual.declarations.isEmpty) {
    return true;
  }

  return declaration != null && node.actual.declarations.contains(declaration);
}

List<String> _ownerPrefixes(ArchitectureNode node) {
  return _ownerPathPrefixes[node.owner] ?? ['lib/src/${node.owner}/'];
}

bool _isArchitectureSeamDeclaration(String name) {
  return _architectureSeamSuffixes.any(name.endsWith);
}

bool _matchesGlob(String path, String pattern) {
  if (pattern.endsWith('/**')) {
    return path.startsWith(pattern.replaceFirst(RegExp(r'/\*\*$'), ''));
  }

  return path == pattern;
}
