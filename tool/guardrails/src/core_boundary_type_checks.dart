import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';

import 'guardrail_violation.dart';

const vectorPreparationApiOwnerPath = 'lib/src/api/';

const _vectorPreparationAssetLoadMethods = {
  'load',
  'loadBuffer',
  'loadString',
  'loadStructuredData',
};
const _immutableBufferExternalLoadMethods = {'fromAsset', 'fromFilePath'};
const _sceneControllerShapeNames = {'SceneController', 'SceneSnapshot'};
const _nodeSpecPatchShapeNames = {'NodeSpec', 'NodePatch', 'PatchField'};

List<GuardrailViolation> checkRetiredShapeReferences(
  String path,
  CompilationUnit unit,
) {
  final visitor = _RetiredShapeVisitor(path);
  unit.accept(visitor);

  return [..._checkRetiredShapeDeclarations(path, unit), ...visitor.violations];
}

List<GuardrailViolation> checkResourceResolverTypeReferences(
  String path,
  CompilationUnit unit, {
  bool requireResolvedElement = true,
}) {
  final visitor = _ResourceResolverBoundaryVisitor(
    path,
    requireResolvedElement: requireResolvedElement,
  );
  unit.accept(visitor);

  return visitor.violations;
}

List<GuardrailViolation> checkVectorPreparationApiRuntimeReferences(
  String path,
  CompilationUnit unit, {
  required bool requireResolvedElement,
}) {
  if (!path.startsWith(vectorPreparationApiOwnerPath)) {
    return const [];
  }

  return checkVectorPreparationDependencyRuntimeReferences(
    path,
    unit,
    requireResolvedElement: requireResolvedElement,
  );
}

List<GuardrailViolation> checkVectorPreparationDependencyRuntimeReferences(
  String path,
  CompilationUnit unit, {
  required bool requireResolvedElement,
}) {
  final visitor = _VectorPreparationRuntimeBoundaryVisitor(
    path,
    requireResolvedElement: requireResolvedElement,
  );
  unit.accept(visitor);

  return visitor.violations;
}

List<GuardrailViolation> _checkRetiredShapeDeclarations(
  String path,
  CompilationUnit unit,
) {
  return _topLevelDeclarationNames(unit)
      .where(_isRetiredShapeName)
      .map((name) => _retiredShapeViolation(path, name))
      .toList();
}

Iterable<String> _topLevelDeclarationNames(CompilationUnit unit) sync* {
  for (final declaration in unit.declarations) {
    final name = _topLevelDeclarationName(declaration);
    if (name != null) {
      yield name;
    }
    if (declaration case TopLevelVariableDeclaration(:final variables)) {
      for (final variable in variables.variables) {
        yield variable.name.lexeme;
      }
    }
  }
}

String? _topLevelDeclarationName(CompilationUnitMember declaration) {
  return switch (declaration) {
    ClassDeclaration(:final namePart) => namePart.typeName.lexeme,
    ClassTypeAlias(:final name) => name.lexeme,
    EnumDeclaration(:final namePart) => namePart.typeName.lexeme,
    FunctionDeclaration(:final name) => name.lexeme,
    GenericTypeAlias(:final name) => name.lexeme,
    MixinDeclaration(:final name) => name.lexeme,
    _ => null,
  };
}

final class _RetiredShapeVisitor extends RecursiveAstVisitor<void> {
  _RetiredShapeVisitor(this.path);

  final String path;
  final List<GuardrailViolation> violations = [];

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    _recordName(node.name, node.element);
  }

  @override
  void visitNamedType(NamedType node) {
    _recordName(node.name.lexeme, node.element);
    super.visitNamedType(node);
  }

  void _recordName(String name, Element? element) {
    if (!_isRetiredShapeDependency(name, element)) {
      return;
    }
    violations.add(_retiredShapeViolation(path, name));
  }
}

final class _ResourceResolverBoundaryVisitor extends RecursiveAstVisitor<void> {
  _ResourceResolverBoundaryVisitor(
    this.path, {
    required this.requireResolvedElement,
  });

  final String path;
  final bool requireResolvedElement;
  final List<GuardrailViolation> violations = [];

  @override
  void visitNamedType(NamedType node) {
    _record(name: node.name.lexeme, element: node.element, type: node.type);
    super.visitNamedType(node);
  }

  void _record({
    required String name,
    required Element? element,
    required DartType? type,
  }) {
    if (!_isCanvasResourceResolverTypeReference(
      name: name,
      element: element,
      type: type,
      requireResolvedElement: requireResolvedElement,
    )) {
      return;
    }
    violations.addAll(_resolverBoundaryViolation(path));
  }
}

