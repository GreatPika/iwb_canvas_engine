import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine_example/src/canvas_example_app.dart';
import 'package:iwb_canvas_engine_example/src/canvas_example_defaults.dart';
import 'package:iwb_canvas_engine_example/src/canvas_example_screen.dart';
import 'package:yaml/yaml.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  _registerStartupTests();
  _registerDefaultDocumentTests();
  _registerRuntimePolicyTests();
  _registerAssetTests();
}

void _registerStartupTests() {
  testWidgets('real example app starts with the public CanvasSurface', (
    tester,
  ) async {
    await tester.pumpWidget(const CanvasExampleApp());
    await tester.pump();

    expect(find.byType(CanvasExampleApp), findsOneWidget);
    expect(find.byType(CanvasExampleScreen), findsOneWidget);
    expect(find.byType(CanvasSurface), findsOneWidget);
  });
}

void _registerDefaultDocumentTests() {
  test('default document preserves the legacy startup canvas defaults', () {
    final document = createCanvasExampleDocument();

    expect(document.layers, hasLength(2));
    _expectDefaultLayers(document);
    _expectDefaultCameraAndBackground(document);
    _expectDefaultPalette(document);
  });
}

void _registerRuntimePolicyTests() {
  test('runtime config preserves selection and pointer startup policy', () {
    final config = createCanvasExampleRuntimeConfig();

    expect(config.clearSelectionOnDrawModeEnter, isTrue);
    expect(config.pointerPolicy.tapSlop, 16);
    expect(config.pointerPolicy.doubleTapSlop, 32);
    expect(config.pointerPolicy.doubleTapMaxDelayMs, 450);
  });

  test('runtime is constructed from public DTOs and exposes initial state', () {
    final runtime = createCanvasExampleRuntime();
    addTearDown(runtime.dispose);

    final document = runtime.readDocument();
    _expectDefaultLayers(document);
    expect(runtime.state.value.summary.layerCount, 2);
    expect(runtime.state.value.summary.elementCount, 0);
    expect(runtime.state.value.summary.resourceCount, 0);
    expect(runtime.tools.pointerPolicy.tapSlop, 16);
  });
}

void _registerAssetTests() {
  test('pubspec declares the app-owned cat image asset', () {
    final contents = File('pubspec.yaml').readAsStringSync();
    final pubspec = loadYaml(contents) as YamlMap;
    final flutter = pubspec['flutter'] as YamlMap;
    final dependencies = pubspec['dependencies'] as YamlMap;
    final engineDependency = dependencies['iwb_canvas_engine'] as YamlMap;

    expect(engineDependency['path'], '../');
    expect(flutter['uses-material-design'], isTrue);
    expect(flutter['assets'], contains('image/cat.png'));
    expect(File('image/cat.png').existsSync(), isTrue);
  });

  test('cat image asset loads through Flutter asset APIs', () async {
    final data = await rootBundle.load('image/cat.png');

    expect(data.lengthInBytes, greaterThan(0));
  });
}

void _expectDefaultLayers(CanvasDocument document) {
  expect(document.layers.map((layer) => layer.id.value), [
    'layer-auto-0',
    'layer-auto-1',
  ]);
  expect(document.layers.every((layer) => layer.elements.isEmpty), isTrue);
}

void _expectDefaultCameraAndBackground(CanvasDocument document) {
  expect(document.camera, CanvasCamera.origin);
  expect(document.background.color.toARGB32(), 0xFFFFFFFF);
  expect(document.background.grid.enabled, isFalse);
  expect(document.background.grid.cellSize, 10);
  expect(document.background.grid.color.toARGB32(), 0x1F000000);
}

void _expectDefaultPalette(CanvasDocument document) {
  expect(document.palette.penColors.map((color) => color.toARGB32()), [
    0xFF000000,
    0xFFE53935,
    0xFF1E88E5,
    0xFF43A047,
    0xFFFB8C00,
    0xFF8E24AA,
  ]);
  expect(document.palette.backgroundColors.map((color) => color.toARGB32()), [
    0xFFFFFFFF,
    0xFFFFF9C4,
    0xFFBBDEFB,
    0xFFC8E6C9,
  ]);
  expect(document.palette.gridSizes, [10, 20, 40, 80]);
}
