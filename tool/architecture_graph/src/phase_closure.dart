import 'actual_graph.dart';
import 'architecture_graph.dart';

const _ownerPathPrefixes = {
  'api': ['lib/src/api/', 'lib/iwb_canvas_engine.dart'],
  'codec': ['lib/src/codec/'],
  'diagnostics': ['lib/src/diagnostics/'],
  'runtime': ['lib/src/runtime/'],
  'store': ['lib/src/store/'],
  'selection': ['lib/src/selection/'],
  'edit': ['lib/src/edit/'],
  'load_document': ['lib/src/load_document/'],
  'resource': ['lib/src/resources/'],
  'spatial': ['lib/src/geometry/'],
  'frame': ['lib/src/frame/'],
  'interaction': ['lib/src/interaction/'],
  'tools': ['lib/src/tools/'],
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

final class PhaseClosureViolation {
  const PhaseClosureViolation({
    required this.graphId,
    required this.selectedPhase,
    required this.expectedFact,
    required this.actualEvidence,
    required this.path,
    required this.status,
    required this.message,
  });

  final String graphId;
  final String selectedPhase;
  final String expectedFact;
  final String actualEvidence;
  final String path;
  final String status;
  final String message;
}

final class PhaseClosureReport {
  const PhaseClosureReport({
    required this.selectedPhase,
    required this.violations,
  });

  final String selectedPhase;
  final List<PhaseClosureViolation> violations;

  bool get isClosed => violations.isEmpty;
}

PhaseClosureReport checkPhaseClosure({
  required ExpectedArchitectureGraph expected,
  required ActualArchitectureGraph actual,
  required String selectedPhase,
}) {
  return _PhaseClosureRun(
    expected: expected,
    actual: actual,
    selectedPhase: selectedPhase,
  ).check();
}

String formatPhaseClosureReport(PhaseClosureReport report) {
  if (report.isClosed) {
    return 'Architecture graph closure passed for ${report.selectedPhase}.';
  }
  final buffer = StringBuffer()
    ..writeln('Architecture graph closure failed for ${report.selectedPhase}.')
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

final class _PhaseClosureRun {
  _PhaseClosureRun({
    required ExpectedArchitectureGraph expected,
    required ActualArchitectureGraph actual,
    required String selectedPhase,
  }) : context = _PhaseClosureContext(
         expected: expected,
         actual: actual,
         selectedPhase: selectedPhase,
       );

  final _PhaseClosureContext context;

  PhaseClosureReport check() {
    _SelectedPhaseRule(context).check();
    _RequiredObligationRule(context).check();
    _ForbiddenEdgeRule(context).check();
    _PlaceholderRule(context).check();
    _UnknownArchitectureDeclarationRule(context).check();

    return PhaseClosureReport(
      selectedPhase: context.selectedPhase,
      violations: context.violations,
    );
  }
}

final class _PhaseClosureContext {
  _PhaseClosureContext({
    required this.expected,
    required this.actual,
    required this.selectedPhase,
  }) : matcher = _ExpectationEvidenceMatcher(
         expected: expected,
         actual: actual,
       );

  final ExpectedArchitectureGraph expected;
  final ActualArchitectureGraph actual;
  final String selectedPhase;
  final _ExpectationEvidenceMatcher matcher;
  final List<PhaseClosureViolation> violations = [];

  void add(PhaseClosureViolation violation) => violations.add(violation);

  ArchitectureNode? node(String id) {
    for (final node in expected.nodes) {
      if (node.id == id) {
        return node;
      }
    }

    return null;
  }

  bool isActive(String phase) =>
      _phaseIndex(selectedPhase) >= _phaseIndex(phase);

  bool isRequiredBySelectedPhase(String phase, String status) {
    return isActive(phase) &&
        (status == 'required' || status == 'future' || status == 'measurement');
  }
}

final class _SelectedPhaseRule {
  const _SelectedPhaseRule(this.context);

  final _PhaseClosureContext context;

  void check() {
    if (context.expected.phaseIds.contains(context.selectedPhase)) {
      return;
    }
    context.add(
      PhaseClosureViolation(
        graphId: 'phase.selected.unknown',
        selectedPhase: context.selectedPhase,
        expectedFact: 'selected phase exists',
        actualEvidence: context.selectedPhase,
        path: architectureGraphPath,
        status: 'unknown_phase',
        message: 'Selected phase is not declared in architecture_graph.yaml.',
      ),
    );
  }
}

final class _RequiredObligationRule {
  const _RequiredObligationRule(this.context);

  final _PhaseClosureContext context;

  void check() {
    _nodes();
    _edges();
  }

  void _nodes() {
    for (final node in context.expected.nodes) {
      if (!context.isRequiredBySelectedPhase(
        node.phaseRequiredBy,
        node.status,
      )) {
        continue;
      }
      final missing = context.matcher.missingForNode(node);
      if (missing.isEmpty) {
        continue;
      }
      context.add(
        PhaseClosureViolation(
          graphId: node.id,
          selectedPhase: context.selectedPhase,
          expectedFact: 'required node ${node.label}',
          actualEvidence: 'missing ${missing.join(', ')}',
          path: node.sourceDocs.first.path,
          status: 'missing_required_node',
          message:
              'Required selected-phase architecture node is not implemented.',
        ),
      );
    }
  }

  void _edges() {
    for (final edge in context.expected.edges) {
      if (!context.isRequiredBySelectedPhase(
        edge.phaseRequiredBy,
        edge.status,
      )) {
        continue;
      }
      final missing = context.matcher.missingForEdge(edge);
      if (missing.isEmpty) {
        continue;
      }
      context.add(
        PhaseClosureViolation(
          graphId: edge.id,
          selectedPhase: context.selectedPhase,
          expectedFact: '${edge.from} ${edge.kind} ${edge.to}',
          actualEvidence: 'missing ${missing.join(', ')}',
          path: edge.sourceDocs.first.path,
          status: 'missing_required_edge',
          message:
              'Required selected-phase architecture edge is not implemented.',
        ),
      );
    }
  }
}

final class _ForbiddenEdgeRule {
  const _ForbiddenEdgeRule(this.context);

  final _PhaseClosureContext context;

  void check() {
    for (final edge in context.expected.forbiddenEdges) {
      if (!context.isActive(edge.phaseRequiredBy)) {
        continue;
      }
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
        PhaseClosureViolation(
          graphId: edge.id,
          selectedPhase: context.selectedPhase,
          expectedFact: '${edge.from} must not import ${edge.to}',
          actualEvidence: '${fact.path}:${fact.line} imports ${fact.uri}',
          path: fact.path,
          status: 'forbidden_edge',
          message: 'Forbidden selected-phase dependency is present.',
        ),
      );
    }
  }
}

final class _PlaceholderRule {
  const _PlaceholderRule(this.context);

  final _PhaseClosureContext context;

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
      PhaseClosureViolation(
        graphId: 'placeholder.untracked.${fact.member}',
        selectedPhase: context.selectedPhase,
        expectedFact: 'public placeholder has graph-owned deferral',
        actualEvidence: '${fact.path}:${fact.line} throws ${fact.throwType}',
        path: fact.path,
        status: 'untracked_placeholder',
        message: 'Public placeholder is not owned by the expected graph.',
      ),
    );
  }

  void _tracked(ArchitecturePlaceholder placeholder, PlaceholderFact fact) {
    if (placeholder.status == 'forbidden_after_phase' &&
        context.isActive(placeholder.phaseRequiredBy)) {
      _closedPhase(placeholder, fact);
    }
    if (placeholder.status == 'deferred_until_phase' &&
        context.isActive(placeholder.phaseRequiredBy)) {
      _expiredDeferral(placeholder, fact);
    }
  }

  void _closedPhase(ArchitecturePlaceholder placeholder, PlaceholderFact fact) {
    context.add(
      PhaseClosureViolation(
        graphId: placeholder.id,
        selectedPhase: context.selectedPhase,
        expectedFact:
            '${placeholder.member} implemented by ${placeholder.phaseRequiredBy}',
        actualEvidence: '${fact.path}:${fact.line} throws ${fact.throwType}',
        path: fact.path,
        status: 'closed_phase_placeholder',
        message: 'Closed-phase public placeholder remains in production code.',
      ),
    );
  }

  void _expiredDeferral(
    ArchitecturePlaceholder placeholder,
    PlaceholderFact fact,
  ) {
    context.add(
      PhaseClosureViolation(
        graphId: placeholder.id,
        selectedPhase: context.selectedPhase,
        expectedFact:
            '${placeholder.member} deferred only before ${placeholder.phaseRequiredBy}',
        actualEvidence: '${fact.path}:${fact.line} throws ${fact.throwType}',
        path: fact.path,
        status: 'expired_placeholder_deferral',
        message: 'Placeholder deferral has expired for the selected phase.',
      ),
    );
  }
}

final class _UnknownArchitectureDeclarationRule {
  const _UnknownArchitectureDeclarationRule(this.context);

  final _PhaseClosureContext context;

  void check() {
    final expectedDeclarations = {
      for (final node in context.expected.nodes) ...node.actual.declarations,
    };
    for (final fact in context.actual.declarations) {
      if (!_isUnknownArchitectureDeclaration(fact, expectedDeclarations)) {
        continue;
      }
      context.add(
        PhaseClosureViolation(
          graphId: 'architecture.unknown.${fact.name}',
          selectedPhase: context.selectedPhase,
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
        ? fact.member.substring(0, fact.member.indexOf('.'))
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

int _phaseIndex(String phase) {
  if (!phase.startsWith('P')) {
    return -1;
  }

  return int.tryParse(phase.substring(1)) ?? -1;
}

bool _matchesGlob(String path, String pattern) {
  if (pattern.endsWith('/**')) {
    return path.startsWith(pattern.substring(0, pattern.length - 3));
  }

  return path == pattern;
}
