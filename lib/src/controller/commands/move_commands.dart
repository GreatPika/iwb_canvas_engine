import 'dart:ui';

import '../../contract/scene_write_txn.dart';
import '../scene_writer.dart';

class MoveCommands {
  MoveCommands(this._writeRunner);

  final T Function<T>(T Function(SceneWriteTxn writer) fn) _writeRunner;

  SceneWriter _sceneWriter(SceneWriteTxn writer) {
    return writer as SceneWriter;
  }

  int writeTranslateSelection(Offset delta) {
    return _writeRunner((writer) {
      final movedCount = writer.writeSelectionTranslate(delta);
      if (movedCount > 0) {
        _sceneWriter(writer).writeOwnedSignalEnqueue(
          type: 'selection.translated',
          payload: <String, Object?>{'dx': delta.dx, 'dy': delta.dy},
        );
      }
      return movedCount;
    });
  }
}
