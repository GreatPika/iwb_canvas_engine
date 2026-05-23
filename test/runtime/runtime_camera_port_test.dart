import 'package:test/test.dart';

import '../support/flutter_consumer_test_harness.dart';

void main() {
  test('runtime camera port publishes view camera state only', () async {
    await expectLater(
      runFlutterConsumerTest(
        packageName: 'iwb_canvas_engine_runtime_camera_consumer',
        testFileName: 'runtime_camera_port_test.dart',
        testSource: _runtimeCameraPortSource,
      ),
      completes,
    );
  });
}

const _runtimeCameraPortSource = '''
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';

void main() {
  test('camera starts from document and updates only view camera revision', () {
    final persistedCamera = CanvasCamera(offset: const Offset(4, 8));
    final runtime = CanvasRuntime(
      initialDocument: CanvasDocument(camera: persistedCamera),
    );
    final notifications = <CanvasRuntimeState>[];
    runtime.state.addListener(() {
      notifications.add(runtime.state.value);
    });

    expect(runtime.camera.camera, persistedCamera);
    expect(runtime.camera.offset, const Offset(4, 8));
    expect(runtime.readDocument().camera, persistedCamera);
    expect(runtime.state.value.revisions.document, 0);
    expect(runtime.state.value.revisions.viewCamera, 0);

    runtime.camera.setOffset(const Offset(10, 12));

    expect(runtime.camera.camera, CanvasCamera(offset: const Offset(10, 12)));
    expect(runtime.camera.offset, const Offset(10, 12));
    expect(runtime.readDocument().camera, persistedCamera);
    expect(runtime.state.value.revisions.document, 0);
    expect(runtime.state.value.revisions.viewCamera, 1);

    runtime.camera.panBy(const Offset(-2, 3));

    expect(runtime.camera.camera, CanvasCamera(offset: const Offset(8, 15)));
    expect(runtime.camera.offset, const Offset(8, 15));
    expect(runtime.readDocument().camera, persistedCamera);
    expect(runtime.state.value.revisions.document, 0);
    expect(runtime.state.value.revisions.viewCamera, 2);
    expect(notifications.map((state) => state.revisions.viewCamera), [1, 2]);
    expect(notifications.every((state) => state.revisions.document == 0), true);
  });

  test('camera rejects invalid offsets with CanvasDataException', () {
    final runtime = CanvasRuntime();

    expect(
      () => runtime.camera.setOffset(const Offset(double.nan, 0)),
      throwsA(
        isA<CanvasDataException>()
            .having(
              (error) => error.code,
              'code',
              CanvasDataErrorCode.fieldMustBeFinite,
            )
            .having((error) => error.path, 'path', 'camera.offset.dx'),
      ),
    );
    expect(runtime.camera.offset, Offset.zero);
    expect(runtime.state.value.revisions.viewCamera, 0);
    expect(runtime.state.value.revisions.document, 0);
  });
}
''';
