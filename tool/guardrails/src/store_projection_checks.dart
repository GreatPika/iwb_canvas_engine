// Analyzer-backed store/projection checks stay together because they enforce
// one P4 boundary: public CanvasDocument objects may exist only as read
// projections, not as directly retained runtime/store state.
// The analyzer APIs require several package imports here; hiding them behind a
// wrapper would make the guardrail less direct.
// ignore_for_file: number-of-external-imports

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/type.dart';

import 'guardrail_violation.dart';
import 'repository_paths.dart';

Future<List<GuardrailViolation>> checkNoPublicDocumentLiveState({
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
      if (!_isStoreRuntimeStatePath(path)) {
        continue;
      }
      if (path == 'lib/src/store/document_projection_cache.dart') {
        continue;
      }

      final context = collection.contextFor(file.absolutePath);
      final result = await context.currentSession.getResolvedUnit(
        file.absolutePath,
      );
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

Future<List<GuardrailViolation>> checkProjectionOnlyExplicitReadPaths({
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
      if (!_isRuntimeOrStorePath(path)) {
        continue;
      }

      final context = collection.contextFor(file.absolutePath);
      final result = await context.currentSession.getResolvedUnit(
        file.absolutePath,
      );
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
  return _isCanvasRuntimeApiPath(path) ||
      _isFutureProjectionHotPath(path) ||
      path.startsWith('lib/src/runtime/') ||
      path.startsWith('lib/src/store/');
}

bool _isFutureProjectionHotPath(String path) {
  return path.startsWith('lib/src/frame/') ||
      path.startsWith('lib/src/interaction/') ||
      path.startsWith('lib/src/spatial/');
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

// This is a direct structural scan, not a whole-program flow proof: P4 blocks
// explicit CanvasDocument state declarations in runtime/store owners.
// ignore: coupling-between-object-classes
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
    if (!_containsCanvasDocument(variableType)) {
      return;
    }
    _addViolation();
  }

  void _addViolation() {
    violations.add(
      GuardrailViolation(
        guardrailId: 'store.no_public_document_live_state',
        path: path,
        message: 'runtime/store state may not retain CanvasDocument variables',
      ),
    );
  }
}

// The projection checks are deliberately grouped around one public-document
// read-path rule; splitting by AST node would obscure the shared allowance
// logic and duplicate violation reporting.
// ignore: coupling-between-object-classes
final class _ProjectionReadPathVisitor extends RecursiveAstVisitor<void> {
  _ProjectionReadPathVisitor(this.path);

  final String path;
  final List<GuardrailViolation> violations = [];

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    if (!_isAllowedDocumentConstructionPath(path, node) &&
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
  return switch (type) {
    null => false,
    InterfaceType() =>
      type.typeArguments.any(_containsCanvasDocument) ||
          _isCanvasDocument(type),
    FunctionType() => _containsCanvasDocument(type.returnType),
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
  if (!_isCanvasRuntimeFacadePath(path) &&
      path != 'lib/src/runtime/runtime_root.dart' &&
      path != 'lib/src/store/document_store_kernel.dart') {
    return false;
  }

  return _enclosingExecutableName(node) == 'readDocument' &&
      _enclosingClassName(node) == _allowedReadPathOwner(path);
}

bool isProjectionReadPathAllowedForGuardrailTest(String path, AstNode node) {
  return _isAllowedProjectionReadPath(path, node);
}

bool _isAllowedDocumentConstructionPath(String path, AstNode node) {
  return _isProjectionCachePath(path) ||
      _isCanvasRuntimeFacadePath(path) &&
          _enclosingExecutableName(node) == 'CanvasRuntime';
}

bool _isCanvasRuntimeApiPath(String path) {
  return path.startsWith('lib/src/api/canvas_runtime');
}

bool _isCanvasRuntimeFacadePath(String path) {
  return path == 'lib/src/api/canvas_runtime.dart';
}

bool _isProjectionCachePath(String path) {
  return path == 'lib/src/store/document_projection_cache.dart';
}

String? _allowedReadPathOwner(String path) {
  return switch (path) {
    'lib/src/api/canvas_runtime.dart' => 'CanvasRuntime',
    'lib/src/runtime/runtime_root.dart' => 'RuntimeRoot',
    'lib/src/store/document_store_kernel.dart' => 'DocumentStoreKernel',
    _ => null,
  };
}

String? _enclosingClassName(AstNode node) {
  for (var current = node.parent; current != null; current = current.parent) {
    if (current case ClassDeclaration(:final namePart)) {
      return namePart.typeName.lexeme;
    }
  }

  return null;
}

String? _enclosingExecutableName(AstNode node) {
  for (var current = node.parent; current != null; current = current.parent) {
    switch (current) {
      case FunctionExpression():
        return null;
      case MethodDeclaration():
        return current.name.lexeme;
      case FunctionDeclaration():
        return current.name.lexeme;
      case ConstructorDeclaration():
        return current.typeName?.name;
    }
  }

  return null;
}
