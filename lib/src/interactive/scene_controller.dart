import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../contract/scene_view_render_state.dart';
import '../contract/snapshot.dart';
import '../core/action_events.dart';
import '../core/pointer_input.dart';
import '../controller/scene_controller.dart';
import 'scene_view_pointer_semantics.dart';
import 'internal/scene_controller_facade_assembly.dart';
import 'internal/scene_controller_internal_access.dart';
import 'internal/scene_controller_interaction_runtime.dart';
import 'scene_controller_interaction.dart';
import 'scene_controller_scene.dart';
import 'scene_controller_selection.dart';

class SceneController extends ChangeNotifier
    implements SceneViewRenderState, SceneViewPointerSemanticsSource {
  SceneController({
    SceneSnapshot? initialSnapshot,
    PointerInputSettings? pointerSettings,
    double? dragStartSlop,
    bool clearSelectionOnDrawModeEnter = false,
    MoveCommitDeltaResolver? moveCommitDeltaResolver,
    String? textFontFamilyByDefault,
  }) : _core = SceneControllerCore(
         initialSnapshot: initialSnapshot,
         textFontFamilyByDefault: textFontFamilyByDefault,
       ) {
    _facade = assembleSceneControllerFacade(
      SceneControllerFacadeRequest(
        owner: this,
        notifyListeners: notifyListeners,
        core: _core,
        readSnapshot: () => snapshot,
        readSelectedNodeIds: () => selectedNodeIds,
        pointerSettings: pointerSettings,
        dragStartSlop: dragStartSlop,
        clearSelectionOnDrawModeEnter: clearSelectionOnDrawModeEnter,
        moveCommitDeltaResolver: moveCommitDeltaResolver,
      ),
    );

    registerSceneControllerInternalAccess(
      this,
      SceneControllerInternalAccessRegistration(
        readEpoch: () => _core.controllerEpoch,
        previewDeltaForNode: _facade.interactionRuntime.previewDeltaForNode,
        setBeforePointerDispatchHook:
            _facade.interactionRuntime.setBeforePointerDispatchHook,
        runMoveCommitDeltaResolverForTest:
            _facade.interactionRuntime.runMoveCommitDeltaResolver,
        readInteractionAccessForTest: () => _facade.interactionAccess,
        readActiveEraserPointsLength: () =>
            _facade.interactionRuntime.activeEraserPointsLength,
        readEraserSpatialQueryCount: () =>
            _facade.interactionRuntime.eraserSpatialQueryCount,
        readEraserPreciseSegmentCheckCount: () =>
            _facade.interactionRuntime.eraserPreciseSegmentCheckCount,
      ),
    );
  }

  final SceneControllerCore _core;
  late final SceneControllerFacadeAssembly _facade;

  @override
  SceneSnapshot get snapshot => _core.snapshot;

  @override
  Set<NodeId> get selectedNodeIds => _core.selectedNodeIds;

  @override
  int get controllerEpoch => _core.controllerEpoch;

  @override
  Rect? get selectionRect => _facade.interactionRuntime.selectionRect;

  @override
  Offset get cameraOffset => snapshot.camera.offset;

  @override
  Offset Function(NodeId nodeId) get previewDeltaResolver =>
      _facade.interactionRuntime.previewDeltaForNode;

  @override
  bool get hasActiveStrokePreview => interaction.hasActiveStrokePreview;

  @override
  List<Offset> get activeStrokePreviewPoints =>
      interaction.activeStrokePreviewPoints;

  @override
  double get activeStrokePreviewThickness =>
      interaction.activeStrokePreviewThickness;

  @override
  Color get activeStrokePreviewColor => interaction.activeStrokePreviewColor;

  @override
  double get activeStrokePreviewOpacity =>
      interaction.activeStrokePreviewOpacity;

  @override
  bool get hasActiveLinePreview => interaction.hasActiveLinePreview;

  @override
  Offset? get activeLinePreviewStart => interaction.activeLinePreviewStart;

  @override
  Offset? get activeLinePreviewEnd => interaction.activeLinePreviewEnd;

  @override
  double get activeLinePreviewThickness =>
      interaction.activeLinePreviewThickness;

  @override
  Color get activeLinePreviewColor => interaction.activeLinePreviewColor;

  @override
  SceneViewPointerSemanticsBridge createPointerSemanticsBridge({
    required bool Function() isMounted,
  }) {
    _ensurePublicSideEffectAllowed('createPointerSemanticsBridge');
    return _facade.createPointerSemanticsBridge(isMounted: isMounted);
  }

  SceneControllerInteraction get interaction => _facade.interaction;
  SceneControllerSelection get selection => _facade.selection;
  SceneControllerScene get scene => _facade.scene;

  Stream<ActionCommitted> get actions => _facade.interactionRuntime.actions;
  Stream<EditTextRequested> get editTextRequests =>
      _facade.interactionRuntime.editTextRequests;

  void _ensurePublicSideEffectAllowed(
    String operation, {
    bool allowAfterDispose = false,
  }) {
    _facade.interactionRuntime.ensurePublicSideEffectAllowed(
      operation,
      allowAfterDispose: allowAfterDispose,
    );
  }

  @override
  void dispose() {
    _ensurePublicSideEffectAllowed('dispose', allowAfterDispose: true);
    if (_facade.interactionRuntime.isDisposed) {
      return;
    }
    _facade.interactionRuntime.resetInteractiveState();
    _core.dispose();
    _facade.interactionRuntime.dispose();
    unregisterSceneControllerInternalAccess(this);
    super.dispose();
  }
}
