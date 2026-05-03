import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine_example/data/services/sample_image_asset_service.dart';
import 'package:iwb_canvas_engine_example/ui/canvas_example/view_models/canvas_example_view_model.dart';

void main() {
  test('internally created controller is disposed by the view model', () async {
    final viewModel = CanvasExampleViewModel(
      sampleImageAssetService: _FakeSampleImageAssetService(),
    );
    final controller = viewModel.controller;

    viewModel.dispose();

    expect(() => controller.scene.clearScene(), throwsA(isA<StateError>()));
  });

  test('injected controller is not disposed by the view model', () async {
    final controller = _createController();
    final viewModel = CanvasExampleViewModel(
      controller: controller,
      sampleImageAssetService: _FakeSampleImageAssetService(),
    );

    viewModel.dispose();

    expect(() => controller.scene.clearScene(), returnsNormally);
    controller.dispose();
  });

  test(
    'edit text request opens and closes a text edit session safely',
    () async {
      final controller = _createController();
      final viewModel = CanvasExampleViewModel(
        controller: controller,
        sampleImageAssetService: _FakeSampleImageAssetService(),
      );
      addTearDown(viewModel.dispose);

      controller.interaction.handleDoubleTap(
        position: const Offset(120, 120),
        timestampMs: 1,
      );
      await _flushAsyncEvents();

      expect(viewModel.editingNodeId, 'text-node');
      final editingNode = viewModel.editingTextNode;
      expect(editingNode, isNotNull);
      expect(editingNode?.isVisible, isFalse);

      viewModel.finishInlineTextEdit(save: true, text: 'updated');

      final committed = viewModel.findTextNode('text-node');
      expect(committed, isNotNull);
      expect(committed?.text, 'updated');
      expect(committed?.isVisible, isTrue);

      controller.scene.replaceScene(
        SceneSnapshot(
          layers: <ContentLayerSnapshot>[
            ContentLayerSnapshot(id: 'layer-auto-0'),
            ContentLayerSnapshot(id: 'layer-auto-1'),
          ],
        ),
      );
      viewModel.finishInlineTextEdit(save: false);
      expect(viewModel.editingNodeId, isNull);
    },
  );

  test(
    'selected text formatting commands patch only selected text nodes',
    () async {
      final controller = _createController();
      final viewModel = CanvasExampleViewModel(
        controller: controller,
        sampleImageAssetService: _FakeSampleImageAssetService(),
      );
      addTearDown(viewModel.dispose);

      controller.selection.setSelection(<NodeId>{'text-node'});

      viewModel.toggleSelectedTextBold();
      viewModel.setSelectedTextAlign(TextAlign.center);
      viewModel.setSelectedTextColor(const Color(0xFF112233));
      viewModel.setSelectedTextFontSize(30);

      final textNode = viewModel.findTextNode('text-node');
      expect(textNode, isNotNull);
      expect(textNode?.isBold, isTrue);
      expect(textNode?.align, TextAlign.center);
      expect(textNode?.color, const Color(0xFF112233));
      expect(textNode?.fontSize, 30);
      expect(textNode?.lineHeight, 45);
    },
  );

  test('exports current scene json', () {
    final controller = _createController();
    final viewModel = CanvasExampleViewModel(
      controller: controller,
      sampleImageAssetService: _FakeSampleImageAssetService(),
    );
    addTearDown(viewModel.dispose);

    final exportedJson = viewModel.exportSceneJson();

    expect(exportedJson, encodeSceneToJson(controller.snapshot));
    expect(viewModel.lastExportedJson, exportedJson);
  });

  test('imports decoded scenes and keeps current state on invalid json', () {
    final controller = _createController();
    final viewModel = CanvasExampleViewModel(
      controller: controller,
      sampleImageAssetService: _FakeSampleImageAssetService(),
    );
    addTearDown(viewModel.dispose);

    final nextScene = SceneSnapshot(
      layers: <ContentLayerSnapshot>[
        ContentLayerSnapshot(
          id: 'layer-auto-0',
          nodes: <NodeSnapshot>[
            RectNodeSnapshot(
              id: 'imported-rect',
              size: const Size(40, 20),
              fillColor: const Color(0xFF00FF00),
              transform: Transform2D.identity,
            ),
          ],
        ),
      ],
    );
    final json = encodeSceneToJson(nextScene);

    expect(viewModel.importSceneJson(json), isNull);
    expect(
      viewModel.controller.snapshot.layers.single.nodes.single.id,
      'imported-rect',
    );

    final previousJson = encodeSceneToJson(viewModel.controller.snapshot);
    final error = viewModel.importSceneJson('{');

    expect(error, isNotNull);
    expect(encodeSceneToJson(viewModel.controller.snapshot), previousJson);
  });

  test(
    'sample insertion adds rect, text, and image nodes with monotonic ids',
    () async {
      final controller = SceneController(
        initialSnapshot: SceneSnapshot(
          layers: <ContentLayerSnapshot>[
            ContentLayerSnapshot(id: 'layer-auto-0'),
          ],
        ),
      );
      final viewModel = CanvasExampleViewModel(
        controller: controller,
        sampleImageAssetService: _FakeSampleImageAssetService(),
      );
      addTearDown(viewModel.dispose);

      viewModel.addSampleObjects();
      viewModel.addSampleObjects();
      await _flushAsyncEvents();

      final nodes = viewModel.controller.snapshot.layers.single.nodes;
      expect(nodes.map((node) => node.id).toList(), <String>[
        'sample-0',
        'sample-1',
        'sample-2',
        'sample-3',
        'sample-4',
        'sample-5',
      ]);
      expect(nodes[0], isA<RectNodeSnapshot>());
      expect(nodes[1], isA<TextNodeSnapshot>());
      expect(nodes[2], isA<ImageNodeSnapshot>());
      expect(
        (nodes[2] as ImageNodeSnapshot).imageId,
        CanvasExampleViewModel.sampleCatImageId,
      );
      expect(nodes[3], isA<RectNodeSnapshot>());
      expect(nodes[4], isA<TextNodeSnapshot>());
      expect(nodes[5], isA<ImageNodeSnapshot>());
    },
  );
}

Future<void> _flushAsyncEvents() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

SceneController _createController() {
  return SceneController(
    initialSnapshot: SceneSnapshot(
      layers: <ContentLayerSnapshot>[
        ContentLayerSnapshot(id: 'layer-auto-0'),
        ContentLayerSnapshot(
          id: 'layer-auto-1',
          nodes: <NodeSnapshot>[
            TextNodeSnapshot(
              id: 'text-node',
              text: 'hello',
              color: const Color(0xFF000000),
              textDirection: TextDirection.ltr,
              fontSize: 24,
              lineHeight: 36,
              transform: Transform2D.translation(const Offset(120, 120)),
            ),
            RectNodeSnapshot(
              id: 'rect-node',
              size: const Size(32, 24),
              fillColor: const Color(0xFFCCCCCC),
              transform: Transform2D.translation(const Offset(40, 40)),
            ),
          ],
        ),
      ],
    ),
  );
}

class _FakeSampleImageAssetService extends SampleImageAssetService {
  _FakeSampleImageAssetService();

  @override
  Future<ui.Image> loadSampleCatImage() => _createTestImage();
}

Future<ui.Image> _createTestImage() async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(
    const Rect.fromLTWH(0, 0, 1, 1),
    Paint()..color = const Color(0xFF000000),
  );
  final picture = recorder.endRecording();
  return picture.toImage(1, 1);
}
