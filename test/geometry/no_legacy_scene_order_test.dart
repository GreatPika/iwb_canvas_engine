import 'dart:io';

import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:test/test.dart';

void main() {
  _testGeometryImportsCommittedFacts();
  _testTopmostUsesCommittedHandleOrder();
}

void _testGeometryImportsCommittedFacts() {
  test('geometry imports committed facts and not legacy scene owners', () {
    final units = _geometryUnits();

    expect(
      _importUris(units),
      contains('../contracts/internal/frame_facts_port.dart'),
    );
    expect(_forbiddenOwnerImports(_importUris(units)), isEmpty);
    expect(_declaredTypeNames(units), isNot(contains('SceneNode')));
    expect(_declaredTypeNames(units), isNot(contains('NodeSnapshot')));
    expect(_declaredTypeNames(units), isNot(contains('SceneController')));
  });
}

void _testTopmostUsesCommittedHandleOrder() {
  test('topmost hit resolution uses committed handle order tokens', () {
    final unit = _parse(File('lib/src/geometry/hit_test_policy.dart'));
    final method = _classMethod(unit, 'HitTestPolicy', 'topmostHitResult');
    final source = method.toSource();

    expect(source, contains('FrameElementHandle'));
    expect(source, contains('orderToken.compareTo'));
    expect(source, contains('resolve(handle)'));
    expect(source, contains('HitTestResult'));
    expect(source, isNot(contains('scene.layers')));
    expect(source, isNot(contains('layer.nodes')));
  });
}

List<CompilationUnit> _geometryUnits() {
  return [
    _parse(File('lib/src/geometry/geometry_policy.dart')),
    _parse(File('lib/src/geometry/hit_test_policy.dart')),
  ];
}

CompilationUnit _parse(File file) {
  return parseString(
    content: file.readAsStringSync(),
    featureSet: FeatureSet.latestLanguageVersion(),
  ).unit;
}

Set<String> _importUris(Iterable<CompilationUnit> units) {
  return {
    for (final unit in units)
      for (final directive in unit.directives.whereType<ImportDirective>())
        directive.uri.stringValue ?? '',
  };
}

Set<String> _forbiddenOwnerImports(Set<String> uris) {
  return uris.where(_isForbiddenOwnerImport).toSet();
}

bool _isForbiddenOwnerImport(String uri) {
  final normalized = uri.startsWith('package:iwb_canvas_engine/src/')
      ? uri.replaceFirst('package:iwb_canvas_engine/src/', '../')
      : uri;

  return normalized.startsWith('../store/') ||
      normalized.startsWith('../runtime/') ||
      normalized.startsWith('../frame/') ||
      normalized.startsWith('../interaction/');
}

Set<String> _declaredTypeNames(Iterable<CompilationUnit> units) {
  final names = <String>{};
  for (final unit in units) {
    for (final declaration in unit.declarations) {
      final name = _typeName(declaration);
      if (name != null) {
        names.add(name);
      }
    }
  }

  return names;
}

String? _typeName(CompilationUnitMember declaration) {
  return switch (declaration) {
    ClassDeclaration(:final namePart) => namePart.typeName.lexeme,
    EnumDeclaration(:final namePart) => namePart.typeName.lexeme,
    MixinDeclaration(:final name) => name.lexeme,
    ExtensionDeclaration(:final name) => name?.lexeme,
    _ => null,
  };
}

MethodDeclaration _classMethod(
  CompilationUnit unit,
  String className,
  String methodName,
) {
  final declaration = unit.declarations
      .whereType<ClassDeclaration>()
      .singleWhere(
        (candidate) => candidate.namePart.typeName.lexeme == className,
      );

  return declaration.body.members.whereType<MethodDeclaration>().singleWhere(
    (candidate) => candidate.name.lexeme == methodName,
  );
}
