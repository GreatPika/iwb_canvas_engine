import 'package:test/test.dart';

import '../support/flutter_consumer_test_harness.dart';

void main() {
  test('CanvasFieldUpdate variants expose stable value semantics', () async {
    await expectLater(
      runFlutterConsumerTest(
        packageName: 'iwb_canvas_engine_field_update_consumer',
        testFileName: 'canvas_field_update_test.dart',
        testSource: _canvasFieldUpdateSource,
      ),
      completes,
    );
  });
}

const _canvasFieldUpdateSource = '''
import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';

void main() {
  test('CanvasFieldUpdate variants expose stable value semantics', () {
    const absent = CanvasFieldUpdate<String>.absent();
    const alsoAbsent = CanvasFieldAbsent<String>();
    const set = CanvasFieldSet('value');
    const sameSet = CanvasFieldSet('value');
    const clear = CanvasFieldClear<String>();
    const sameClear = CanvasFieldClear<String>();

    expect(absent, alsoAbsent);
    expect(absent.hashCode, alsoAbsent.hashCode);
    expect(set.value, 'value');
    expect(set, sameSet);
    expect(set.hashCode, sameSet.hashCode);
    expect(clear, sameClear);
    expect(clear.hashCode, sameClear.hashCode);
    expect(absent, isA<CanvasFieldUpdate<String>>());
    expect(set, isA<CanvasFieldUpdate<String>>());
    expect(clear, isA<CanvasFieldUpdate<String?>>());
  });
}
''';
