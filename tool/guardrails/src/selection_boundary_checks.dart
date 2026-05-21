import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/type.dart';

import 'guardrail_violation.dart';
import 'repository_paths.dart';

Future<List<GuardrailViolation>> checkSelectionOwnerSeparation() async {
  final violations = <GuardrailViolation>[];
  final collection = AnalysisContextCollection(
    includedPaths: ['$repositoryRoot/lib'],
  );

  try {
    for (final file in dartFilesUnder('lib')) {
      final path = relativePath(file);
      if (!_isForbiddenSelectionStateOwner(path)) {
        continue;
      }

      final context = collection.contextFor(file.path);
      final result = await context.currentSession.getResolvedUnit(file.path);
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
  return path == 'lib/src/api/canvas_document.dart' ||
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

// This visitor intentionally keeps AST context, resolved type checks, and
// allowlisted document-id ownership together so selection-state bypasses are
// reviewed as one boundary rule instead of split into metric-shaped fragments.
// ignore: metrics
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
    if (!_isSelectionStateShape(variable, elementType) &&
        !_isSelectionStateShape(variable, initializerType)) {
      return;
    }
    violations.add(
      GuardrailViolation(
        guardrailId: 'selection.owner_separate_from_document',
        path: path,
        message:
            'selected ids and selection revision must stay selection-owned',
      ),
    );
  }

  bool _isSelectionStateShape(VariableDeclaration variable, DartType? type) {
    if (_isAllowedDocumentElementIds(variable)) {
      return false;
    }
    if (_isSelectionIdName(variable.name.lexeme)) {
      return true;
    }
    if (type == null) {
      return false;
    }
    if (_isSelectionOwnerType(type) || _carriesCanvasElementId(type)) {
      return true;
    }

    return _isSelectionRevisionName(variable.name.lexeme);
  }

  bool _isAllowedDocumentElementIds(VariableDeclaration variable) {
    final owner = _classStack.isEmpty ? '' : _classStack.last;
    final variableName = variable.name.lexeme;

    return path == 'lib/src/store/element_registry.dart' &&
            owner == 'ElementRegistry' &&
            variableName == 'backgroundElementIds' ||
        path == 'lib/src/store/layer_table.dart' &&
            owner == 'LayerRow' &&
            variableName == 'elementIds' ||
        path == 'lib/src/codec/validated_import_draft.dart' &&
            owner == 'ValidatedImportDraft' &&
            variableName == 'elementIds';
  }
}

bool _isSelectionOwnerType(DartType type) {
  final element = type.element;
  final uri = element?.library?.uri.toString();

  return uri ==
          'package:iwb_canvas_engine/src/selection/selection_kernel.dart' ||
      uri ==
          'package:iwb_canvas_engine/src/runtime/selection_facts_port.dart' ||
      uri ==
          'package:iwb_canvas_engine/src/runtime/selection_normalization_port.dart' ||
      element?.name == 'CanvasSelectionPort' &&
          uri == 'package:iwb_canvas_engine/src/api/canvas_runtime.dart';
}

bool _carriesCanvasElementId(DartType type) {
  if (type is! InterfaceType) {
    return false;
  }

  return type.typeArguments.any(_containsCanvasElementId) ||
      type.allSupertypes.any(
        (supertype) => supertype.typeArguments.any(_containsCanvasElementId),
      );
}

bool _containsCanvasElementId(DartType type) {
  if (_isCanvasElementId(type)) {
    return true;
  }
  if (type is InterfaceType) {
    return type.typeArguments.any(_containsCanvasElementId);
  }

  return false;
}

bool _isCanvasElementId(DartType type) {
  final element = type.element;

  return element?.name == 'CanvasElementId' &&
      element?.library?.uri.toString() ==
          'package:iwb_canvas_engine/src/api/canvas_ids.dart';
}

bool _isSelectionRevisionName(String name) {
  final lower = name.toLowerCase();

  return lower.contains('selectionrevision') ||
      lower.contains('selection_revision');
}

bool _isSelectionIdName(String name) {
  final lower = name.toLowerCase();
  final mentionsSelection =
      lower.contains('selected') || lower.contains('selection');

  return mentionsSelection && lower.contains('id');
}
