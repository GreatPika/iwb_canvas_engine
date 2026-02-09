import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/src/v2/controller/scene_controller_v2.dart';
import 'package:iwb_canvas_engine/src/v2/public/snapshot.dart';
import 'package:iwb_canvas_engine/src/v2/render/scene_painter_v2.dart';

Future<Image> _paintToImage(
  ScenePainterV2 painter, {
  int width = 120,
  int height = 120,
}) async {
  final recorder = PictureRecorder();
  final canvas = Canvas(recorder);
  painter.paint(canvas, Size(width.toDouble(), height.toDouble()));
  final picture = recorder.endRecording();
  return picture.toImage(width, height);
}

Future<int> _countNonBackgroundPixels(Image image, Color background) async {
  final data = await image.toByteData(format: ImageByteFormat.rawRgba);
  if (data == null) {
    throw StateError('Failed to encode image to raw RGBA.');
  }
  final bytes = data.buffer.asUint8List();
  final bg = background.toARGB32();
  final bgA = (bg >> 24) & 0xFF;
  final bgR = (bg >> 16) & 0xFF;
  final bgG = (bg >> 8) & 0xFF;
  final bgB = bg & 0xFF;

  var count = 0;
  for (var i = 0; i < bytes.length; i += 4) {
    if (bytes[i] != bgR ||
        bytes[i + 1] != bgG ||
        bytes[i + 2] != bgB ||
        bytes[i + 3] != bgA) {
      count++;
    }
  }
  return count;
}

void main() {
  test('ScenePainterV2 paints snapshot without throwing', () async {
    final controller = SceneControllerV2(
      initialSnapshot: SceneSnapshot(
        layers: <LayerSnapshot>[
          LayerSnapshot(
            nodes: const <NodeSnapshot>[
              RectNodeSnapshot(
                id: 'rect-1',
                size: Size(40, 30),
                fillColor: Color(0xFF2196F3),
              ),
            ],
          ),
        ],
      ),
    );
    addTearDown(controller.dispose);

    final painter = ScenePainterV2(
      controller: controller,
      imageResolver: (_) => null,
    );

    await _paintToImage(painter, width: 80, height: 80);
  });

  test(
    'ScenePainterV2 keeps grid visible with over-density via stride',
    () async {
      const background = Color(0xFFFFFFFF);
      final controller = SceneControllerV2(
        initialSnapshot: SceneSnapshot(
          background: BackgroundSnapshot(
            color: background,
            grid: GridSnapshot(
              isEnabled: true,
              cellSize: 1,
              color: Color(0xFF000000),
            ),
          ),
        ),
      );
      addTearDown(controller.dispose);

      final painter = ScenePainterV2(
        controller: controller,
        imageResolver: (_) => null,
      );
      final image = await _paintToImage(painter, width: 500, height: 500);
      final nonBackground = await _countNonBackgroundPixels(image, background);
      expect(nonBackground, greaterThan(0));
    },
  );
}