final class _VectorPreparationRuntimeBoundaryVisitor
    extends RecursiveAstVisitor<void> {
  _VectorPreparationRuntimeBoundaryVisitor(
    this.path, {
    required this.requireResolvedElement,
  });

  final String path;
  final bool requireResolvedElement;
  final List<GuardrailViolation> violations = [];
  final Set<int> _assetReferenceOffsets = {};

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    _recordAssetReference(
      offset: node.offset,
      name: node.name,
      element: node.element,
    );
  }

  @override
  void visitNamedType(NamedType node) {
    _recordAssetReference(
      offset: node.offset,
      name: node.name.lexeme,
      element: node.element,
    );
    super.visitNamedType(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (_isVectorPreparationAssetLoad(
          node,
          requireResolvedElement: requireResolvedElement,
        ) ||
        _isImmutableBufferExternalLoad(
          node,
          requireResolvedElement: requireResolvedElement,
        )) {
      _recordAssetViolation(node.target?.offset ?? node.offset);
    }
    super.visitMethodInvocation(node);
  }

  @override
  void visitPropertyAccess(PropertyAccess node) {
    if (_isImmutableBufferExternalLoadTearOff(
      node,
      requireResolvedElement: requireResolvedElement,
    )) {
      _recordAssetViolation(node.offset);
    }
    super.visitPropertyAccess(node);
  }

  @override
  void visitAssignmentExpression(AssignmentExpression node) {
    if (_isFlutterErrorOnErrorAssignment(
      node.leftHandSide,
      requireResolvedElement: requireResolvedElement,
    )) {
      violations.add(_vectorPreparationRuntimeViolation(path));
    }
    super.visitAssignmentExpression(node);
  }

  void _recordAssetReference({
    required int offset,
    required String name,
    required Element? element,
  }) {
    if (_isVectorPreparationAssetReference(
      name: name,
      element: element,
      requireResolvedElement: requireResolvedElement,
    )) {
      _recordAssetViolation(offset);
    }
  }

  void _recordAssetViolation(int offset) {
    if (_assetReferenceOffsets.add(offset)) {
      violations.add(_vectorPreparationRuntimeViolation(path));
    }
  }
}

bool _isCanvasResourceResolverTypeReference({
  required String name,
  required Element? element,
  required DartType? type,
  required bool requireResolvedElement,
}) {
  if (_isPublicCanvasResourceResolverElement(type?.element) ||
      _isPublicCanvasResourceResolverElement(element)) {
    return true;
  }

  return !requireResolvedElement && name == 'CanvasResourceResolver';
}

bool _isVectorPreparationAssetReference({
  required String name,
  required Element? element,
  required bool requireResolvedElement,
}) {
  if (!requireResolvedElement) {
    return name == 'rootBundle' || name.endsWith('AssetBundle');
  }

  if (name == 'rootBundle') {
    return _isFlutterServicesElement(element);
  }

  return _isFlutterAssetBundleElement(element);
}

bool _isVectorPreparationAssetLoad(
  MethodInvocation invocation, {
  required bool requireResolvedElement,
}) {
  final target = invocation.target;
  if (!_vectorPreparationAssetLoadMethods.contains(
        invocation.methodName.name,
      ) ||
      target == null) {
    return false;
  }

  if (requireResolvedElement) {
    return _isFlutterAssetBundleType(target.staticType);
  }

  return switch (target) {
    MethodInvocation(:final target, :final methodName)
        when methodName.name == 'of' &&
            _isDefaultAssetBundleReference(target) =>
      true,
    _ => false,
  };
}

bool _isImmutableBufferExternalLoad(
  MethodInvocation invocation, {
  required bool requireResolvedElement,
}) {
  if (!_immutableBufferExternalLoadMethods.contains(
    invocation.methodName.name,
  )) {
    return false;
  }

  if (requireResolvedElement) {
    final method = invocation.methodName.element;
    return method is MethodElement &&
        method.enclosingElement?.displayName == 'ImmutableBuffer' &&
        method.library.uri.toString() == 'dart:ui';
  }

  final target = invocation.target;
  return switch (target) {
    PrefixedIdentifier(:final identifier) =>
      identifier.name == 'ImmutableBuffer',
    PropertyAccess(:final propertyName) =>
      propertyName.name == 'ImmutableBuffer',
    _ => false,
  };
}

bool _isImmutableBufferExternalLoadTearOff(
  PropertyAccess access, {
  required bool requireResolvedElement,
}) {
  if (!_immutableBufferExternalLoadMethods.contains(access.propertyName.name)) {
    return false;
  }

  if (requireResolvedElement) {
    final method = access.propertyName.element;
    return method is MethodElement &&
        method.enclosingElement?.displayName == 'ImmutableBuffer' &&
        method.library.uri.toString() == 'dart:ui';
  }

  return switch (access.target) {
    PrefixedIdentifier(:final identifier) =>
      identifier.name == 'ImmutableBuffer',
    PropertyAccess(:final propertyName) =>
      propertyName.name == 'ImmutableBuffer',
    _ => false,
  };
}

bool _isFlutterAssetBundleType(DartType? type) {
  return type is InterfaceType && _isFlutterAssetBundleElement(type.element);
}

bool _isFlutterAssetBundleElement(Element? element) {
  return _isExactFlutterAssetBundleElement(element) ||
      (element is InterfaceElement &&
          element.allSupertypes.any(
            (supertype) => _isExactFlutterAssetBundleElement(supertype.element),
          ));
}

