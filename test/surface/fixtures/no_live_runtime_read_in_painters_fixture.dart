import 'dart:io';

import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/src/frame/render_element_record.dart';
import 'package:iwb_canvas_engine/src/surface/main_painter.dart';

import '../../frame/fixtures/ordinary_paint_test_support.dart';

void main() {
  _registerPainterBoundaryTests();
  _registerOverlayPainterBoundaryTests();
  _registerMainPainterBoundaryTests();
  _registerPaintOrderTests();
  _registerSelectionChromeBoundaryTests();
}

void _registerPainterBoundaryTests() {
  test('surface painters import only immutable frame paint outputs', () {
    expect(File('lib/src/surface/main_painter.dart').existsSync(), isTrue);
    _expectPainterBoundary('lib/src/surface/main_painter.dart');
    _expectPainterBoundary('lib/src/surface/overlay_painter.dart');
  });
}

void _registerOverlayPainterBoundaryTests() {
  test('overlay painter consumes primitive paint data', () {
    final overlayPainterSource = File(
      'lib/src/surface/overlay_painter.dart',
    ).readAsStringSync();
    expect(
      overlayPainterSource,
      contains('case final PendingLineStartOverlayPrimitive primitive'),
    );
    expect(overlayPainterSource, contains('Paint()..color = primitive.color'));
    expect(overlayPainterSource, isNot(contains('BlendMode.clear')));
    expect(overlayPainterSource, contains('_paintEraserOverlay'));
  });
}

void _registerMainPainterBoundaryTests() {
  test('main painter consumes derived frame plans', () {
    final mainPainterSource = File(
      'lib/src/surface/main_painter.dart',
    ).readAsStringSync();

    expect(mainPainterSource, contains('staticBackgroundPlan'));
    expect(mainPainterSource, contains('drawPicture'));
    expect(mainPainterSource, isNot(contains('StaticBackgroundPrimitive')));
    expect(mainPainterSource, contains('selectionDecorationPlan'));
    expect(
      mainPainterSource,
      contains('paintMainFrameRecordsAndSelectionDecorations(canvas, output)'),
    );
    expect(
      mainPainterSource,
      isNot(contains('void _paintSelectionDecorations(')),
    );
    expect(mainPainterSource, isNot(contains('.sort(')));
    expect(mainPainterSource, isNot(contains('SelectedOrderSnapshot')));
    expect(mainPainterSource, isNot(contains('selectedOrderSnapshot')));
    expect(mainPainterSource, isNot(contains('saveLayer')));
    expect(mainPainterSource, isNot(contains('ordinaryPaintRecordCache')));
  });
}

void _registerSelectionChromeBoundaryTests() {
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
      excludedBasenames: {'main_painter.dart', 'overlay_painter.dart'},
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
      allowedListenerCount: 1,
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

void _registerPaintOrderTests() {
  test('main painter consumes records bottom-to-top', () {
    final bottom = RenderElementRecord.fromFacts(
      rectFacts('bottom', orderToken: 1),
    );
    final top = RenderElementRecord.fromFacts(rectFacts('top', orderToken: 2));

    expect(
      mainFrameRecordsInPaintOrder([top, bottom]).map((record) => record.id),
      [bottom.id, top.id],
    );
    expect(
      mainFrameRecordsInPaintOrder([bottom, top]).map((record) => record.id),
      [bottom.id, top.id],
    );
  });
}

void _expectPainterBoundary(String path) {
  final source = File(path).readAsStringSync();

  expect(source, contains('FramePaintOutput'));
  _expectNoLivePaintInputs(source);
}

void _expectNoLivePaintInputs(String source) {
  for (final forbidden in [
    'RuntimeRoot',
    'DocumentStoreKernel',
    'CanvasRuntime',
    'SurfaceResourceSession',
    'CanvasResourceResolver',
    'readDocument',
    'resolveImage',
  ]) {
    expect(source, isNot(contains(forbidden)));
  }
}
