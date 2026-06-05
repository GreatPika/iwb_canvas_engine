import 'dart:io';

import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('selection chrome has no surface-owned hit target bridge', () {
    final surfaceWidget = File('lib/src/surface/canvas_surface_widget.dart');
    final pointerAdapter = File('lib/src/surface/pointer_adapter.dart');
    final buildPaintHost = _classMethod(
      _parse(surfaceWidget),
      '_CanvasSurfaceState',
      '_buildPaintHost',
    ).toSource();
    final adapterBuild = _classMethod(
      _parse(pointerAdapter),
      'CanvasSurfacePointerAdapter',
      'build',
    ).toSource();
    final nonPainterSurfaceSource = _surfaceOwnerSource(
      excludedBasenames: {
        'main_painter.dart',
        'overlay_painter.dart',
        'pointer_adapter.dart',
        'text_editing_overlay.dart',
      },
    );

    expect(
      _constructorCallCount(buildPaintHost, 'CanvasSurfacePointerAdapter'),
      1,
    );
    expect(buildPaintHost, contains('child: paintHost'));
    expect(buildPaintHost, contains('return paintHost;'));
    _expectNoPointerBridgeConstructors(buildPaintHost, allowedListenerCount: 0);
    _expectNoPointerBridgeConstructors(
      nonPainterSurfaceSource,
      allowedListenerCount: 0,
    );
    expect(_constructorCallCount(adapterBuild, 'Listener'), 1);
    expect(adapterBuild, contains('child: child'));
  });
}

String _surfaceOwnerSource({required Set<String> excludedBasenames}) {
  final buffer = StringBuffer();
  for (final entity
      in Directory('lib/src/surface')
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'))
          .where((file) => !excludedBasenames.contains(_basename(file.path)))) {
    buffer
      ..writeln(entity.path)
      ..writeln(entity.readAsStringSync());
  }

  return buffer.toString();
}

String _basename(String path) {
  return path.split(Platform.pathSeparator).last;
}

int _constructorCallCount(String source, String typeName) {
  return RegExp('\\b$typeName\\s*\\(').allMatches(source).length;
}

void _expectNoPointerBridgeConstructors(
  String source, {
  required int allowedListenerCount,
}) {
  expect(_constructorCallCount(source, 'Listener'), allowedListenerCount);
  for (final typeName in [
    'GestureDetector',
    'RawGestureDetector',
    'MouseRegion',
  ]) {
    expect(_constructorCallCount(source, typeName), 0);
  }
}

CompilationUnit _parse(File file) {
  return parseString(
    content: file.readAsStringSync(),
    featureSet: FeatureSet.latestLanguageVersion(),
  ).unit;
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
