import 'dart:ui';

import '../../../controller/scene_writer.dart';

class V2MoveSlice {
  V2MoveSlice(this._writeRunner);

  final T Function<T>(T Function(SceneWriter writer) fn) _writeRunner;

  int writeTranslateSelection(Offset delta) {
    return _writeRunner((writer) {
      final movedCount = writer.writeSelectionTranslate(delta);
      if (movedCount > 0) {
        writer.writeSignalEnqueue(
          type: 'selection.translated',
          payload: <String, Object?>{'dx': delta.dx, 'dy': delta.dy},
        );
      }
      return movedCount;
    });
  }
}
