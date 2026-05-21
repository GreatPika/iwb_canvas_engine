import 'dart:io';

import 'package:test/test.dart';

import '../../tool/guardrails/src/repository_paths.dart';
import '../../tool/guardrails/src/selection_boundary_checks.dart';

void main() {
  test('production document and store code do not retain selection state', () {
    return expectLater(checkSelectionOwnerSeparation(), completion(isEmpty));
  });

  test('selection owner check rejects selected ids in store state', () {
    return expectLater(
      _expectSelectionBoundaryViolation({
        'lib/src/store/bad_selected_ids.dart': '''
import 'dart:collection';

import '../api/canvas_ids.dart';

class BadStoreState {
  final activeElementIds = <CanvasElementId, bool>{};
  final viewIds = LinkedHashSet<CanvasElementId>();
  final selectedElementId = 'element-a';
  final selectedIds = <String>{};
}
''',
      }, contains('lib/src/store/bad_selected_ids.dart')),
      completes,
    );
  });

  test('selection owner check rejects selection revision in codec state', () {
    return expectLater(
      _expectSelectionBoundaryViolation({
        'lib/src/codec/bad_selection_revision.dart': '''
class BadCodecState {
  int selectionRevision = 0;
}
''',
      }, contains('lib/src/codec/bad_selection_revision.dart')),
      completes,
    );
  });
}

Future<void> _expectSelectionBoundaryViolation(
  Map<String, String> files,
  Matcher pathsMatcher,
) {
  return _withTemporaryProductionFiles(files, () async {
    final violations = await checkSelectionOwnerSeparation();

    expect(violations.map((violation) => violation.path), pathsMatcher);
  });
}

Future<void> _withTemporaryProductionFiles(
  Map<String, String> files,
  Future<void> Function() run,
) async {
  final createdFiles = <File>[];

  try {
    for (final entry in files.entries) {
      final file = File('$repositoryRoot/${entry.key}');
      expect(file.existsSync(), isFalse);
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(entry.value);
      createdFiles.add(file);
    }

    await run();
  } finally {
    for (final file in createdFiles.reversed) {
      if (file.existsSync()) {
        file.deleteSync();
      }
    }
  }
}
