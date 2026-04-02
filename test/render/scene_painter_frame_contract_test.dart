import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/src/controller/scene_store_controller.dart';
import 'package:iwb_canvas_engine/src/contract/transform2d.dart';
import 'package:iwb_canvas_engine/src/contract/snapshot.dart';
import 'package:iwb_canvas_engine/src/render/render_geometry_cache.dart';
import 'package:iwb_canvas_engine/src/render/scene_painter.dart';

// INV:INV-ENG-SCENE-PAINTER-FRAME-RESOLUTION

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'ScenePainter resolves preview delta and geometry once per node per frame',
    () {
      final geometryCache = RenderGeometryCache();
      var previewCalls = 0;

      final controller = SceneStoreController(
        initialSnapshot: SceneSnapshot(
          background: const BackgroundSnapshot(color: Color(0xFFFFFFFF)),
          layers: <ContentLayerSnapshot>[
            ContentLayerSnapshot(
              id: 'layer-frame-contract',
              nodes: <NodeSnapshot>[
                PathNodeSnapshot(
                  id: 'path-frame-contract',
                  svgPathData: 'M0 0 H30 V20 H0 Z',
                  fillColor: Color(0xFF81C784),
                  strokeColor: Color(0xFF000000),
                  strokeWidth: 4,
                  transform: Transform2D.translation(const Offset(50, 40)),
                ),
              ],
            ),
          ],
        ),
      );
      addTearDown(controller.dispose);
      controller.write<void>((writer) {
        writer.writeSelectionReplace(const <NodeId>{'path-frame-contract'});
      });
      final renderState = _ScenePainterFrameTestRenderState(
        snapshot: controller.snapshot,
        selectedNodeIds: controller.selectedNodeIds,
        previewDeltaReader: (_) {
          previewCalls += 1;
          return const Offset(5, -3);
        },
      );

      final painter = ScenePainter(
        controller: renderState,
        imageResolver: (_) => null,
        geometryCache: geometryCache,
        selectionStrokeWidth: 2,
      );

      painter.paint(TestRecordingCanvas(), const Size(120, 100));

      expect(previewCalls, 1);
      expect(geometryCache.debugBuildCount, 1);
      expect(geometryCache.debugHitCount, 0);
      expect(geometryCache.debugSize, 1);
    },
  );
}

final class _ScenePainterFrameTestRenderState extends SceneStoreController {
  _ScenePainterFrameTestRenderState({
    required SceneSnapshot snapshot,
    required Set<NodeId> selectedNodeIds,
    required this.previewDeltaReader,
  }) : _selectedNodeIds = selectedNodeIds,
       super(initialSnapshot: snapshot);

  final Set<NodeId> _selectedNodeIds;
  final Offset Function(NodeId nodeId) previewDeltaReader;

  @override
  Set<NodeId> get selectedNodeIds => _selectedNodeIds;

  @override
  Offset Function(NodeId nodeId) get previewDeltaResolver => previewDeltaReader;
}