bool _isExactFlutterAssetBundleElement(Element? element) {
  return element?.displayName == 'AssetBundle' &&
      _isFlutterServicesElement(element);
}

bool _isDefaultAssetBundleReference(Expression? expression) {
  final reference = switch (expression) {
    SimpleIdentifier() => expression,
    PrefixedIdentifier(:final identifier) => identifier,
    _ => null,
  };

  return reference is SimpleIdentifier &&
      reference.name == 'DefaultAssetBundle';
}

bool _isFlutterErrorOnErrorAssignment(
  Expression expression, {
  required bool requireResolvedElement,
}) {
  return switch (expression) {
    PropertyAccess(:final target, :final propertyName) =>
      propertyName.name == 'onError' &&
          _isFlutterErrorReference(
            target,
            requireResolvedElement: requireResolvedElement,
          ),
    PrefixedIdentifier(:final prefix, :final identifier) =>
      identifier.name == 'onError' &&
          _isFlutterErrorReference(
            prefix,
            requireResolvedElement: requireResolvedElement,
          ),
    _ => false,
  };
}

bool _isFlutterErrorReference(
  Expression? expression, {
  required bool requireResolvedElement,
}) {
  final reference = switch (expression) {
    SimpleIdentifier() => expression,
    PrefixedIdentifier(:final identifier) => identifier,
    _ => null,
  };
  if (reference is! SimpleIdentifier || reference.name != 'FlutterError') {
    return false;
  }

  return !requireResolvedElement ||
      _isFlutterFoundationElement(reference.element);
}

bool _isFlutterServicesElement(Element? element) =>
    _isFlutterLibraryElement(element, '/services/');

bool _isFlutterFoundationElement(Element? element) =>
    _isFlutterLibraryElement(element, '/foundation/');

bool _isFlutterLibraryElement(Element? element, String libraryPath) {
  final libraryUri = element?.library?.uri.toString();

  return libraryUri != null &&
      libraryUri.startsWith('package:flutter/') &&
      libraryUri.contains(libraryPath);
}

GuardrailViolation _vectorPreparationRuntimeViolation(String path) {
  return GuardrailViolation(
    guardrailId: 'core.import_boundaries',
    path: path,
    message:
        'vector preparation dependencies may not load assets or assign '
        'FlutterError.onError',
  );
}

bool _isPublicCanvasResourceResolverElement(Element? element) {
  final libraryUri = element?.library?.uri.toString();

  return element?.displayName == 'CanvasResourceResolver' &&
      libraryUri ==
          'package:iwb_canvas_engine/src/contracts/public/canvas_resource.dart';
}

List<GuardrailViolation> _resolverBoundaryViolation(String path) {
  if (_isUnauthorizedResourceResolverOwnerPath(path)) {
    return [
      GuardrailViolation(
        guardrailId: 'resources.resolver_boundary_owned_by_surface_session',
        path: path,
        message:
            'resource code must route typed CanvasResourceResolver ownership '
            'through SurfaceResourceSession',
      ),
    ];
  }
  if (!path.startsWith('lib/src/frame/') &&
      !path.startsWith('lib/src/interaction/') &&
      !_isSurfacePainterPath(path)) {
    return const [];
  }

  return [
    GuardrailViolation(
      guardrailId: 'resources.resolver_boundary_owned_by_surface_session',
      path: path,
      message:
          'frame, interaction, and surface painter code must not own typed '
          'CanvasResourceResolver references',
    ),
  ];
}

GuardrailViolation _retiredShapeViolation(String path, String name) {
  if (_sceneControllerShapeNames.contains(name)) {
    return GuardrailViolation(
      guardrailId: 'core.no_unapproved_controller_shape_dependency',
      path: path,
      message: 'references unapproved controller shape $name',
    );
  }

  return GuardrailViolation(
    guardrailId: 'core.no_unapproved_patch_shape_dependency',
    path: path,
    message: 'references unapproved patch shape $name',
  );
}

bool _isRetiredShapeDependency(String name, Element? element) {
  final isRetiredName = _isRetiredShapeName(name);

  if (!isRetiredName) {
    return false;
  }

  return element == null ||
      _isRetiredPackageElement(element) ||
      _isProductionElement(element);
}

bool _isRetiredShapeName(String name) {
  return _sceneControllerShapeNames.contains(name) ||
      _nodeSpecPatchShapeNames.contains(name);
}

bool _isRetiredPackageElement(Element element) {
  final uri = element.library?.uri.toString();

  return uri != null && uri.contains('legacy/iwb_canvas_engine');
}

bool _isProductionElement(Element element) {
  final uri = element.library?.uri.toString();

  return uri != null && uri.startsWith('package:iwb_canvas_engine/src/');
}

bool _isSurfacePainterPath(String path) {
  if (!path.startsWith('lib/src/surface/')) {
    return false;
  }

  return path.split('/').last.contains('painter');
}

bool _isUnauthorizedResourceResolverOwnerPath(String path) {
  return path.startsWith('lib/src/resources/') &&
      path != 'lib/src/resources/surface_resource_session.dart';
}
