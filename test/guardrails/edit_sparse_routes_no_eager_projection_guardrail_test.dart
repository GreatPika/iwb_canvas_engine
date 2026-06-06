import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:test/test.dart';

void main() {
  test('ordinary edit and interaction commit routes open sparse sessions', () {
    final source = File('lib/src/edit/edit_kernel.dart').readAsStringSync();
    final unit = parseString(content: source).unit;

    for (final route in _guardedRoutes) {
      final method = _classMethod(unit, 'EditKernel', route.methodName);
      final invocations = _methodInvocations(method);
      final createdTypes = _createdTypeNames(method);
      expect(
        invocations,
        contains('_openSparseSession'),
        reason: '${route.name} must open the sparse edit session route.',
      );
      expect(
        createdTypes,
        isNot(contains('DraftDocument')),
        reason:
            '${route.name} must not eagerly materialize the public projection.',
      );
      expect(
        invocations,
        isNot(contains('_readDocument')),
        reason:
            '${route.name} must not read the public projection before accepting sparse commits.',
      );
      expect(
        invocations,
        isNot(contains('readDraftDocument')),
        reason:
            '${route.name} must not materialize before accepting sparse commits.',
      );
    }
  });
}

MethodDeclaration _classMethod(
  CompilationUnit unit,
  String className,
  String methodName,
) {
  final declaration = unit.declarations
      .whereType<ClassDeclaration>()
      .singleWhere(
        (declaration) => declaration.namePart.typeName.lexeme == className,
      );

  return declaration.body.members.whereType<MethodDeclaration>().singleWhere((
    method,
  ) {
    return method.name.lexeme == methodName;
  });
}

Set<String> _methodInvocations(MethodDeclaration method) {
  final visitor = _MethodInvocationVisitor();
  method.body.accept(visitor);

  return visitor.invocations;
}

Set<String> _createdTypeNames(MethodDeclaration method) {
  final visitor = _InstanceCreationVisitor();
  method.body.accept(visitor);

  return visitor.typeNames;
}

final class _MethodInvocationVisitor extends RecursiveAstVisitor<void> {
  final Set<String> invocations = {};

  @override
  void visitMethodInvocation(MethodInvocation node) {
    invocations.add(node.methodName.name);
    super.visitMethodInvocation(node);
  }
}

final class _InstanceCreationVisitor extends RecursiveAstVisitor<void> {
  final Set<String> typeNames = {};

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    typeNames.add(node.constructorName.type.name.lexeme);
    super.visitInstanceCreationExpression(node);
  }
}

const _guardedRoutes = [
  (name: 'EditKernel.edit', methodName: 'edit'),
  (
    name: 'EditKernel.prepareInteractionCommit',
    methodName: 'prepareInteractionCommit',
  ),
];
