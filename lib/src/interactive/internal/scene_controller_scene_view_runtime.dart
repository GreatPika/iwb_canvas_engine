import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../../contract/scene_view_render_state.dart';
import '../../contract/scene_view_runtime.dart';
import '../../contract/snapshot.dart';
import '../../controller/scene_store_controller.dart';
import '../../core/scene_snapshot_paint_candidates.dart';
import '../scene_controller_interaction.dart';
import 'scene_controller_interaction_runtime.dart';
import 'scene_controller_paint_candidate_stage.dart';
import 'scene_controller_pointer_session.dart';

final class SceneControllerSceneViewRuntime implements SceneViewRuntime {
  SceneControllerSceneViewRuntime({
    required SceneStoreController storeController,
    required Listenable ownerListenable,
    required void Function(String operation, {bool allowAfterDispose})
    ensurePublicSideEffectAllowed,
    required SceneSnapshot Function() readSnapshot,
    required Set<NodeId> Function() readSelectedNodeIds,
    required int Function() readControllerEpoch,
    required SceneViewFramePreview Function() captureFramePreview,
    required SceneControllerInteraction Function() readInteraction,
    required SceneControllerInteractionRuntime Function()
    readInteractionRuntime,
  }) : _ownerListenable = ownerListenable,
       _ensurePublicSideEffectAllowed = ensurePublicSideEffectAllowed,
       _readInteraction = readInteraction,
       _readInteractionRuntime = readInteractionRuntime,
       _renderState = SceneControllerSceneViewRenderState(
         storeController: storeController,
         readSnapshot: readSnapshot,
         readSelectedNodeIds: readSelectedNodeIds,
         readControllerEpoch: readControllerEpoch,
         captureFramePreview: captureFramePreview,
         readInteraction: readInteraction,
       );

  final Listenable _ownerListenable;
  final void Function(String operation, {bool allowAfterDispose})
  _ensurePublicSideEffectAllowed;
  final SceneControllerInteraction Function() _readInteraction;
  final SceneControllerInteractionRuntime Function() _readInteractionRuntime;
  final SceneControllerSceneViewRenderState _renderState;

  SceneControllerInteractionRuntime get _interactionRuntime =>
      _readInteractionRuntime();

  @override
  SceneViewRenderState get renderState => _renderState;

  void scheduleSceneRepaint() {
    _renderState.scheduleSceneRepaint();
  }

  void scheduleOverlayRepaint() {
    _renderState.scheduleOverlayRepaint();
  }

  void dispose() {
    _renderState.dispose();
  }

  @override
  SceneViewPointerSession createPointerSession({
    required bool Function() isMounted,
    required bool Function() hasLiveRawPointers,
  }) {
    _ensurePublicSideEffectAllowed('createPointerSession');
    final token = _interactionRuntime.createPointerSessionToken();
    return SceneControllerPointerSession(
      ownerListenable: _ownerListenable,
      token: token,
      readPointerSettings: () => _readInteraction().pointerSettings,
      isMounted: isMounted,
      hasLiveRawPointers: hasLiveRawPointers,
      detachPointerSession: _interactionRuntime.detachPointerSession,
      releasePointerSessionToken:
          _interactionRuntime.releasePointerSessionToken,
      handlePointerFromSession: _interactionRuntime.handlePointerFromSession,
      handleDoubleTapFromSession:
          _interactionRuntime.handleDoubleTapFromSession,
    );
  }
}

