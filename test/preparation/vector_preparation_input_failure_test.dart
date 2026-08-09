import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';

import 'fixtures/vector_preparation_fixture.dart';

const _vectorByteLimit = 32 * 1024 * 1024;

void main() {
  test(
    'preparation bounds input views and classifies selected failures',
    () async {
      final createdPictures = <ui.Picture>[];
      final previousOnCreate = ui.Picture.onCreate;
      ui.Picture.onCreate = createdPictures.add;
      addTearDown(() => ui.Picture.onCreate = previousOnCreate);

      await _expectPreparationFailure(
        ByteData(_vectorByteLimit + 1),
        CanvasDataErrorCode.fieldMaxLength,
      );
      expect(createdPictures, isEmpty);

      await _expectPreparationFailure(
        ByteData(_vectorByteLimit),
        CanvasDataErrorCode.invalidVectorData,
      );
      await _expectPreparationFailure(
        _replaceByte(basicVectorBytes(), 0, 0x00),
        CanvasDataErrorCode.invalidVectorData,
      );
      await _expectPreparationFailure(
        _replaceByte(basicVectorBytes(), 4, 0x02),
        CanvasDataErrorCode.invalidVectorData,
      );
      await _expectPreparationFailure(
        _replaceByte(basicVectorBytes(), 5, 0x00),
        CanvasDataErrorCode.invalidVectorData,
      );
      await _expectPreparationFailure(
        _truncate(basicVectorBytes(), 6),
        CanvasDataErrorCode.invalidVectorData,
      );
      expect(createdPictures, isEmpty);

      final original = basicVectorBytes();
      final backing = Uint8List(_vectorByteLimit + original.lengthInBytes + 2);
      backing.setRange(
        _vectorByteLimit + 1,
        _vectorByteLimit + 1 + original.lengthInBytes,
        _viewBytes(original),
      );
      final smallView = ByteData.sublistView(
        backing,
        _vectorByteLimit + 1,
        _vectorByteLimit + 1 + original.lengthInBytes,
      );
      final prepared = await prepareVector(smallView);

      expect(prepared.intrinsicSize, const ui.Size(10, 20));
      expect(createdPictures, hasLength(1));
      prepared.dispose();
    },
  );

  test(
    'assertion-only malformed fixture is accepted without assertions',
    () async {
      final result = await Process.run('dart', [
        '--disable-analytics',
        'run',
        '--no-enable-asserts',
        'test/preparation/fixtures/assertion_only_vector_codec_probe.dart',
      ]);

      expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
    },
  );
}

Future<void> _expectPreparationFailure(
  ByteData bytes,
  CanvasDataErrorCode code,
) {
  return expectLater(
    prepareVector(bytes),
    throwsA(
      isA<CanvasDataException>()
          .having((error) => error.code, 'code', code)
          .having((error) => error.path, 'path', 'vector.bytes'),
    ),
  );
}

ByteData _replaceByte(ByteData source, int index, int value) {
  final copy = Uint8List.fromList(_viewBytes(source))..[index] = value;
  return ByteData.sublistView(copy);
}

ByteData _truncate(ByteData source, int length) => ByteData.sublistView(
  Uint8List.fromList(_viewBytes(source).sublist(0, length)),
);

Uint8List _viewBytes(ByteData data) =>
    data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
