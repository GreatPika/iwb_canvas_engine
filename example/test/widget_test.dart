import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'dart:ui' as ui;
import 'package:iwb_canvas_engine_example/data/services/sample_image_asset_service.dart';

import 'package:iwb_canvas_engine_example/main.dart';

void main() {
  testWidgets('Renders canvas example app from injected controller', (
    WidgetTester tester,
  ) async {
    final controller = SceneController(
      initialSnapshot: SceneSnapshot(
        layers: <ContentLayerSnapshot>[
          ContentLayerSnapshot(id: 'layer-auto-0'),
          ContentLayerSnapshot(id: 'layer-auto-1'),
        ],
      ),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      CanvasExampleApp(
        controller: controller,
        sampleImageAssetService: _FakeSampleImageAssetService(),
      ),
    );
    await tester.pump();

    expect(find.byType(Scaffold), findsOneWidget);
    expect(find.byIcon(Icons.add_box_outlined), findsOneWidget);
  });

  testWidgets(
    'Outside tap closes inline text edit before canvas interaction begins',
    (WidgetTester tester) async {
      final controller = SceneController(
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
                  transform: Transform2D.translation(const Offset(120, 120)),
                ),
              ],
            ),
          ],
        ),
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        CanvasExampleApp(
          controller: controller,
          sampleImageAssetService: _FakeSampleImageAssetService(),
        ),
      );
      await tester.pump();

      controller.interaction.handleDoubleTap(
        position: const Offset(120, 120),
        timestampMs: 1,
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(TextField), findsOneWidget);
      expect(
        find.byKey(const Key('canvas-example-text-edit-dismiss-overlay')),
        findsOneWidget,
      );

      await tester.enterText(find.byType(TextField), 'updated');
      await tester.tap(
        find.byKey(const Key('canvas-example-text-edit-dismiss-overlay')),
      );
      await tester.pump();
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.byType(TextField), findsNothing);

      final layer = controller.snapshot.layers[1];
      final textNode = layer.nodes.single as TextNodeSnapshot;
      expect(textNode.text, 'updated');
      expect(textNode.isVisible, isTrue);
    },
  );
}

class _FakeSampleImageAssetService extends SampleImageAssetService {
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