final class SceneControllerSceneViewRenderState
    implements SceneViewRenderState {
  SceneControllerSceneViewRenderState({
    required SceneStoreController storeController,
    required SceneSnapshot Function() readSnapshot,
    required Set<NodeId> Function() readSelectedNodeIds,
    required int Function() readControllerEpoch,
    required SceneViewFramePreview Function() captureFramePreview,
    required SceneControllerInteraction Function() readInteraction,
  }) : _storeController = storeController,
       _paintCandidateStage = SceneControllerPaintCandidateStage(
         store: storeController,
       ),
       _readSnapshot = readSnapshot,
       _readSelectedNodeIds = readSelectedNodeIds,
       _readControllerEpoch = readControllerEpoch,
       _captureFramePreview = captureFramePreview,
       _readInteraction = readInteraction;

  final SceneStoreController _storeController;
  final SceneControllerPaintCandidateStage _paintCandidateStage;
  final SceneControllerSceneRepaintChannel _sceneRepaintChannel =
      SceneControllerSceneRepaintChannel();
  final SceneControllerOverlayRepaintChannel _overlayRepaintChannel =
      SceneControllerOverlayRepaintChannel();
  final SceneSnapshot Function() _readSnapshot;
  final Set<NodeId> Function() _readSelectedNodeIds;
  final int Function() _readControllerEpoch;
  final SceneViewFramePreview Function() _captureFramePreview;
  final SceneControllerInteraction Function() _readInteraction;

  SceneControllerInteraction get _interaction => _readInteraction();

  @override
  void addListener(VoidCallback listener) {
    _sceneRepaintChannel.addListener(listener);
  }

  @override
  void removeListener(VoidCallback listener) {
    _sceneRepaintChannel.removeListener(listener);
  }

  @override
  Listenable get overlayRepaintListenable => _overlayRepaintChannel;

  @override
  SceneSnapshot get snapshot => _readSnapshot();

  @override
  Set<NodeId> get selectedNodeIds => _readSelectedNodeIds();

  @override
  int get controllerEpoch => _readControllerEpoch();

  @override
  Rect? get selectionRect => _interaction.selectionRect;

  @override
  Offset get cameraOffset => snapshot.camera.offset;

  @override
  SceneViewFrameRead captureFrameRead() {
    return SceneViewFrameRead(
      snapshot: _readSnapshot(),
      selectedNodeIds: _readSelectedNodeIds(),
      selectionRevision: _storeController.selectionRevision,
      preview: _captureFramePreview(),
    );
  }

  @override
  ScenePreparedPaintPlan preparePaintPlan(
    SceneViewFrameRead frameRead,
    ScenePaintCandidateQuery query,
  ) {
    final snapshot = frameRead.snapshot;
    if (!identical(snapshot, _storeController.snapshot)) {
      return ScenePreparedPaintCandidateList(
        enumerateSnapshotPaintCandidates(
          snapshot: frameRead.snapshot,
          query: query,
          selectedNodeIds: frameRead.selectedNodeIds,
          preview: frameRead.preview,
        ),
      );
    }
    return _paintCandidateStage.prepareCommittedPaintPlan(
      query: query,
      selectedNodeIds: frameRead.selectedNodeIds,
      selectionRevision: frameRead.selectionRevision,
      preview: frameRead.preview,
    );
  }

  @override
  bool get hasActiveStrokePreview => _interaction.hasActiveStrokePreview;

  @override
  List<Offset> get activeStrokePreviewPoints =>
      _interaction.activeStrokePreviewPoints;

  @override
  double get activeStrokePreviewThickness =>
      _interaction.activeStrokePreviewThickness;

  @override
  Color get activeStrokePreviewColor => _interaction.activeStrokePreviewColor;

  @override
  double get activeStrokePreviewOpacity =>
      _interaction.activeStrokePreviewOpacity;

  @override
  bool get hasActiveLinePreview => _interaction.hasActiveLinePreview;

  @override
  Offset? get activeLinePreviewStart => _interaction.activeLinePreviewStart;

  @override
  Offset? get activeLinePreviewEnd => _interaction.activeLinePreviewEnd;

  @override
  double get activeLinePreviewThickness =>
      _interaction.activeLinePreviewThickness;

  @override
  Color get activeLinePreviewColor => _interaction.activeLinePreviewColor;

  void scheduleSceneRepaint() {
    _sceneRepaintChannel.scheduleNotify();
  }

  void scheduleOverlayRepaint() {
    _overlayRepaintChannel.scheduleNotify();
  }

  void dispose() {
    _sceneRepaintChannel.dispose();
    _overlayRepaintChannel.dispose();
  }
}

final class SceneControllerSceneRepaintChannel extends ChangeNotifier {
  SceneControllerSceneRepaintChannel();

  void scheduleNotify() {
    notifyListeners();
  }
}

final class SceneControllerOverlayRepaintChannel extends ChangeNotifier {
  SceneControllerOverlayRepaintChannel();

  void scheduleNotify() {
    notifyListeners();
  }
}
