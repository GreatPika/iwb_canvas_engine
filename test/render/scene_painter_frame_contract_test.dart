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
import 'package:iwb_canvas_engine/src/render/scene_painter_frame.dart';

// INV:INV-ENG-SCENE-PAINTER-FRAME-RESOLUTION

class _CapturedWorldRectRenderState extends ChangeNotifier
    implements SceneViewRenderState {
  _CapturedWorldRectRenderState({
    required this.snapshot,
    required this.paintCandidates,
    this.camera = Offset.zero,
    Set<NodeId> selectedNodeIds = const <NodeId>{},
  }) : selectedNodeIds = Set<NodeId>.unmodifiable(selectedNodeIds);

  @override
  final Set<NodeId> selectedNodeIds;

  @override
  final SceneSnapshot snapshot;

  final Offset camera;
  final List<NodeSnapshot> paintCandidates;
  ScenePaintCandidateQuery? lastEnumeratedQuery;

  @override
  Offset get cameraOffset => camera;

  @override
  Iterable<NodeSnapshot> enumeratePaintCandidates(
    ScenePaintCandidateQuery query,
  ) {
    lastEnumeratedQuery = query;
    return paintCandidates;
  }

  @override
  int get controllerEpoch => 0;

  @override
  Listenable get overlayRepaintListenable => this;

  @override
  Rect? get selectionRect => null;

  @override
  Offset Function(NodeId nodeId) get previewDeltaResolver =>
      (_) => Offset.zero;

  @override
  bool get hasActiveStrokePreview => false;

  @override
  List<Offset> get activeStrokePreviewPoints => const <Offset>[];

  @override
  double get activeStrokePreviewThickness => 0;

  @override
  Color get activeStrokePreviewColor => const Color(0x00000000);

  @override
  double get activeStrokePreviewOpacity => 0;

  @override
  bool get hasActiveLinePreview => false;

  @override
  Offset? get activeLinePreviewStart => null;

  @override
  Offset? get activeLinePreviewEnd => null;

  @override
  double get activeLinePreviewThickness => 0;

  @override
  Color get activeLinePreviewColor => const Color(0x00000000);
}

