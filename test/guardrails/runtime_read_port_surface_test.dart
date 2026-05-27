// This guardrail imports analyzer AST APIs directly so read-port surfaces are
// checked structurally instead of by fragile text search.
// ignore_for_file: number-of-external-imports

import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:test/test.dart';

import '../../tool/guardrails/src/repository_paths.dart';

// This test keeps the runtime read-port surface contract in one AST assertion
// so document, frame, and selection port claims cannot drift independently.
// ignore: halstead-volume
void main() {
  test(
    'runtime read-port declarations expose immutable fact surfaces',
    () async {
      const forbiddenReadPortTypes = {
        'CanvasDocument',
        'CommittedDocument',
        'DocumentStoreKernel',
        'DocumentProjectionCache',
        'CanvasSelectionPort',
        'RenderElementRecord',
        'PaintPlan',
      };
      expect(forbiddenReadPortTypes, isNotEmpty);

      await _expectDocumentPortSurface(forbiddenReadPortTypes);
      await _expectFramePortSurface(forbiddenReadPortTypes);
      await _expectSelectionPortSurfaces(forbiddenReadPortTypes);
    },
  );

  test('collection fields must be frozen by every constructor', () async {
    final unit = await _resolveFixture('''
final class BadFacts {
  BadFacts({required Iterable<int> values})
    : values = Set.unmodifiable(values);

  BadFacts.raw(this.values);

  final Set<int> values;
}
''');

    expect(
      () => _expectFrozenCollectionFields(unit, 'BadFacts'),
      throwsA(isA<TestFailure>()),
    );
  });
}

Future<void> _expectDocumentPortSurface(
  Set<String> forbiddenReadPortTypes,
) async {
  final documentPort = await _resolve(
    'lib/src/contracts/internal/document_facts_port.dart',
  );

  expect(documentPort.declarations, isNotEmpty);
  _expectNoTypeReferences(documentPort, forbiddenReadPortTypes);
  _expectFinalClass(documentPort, 'DocumentFacts');
  _expectOnlyFinalFields(documentPort, 'DocumentFacts');
  _expectFrozenCollectionFields(documentPort, 'DocumentFacts');
}

Future<void> _expectFramePortSurface(Set<String> forbiddenReadPortTypes) async {
  final framePort = await _resolve(
    'lib/src/contracts/internal/frame_facts_port.dart',
  );

  expect(framePort.declarations, isNotEmpty);
  _expectNoTypeReferences(framePort, {
    ...forbiddenReadPortTypes,
    'SelectionFacts',
  });
  _expectFinalClass(framePort, 'FrameRevisionFacts');
  _expectFinalClass(framePort, 'FrameElementHandle');
  _expectFinalClass(framePort, 'FrameElementFacts');
  _expectFinalClass(framePort, 'FrameResourceDescriptorFacts');
  _expectOnlyFinalFields(framePort, 'FrameRevisionFacts');
  _expectOnlyFinalFields(framePort, 'FrameElementHandle');
  _expectOnlyFinalFields(framePort, 'FrameElementFacts');
  _expectOnlyFinalFields(framePort, 'FrameResourceDescriptorFacts');
  _expectFrozenCollectionFields(framePort, 'FrameElementFacts');
}

Future<void> _expectSelectionPortSurfaces(
  Set<String> forbiddenReadPortTypes,
) async {
  final selectionFactsPort = await _resolve(
    'lib/src/contracts/internal/selection_facts_port.dart',
  );
  final selectionMembershipPort = await _resolve(
    'lib/src/contracts/internal/selection_membership_port.dart',
  );

  expect(selectionFactsPort.declarations, isNotEmpty);
  expect(selectionMembershipPort.declarations, isNotEmpty);
  _expectNoTypeReferences(selectionFactsPort, forbiddenReadPortTypes);
  _expectNoTypeReferences(selectionMembershipPort, forbiddenReadPortTypes);
  _expectFinalClass(selectionFactsPort, 'SelectionFacts');
  _expectInterface(selectionFactsPort, 'SelectionFactsPort');
  _expectInterface(selectionMembershipPort, 'SelectionMembershipPort');
  _expectOnlyFinalFields(selectionFactsPort, 'SelectionFacts');
  _expectFrozenCollectionFields(selectionFactsPort, 'SelectionFacts');
}

Future<CompilationUnit> _resolve(String path) async {
  final collection = AnalysisContextCollection(
    includedPaths: ['$repositoryRoot/lib'],
  );
  try {
    final absolutePath = '$repositoryRoot/$path';
    final context = collection.contextFor(absolutePath);
    final result = await context.currentSession.getResolvedUnit(absolutePath);
    if (result is ResolvedUnitResult) {
      return result.unit;
    }

    throw StateError('Could not resolve $path');
  } finally {
    await collection.dispose();
  }
}

Future<CompilationUnit> _resolveFixture(String content) async {
  final path = '$repositoryRoot/.dart_tool/runtime_read_port_fixture.dart';
  final file = File(path);
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(content);

  final collection = AnalysisContextCollection(
    includedPaths: [file.absolute.path, '$repositoryRoot/lib'],
  );
  try {
    final context = collection.contextFor(file.absolute.path);
    final resolved = await context.currentSession.getResolvedUnit(
      file.absolute.path,
    );
    if (resolved is ResolvedUnitResult) {
      return resolved.unit;
    }

    throw StateError('Could not resolve runtime read-port fixture');
  } finally {
    await collection.dispose();
    if (file.existsSync()) {
      file.deleteSync();
    }
  }
}

