import 'package:flutter/foundation.dart';

import '../../contract/snapshot.dart';
import 'scene_controller_interaction_config.dart';
import 'scene_controller_interaction_runtime.dart';

abstract interface class SceneControllerInteractionAccess
    implements Listenable {
  SceneSnapshot get snapshot;
  SceneControllerInteractionConfig get config;
  SceneControllerInteractionRuntime get runtime;
  bool get clearSelectionOnDrawModeEnter;
  bool get hasSelection;
  void clearSelectionState();
}

final class SceneControllerInteractionContext
    implements SceneControllerInteractionAccess {
  const SceneControllerInteractionContext({
    required this.owner,
    required this.config,
    required this.runtime,
    required this.readSnapshot,
    required this.hasSelectionState,
    required VoidCallback clearSelectionState,
    required this.clearSelectionOnDrawModeEnter,
  }) : _clearSelectionState = clearSelectionState;

  final Listenable owner;
  @override
  final SceneControllerInteractionConfig config;
  @override
  final SceneControllerInteractionRuntime runtime;
  final SceneSnapshot Function() readSnapshot;
  final bool Function() hasSelectionState;
  final VoidCallback _clearSelectionState;
  @override
  final bool clearSelectionOnDrawModeEnter;

  @override
  SceneSnapshot get snapshot => readSnapshot();

  @override
  bool get hasSelection => hasSelectionState();

  @override
  void clearSelectionState() {
    _clearSelectionState();
  }

  @override
  void addListener(VoidCallback listener) => owner.addListener(listener);

  @override
  void removeListener(VoidCallback listener) => owner.removeListener(listener);
}
