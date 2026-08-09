import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';

import '../support/vector_preparation_fixture.dart';
import 'fixtures/vm_retention_observer.dart';

// Flutter's test runner supplies this mutually exclusive VM-service intent.
const _vmServiceDisabledArgument = '--disable-vm-service';

void main() {
  _testUnresolvedVmObjectIdentity();
  _testPreparationRetention();
}

void _testUnresolvedVmObjectIdentity() {
  test(
    'unresolved VM object identity leaves retention observation incomplete',
    () async {
      final observer = await VmRetentionObserver.connect();
      addTearDown(observer.dispose);

      final observation = await observer.observeObjectId('objects/invalid');

      expect(observation.retainingPathComplete, isFalse);
      expect(
        observation.retainingPathIncompleteReasons,
        contains(startsWith('retaining path unavailable')),
      );
      expect(observation.inboundTraversalComplete, isFalse);
      expect(
        observation.inboundTraversalLimitReasons,
        contains(startsWith('inbound references unavailable')),
      );
    },
    skip: Platform.executableArguments.contains(_vmServiceDisabledArgument)
        ? 'Requires flutter test --enable-vmservice for VM retaining-path evidence.'
        : false,
  );
}

void _testPreparationRetention() {
  test(
    'preparation owns an exact caller view and releases settled snapshots',
    () async {
      final observation = await _runPreparationRetentionScenario();

      expect(observation.retainingPathLength, greaterThan(0));
      expect(observation.retainingPathRoot, isNotEmpty);
      expect(
        observation.inboundTraversalComplete,
        isTrue,
        reason: observation.inboundTraversalLimitReasons.join(', '),
      );
      expect(observation.inboundTraversalLimitReasons, isEmpty);
      expect(
        _hasEngineOrUpstreamOwner(observation.inboundOwnershipSources),
        isFalse,
      );
    },
    skip: Platform.executableArguments.contains(_vmServiceDisabledArgument)
        ? 'Requires flutter test --enable-vmservice for VM retaining-path evidence.'
        : false,
  );
}

Future<VmRetentionObservation> _runPreparationRetentionScenario() async {
  final observer = await VmRetentionObserver.connect();
  addTearDown(observer.dispose);
  final observedPictures = <ui.Picture>[];
  final previousOnCreate = ui.Picture.onCreate;
  ui.Picture.onCreate = observedPictures.add;
  addTearDown(() => ui.Picture.onCreate = previousOnCreate);

  final callerBytes = _RetainedCallerVectorBytes();
  final preparedVectors = await _prepareCallerViews(
    callerBytes,
    observedPictures,
  );
  final census = await _censusCallerBytes(observer, callerBytes);
  final observation = await _observeCallerOwnership(
    observer,
    census.anchor.objectId,
  );

  for (final prepared in preparedVectors) {
    prepared.dispose();
  }
  return observation;
}

Future<List<CanvasPreparedVector>> _prepareCallerViews(
  _RetainedCallerVectorBytes callerBytes,
  List<ui.Picture> observedPictures,
) async {
  final preparedVectors = <CanvasPreparedVector>[];
  for (var index = 0; index < 4; index++) {
    final prepared = await callerBytes.prepare();
    preparedVectors.add(prepared);
    expect(prepared.intrinsicSize, const ui.Size(13.25, 20));
    expect(observedPictures, hasLength(index + 1));
  }
  return preparedVectors;
}

Future<VmTypedDataCensus> _censusCallerBytes(
  VmRetentionObserver observer,
  _RetainedCallerVectorBytes callerBytes,
) async {
  await observer.collectGarbage();
  final census = await callerBytes.census(observer);
  final anchorMatches = census.matchingInstances
      .where(
        (instance) =>
            instance.identityHashCode == census.anchor.identityHashCode,
      )
      .toList();
  expect(anchorMatches, hasLength(1));
  await _expectNoRetainedSnapshots(observer, census);
  return census;
}

Future<void> _expectNoRetainedSnapshots(
  VmRetentionObserver observer,
  VmTypedDataCensus census,
) async {
  final extraMatches = census.matchingInstances
      .where(
        (instance) =>
            instance.identityHashCode != census.anchor.identityHashCode,
      )
      .toList();
  final extraObservations = await Future.wait(
    extraMatches.map((instance) => observer.observeObjectId(instance.objectId)),
  );
  expect(
    extraMatches,
    isEmpty,
    reason:
        'Completed preparation retained exact-copy snapshots: '
        '$extraObservations',
  );
}

Future<VmRetentionObservation> _observeCallerOwnership(
  VmRetentionObserver observer,
  String anchorObjectId,
) => observer.observeReleasedObjectId(
  anchorObjectId,
  isTerminalOwnershipRoot: _isExplicitTestOrServiceOwnership,
);

bool _hasEngineOrUpstreamOwner(Iterable<VmRetentionSource> sources) {
  return sources.any(
    (source) =>
        source.libraryUri.startsWith('package:iwb_canvas_engine/src/api/') ||
        source.libraryUri.startsWith('package:vector_graphics/'),
  );
}

bool _isExplicitTestOrServiceOwnership(VmRetentionSource source) {
  final libraryUri = source.libraryUri;
  return libraryUri.startsWith('dart:developer') ||
      libraryUri.startsWith('package:vm_service/') ||
      libraryUri.startsWith('package:flutter_test/') ||
      libraryUri.startsWith('package:test_api/') ||
      libraryUri.contains('/test/api/') ||
      (libraryUri.startsWith('package:flutter/src/widgets/') &&
          source.className.endsWith('Element'));
}

Uint8List _uniquelyMarkedVectorBytes() {
  final bytes = Uint8List.fromList(_viewBytes(basicVectorBytes()));
  ByteData.sublistView(bytes).setFloat32(6, 13.25, Endian.little);
  return bytes;
}

final class _RetainedCallerVectorBytes {
  _RetainedCallerVectorBytes() : _bytes = _uniquelyMarkedVectorBytes();

  final Uint8List _bytes;

  Future<CanvasPreparedVector> prepare() =>
      _prepareFromErasableOffsetView(_bytes);

  Future<VmTypedDataCensus> census(VmRetentionObserver observer) =>
      observer.censusUint8ListsWithBytes(_bytes);
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