void _expectNoTypeReferences(
  CompilationUnit unit,
  Set<String> forbiddenTypeNames,
) {
  final visitor = _TypeReferenceVisitor();
  unit.accept(visitor);

  for (final typeName in forbiddenTypeNames) {
    expect(visitor.forbiddenTypeNames, isNot(contains(typeName)));
  }
}

void _expectFinalClass(CompilationUnit unit, String className) {
  expect(_classDeclaration(unit, className).finalKeyword, isNotNull);
}

void _expectInterface(CompilationUnit unit, String className) {
  final declaration = _classDeclaration(unit, className);

  expect(declaration.abstractKeyword, isNotNull);
  expect(declaration.interfaceKeyword, isNotNull);
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

void _expectFrozenCollectionFields(CompilationUnit unit, String className) {
  final declaration = _classDeclaration(unit, className);
  final collectionFields = _collectionFields(declaration);

  for (final constructor in _generativeConstructors(declaration)) {
    final constructorFrozenFields = _frozenConstructorFieldNames(constructor);
    expect(
      constructorFrozenFields,
      containsAll([
        for (final field in collectionFields)
          if (field.initializer == null) field.name.lexeme,
      ]),
    );
  }

  for (final field in collectionFields) {
    final initializer = field.initializer;
    if (initializer != null) {
      expect(_isImmutableCollectionExpression(initializer), isTrue);
      continue;
    }
    expect(_generativeConstructors(declaration), isNotEmpty);
  }
}

List<VariableDeclaration> _collectionFields(ClassDeclaration declaration) {
  return [
    for (final member in declaration.body.members.whereType<FieldDeclaration>())
      for (final variable in member.fields.variables)
        if (_isCollectionType(variable.declaredFragment?.element.type))
          variable,
  ];
}

Iterable<ConstructorDeclaration> _generativeConstructors(
  ClassDeclaration declaration,
) {
  return declaration.body.members.whereType<ConstructorDeclaration>().where(
    (constructor) => constructor.factoryKeyword == null,
  );
}

Set<String> _frozenConstructorFieldNames(ConstructorDeclaration constructor) {
  return {
    for (final initializer
        in constructor.initializers.whereType<ConstructorFieldInitializer>())
      if (_isUnmodifiableCall(initializer.expression))
        initializer.fieldName.name,
  };
}

bool _isCollectionType(DartType? type) {
  return type is InterfaceType && _isCoreCollectionName(type.element.name);
}

bool _isCoreCollectionName(String? name) {
  return _coreCollectionTypeNames.contains(name);
}

const _coreCollectionTypeNames = {'Iterable', 'List', 'Map', 'Set'};

bool _isUnmodifiableCall(Expression expression) {
  if (expression is MethodInvocation &&
      expression.methodName.name == 'unmodifiable' &&
      expression.target is SimpleIdentifier &&
      ((expression.target as SimpleIdentifier).name == 'Map' ||
          (expression.target as SimpleIdentifier).name == 'List' ||
          (expression.target as SimpleIdentifier).name == 'Set')) {
    return true;
  }

  final source = expression.toSource();

  return source.startsWith('Map.unmodifiable(') ||
      source.startsWith('List.unmodifiable(') ||
      source.startsWith('Set.unmodifiable(');
}

bool _isImmutableCollectionExpression(Expression expression) {
  return _isUnmodifiableCall(expression) ||
      expression is ListLiteral && expression.constKeyword != null ||
      expression is SetOrMapLiteral && expression.constKeyword != null;
}

ClassDeclaration _classDeclaration(CompilationUnit unit, String className) {
  return unit.declarations.whereType<ClassDeclaration>().singleWhere(
    (declaration) => declaration.namePart.typeName.lexeme == className,
  );
}

final class _TypeReferenceVisitor extends RecursiveAstVisitor<void> {
  final Set<String> forbiddenTypeNames = {};
  final Set<DartType> _visitedTypes = {};

  @override
  void visitNamedType(NamedType node) {
    _collectForbiddenTypes(node.type);
    super.visitNamedType(node);
  }

  // Direct type traversal is enough for the P4 read-port surface contract.
  // ignore: cyclomatic-complexity, halstead-volume
  void _collectForbiddenTypes(DartType? type) {
    if (type == null || !_visitedTypes.add(type)) {
      return;
    }

    final element = type.element;
    if (element != null) {
      forbiddenTypeNames.add(element.name ?? type.getDisplayString());
    }

    switch (type) {
      case InterfaceType():
        for (final argument in type.typeArguments) {
          _collectForbiddenTypes(argument);
        }
      case FunctionType():
        _collectForbiddenTypes(type.returnType);
        for (final argument in type.normalParameterTypes) {
          _collectForbiddenTypes(argument);
        }
        for (final argument in type.optionalParameterTypes) {
          _collectForbiddenTypes(argument);
        }
        for (final argument in type.namedParameterTypes.values) {
          _collectForbiddenTypes(argument);
        }
      case RecordType():
        for (final field in type.positionalFields) {
          _collectForbiddenTypes(field.type);
        }
        for (final field in type.namedFields) {
          _collectForbiddenTypes(field.type);
        }
      case TypeParameterType():
        _collectForbiddenTypes(type.bound);
      default:
        break;
    }
  }
}
