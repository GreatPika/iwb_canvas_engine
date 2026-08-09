import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/contracts/public/canvas_prepared_vector.dart';

import '../support/vector_preparation_fixture.dart';

// This scenario keeps hooks, disposal, and assertions together so the required
// reference-retirement ordering remains visible rather than split across setup.
// ignore: halstead-volume, maximum-nesting-level, source-lines-of-code
void main() {
  test(
    'prepared vector retires its Picture before idempotent disposal',
    () async {
      final createdPictures = <ui.Picture>[];
      final disposedPictures = <ui.Picture>[];
      final previousOnCreate = ui.Picture.onCreate;
      final previousOnDispose = ui.Picture.onDispose;
      late CanvasPreparedVector prepared;
      late ui.Picture exactPicture;
      var referenceRetiredBeforeNativeDispose = false;
      ui.Picture.onCreate = createdPictures.add;
      ui.Picture.onDispose = (picture) {
        disposedPictures.add(picture);
        if (identical(picture, exactPicture)) {
          try {
            liveCanvasPreparedVectorPicture(prepared);
          } catch (error) {
            if (error is! StateError) {
              rethrow;
            }
            referenceRetiredBeforeNativeDispose = true;
          }
        }
      };
      addTearDown(() {
        ui.Picture.onCreate = previousOnCreate;
        ui.Picture.onDispose = previousOnDispose;
      });

      prepared = await prepareVector(basicVectorBytes());
      exactPicture = liveCanvasPreparedVectorPicture(prepared);

      expect(createdPictures, hasLength(1));
      expect(identical(createdPictures.single, exactPicture), isTrue);

      prepared.dispose();

      expect(referenceRetiredBeforeNativeDispose, isTrue);
      expect(disposedPictures, hasLength(1));
      expect(identical(disposedPictures.single, exactPicture), isTrue);
      expect(
        () => liveCanvasPreparedVectorPicture(prepared),
        throwsA(isA<StateError>()),
      );

      prepared.dispose();
      expect(disposedPictures, hasLength(1));
    },
  );
}
