import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/type.dart';

import 'guardrail_violation.dart';
import 'repository_paths.dart';

// Selection boundary checks use analyzer resolution directly for simple P4
// structural scans of current production code. They are not a whole-program
// selection-state flow analyzer.
// ignore_for_file: number-of-external-imports

Future<List<GuardrailViolation>> checkSelectionOwnerSeparation({
  Iterable<GuardrailSourceFile>? sources,
  List<String>? analysisIncludedPaths,
}) async {
  final violations = <GuardrailViolation>[];
  final collection = AnalysisContextCollection(
    includedPaths: analysisIncludedPaths ?? ['$repositoryRoot/lib'],
  );
  final sourceFiles = sources ?? dartSourceFilesUnder('lib');

  try {
    for (final file in sourceFiles) {
      final path = file.path;
      if (!_isForbiddenSelectionStateOwner(path)) {
        continue;
      }

      final context = collection.contextFor(file.absolutePath);
      final result = await context.currentSession.getResolvedUnit(
        file.absolutePath,
      );
      if (result is! ResolvedUnitResult) {
        violations.add(
          GuardrailViolation(
            guardrailId: 'selection.owner_separate_from_document',
            path: path,
            message: 'could not resolve selection boundary source file',
          ),
        );
        continue;
      }

      violations.addAll(_selectionStateViolations(path, result.unit));
    }
  } finally {
    await collection.dispose();
  }

  return violations;
}

bool _isForbiddenSelectionStateOwner(String path) {
  return path.startsWith('lib/src/api/') ||
      path.startsWith('lib/src/runtime/') ||
      path.startsWith('lib/src/store/') ||
      path.startsWith('lib/src/codec/');
}

List<GuardrailViolation> _selectionStateViolations(
  String path,
  CompilationUnit unit,
) {
  final visitor = _SelectionStateVisitor(path);
  unit.accept(visitor);

  return visitor.violations;
}

// This visitor intentionally keeps direct field/top-level checks together so
// P4 selection-owner leakage is scanned as one production boundary rule.
// ignore: coupling-between-object-classes
final class _SelectionStateVisitor extends RecursiveAstVisitor<void> {
  _SelectionStateVisitor(this.path);

  final String path;
  final List<GuardrailViolation> violations = [];
  final List<String> _classStack = [];

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    _classStack.add(node.namePart.typeName.lexeme);
    super.visitClassDeclaration(node);
    _classStack.removeLast();
  }

  @override
  void visitTopLevelVariableDeclaration(TopLevelVariableDeclaration node) {
    for (final variable in node.variables.variables) {
      _checkVariable(variable);
    }
    super.visitTopLevelVariableDeclaration(node);
  }

  @override
  void visitFieldDeclaration(FieldDeclaration node) {
    for (final variable in node.fields.variables) {
      _checkVariable(variable);
    }
    super.visitFieldDeclaration(node);
  }

  void _checkVariable(VariableDeclaration variable) {
    final elementType = variable.declaredFragment?.element.type;
    final initializerType = variable.initializer?.staticType;
    final name = variable.name.lexeme;
    if (!_isSelectionStateShape(name, elementType, variable.initializer) &&
        !_isSelectionStateShape(name, initializerType, variable.initializer)) {
      return;
    }
    _addViolation();
  }

  void _addViolation() {
    violations.add(
      GuardrailViolation(
        guardrailId: 'selection.owner_separate_from_document',
        path: path,
        message:
            'selected ids and selection revision must stay selection-owned',
      ),
    );
  }

  bool _isSelectionStateShape(
    String name,
    DartType? type,
    Expression? expression,
  ) {
    if (_isAllowedSelectionStateShape(name)) {
      return false;
    }
    if (_isSelectionIdName(name) || _isSelectionRevisionName(name)) {
      return true;
    }
    if (_expressionContainsSelectionOwner(expression) ||
        _isSelectionStateName(name) &&
            _expressionContainsCanvasElementId(expression)) {
      return true;
    }
    if (type == null) {
      return false;
    }
    if (_isSelectionStateName(name) && _carriesCanvasElementId(type)) {
      return true;
    }

    return _containsSelectionOwnerType(type);
  }

  String get _currentClassName {
    return _classStack.isEmpty ? '' : _classStack.last;
  }

  bool _isAllowedSelectionStateShape(String name) {
    return _isAllowedActionHistoryName(path, name, _currentClassName) ||
        _isRuntimeSelectionReadPortState(path, name, _currentClassName) ||
        _isRuntimeSelectionBoundaryReadContext(path, name, _currentClassName) ||
        _isRuntimeSelectionBoundaryReadPort(path, name, _currentClassName) ||
        _isRuntimeRootCompositionState(path, name, _currentClassName);
  }
}

