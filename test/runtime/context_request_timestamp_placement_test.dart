import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('context request timestamps commit only at delivery placement', () {
    expect(() {
      final sources = _SourceFiles.read();

      _expectInteractionAdmissionCarriesHints(sources.interactionEngine);
      _expectPendingStorageCarriesNoPublicRequest(sources);
      _expectSuppressionAndFilteringAreTimestampSilent(sources.runtimeRoot);
      _expectDeliveryCommitsTimestampBeforeRequestBuild(sources.runtimeRoot);
    }, returnsNormally);
  });
}

final class _SourceFiles {
  const _SourceFiles({
    required this.runtimeRoot,
    required this.interactionEngine,
    required this.runtimeIntents,
  });

  final String runtimeRoot;
  final String interactionEngine;
  final String runtimeIntents;

  factory _SourceFiles.read() {
    return _SourceFiles(
      runtimeRoot: _read('lib/src/runtime/runtime_root.dart'),
      interactionEngine: _read('lib/src/interaction/interaction_engine.dart'),
      runtimeIntents: _read(
        'lib/src/interaction/interaction_runtime_intents.dart',
      ),
    );
  }
}

void _expectInteractionAdmissionCarriesHints(String interactionEngine) {
  final handleDoubleTap = _between(
    interactionEngine,
    'ContextActionRequestIntent? handleDoubleTap(',
    '  // Tool settings.',
  );
  final pointerAdmission = _between(
    interactionEngine,
    'InteractionPointerAdmission _contextTapRequestAdmission(',
    '  InteractionPointerAdmission _handleActiveTerminal(',
  );

  expect(handleDoubleTap, isNot(contains('resolveOutputTimestamp')));
  expect(pointerAdmission, isNot(contains('resolveOutputTimestamp')));
  expect(handleDoubleTap, contains('timestampHintMs: timestampHintMs'));
  expect(pointerAdmission, contains('timestampHintMs: sample.timestampMs'));
}

void _expectPendingStorageCarriesNoPublicRequest(_SourceFiles sources) {
  final emitContextRequest = _emitContextRequestSource(sources.runtimeRoot);
  final pendingStorage = _between(
    emitContextRequest,
    '    _pendingContextRequests.add((',
    '    if (_isContextRequestDeliveryScheduled) {',
  );

  expect(
    sources.runtimeRoot,
    contains(
      'final List<({int generation, PendingContextActionRequest pendingRequest})>',
    ),
  );
  expect(
    sources.runtimeIntents,
    isNot(contains('final CanvasContextActionRequested request;')),
  );
  expect(pendingStorage, isNot(contains('reserveTimestamp')));
  expect(pendingStorage, isNot(contains('toRequest')));
}

void _expectSuppressionAndFilteringAreTimestampSilent(String runtimeRoot) {
  final suppressPending = _between(
    runtimeRoot,
    '  void _suppressPendingContextRequests() {',
    '  List<PendingContextActionRequest> _takeDeliverablePendingContextRequests() {',
  );
  final takeDeliverable = _between(
    runtimeRoot,
    '  List<PendingContextActionRequest> _takeDeliverablePendingContextRequests() {',
    '  // Selected move commit flow.',
  );

  expect(suppressPending, isNot(contains('reserveTimestamp')));
  expect(suppressPending, isNot(contains('toRequest')));
  expect(takeDeliverable, isNot(contains('reserveTimestamp')));
  expect(takeDeliverable, isNot(contains('toRequest')));
  expect(takeDeliverable, isNot(contains('_contextActionRequests.add')));
}

void _expectDeliveryCommitsTimestampBeforeRequestBuild(String runtimeRoot) {
  _expectOrdered(_emitContextRequestSource(runtimeRoot), [
    '_takeDeliverablePendingContextRequests()',
    '_actionFinalizer.reserveTimestamp',
    'pendingRequest.toRequest',
    '_contextActionRequests.add(request)',
  ]);
}

String _emitContextRequestSource(String runtimeRoot) {
  return _between(
    runtimeRoot,
    '  void _emitContextRequest(ContextActionRequestIntent intent) {',
    '  void _suppressPendingContextRequests() {',
  );
}

String _read(String path) => File(path).readAsStringSync();

String _between(String source, String start, String end) {
  final pattern = RegExp(
    '${RegExp.escape(start)}[\\s\\S]*?${RegExp.escape(end)}',
  );
  final match = pattern.firstMatch(source);
  if (match == null) {
    fail('missing bounded source: $start');
  }
  final boundedSource = match.group(0);
  if (boundedSource == null) {
    fail('empty bounded source: $start');
  }

  return boundedSource;
}

void _expectOrdered(String source, List<String> tokens) {
  var cursor = -1;
  for (final token in tokens) {
    final index = source.indexOf(token, cursor + 1);
    expect(index, isNonNegative, reason: 'missing ordered token: $token');
    expect(index, greaterThan(cursor), reason: 'token out of order: $token');
    cursor = index;
  }
}
