import 'dart:ui';

import '../scene_writer_command_results.dart';
import '../scene_writer.dart';

class MoveCommands {
  MoveCommands(this._writeRunner);

  final T Function<T>(T Function(SceneWriter writer) fn) _writeRunner;

  int writeTranslateSelection(Offset delta) {
    return _writeRunner((writer) {
      final movedCount = writer.writeSelectionTranslate(delta);
      if (movedCount > 0) {
        sceneWriterWriteOwnedSignalExactEnqueue(
          writer,
          type: 'selection.translated',
          payload: <String, Object?>{'dx': delta.dx, 'dy': delta.dy},
        );
      }
      return movedCount;
    });
  }
}
