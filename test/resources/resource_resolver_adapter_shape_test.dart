import 'dart:io';

import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:test/test.dart';

void main() {
  _testRequestModelShape();
  _testResultStateShape();
  _testResourceBoundary();
}

void _testRequestModelShape() {
  test(
    'resource resolver adapter declares the P7 request and result model',
    () {
      final source = _adapterSource();
      final unit = _parse(source);

      expect(
        _topLevelNames(unit),
        contains('kMaxSyncResourceResolverCallsPerFrame'),
      );
      expect(
        source,
        contains('const int kMaxSyncResourceResolverCallsPerFrame = 128;'),
      );
      expect(_topLevelNames(unit), contains('ResourceImageResolveRequest'));
      _expectImageResourceConstructorArguments(source);
      expect(_fieldTypesByName(unit, 'ResourceImageResolveRequest'), {
        'id': 'CanvasResourceId',
        'appKey': 'String?',
        'mimeType': 'String?',
        'contentHash': 'String?',
        'byteLength': 'int?',
        'metadata': 'CanvasMetadata',
        'resourceRevision': 'int',
        'placeholderBounds': 'ui.Rect',
        'imageResource': 'CanvasImageResource?',
      });
      expect(source, contains('CanvasResourceSource.appKey(appKey)'));
      expect(
        source,
        contains('bool get hasDescriptor => imageResource != null;'),
      );
    },
  );
}

void _expectImageResourceConstructorArguments(String source) {
  expect(source, contains('id: resourceId,'));
  expect(source, contains('source: CanvasResourceSource.appKey(appKey),'));
  expect(source, contains('mimeType: mimeType,'));
  expect(source, contains('contentHash: contentHash,'));
  expect(source, contains('byteLength: byteLength,'));
  expect(source, contains('metadata: metadata,'));
}

void _testResultStateShape() {
  test('resource resolver adapter has explicit placeholder result states', () {
    final source = _adapterSource();
    final unit = _parse(source);

    expect(
      _topLevelNames(unit),
      containsAll([
        'ResourceImageResolveResult',
        'ResolvedResourceImage',
        'ResourceImagePlaceholderResult',
        'MissingDescriptorResourceImagePlaceholder',
        'NoResolverResourceImagePlaceholder',
        'NullResourceImagePlaceholder',
        'BudgetExceededResourceImagePlaceholder',
      ]),
    );
    expect(_fieldTypesByName(unit, 'ResourceImageResolveResult'), {
      'placeholderBounds': 'ui.Rect',
    });
    expect(_fieldTypesByName(unit, 'ResolvedResourceImage'), {
      'image': 'ui.Image',
    });
  });
}

void _testResourceBoundary() {
  test('resource resolver values stay resource-owned', () {
    final source = _adapterSource();
    final forbiddenImports = RegExp(
      r"(\.\./(runtime|store|frame|surface|interaction|diagnostics|flutter_bridge)/|"
      r"package:iwb_canvas_engine/src/(runtime|store|frame|surface|interaction|diagnostics|flutter_bridge)|"
      r"package:flutter/|dart:io)",
    );

    expect(source, isNot(matches(forbiddenImports)));
    expect(source, isNot(contains('AssetBundle')));
    expect(source, isNot(contains('File')));
    expect(source, isNot(contains('Network')));
    expect(source, isNot(contains('HttpClient')));
  });
}

String _adapterSource() {
  return File(
    'lib/src/resources/resource_resolver_adapter.dart',
  ).readAsStringSync();
}

CompilationUnit _parse(String content) {
  return parseString(
    content: content,
    featureSet: FeatureSet.latestLanguageVersion(),
  ).unit;
}

Set<String> _topLevelNames(CompilationUnit unit) {
  return unit.declarations.map(_declarationName).nonNulls.toSet();
}

String? _declarationName(CompilationUnitMember declaration) {
  return switch (declaration) {
    ClassDeclaration(:final namePart) => namePart.typeName.lexeme,
    TopLevelVariableDeclaration(:final variables) =>
      variables.variables.isEmpty
          ? null
          : variables.variables.first.name.lexeme,
    _ => null,
  };
}

Map<String, String> _fieldTypesByName(CompilationUnit unit, String className) {
  final declaration = unit.declarations
      .whereType<ClassDeclaration>()
      .singleWhere(
        (declaration) => declaration.namePart.typeName.lexeme == className,
      );
  final fields = declaration.body.members.whereType<FieldDeclaration>();

  return {
    for (final field in fields)
      for (final variable in field.fields.variables)
        variable.name.lexeme: field.fields.type?.toSource() ?? '',
  };
}
