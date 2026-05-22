import 'actual_graph.dart';
import 'architecture_graph.dart';

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
  final checker = _PhaseClosureChecker(
    expected: expected,
    actual: actual,
    selectedPhase: selectedPhase,
  );

  return checker.check();
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

final class _PhaseClosureChecker {
  _PhaseClosureChecker({
    required this.expected,
    required this.actual,
    required this.selectedPhase,
  });

  final ExpectedArchitectureGraph expected;
  final ActualArchitectureGraph actual;
  final String selectedPhase;
  final List<PhaseClosureViolation> _violations = [];

  PhaseClosureReport check() {
    _selectedPhaseExists();
    _requiredNodes();
    _requiredEdges();
    _forbiddenEdges();
    _placeholders();
    _unknownArchitectureDeclarations();

    return PhaseClosureReport(
      selectedPhase: selectedPhase,
      violations: _violations,
    );
  }

  void _selectedPhaseExists() {
    if (!expected.phaseIds.contains(selectedPhase)) {
      _add(
        graphId: 'phase.selected.unknown',
        expectedFact: 'selected phase exists',
        actualEvidence: selectedPhase,
        path: architectureGraphPath,
        status: 'unknown_phase',
        message: 'Selected phase is not declared in architecture_graph.yaml.',
      );
    }
  }

  void _requiredNodes() {
    for (final node in expected.nodes) {
      if (!_isRequiredBySelectedPhase(node.phaseRequiredBy, node.status)) {
        continue;
      }
      final missingFacts = _missingNodeExpectations(node);
      if (missingFacts.isEmpty) {
        continue;
      }
      _add(
        graphId: node.id,
        expectedFact: 'required node ${node.label}',
        actualEvidence: 'missing ${missingFacts.join(', ')}',
        path: node.sourceDocs.first.path,
        status: 'missing_required_node',
        message:
            'Required selected-phase architecture node is not implemented.',
      );
    }
  }

  void _requiredEdges() {
    for (final edge in expected.edges) {
      if (!_isRequiredBySelectedPhase(edge.phaseRequiredBy, edge.status)) {
        continue;
      }
      final missingFacts = _missingEdgeExpectations(edge);
      if (missingFacts.isEmpty) {
        continue;
      }
      _add(
        graphId: edge.id,
        expectedFact: '${edge.from} ${edge.kind} ${edge.to}',
        actualEvidence: 'missing ${missingFacts.join(', ')}',
        path: edge.sourceDocs.first.path,
        status: 'missing_required_edge',
        message:
            'Required selected-phase architecture edge is not implemented.',
      );
    }
  }

  void _forbiddenEdges() {
    for (final edge in expected.forbiddenEdges) {
      if (!_isActive(edge.phaseRequiredBy)) {
        continue;
      }
      final fromNode = _node(edge.from);
      final toNode = _node(edge.to);
      if (fromNode == null || toNode == null) {
        continue;
      }
      final forbiddenImports = actual.imports.where((fact) {
        return _factMatchesNode(fact.path, fromNode) &&
            _uriMatchesNode(fact.uri, toNode);
      });
      for (final fact in forbiddenImports) {
        _add(
          graphId: edge.id,
          expectedFact: '${edge.from} must not import ${edge.to}',
          actualEvidence: '${fact.path}:${fact.line} imports ${fact.uri}',
          path: fact.path,
          status: 'forbidden_edge',
          message: 'Forbidden selected-phase dependency is present.',
        );
      }
    }
  }

  void _placeholders() {
    final expectedByMember = {
      for (final placeholder in expected.placeholders)
        placeholder.member: placeholder,
    };
    for (final fact in actual.placeholders) {
      final placeholder = expectedByMember[fact.member];
      if (placeholder == null) {
        _add(
          graphId: 'placeholder.untracked.${fact.member}',
          expectedFact: 'public placeholder has graph-owned deferral',
          actualEvidence: '${fact.path}:${fact.line} throws ${fact.throwType}',
          path: fact.path,
          status: 'untracked_placeholder',
          message: 'Public placeholder is not owned by the expected graph.',
        );
        continue;
      }
      if (placeholder.status == 'forbidden_after_phase' &&
          _isActive(placeholder.phaseRequiredBy)) {
        _add(
          graphId: placeholder.id,
          expectedFact:
              '${placeholder.member} implemented by ${placeholder.phaseRequiredBy}',
          actualEvidence: '${fact.path}:${fact.line} throws ${fact.throwType}',
          path: fact.path,
          status: 'closed_phase_placeholder',
          message:
              'Closed-phase public placeholder remains in production code.',
        );
      }
      if (placeholder.status == 'deferred_until_phase' &&
          _isAfterOrAt(selectedPhase, placeholder.phaseRequiredBy)) {
        _add(
          graphId: placeholder.id,
          expectedFact:
              '${placeholder.member} deferred only before ${placeholder.phaseRequiredBy}',
          actualEvidence: '${fact.path}:${fact.line} throws ${fact.throwType}',
          path: fact.path,
          status: 'expired_placeholder_deferral',
          message: 'Placeholder deferral has expired for the selected phase.',
        );
      }
    }
  }

