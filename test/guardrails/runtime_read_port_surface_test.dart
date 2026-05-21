import 'dart:io';

// This guardrail imports analyzer AST APIs directly so read-port surfaces are
// checked structurally instead of by fragile text search.
// ignore_for_file: number-of-external-imports

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:test/test.dart';

import '../../tool/guardrails/src/repository_paths.dart';

void main() {
  test('runtime read-port declarations expose immutable fact surfaces', () {
    final documentPort = _parse('lib/src/runtime/document_facts_port.dart');
    final framePort = _parse('lib/src/runtime/frame_facts_port.dart');

    expect(documentPort.declarations, isNotEmpty);
    expect(framePort.declarations, isNotEmpty);

    _expectNoTypeReferences(documentPort, {'CanvasDocument'});
    _expectNoTypeReferences(framePort, {
      'CanvasDocument',
      'CommittedDocument',
      'DocumentStoreKernel',
      'DocumentProjectionCache',
      'SelectionFacts',
      'CanvasSelectionPort',
      'RenderElementRecord',
      'PaintPlan',
    });

    _expectFinalClass(documentPort, 'DocumentFacts');
    _expectFinalClass(framePort, 'FrameElementFacts');
    _expectFinalClass(framePort, 'FrameResourceDescriptorFacts');
    _expectOnlyFinalFields(documentPort, 'DocumentFacts');
    _expectOnlyFinalFields(framePort, 'FrameElementFacts');
    _expectOnlyFinalFields(framePort, 'FrameResourceDescriptorFacts');
  });
}

CompilationUnit _parse(String path) {
  return parseString(
    content: File('$repositoryRoot/$path').readAsStringSync(),
    path: '$repositoryRoot/$path',
  ).unit;
}

void _expectNoTypeReferences(
  CompilationUnit unit,
  Set<String> forbiddenTypeNames,
) {
  final visitor = _TypeReferenceVisitor();
  unit.accept(visitor);

  for (final typeName in forbiddenTypeNames) {
    expect(visitor.typeNames, isNot(contains(typeName)));
  }
}

void _expectFinalClass(CompilationUnit unit, String className) {
  expect(_classDeclaration(unit, className).finalKeyword, isNotNull);
}

void _expectOnlyFinalFields(CompilationUnit unit, String className) {
  final declaration = _classDeclaration(unit, className);
  final nonFinalFields = [
    for (final member in declaration.body.members.whereType<FieldDeclaration>())
      if (!member.fields.isFinal)
        for (final variable in member.fields.variables) variable.name.lexeme,
  ];

  expect(nonFinalFields, isEmpty);
}

ClassDeclaration _classDeclaration(CompilationUnit unit, String className) {
  return unit.declarations.whereType<ClassDeclaration>().singleWhere(
    (declaration) => declaration.namePart.typeName.lexeme == className,
  );
}

final class _TypeReferenceVisitor extends RecursiveAstVisitor<void> {
  final Set<String> typeNames = {};

  @override
  void visitNamedType(NamedType node) {
    typeNames.add(node.name.lexeme);
    super.visitNamedType(node);
  }
}
