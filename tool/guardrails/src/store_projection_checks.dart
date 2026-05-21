// Analyzer-backed store/projection checks stay together because they enforce a
// single boundary: public CanvasDocument objects may exist only as read
// projections, not as retained runtime/store state.
// ignore_for_file: type=metrics

import 'dart:collection';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/type.dart';

import 'guardrail_violation.dart';
import 'repository_paths.dart';

Future<List<GuardrailViolation>> checkNoPublicDocumentLiveState() async {
  final violations = <GuardrailViolation>[];
  final collection = AnalysisContextCollection(
    includedPaths: ['$repositoryRoot/lib'],
  );

  try {
    for (final file in dartFilesUnder('lib')) {
      final path = relativePath(file);
      if (!_isStoreRuntimeStatePath(path)) {
        continue;
      }
      if (path == 'lib/src/store/document_projection_cache.dart') {
        continue;
      }

      final context = collection.contextFor(file.path);
      final result = await context.currentSession.getResolvedUnit(file.path);
      if (result is! ResolvedUnitResult) {
        violations.add(
          GuardrailViolation(
            guardrailId: 'store.no_public_document_live_state',
            path: path,
            message: 'could not resolve runtime/store source file',
          ),
        );
        continue;
      }

      violations.addAll(_publicDocumentFieldViolations(path, result.unit));
    }
  } finally {
    await collection.dispose();
  }

  return violations;
}

Future<List<GuardrailViolation>> checkProjectionOnlyExplicitReadPaths() async {
  final violations = <GuardrailViolation>[];
  final collection = AnalysisContextCollection(
    includedPaths: ['$repositoryRoot/lib'],
  );

  try {
    for (final file in dartFilesUnder('lib')) {
      final path = relativePath(file);
      if (!_isRuntimeOrStorePath(path)) {
        continue;
      }

      final context = collection.contextFor(file.path);
      final result = await context.currentSession.getResolvedUnit(file.path);
      if (result is! ResolvedUnitResult) {
        violations.add(
          GuardrailViolation(
            guardrailId: 'projection.only_explicit_read_paths',
            path: path,
            message: 'could not resolve runtime/store source file',
          ),
        );
        continue;
      }

      violations.addAll(_projectionReadPathViolations(path, result.unit));
    }
  } finally {
    await collection.dispose();
  }

  return violations;
}

bool _isStoreRuntimeStatePath(String path) {
  return path == 'lib/src/api/canvas_runtime.dart' ||
      path.startsWith('lib/src/runtime/') ||
      path.startsWith('lib/src/store/');
}

bool _isRuntimeOrStorePath(String path) {
  return path.startsWith('lib/src/runtime/') ||
      path.startsWith('lib/src/store/');
}

List<GuardrailViolation> _publicDocumentFieldViolations(
  String path,
  CompilationUnit unit,
) {
  final visitor = _PublicDocumentFieldVisitor(path);
  unit.accept(visitor);

  return visitor.violations;
}

List<GuardrailViolation> _projectionReadPathViolations(
  String path,
  CompilationUnit unit,
) {
  final visitor = _ProjectionReadPathVisitor(path);
  unit.accept(visitor);

  return visitor.violations;
}

final class _PublicDocumentFieldVisitor extends RecursiveAstVisitor<void> {
  _PublicDocumentFieldVisitor(this.path);

  final String path;
  final List<GuardrailViolation> violations = [];

  @override
  void visitTopLevelVariableDeclaration(TopLevelVariableDeclaration node) {
    for (final variable in node.variables.variables) {
      _checkRetainedVariable(variable);
    }
    super.visitTopLevelVariableDeclaration(node);
  }

  @override
  void visitFieldDeclaration(FieldDeclaration node) {
    for (final variable in node.fields.variables) {
      _checkRetainedVariable(variable);
    }
    super.visitFieldDeclaration(node);
  }