SceneViewRenderState _controllerOwnedRenderState(
  SceneStoreController controller, {
  Set<NodeId> selectedNodeIds = const <NodeId>{},
  Offset Function(NodeId nodeId)? previewDeltaResolver,
  SceneSnapshot? snapshotOverride,
}) {
  final interactionController = interactive.SceneController();
  addTearDown(interactionController.dispose);
  final renderState = SceneControllerSceneViewRenderState(
    storeController: controller,
    readSnapshot: () => snapshotOverride ?? controller.snapshot,
    readSelectedNodeIds: () => selectedNodeIds,
    readControllerEpoch: () => controller.controllerEpoch,
    readPreviewDeltaResolver: () => previewDeltaResolver ?? (_) => Offset.zero,
    readInteraction: () => interactionController.interaction,
  );
  addTearDown(renderState.dispose);
  return renderState;
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
          .enumeratePaintCandidates(
            const ScenePaintCandidateQuery(
              viewportRect: Rect.fromLTWH(0, 0, 120, 100),
              visibilityRect: Rect.fromLTWH(0, 0, 120, 100),
            ),
          )
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
    'controller-owned render state enumerates committed snapshot background nodes',
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
          .enumeratePaintCandidates(
            const ScenePaintCandidateQuery(
              viewportRect: Rect.fromLTWH(0, 0, 120, 100),
              visibilityRect: Rect.fromLTWH(0, 0, 120, 100),
            ),
          )
          .map((node) => node.id)
          .toList(growable: false);

      expect(candidateIds, const <NodeId>[
        'runtime-background-node',
        'snapshot-only-background-node',
      ]);
    },
  );

  test(
    'ScenePainterFrameOwner resolves one text layout payload and hands it to geometry plus paint data',
    () {
      final textLayoutCache = SceneTextLayoutCache(maxEntries: 8);
      final geometryCache = RenderGeometryCache();
      final controller = SceneStoreController(
        initialSnapshot: SceneSnapshot(
          background: BackgroundSnapshot(color: Color(0xFFFFFFFF)),
          layers: <ContentLayerSnapshot>[
            ContentLayerSnapshot(
              id: 'layer-text-frame-contract',
              nodes: <NodeSnapshot>[
                TextNodeSnapshot(
                  id: 'text-frame-contract',
                  text: 'shared payload',
                  fontSize: 14,
                  color: const Color(0xFF000000),
                  textDirection: TextDirection.ltr,
                  maxWidth: 100,
                  transform: Transform2D.translation(const Offset(40, 30)),
                ),
              ],
            ),
          ],
        ),
      );
      addTearDown(controller.dispose);
      final renderState = _controllerOwnedRenderState(controller);
      final frameOwner = ScenePainterFrameOwner(
        renderState: renderState,
        textLayoutCache: textLayoutCache,
        geometryCache: geometryCache,
        selectionColor: const Color(0xFF1565C0),
        selectionStrokeWidth: 1,
      );
      final textNode =
          controller.snapshot.layers.single.nodes.single as TextNodeSnapshot;

      final resolved = frameOwner.resolveNodePaintData(textNode);

      expect(resolved.node, same(textNode));
      expect(resolved.textLayout, isNotNull);
      expect(
        identical(
          resolved.textLayout,
          textLayoutCache.getOrBuild(node: textNode),
        ),
        isTrue,
      );
      expect(textLayoutCache.debugBuildCount, 1);
      expect(textLayoutCache.debugHitCount, 1);
      expect(geometryCache.debugBuildCount, 1);
    },
  );

  test(
    'ScenePainterFrameOwner passes a raw viewport query and stores the budgeted final-cull rect on the frame',
    () {
      final candidate = RectNodeSnapshot(
        id: 'captured-world-rect',
        size: const Size(12, 12),
        fillColor: const Color(0xFF000000),
        transform: Transform2D.translation(const Offset(40, 25)),
      );
      final renderState = _CapturedWorldRectRenderState(
        snapshot: SceneSnapshot(
          camera: CameraSnapshot(offset: Offset(12, 8)),
          background: BackgroundSnapshot(color: Color(0xFFFFFFFF)),
        ),
        paintCandidates: <NodeSnapshot>[candidate],
        camera: const Offset(12, 8),
      );
      final frameOwner = ScenePainterFrameOwner(
        renderState: renderState,
        textLayoutCache: null,
        geometryCache: RenderGeometryCache(),
        selectionColor: const Color(0xFF1565C0),
        selectionStrokeWidth: 4,
      );

      final frame = frameOwner.create(const Size(100, 60));

      expect(frame.viewRect, const Rect.fromLTWH(11, 7, 102, 62));
      expect(
        renderState.lastEnumeratedQuery,
        const ScenePaintCandidateQuery(
          viewportRect: Rect.fromLTWH(12, 8, 100, 60),
          visibilityRect: Rect.fromLTWH(11, 7, 102, 62),
        ),
      );
      expect(frame.paintCandidates, hasLength(1));
      expect(frame.paintCandidates.single, same(candidate));
    },
  );

  test(
    'ScenePainterFrameOwner expands only the visibility rect to halo width while keeping the viewport query raw',
    () {
      final candidate = RectNodeSnapshot(
        id: 'captured-selected-world-rect',
        size: const Size(12, 12),
        fillColor: const Color(0xFF000000),
        transform: Transform2D.translation(const Offset(40, 25)),
      );
      final renderState = _CapturedWorldRectRenderState(
        snapshot: SceneSnapshot(
          camera: CameraSnapshot(offset: Offset(12, 8)),
          background: BackgroundSnapshot(color: Color(0xFFFFFFFF)),
        ),
        paintCandidates: <NodeSnapshot>[candidate],
        camera: const Offset(12, 8),
        selectedNodeIds: const <NodeId>{'captured-selected-world-rect'},
      );
      final frameOwner = ScenePainterFrameOwner(
        renderState: renderState,
        textLayoutCache: null,
        geometryCache: RenderGeometryCache(),
        selectionColor: const Color(0xFF1565C0),
        selectionStrokeWidth: 4,
      );

      final frame = frameOwner.create(const Size(100, 60));

      expect(frame.viewRect, const Rect.fromLTWH(8, 4, 108, 68));
      expect(
        renderState.lastEnumeratedQuery,
        const ScenePaintCandidateQuery(
          viewportRect: Rect.fromLTWH(12, 8, 100, 60),
          visibilityRect: Rect.fromLTWH(8, 4, 108, 68),
        ),
      );
    },
  );

  test(
    'controller-owned render state supplements selected edge nodes through visibility rect without widening ordinary viewport candidates',
    () {
      final controller = SceneStoreController(
        initialSnapshot: SceneSnapshot(
          background: BackgroundSnapshot(color: Color(0xFFFFFFFF)),
          layers: <ContentLayerSnapshot>[
            ContentLayerSnapshot(
              id: 'layer-visibility-supplement',
              nodes: <NodeSnapshot>[
                RectNodeSnapshot(
                  id: 'visible-viewport-node',
                  size: const Size(10, 10),
                  fillColor: const Color(0xFF000000),
                  strokeWidth: 0,
                  transform: Transform2D.translation(const Offset(15, 15)),
                ),
                RectNodeSnapshot(
                  id: 'selected-edge-node',
                  size: const Size(10, 10),
                  fillColor: const Color(0xFF000000),
                  strokeWidth: 0,
                  transform: Transform2D.translation(const Offset(-10, 15)),
                ),
                RectNodeSnapshot(
                  id: 'unselected-edge-node',
                  size: const Size(10, 10),
                  fillColor: const Color(0xFF000000),
                  strokeWidth: 0,
                  transform: Transform2D.translation(const Offset(-10, 15)),
                ),
              ],
            ),
          ],
        ),
      );
      addTearDown(controller.dispose);
      final renderState = _controllerOwnedRenderState(
        controller,
        selectedNodeIds: const <NodeId>{'selected-edge-node'},
      );

      final candidateIds = renderState
          .enumeratePaintCandidates(
            const ScenePaintCandidateQuery(
              viewportRect: Rect.fromLTWH(0, 0, 30, 30),
              visibilityRect: Rect.fromLTWH(-8, -8, 46, 46),
            ),
          )
          .map((node) => node.id)
          .toList(growable: false);

      expect(candidateIds, const <NodeId>[
        'visible-viewport-node',
        'selected-edge-node',
      ]);
    },
  );

  test(
    'controller-owned render state supplements selected background edge nodes through visibility rect',
    () {
      final controller = SceneStoreController(
        initialSnapshot: SceneSnapshot(
          background: BackgroundSnapshot(color: Color(0xFFFFFFFF)),
          backgroundLayer: BackgroundLayerSnapshot(
            nodes: <NodeSnapshot>[
              RectNodeSnapshot(
                id: 'selected-background-edge-node',
                size: const Size(10, 10),
                fillColor: const Color(0xFF000000),
                strokeWidth: 0,
                transform: Transform2D.translation(const Offset(-10, 15)),
              ),
              RectNodeSnapshot(
                id: 'unselected-background-edge-node',
                size: const Size(10, 10),
                fillColor: const Color(0xFF000000),
                strokeWidth: 0,
                transform: Transform2D.translation(const Offset(-10, 15)),
              ),
            ],
          ),
        ),
      );
      addTearDown(controller.dispose);
      final renderState = _controllerOwnedRenderState(
        controller,
        selectedNodeIds: const <NodeId>{'selected-background-edge-node'},
      );

      final candidateIds = renderState
          .enumeratePaintCandidates(
            const ScenePaintCandidateQuery(
              viewportRect: Rect.fromLTWH(0, 0, 30, 30),
              visibilityRect: Rect.fromLTWH(-8, -8, 46, 46),
            ),
          )
          .map((node) => node.id)
          .toList(growable: false);

      expect(candidateIds, const <NodeId>['selected-background-edge-node']);
    },
  );

  test(
    'controller-owned render state resolves selected background supplements from the active frame snapshot',
    () {
      final controller = SceneStoreController(
        initialSnapshot: SceneSnapshot(
          background: BackgroundSnapshot(color: Color(0xFFFFFFFF)),
          backgroundLayer: BackgroundLayerSnapshot(
            nodes: <NodeSnapshot>[
              RectNodeSnapshot(
                id: 'stale-background-edge-node',
                size: const Size(10, 10),
                fillColor: const Color(0xFF000000),
                strokeWidth: 0,
                transform: Transform2D.translation(const Offset(-10, 15)),
              ),
            ],
          ),
        ),
      );
      addTearDown(controller.dispose);
      final renderState = _controllerOwnedRenderState(
        controller,
        selectedNodeIds: const <NodeId>{'stale-background-edge-node'},
        snapshotOverride: SceneSnapshot(
          background: BackgroundSnapshot(color: Color(0xFFFFFFFF)),
        ),
      );

      final candidateIds = renderState
          .enumeratePaintCandidates(
            const ScenePaintCandidateQuery(
              viewportRect: Rect.fromLTWH(0, 0, 30, 30),
              visibilityRect: Rect.fromLTWH(-8, -8, 46, 46),
            ),
          )
          .map((node) => node.id)
          .toList(growable: false);

      expect(candidateIds, isEmpty);
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
            .enumeratePaintCandidates(
              const ScenePaintCandidateQuery(
                viewportRect: Rect.fromLTWH(0, 0, 120, 100),
                visibilityRect: Rect.fromLTWH(0, 0, 120, 100),
              ),
            )
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
