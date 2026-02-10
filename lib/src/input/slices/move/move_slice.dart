import 'dart:ui';

import '../../../public/scene_write_txn.dart';

class V2MoveSlice {
  V2MoveSlice(this._writeRunner);

  final T Function<T>(T Function(SceneWriteTxn writer) fn) _writeRunner;

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
