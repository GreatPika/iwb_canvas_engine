import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/src/controller/scene_store_controller.dart';
import 'package:iwb_canvas_engine/src/contract/transform2d.dart';
import 'package:iwb_canvas_engine/src/contract/snapshot.dart';
import 'package:iwb_canvas_engine/src/contract/scene_view_render_state.dart';
import 'package:iwb_canvas_engine/src/interactive/internal/scene_controller_scene_view_runtime.dart';
import 'package:iwb_canvas_engine/src/interactive/scene_controller.dart'
    as interactive;
import 'package:iwb_canvas_engine/src/render/render_geometry_cache.dart';
import 'package:iwb_canvas_engine/src/render/scene_painter.dart';

// INV:INV-ENG-SCENE-PAINTER-FRAME-RESOLUTION

SceneViewRenderState _controllerOwnedRenderState(
  SceneStoreController controller, {
  Set<NodeId> selectedNodeIds = const <NodeId>{},
  Offset Function(NodeId nodeId)? previewDeltaResolver,
  SceneSnapshot? snapshotOverride,
}) {
  final owner = ChangeNotifier();
  addTearDown(owner.dispose);
  final interactionController = interactive.SceneController();
  addTearDown(interactionController.dispose);
  return SceneControllerSceneViewRenderState(
    storeController: controller,
    ownerListenable: owner,
    readSnapshot: () => snapshotOverride ?? controller.snapshot,
    readSelectedNodeIds: () => selectedNodeIds,
    readControllerEpoch: () => controller.controllerEpoch,
    readPreviewDeltaResolver: () => previewDeltaResolver ?? (_) => Offset.zero,
    readInteraction: () => interactionController.interaction,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'ScenePainter resolves geometry only for controller-owned paint candidates',
    () {
      final geometryCache = RenderGeometryCache();
      final controller = SceneStoreController(
        initialSnapshot: SceneSnapshot(
          background: BackgroundSnapshot(color: Color(0xFFFFFFFF)),
          layers: <ContentLayerSnapshot>[
            ContentLayerSnapshot(
              id: 'layer-frame-contract',
              nodes: <NodeSnapshot>[
                RectNodeSnapshot(
                  id: 'offscreen-frame-contract',
                  size: const Size(20, 20),
                  fillColor: const Color(0xFF000000),
                  transform: Transform2D.translation(const Offset(220, 220)),
                ),
                PathNodeSnapshot(
                  id: 'visible-frame-contract',
                  svgPathData: 'M0 0 H30 V20 H0 Z',
                  fillColor: Color(0xFF81C784),
                  strokeColor: Color(0xFF000000),
                  strokeWidth: 4,
                  transform: Transform2D.translation(const Offset(50, 40)),
                ),
                RectNodeSnapshot(
                  id: 'second-offscreen-frame-contract',
                  size: const Size(16, 16),
                  fillColor: const Color(0xFF000000),
                  transform: Transform2D.translation(const Offset(-220, -220)),
                ),
              ],
            ),
          ],
        ),
      );
      addTearDown(controller.dispose);
      final renderState = _controllerOwnedRenderState(controller);

      final painter = ScenePainter(
        controller: renderState,
        imageResolver: (_) => null,
        geometryCache: geometryCache,
        selectionStrokeWidth: 2,
      );

      painter.paint(TestRecordingCanvas(), const Size(120, 100));

      expect(geometryCache.debugBuildCount, 1);
      expect(geometryCache.debugHitCount, 0);
      expect(geometryCache.debugSize, 1);
    },
  );

  test(
    'controller-owned render state orders background and preview supplements before resolution',
    () {
      final controller = SceneStoreController(
        initialSnapshot: SceneSnapshot(
          background: BackgroundSnapshot(color: Color(0xFFFFFFFF)),
          backgroundLayer: BackgroundLayerSnapshot(
            nodes: <NodeSnapshot>[
              RectNodeSnapshot(
                id: 'bg-candidate',
                size: const Size(24, 24),
                fillColor: const Color(0xFF1E88E5),
                transform: Transform2D.translation(const Offset(20, 20)),
              ),
            ],
          ),
          layers: <ContentLayerSnapshot>[
            ContentLayerSnapshot(
              id: 'layer-0',
              nodes: <NodeSnapshot>[
                RectNodeSnapshot(
                  id: 'previewed-candidate',
                  size: const Size(20, 20),
                  fillColor: const Color(0xFFE53935),
                  transform: Transform2D.translation(const Offset(160, 20)),
                ),
              ],
            ),
            ContentLayerSnapshot(
              id: 'layer-1',
              nodes: <NodeSnapshot>[
                RectNodeSnapshot(
                  id: 'visible-candidate',
                  size: const Size(20, 20),
                  fillColor: const Color(0xFF43A047),
                  transform: Transform2D.translation(const Offset(70, 20)),
                ),
                RectNodeSnapshot(
                  id: 'offscreen-zero-preview',
                  size: const Size(20, 20),
                  fillColor: const Color(0xFF6D4C41),
                  transform: Transform2D.translation(const Offset(250, 20)),
                ),
              ],
            ),
          ],
        ),
      );
      addTearDown(controller.dispose);
      final renderState = _controllerOwnedRenderState(
        controller,
        selectedNodeIds: const <NodeId>{'previewed-candidate'},
        previewDeltaResolver: (nodeId) {
          if (nodeId == 'previewed-candidate') {
            return const Offset(-120, 0);
          }
          return Offset.zero;
        },
      );

      final candidateIds = renderState
          .enumeratePaintCandidates(const Rect.fromLTWH(0, 0, 120, 100))
          .map((node) => node.id)
          .toList(growable: false);

      expect(candidateIds, const <NodeId>[
        'bg-candidate',
        'previewed-candidate',
        'visible-candidate',
      ]);
    },
  );

  test(
    'controller-owned render state clips background enumeration to runtime node count',
    () {
      final controller = SceneStoreController(
        initialSnapshot: SceneSnapshot(
          background: BackgroundSnapshot(color: Color(0xFFFFFFFF)),
          backgroundLayer: BackgroundLayerSnapshot(
            nodes: <NodeSnapshot>[
              RectNodeSnapshot(
                id: 'runtime-background-node',
                size: const Size(24, 24),
                fillColor: const Color(0xFF1E88E5),
                transform: Transform2D.translation(const Offset(20, 20)),
              ),
            ],
          ),
        ),
      );
      addTearDown(controller.dispose);
      final renderState = _controllerOwnedRenderState(
        controller,
        snapshotOverride: SceneSnapshot(
          background: BackgroundSnapshot(color: Color(0xFFFFFFFF)),
          backgroundLayer: BackgroundLayerSnapshot(
            nodes: <NodeSnapshot>[
              RectNodeSnapshot(
                id: 'runtime-background-node',
                size: const Size(24, 24),
                fillColor: const Color(0xFF1E88E5),
                transform: Transform2D.translation(const Offset(20, 20)),
              ),
              RectNodeSnapshot(
                id: 'snapshot-only-background-node',
                size: const Size(24, 24),
                fillColor: const Color(0xFFE53935),
                transform: Transform2D.translation(const Offset(60, 20)),
              ),
            ],
          ),
        ),
      );

      final candidateIds = renderState
          .enumeratePaintCandidates(const Rect.fromLTWH(0, 0, 120, 100))
          .map((node) => node.id)
          .toList(growable: false);

      expect(candidateIds, const <NodeId>['runtime-background-node']);
    },
  );

  test(
    'controller-owned render state rejects unsupported snapshot node subtypes',
    () {
      final controller = SceneStoreController(
        initialSnapshot: SceneSnapshot(
          background: BackgroundSnapshot(color: Color(0xFFFFFFFF)),
          backgroundLayer: BackgroundLayerSnapshot(
            nodes: <NodeSnapshot>[
              RectNodeSnapshot(
                id: 'runtime-background-node',
                size: const Size(24, 24),
                fillColor: const Color(0xFF1E88E5),
                transform: Transform2D.translation(const Offset(20, 20)),
              ),
            ],
          ),
        ),
      );
      addTearDown(controller.dispose);
      final renderState = _controllerOwnedRenderState(
        controller,
        snapshotOverride: SceneSnapshot(
          background: BackgroundSnapshot(color: Color(0xFFFFFFFF)),
          backgroundLayer: BackgroundLayerSnapshot(
            nodes: <NodeSnapshot>[
              _UnsupportedNodeSnapshot(id: 'runtime-background-node'),
            ],
          ),
        ),
      );

      expect(
        () => renderState
            .enumeratePaintCandidates(const Rect.fromLTWH(0, 0, 120, 100))
            .toList(growable: false),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('Unsupported snapshot node type'),
          ),
        ),
      );
    },
  );
}

class _UnsupportedNodeSnapshot extends NodeSnapshot {
  const _UnsupportedNodeSnapshot({required super.id})
    : super(
        instanceRevision: 0,
        transform: Transform2D.identity,
        opacity: 1,
        hitPadding: 0,
        isVisible: true,
        isSelectable: true,
        isLocked: false,
        isDeletable: true,
        isTransformable: true,
      );
}