  void _unknownArchitectureDeclarations() {
    final expectedDeclarations = {
      for (final node in expected.nodes) ...node.actual.declarations,
    };
    for (final fact in actual.declarations) {
      if (!_isArchitectureOwnerPath(fact.path) ||
          fact.kind != 'class' ||
          fact.name.startsWith('_') ||
          !_isArchitectureSeamDeclaration(fact.name) ||
          expectedDeclarations.contains(fact.name)) {
        continue;
      }
      _add(
        graphId: 'architecture.unknown.${fact.name}',
        expectedFact:
            'architecture declaration is represented in expected graph',
        actualEvidence: '${fact.path}:${fact.line} declares ${fact.name}',
        path: fact.path,
        status: 'unknown_architecture_seam',
        message: 'Covered architecture owner declaration is not graph-owned.',
      );
    }
  }

  List<String> _missingNodeExpectations(ArchitectureNode node) {
    final expectation = node.actual;
    final missing = <String>[];
    for (final declaration in expectation.declarations) {
      if (!actual.declarations.any((fact) {
        return _factMatchesNode(fact.path, node) && fact.name == declaration;
      })) {
        missing.add('declaration:$declaration');
      }
    }
    for (final export in expectation.exports) {
      if (!actual.exports.any((fact) {
        return _factMatchesNode(fact.path, node) && fact.uri == export;
      })) {
        missing.add('export:$export');
      }
    }
    for (final import in expectation.imports) {
      if (!actual.imports.any((fact) {
        return _factMatchesNode(fact.path, node) && fact.uri == import;
      })) {
        missing.add('import:$import');
      }
    }
    for (final interface in expectation.implementedInterfaces) {
      if (!actual.implementedInterfaces.any((fact) {
        return _factMatchesNode(fact.path, node) && fact.interface == interface;
      })) {
        missing.add('implements:$interface');
      }
    }
    for (final field in expectation.compositionFields) {
      if (!actual.compositionFields.any((fact) {
        return _factMatchesNode(fact.path, node) && fact.type == field;
      })) {
        missing.add('composition:$field');
      }
    }
    for (final target in expectation.delegationTargets) {
      if (!actual.delegations.any((fact) {
        return _factMatchesNode(fact.path, node) && fact.targetType == target;
      })) {
        missing.add('delegation:$target');
      }
    }
    final sensitiveOwner = expectation.sensitiveThrowOwner;
    if (sensitiveOwner != null &&
        !actual.exceptionThrows.any((fact) {
          return _factMatchesNode(fact.path, node) &&
              fact.owner == sensitiveOwner;
        })) {
      missing.add('sensitiveThrowOwner:$sensitiveOwner');
    }

    return missing;
  }

  List<String> _missingEdgeExpectations(ArchitectureEdge edge) {
    final expectation = edge.actual;
    final fromNode = _node(edge.from);
    final missing = <String>[];
    for (final declaration in expectation.declarations) {
      if (!actual.declarations.any((fact) {
        return _matchesFromNode(fact.path, fromNode) &&
            fact.name == declaration;
      })) {
        missing.add('declaration:$declaration');
      }
    }
    for (final export in expectation.exports) {
      if (!actual.exports.any((fact) {
        return _matchesFromNode(fact.path, fromNode) && fact.uri == export;
      })) {
        missing.add('export:$export');
      }
    }
    for (final import in expectation.imports) {
      if (!actual.imports.any((fact) {
        return _matchesFromNode(fact.path, fromNode) && fact.uri == import;
      })) {
        missing.add('import:$import');
      }
    }
    for (final field in expectation.compositionFields) {
      if (!actual.compositionFields.any((fact) {
        return _compositionMatchesFrom(fact, fromNode) && fact.type == field;
      })) {
        missing.add('composition:$field');
      }
    }
    for (final target in expectation.delegationTargets) {
      if (!actual.delegations.any((fact) {
        return _delegationMatchesFrom(fact, fromNode) &&
            _delegationMemberMatches(fact, expectation) &&
            fact.targetType == target;
      })) {
        missing.add('delegation:$target');
      }
    }
    for (final interface in expectation.implementedInterfaces) {
      if (!actual.implementedInterfaces.any((fact) {
        return _interfaceMatchesFrom(fact, fromNode) &&
            fact.interface == interface;
      })) {
        missing.add('implements:$interface');
      }
    }
    final sensitiveOwner = expectation.sensitiveThrowOwner;
    if (sensitiveOwner != null &&
        !actual.exceptionThrows.any((fact) {
          return _matchesFromNode(fact.path, fromNode) &&
              fact.owner == sensitiveOwner;
        })) {
      missing.add('sensitiveThrowOwner:$sensitiveOwner');
    }

    return missing;
  }