  void _checkRetainedVariable(VariableDeclaration variable) {
    final variableType = variable.declaredFragment?.element.type;
    final initializerType = variable.initializer?.staticType;
    if (!_containsCanvasDocument(variableType) &&
        !_containsCanvasDocument(initializerType)) {
      return;
    }
    violations.add(
      GuardrailViolation(
        guardrailId: 'store.no_public_document_live_state',
        path: path,
        message: 'runtime/store state may not retain CanvasDocument variables',
      ),
    );
  }
}

final class _ProjectionReadPathVisitor extends RecursiveAstVisitor<void> {
  _ProjectionReadPathVisitor(this.path);

  final String path;
  final List<GuardrailViolation> violations = [];

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    if (!_isProjectionCachePath(path) &&
        _containsCanvasDocument(node.constructorName.element?.returnType)) {
      _addViolation('public document projection construction is cache-owned');
    }
    super.visitInstanceCreationExpression(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (!_isAllowedProjectionReadPath(path, node) &&
        _containsCanvasDocument(node.staticType)) {
      _addViolation('public document projection invocation is read-path-only');
    }
    super.visitMethodInvocation(node);
  }

  @override
  void visitReturnStatement(ReturnStatement node) {
    final expression = node.expression;
    if (expression != null &&
        expression is! InstanceCreationExpression &&
        expression is! MethodInvocation &&
        !_isAllowedProjectionReadPath(path, node) &&
        _containsCanvasDocument(expression.staticType)) {
      _addViolation('public document projection return is read-path-only');
    }
    super.visitReturnStatement(node);
  }

  void _addViolation(String message) {
    violations.add(
      GuardrailViolation(
        guardrailId: 'projection.only_explicit_read_paths',
        path: path,
        message: message,
      ),
    );
  }
}

bool _containsCanvasDocument(DartType? type) {
  return _containsCanvasDocumentType(type, HashSet<DartType>.identity());
}

bool _containsCanvasDocumentType(DartType? type, Set<DartType> visited) {
  if (type == null || !visited.add(type)) {
    return false;
  }

  final aliasType = type.alias?.element.aliasedType;
  if (_isCanvasDocument(type) ||
      _containsCanvasDocumentType(aliasType, visited)) {
    return true;
  }

  return switch (type) {
    InterfaceType() => type.typeArguments.any(
      (argument) => _containsCanvasDocumentType(argument, visited),
    ),
    FunctionType() =>
      _containsCanvasDocumentType(type.returnType, visited) ||
          type.normalParameterTypes.any(
            (argument) => _containsCanvasDocumentType(argument, visited),
          ) ||
          type.optionalParameterTypes.any(
            (argument) => _containsCanvasDocumentType(argument, visited),
          ) ||
          type.namedParameterTypes.values.any(
            (argument) => _containsCanvasDocumentType(argument, visited),
          ),
    RecordType() =>
      type.positionalFields.any(
            (field) => _containsCanvasDocumentType(field.type, visited),
          ) ||
          type.namedFields.any(
            (field) => _containsCanvasDocumentType(field.type, visited),
          ),
    TypeParameterType() => _containsCanvasDocumentType(type.bound, visited),
    _ => false,
  };
}

bool _isCanvasDocument(DartType type) {
  final element = type.element;

  return element?.name == 'CanvasDocument' &&
      element?.library?.uri.toString() ==
          'package:iwb_canvas_engine/src/api/canvas_document.dart';
}

bool _isAllowedProjectionReadPath(String path, AstNode node) {
  if (_isProjectionCachePath(path)) {
    return true;
  }
  if (path != 'lib/src/runtime/runtime_root.dart' &&
      path != 'lib/src/store/document_store_kernel.dart') {
    return false;
  }

  return _enclosingExecutableName(node) == 'readDocument';
}

bool _isProjectionCachePath(String path) {
  return path == 'lib/src/store/document_projection_cache.dart';
}

String? _enclosingExecutableName(AstNode node) {
  for (var current = node.parent; current != null; current = current.parent) {
    switch (current) {
      case MethodDeclaration():
        return current.name.lexeme;
      case FunctionDeclaration():
        return current.name.lexeme;
    }
  }

  return null;
}