bool _containsSelectionOwnerType(DartType? type) {
  return switch (type) {
    null => false,
    InterfaceType() =>
      type.typeArguments.any(_containsSelectionOwnerType) ||
          _isSelectionOwnerType(type),
    _ => false,
  };
}

bool _isSelectionOwnerType(DartType type) {
  final element = type.element;
  final uri = element?.library?.uri.toString();

  return uri ==
          'package:iwb_canvas_engine/src/selection/selection_kernel.dart' ||
      _selectionContractLibraryUris.contains(uri) ||
      element?.name == 'CanvasSelectionPort' &&
          _canvasRuntimeLibraryUris.contains(uri);
}

bool _carriesCanvasElementId(DartType type) {
  return _containsCanvasElementId(type);
}

bool _containsCanvasElementId(DartType? type) {
  return switch (type) {
    null => false,
    InterfaceType() =>
      type.typeArguments.any(_containsCanvasElementId) ||
          _isCanvasElementId(type),
    _ => false,
  };
}

bool _isCanvasElementId(DartType type) {
  final element = type.element;

  return element?.name == 'CanvasElementId' &&
      _canvasIdLibraryUris.contains(element?.library?.uri.toString());
}

const _canvasRuntimeLibraryUris = {
  'package:iwb_canvas_engine/src/api/canvas_runtime.dart',
  'package:iwb_canvas_engine/src/contracts/public/canvas_runtime.dart',
};

const _canvasIdLibraryUris = {
  'package:iwb_canvas_engine/src/api/canvas_ids.dart',
  'package:iwb_canvas_engine/src/contracts/public/canvas_ids.dart',
};

const _selectionContractLibraryUris = {
  'package:iwb_canvas_engine/src/contracts/internal/selection_facts_port.dart',
  'package:iwb_canvas_engine/src/contracts/internal/selection_membership_port.dart',
};

bool _isSelectionRevisionName(String name) {
  final lower = name.toLowerCase();

  return lower.contains('selectionrevision') ||
      lower.contains('selection_revision');
}

bool _isSelectionIdName(String name) {
  final lower = name.toLowerCase();

  return _isSelectionStateName(name) && lower.contains('id');
}

bool _isSelectionStateName(String name) {
  final lower = name.toLowerCase();

  return lower.contains('selected') || lower.contains('selection');
}

bool _isAllowedActionHistoryName(String path, String name, String className) {
  if (path != 'lib/src/api/canvas_actions.dart' ||
      className != 'CanvasSelectionActionPayload') {
    return false;
  }
  final lower = name.toLowerCase();

  return lower.contains('previousselection') || lower.contains('nextselection');
}

bool _isRuntimeSelectionReadPortState(
  String path,
  String name,
  String className,
) {
  return path == 'lib/src/contracts/internal/selection_facts_port.dart' &&
      className == 'SelectionFacts' &&
      (name == 'selectedElementIds' || name == 'selectionRevision');
}

bool _isRuntimeSelectionBoundaryReadContext(
  String path,
  String name,
  String className,
) {
  return name == 'selection' &&
      (path == 'lib/src/runtime/runtime_command_facts_adapter.dart' &&
              className == '_CommandReadContext' ||
          path == 'lib/src/runtime/runtime_interaction_read_adapter.dart' &&
              className == '_InteractionReadContext');
}

bool _isRuntimeSelectionBoundaryReadPort(
  String path,
  String name,
  String className,
) {
  return name == '_selection' &&
      (path == 'lib/src/runtime/runtime_command_facts_adapter.dart' &&
              className == 'RuntimeCommandFactsAdapter' ||
          path == 'lib/src/runtime/runtime_interaction_read_adapter.dart' &&
              className == 'RuntimeInteractionReadAdapter');
}

bool _isRuntimeRootCompositionState(
  String path,
  String name,
  String className,
) {
  return path == 'lib/src/runtime/runtime_root.dart' &&
      className == 'RuntimeRoot' &&
      (name == '_selection' || name == '_selectionPort');
}

bool _expressionContainsSelectionOwner(Expression? expression) =>
    _containsSelectionOwnerType(expression?.staticType);

bool _expressionContainsCanvasElementId(Expression? expression) =>
    _containsCanvasElementId(expression?.staticType);
