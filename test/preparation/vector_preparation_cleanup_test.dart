import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';

import 'fixtures/vector_preparation_fixture.dart';

void main() {
  test(
    'invalid intrinsic Picture is disposed before preparation failure',
    () async {
      final createdPictures = <ui.Picture>[];
      final disposedPictures = <ui.Picture>[];
      final previousOnCreate = ui.Picture.onCreate;
      final previousOnDispose = ui.Picture.onDispose;
      ui.Picture.onCreate = createdPictures.add;
      ui.Picture.onDispose = disposedPictures.add;
      addTearDown(() {
        ui.Picture.onCreate = previousOnCreate;
        ui.Picture.onDispose = previousOnDispose;
      });

      await expectLater(
        prepareVector(invalidIntrinsicVectorBytes()),
        throwsA(
          isA<CanvasDataException>()
              .having(
                (error) => error.code,
                'code',
                CanvasDataErrorCode.fieldMustBePositive,
              )
              .having(
                (error) => error.path,
                'path',
                'vector.intrinsicSize.width',
              ),
        ),
      );

      expect(createdPictures, hasLength(1));
      expect(disposedPictures, hasLength(1));
      expect(
        identical(disposedPictures.single, createdPictures.single),
        isTrue,
      );
    },
  );
}
