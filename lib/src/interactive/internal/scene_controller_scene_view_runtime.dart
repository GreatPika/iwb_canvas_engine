import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../../contract/scene_view_render_state.dart';
import '../../contract/scene_view_runtime.dart';
import '../../contract/snapshot.dart';
import '../scene_controller_interaction.dart';
import 'scene_controller_interaction_runtime.dart';
import 'scene_controller_pointer_session.dart';

final class SceneControllerSceneViewRuntime implements SceneViewRuntime {
  SceneControllerSceneViewRuntime({
    required Listenable ownerListenable,
    required void Function(String operation, {bool allowAfterDispose})
    ensurePublicSideEffectAllowed,
    required SceneSnapshot Function() readSnapshot,
    required Set<NodeId> Function() readSelectedNodeIds,
    required int Function() readControllerEpoch,
    required Offset Function(NodeId nodeId) Function() readPreviewDeltaResolver,
    required SceneControllerInteraction Function() readInteraction,
    required SceneControllerInteractionRuntime interactionRuntime,
  }) : _ownerListenable = ownerListenable,
       _ensurePublicSideEffectAllowed = ensurePublicSideEffectAllowed,
       _readInteraction = readInteraction,
       _interactionRuntime = interactionRuntime,
       _renderState = SceneControllerSceneViewRenderState(
         ownerListenable: ownerListenable,
         readSnapshot: readSnapshot,
         readSelectedNodeIds: readSelectedNodeIds,
         readControllerEpoch: readControllerEpoch,
         readPreviewDeltaResolver: readPreviewDeltaResolver,
         readInteraction: readInteraction,
       );

  final Listenable _ownerListenable;
  final void Function(String operation, {bool allowAfterDispose})
  _ensurePublicSideEffectAllowed;
  final SceneControllerInteraction Function() _readInteraction;
  final SceneControllerInteractionRuntime _interactionRuntime;
  final SceneControllerSceneViewRenderState _renderState;

  @override
  SceneViewRenderState get renderState => _renderState;

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
    required Listenable ownerListenable,
    required SceneSnapshot Function() readSnapshot,
    required Set<NodeId> Function() readSelectedNodeIds,
    required int Function() readControllerEpoch,
    required Offset Function(NodeId nodeId) Function() readPreviewDeltaResolver,
    required SceneControllerInteraction Function() readInteraction,
  }) : _ownerListenable = ownerListenable,
       _readSnapshot = readSnapshot,
       _readSelectedNodeIds = readSelectedNodeIds,
       _readControllerEpoch = readControllerEpoch,
       _readPreviewDeltaResolver = readPreviewDeltaResolver,
       _readInteraction = readInteraction;

  final Listenable _ownerListenable;
  final SceneSnapshot Function() _readSnapshot;
  final Set<NodeId> Function() _readSelectedNodeIds;
  final int Function() _readControllerEpoch;
  final Offset Function(NodeId nodeId) Function() _readPreviewDeltaResolver;
  final SceneControllerInteraction Function() _readInteraction;

  SceneControllerInteraction get _interaction => _readInteraction();

  @override
  void addListener(VoidCallback listener) {
    _ownerListenable.addListener(listener);
  }

  @override
  void removeListener(VoidCallback listener) {
    _ownerListenable.removeListener(listener);
  }

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
  Offset Function(NodeId nodeId) get previewDeltaResolver =>
      _readPreviewDeltaResolver();

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
}
