import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('surface bridge does not expose frame repaint signal ownership', () {
    final source = File(
      'lib/src/api/canvas_runtime_surface_bridge.dart',
    ).readAsStringSync();

    expect(source, isNotEmpty);
    _expectNoFrameRepaintSignalOwnership(source);
  });

  test(
    'runtime state publication requires explicit surface target classification',
    () {
      final source = File(
        'lib/src/runtime/runtime_root.dart',
      ).readAsStringSync();

      expect(source, isNotEmpty);
      _expectExplicitSurfaceTargetClassification(source);
    },
  );
}

void _expectNoFrameRepaintSignalOwnership(String source) {
  expect(source, isNot(contains('frame_repaint_signal.dart')));
  expect(source, isNot(contains('FrameRepaintSignal')));
}

void _expectExplicitSurfaceTargetClassification(String source) {
  expect(
    source,
    contains('required _RuntimeSurfaceRepaintTarget? surfaceRepaintTarget'),
  );
  expect(source, isNot(contains('_publishRuntimeState();')));
  for (final match in '_publishRuntimeState('.allMatches(source)) {
    final callStart = match.start;
    if (source.indexOf('_publishRuntimeState({', callStart) == callStart) {
      continue;
    }
    final callEnd = source.indexOf(';', callStart);
    expect(callEnd, isNonNegative);
    final targetArgument = source.indexOf('surfaceRepaintTarget:', callStart);
    expect(targetArgument, isNonNegative);
    expect(targetArgument, lessThan(callEnd));
  }
}
