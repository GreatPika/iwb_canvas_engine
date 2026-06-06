import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('ordinary edit and interaction commit routes open sparse sessions', () {
    final source = File('lib/src/edit/edit_kernel.dart').readAsStringSync();

    for (final route in _guardedRoutes) {
      final methodSource = _methodBody(source, route.startMarker);
      expect(
        methodSource,
        contains('_openSparseSession(selectedElementIds)'),
        reason: '${route.name} must open the sparse edit session route.',
      );
      expect(
        methodSource,
        isNot(contains('DraftDocument(_readDocument()')),
        reason:
            '${route.name} must not eagerly materialize the public projection.',
      );
      expect(
        methodSource,
        isNot(contains('readDraftDocument()')),
        reason:
            '${route.name} must not materialize before accepting sparse commits.',
      );
    }
  });
}

String _methodBody(String source, String startMarker) {
  final methodStart = source.indexOf(startMarker);
  if (methodStart < 0) {
    throw StateError('Could not find $startMarker.');
  }
  final bodyStart = _methodBodyStart(source, methodStart);

  var depth = 0;
  for (var i = bodyStart; i < source.length; i += 1) {
    final char = source.codeUnitAt(i);
    if (char == 0x7B) {
      depth += 1;
    } else if (char == 0x7D) {
      depth -= 1;
      if (depth == 0) {
        // Source offsets come from ASCII Dart syntax scanning, so the returned
        // slice must use the same code-unit coordinate system.
        // ignore: avoid-substring
        return source.substring(methodStart, i + 1);
      }
    }
  }

  throw StateError('Could not parse $startMarker.');
}

int _methodBodyStart(String source, int methodStart) {
  var parenDepth = 0;
  for (var i = methodStart; i < source.length; i += 1) {
    final char = source.codeUnitAt(i);
    if (char == 0x28) {
      parenDepth += 1;
    } else if (char == 0x29) {
      parenDepth -= 1;
    } else if (char == 0x7B && parenDepth == 0) {
      return i;
    }
  }

  throw StateError('Could not find method body.');
}

const _guardedRoutes = [
  (name: 'EditKernel.edit', startMarker: '\n  T edit<T>('),
  (
    name: 'EditKernel.prepareInteractionCommit',
    startMarker: '\n  CommitDeliveryResult prepareInteractionCommit<T>(',
  ),
];
