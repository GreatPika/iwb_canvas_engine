import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';

import 'fixtures/vector_preparation_fixture.dart';
import 'fixtures/vm_retention_observer.dart';

// Flutter's test runner supplies this mutually exclusive VM-service intent.
const _vmServiceDisabledArgument = '--disable-vm-service';

void main() {
  test(
    'preparation owns an exact caller view and releases settled snapshots',
    () async {
      final observer = await VmRetentionObserver.connect();
      addTearDown(observer.dispose);
      final observedPictures = <ui.Picture>[];
      final previousOnCreate = ui.Picture.onCreate;
      ui.Picture.onCreate = observedPictures.add;
      addTearDown(() => ui.Picture.onCreate = previousOnCreate);

      final fixtureAnchor = _uniquelyMarkedVectorBytes();
      final preparedVectors = <CanvasPreparedVector>[];
      for (var index = 0; index < 4; index++) {
        final prepared = await _prepareFromErasableOffsetView(fixtureAnchor);
        preparedVectors.add(prepared);
        expect(prepared.intrinsicSize, const ui.Size(13.25, 20));
        expect(observedPictures, hasLength(index + 1));
      }

      await observer.collectGarbage();
      final census = await observer.censusUint8ListsWithBytes(fixtureAnchor);
      final anchorMatches = census.matchingInstances
          .where(
            (instance) =>
                instance.identityHashCode == census.anchor.identityHashCode,
          )
          .toList();
      expect(anchorMatches, hasLength(1));

      final extraMatches = census.matchingInstances
          .where(
            (instance) =>
                instance.identityHashCode != census.anchor.identityHashCode,
          )
          .toList();
      final extraObservations = await Future.wait(
        extraMatches.map(
          (instance) => observer.observeObjectId(instance.objectId),
        ),
      );
      expect(
        extraMatches,
        isEmpty,
        reason:
            'Completed preparation retained exact-copy snapshots: '
            '$extraObservations',
      );

      final anchorObservation = await observer.observeObjectId(
        census.anchor.objectId,
      );
      expect(anchorObservation.retainingPathLength, greaterThan(0));
      expect(anchorObservation.retainingPathRoot, isNotEmpty);
      expect(_hasEngineOrUpstreamOwner(anchorObservation), isFalse);

      for (final prepared in preparedVectors) {
        prepared.dispose();
      }
    },
    skip: Platform.executableArguments.contains(_vmServiceDisabledArgument)
        ? 'Requires flutter test --enable-vmservice for VM retaining-path evidence.'
        : false,
  );
}

bool _hasEngineOrUpstreamOwner(VmRetentionObservation observation) {
  return observation.ownershipSources.any(
    (source) =>
        source.libraryUri.startsWith('package:iwb_canvas_engine/src/api/') ||
        source.libraryUri.startsWith('package:vector_graphics/'),
  );
}

Uint8List _uniquelyMarkedVectorBytes() {
  final bytes = Uint8List.fromList(_viewBytes(basicVectorBytes()));
  ByteData.sublistView(bytes).setFloat32(6, 13.25, Endian.little);
  return bytes;
}

Future<CanvasPreparedVector> _prepareFromErasableOffsetView(
  Uint8List vectorBytes,
) {
  const prefixLength = 32;
  const suffixLength = 32;
  final backing = Uint8List(prefixLength + vectorBytes.length + suffixLength)
    ..fillRange(0, prefixLength, 0x71)
    ..fillRange(
      prefixLength + vectorBytes.length,
      prefixLength + vectorBytes.length + suffixLength,
      0x9c,
    )
    ..setRange(prefixLength, prefixLength + vectorBytes.length, vectorBytes);
  final view = ByteData.sublistView(
    backing,
    prefixLength,
    prefixLength + vectorBytes.length,
  );
  final preparation = prepareVector(view);
  backing.fillRange(0, backing.length, 0);
  return preparation;
}

Uint8List _viewBytes(ByteData data) =>
    data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