  bool _isArchitectureOwnerPath(String path) {
    return expected.coverage.architectureOwners.any((pattern) {
      return _matchesGlob(path, pattern);
    });
  }

  bool _factMatchesNode(String path, ArchitectureNode node) {
    return _ownerPathPrefixes(node).any(path.startsWith);
  }

  bool _uriMatchesNode(String uri, ArchitectureNode node) {
    return _ownerPathPrefixes(node).any(uri.startsWith);
  }

  bool _matchesFromNode(String path, ArchitectureNode? node) {
    return node == null || _factMatchesNode(path, node);
  }

  bool _compositionMatchesFrom(
    CompositionFieldFact fact,
    ArchitectureNode? node,
  ) {
    return _matchesFromDeclaration(
      path: fact.path,
      declaration: fact.declaration,
      node: node,
    );
  }

  bool _delegationMatchesFrom(DelegationFact fact, ArchitectureNode? node) {
    final declaration = fact.member.contains('.')
        ? fact.member.substring(0, fact.member.indexOf('.'))
        : fact.member;

    return _matchesFromDeclaration(
      path: fact.path,
      declaration: declaration,
      node: node,
    );
  }

  bool _delegationMemberMatches(
    DelegationFact fact,
    ActualExpectation expectation,
  ) {
    return expectation.delegationMembers.isEmpty ||
        expectation.delegationMembers.contains(fact.member);
  }

  bool _interfaceMatchesFrom(
    ImplementedInterfaceFact fact,
    ArchitectureNode? node,
  ) {
    return _matchesFromDeclaration(
      path: fact.path,
      declaration: fact.declaration,
      node: node,
    );
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

    return declaration != null &&
        node.actual.declarations.contains(declaration);
  }

  List<String> _ownerPathPrefixes(ArchitectureNode node) {
    return switch (node.owner) {
      'api' => const ['lib/src/api/', 'lib/iwb_canvas_engine.dart'],
      'codec' => const ['lib/src/codec/'],
      'diagnostics' => const ['lib/src/diagnostics/'],
      'runtime' => const ['lib/src/runtime/'],
      'store' => const ['lib/src/store/'],
      'selection' => const ['lib/src/selection/'],
      'edit' => const ['lib/src/edit/'],
      'load_document' => const ['lib/src/load_document/'],
      'resource' => const ['lib/src/resources/'],
      'spatial' => const ['lib/src/geometry/'],
      'frame' => const ['lib/src/frame/'],
      'interaction' => const ['lib/src/interaction/'],
      'tools' => const ['lib/src/tools/'],
      'surface' => const ['lib/src/surface/'],
      'release' => const ['tool/', 'docs/verification/'],
      _ => ['lib/src/${node.owner}/'],
    };
  }

  ArchitectureNode? _node(String id) {
    for (final node in expected.nodes) {
      if (node.id == id) {
        return node;
      }
    }

    return null;
  }

  bool _isActive(String phase) => _isAfterOrAt(selectedPhase, phase);

  bool _isRequiredBySelectedPhase(String phase, String status) {
    return _isActive(phase) &&
        (status == 'required' || status == 'future' || status == 'measurement');
  }

  bool _isAfterOrAt(String left, String right) {
    return _phaseIndex(left) >= _phaseIndex(right);
  }

  int _phaseIndex(String phase) {
    if (!phase.startsWith('P')) {
      return -1;
    }

    return int.tryParse(phase.substring(1)) ?? -1;
  }

  void _add({
    required String graphId,
    required String expectedFact,
    required String actualEvidence,
    required String path,
    required String status,
    required String message,
  }) {
    _violations.add(
      PhaseClosureViolation(
        graphId: graphId,
        selectedPhase: selectedPhase,
        expectedFact: expectedFact,
        actualEvidence: actualEvidence,
        path: path,
        status: status,
        message: message,
      ),
    );
  }
}

bool _isArchitectureSeamDeclaration(String name) {
  return name.endsWith('Root') ||
      name.endsWith('Kernel') ||
      name.endsWith('Hub') ||
      name.endsWith('Resolver') ||
      name.endsWith('Pipeline') ||
      name.endsWith('Index') ||
      name.endsWith('Renderer') ||
      name.endsWith('Engine') ||
      name.endsWith('Surface') ||
      name.endsWith('Runtime') ||
      name.endsWith('Seam') ||
      name.endsWith('Coordinator');
}

bool _matchesGlob(String path, String pattern) {
  if (pattern.endsWith('/**')) {
    return path.startsWith(pattern.substring(0, pattern.length - 3));
  }

  return path == pattern;
}
