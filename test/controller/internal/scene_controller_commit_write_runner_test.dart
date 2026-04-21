import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/src/controller/internal/signal_event.dart';
import 'package:iwb_canvas_engine/src/controller/scene_controller_commit_write_runner.dart';
import 'package:iwb_canvas_engine/src/controller/store.dart';
import 'package:iwb_canvas_engine/src/core/scene.dart';

void main() {
  test('run after dispose throws StateError', () {
    final runner = SceneControllerCommitWriteRunner(
      store: SceneStore(sceneDoc: Scene()),
      textFontFamilyByDefault: null,
      beforeTxnContextCreateHook: null,
      txnSignalSink: (BufferedSignal _) {},
    );

    runner.dispose();

    expect(
      () => runner.run<void>(fn: (_) {}, txnCommit: (_) {}),
      throwsStateError,
    );
  });
}
