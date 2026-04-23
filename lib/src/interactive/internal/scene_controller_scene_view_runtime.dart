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
       _mainSceneRenderRead = SceneControllerSceneViewMainSceneRenderRead(
         storeController: storeController,
         readSnapshot: readSnapshot,
         readSelectedNodeIds: readSelectedNodeIds,
         readControllerEpoch: readControllerEpoch,
         captureFramePreview: captureFramePreview,
       ),
       _overlayPreviewRead = SceneControllerSceneViewOverlayPreviewRead(
         readSnapshot: readSnapshot,
         readInteraction: readInteraction,
       );

  final Listenable _ownerListenable;
  final void Function(String operation, {bool allowAfterDispose})
  _ensurePublicSideEffectAllowed;
  final SceneControllerInteraction Function() _readInteraction;
  final SceneControllerInteractionRuntime Function() _readInteractionRuntime;
  final SceneControllerSceneViewMainSceneRenderRead _mainSceneRenderRead;
  final SceneControllerSceneViewOverlayPreviewRead _overlayPreviewRead;

  SceneControllerInteractionRuntime get _interactionRuntime =>
      _readInteractionRuntime();

  @override
  SceneViewMainSceneRenderRead get mainSceneRenderRead => _mainSceneRenderRead;

  @override
  SceneViewOverlayPreviewRead get overlayPreviewRead => _overlayPreviewRead;

  void scheduleSceneRepaint() {
    _mainSceneRenderRead.scheduleSceneRepaint();
  }

  void scheduleOverlayRepaint() {
    _overlayPreviewRead.scheduleOverlayRepaint();
  }

  void dispose() {
    _mainSceneRenderRead.dispose();
    _overlayPreviewRead.dispose();
  }

  @override
  SceneViewPointerSession createPointerSession({
    required bool Function() isMounted,
    required bool Function() hasLiveRawPointers,
  }) {
    _ensurePublicSideEffectAllowed('createPointerSession');
    final token = _interactionRuntime.createPointerSessionToken();
    final session = SceneControllerPointerSession(
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
    _interactionRuntime.registerPointerSession(session, token: token);
    return session;
  }
}

final class SceneControllerSceneViewMainSceneRenderRead
    implements SceneViewMainSceneRenderRead {
  SceneControllerSceneViewMainSceneRenderRead({
    required SceneStoreController storeController,
    required SceneSnapshot Function() readSnapshot,
    required Set<NodeId> Function() readSelectedNodeIds,
    required int Function() readControllerEpoch,
    required SceneViewFramePreview Function() captureFramePreview,
  }) : _storeController = storeController,
       _paintCandidateStage = SceneControllerPaintCandidateStage(
         store: storeController,
       ),
       _readSnapshot = readSnapshot,
       _readSelectedNodeIds = readSelectedNodeIds,
       _readControllerEpoch = readControllerEpoch,
       _captureFramePreview = captureFramePreview;

  final SceneStoreController _storeController;
  final SceneControllerPaintCandidateStage _paintCandidateStage;
  final SceneControllerSceneRepaintChannel _sceneRepaintChannel =
      SceneControllerSceneRepaintChannel();
  final SceneSnapshot Function() _readSnapshot;
  final Set<NodeId> Function() _readSelectedNodeIds;
  final int Function() _readControllerEpoch;
  final SceneViewFramePreview Function() _captureFramePreview;

  @override
  void addListener(VoidCallback listener) {
    _sceneRepaintChannel.addListener(listener);
  }

  @override
  void removeListener(VoidCallback listener) {
    _sceneRepaintChannel.removeListener(listener);
  }

  @override
  SceneSnapshot get snapshot => _readSnapshot();

  @override
  Set<NodeId> get selectedNodeIds => _readSelectedNodeIds();

  @override
  int get controllerEpoch => _readControllerEpoch();

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

  void scheduleSceneRepaint() {
    _sceneRepaintChannel.scheduleNotify();
  }

  void dispose() {
    _sceneRepaintChannel.dispose();
  }
}

final class SceneControllerSceneViewOverlayPreviewRead
    implements SceneViewOverlayPreviewRead {
  SceneControllerSceneViewOverlayPreviewRead({
    required SceneSnapshot Function() readSnapshot,
    required SceneControllerInteraction Function() readInteraction,
  }) : _readSnapshot = readSnapshot,
       _readInteraction = readInteraction;

  final SceneControllerOverlayRepaintChannel _overlayRepaintChannel =
      SceneControllerOverlayRepaintChannel();
  final SceneSnapshot Function() _readSnapshot;
  final SceneControllerInteraction Function() _readInteraction;

  SceneControllerInteraction get _interaction => _readInteraction();

  @override
  Listenable get overlayRepaintListenable => _overlayRepaintChannel;

  @override
  Rect? get selectionRect => _interaction.selectionRect;

  @override
  Offset get cameraOffset => _readSnapshot().camera.offset;

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

  void scheduleOverlayRepaint() {
    _overlayRepaintChannel.scheduleNotify();
  }

  void dispose() {
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
