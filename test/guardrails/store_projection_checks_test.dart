import 'dart:io';

import 'package:test/test.dart';

import '../../tool/guardrails/src/store_projection_checks.dart';
import '../../tool/guardrails/src/repository_paths.dart';

void main() {
  _testLiveStateFields();
  _testLiveStateAliases();
  _testInferredLiveStateFields();
  _testTopLevelLiveStateFields();
  _testProjectionConstruction();
  _testProjectionInvocations();
  _testProjectionReturns();
}

void _testLiveStateFields() {
  test('live document state check rejects nullable and generic fields', () {
    return expectLater(
      _expectLiveStateViolations(
        {
          'lib/src/runtime/bad_nullable_document.dart': '''
import '../api/canvas_document.dart';

class Bad {
  CanvasDocument? document;
}
''',
          'lib/src/store/bad_document_list.dart': '''
import '../api/canvas_document.dart';

class Bad {
  List<CanvasDocument> documents = const [];
}
''',
        },
        containsAll([
          'lib/src/runtime/bad_nullable_document.dart',
          'lib/src/store/bad_document_list.dart',
        ]),
      ),
      completes,
    );
  });
}

void _testLiveStateAliases() {
  test('live document state check rejects resolved aliases', () {
    return expectLater(
      _expectLiveStateViolations({
        'lib/src/runtime/bad_document_alias.dart': '''
import '../api/canvas_document.dart';

typedef RuntimeDoc = CanvasDocument;
''',
        'lib/src/store/bad_alias_field.dart': '''
import '../runtime/bad_document_alias.dart';

class Bad {
  RuntimeDoc? document;
}
''',
      }, contains('lib/src/store/bad_alias_field.dart')),
      completes,
    );
  });
}

void _testInferredLiveStateFields() {
  test('live document state check rejects inferred document fields', () {
    return expectLater(
      _expectLiveStateViolations({
        'lib/src/store/bad_inferred_document.dart': '''
import '../api/canvas_document.dart';

class Bad {
  final document = CanvasDocument();
}
''',
      }, contains('lib/src/store/bad_inferred_document.dart')),
      completes,
    );
  });
}

void _testTopLevelLiveStateFields() {
  test('live document state check rejects top-level document state', () {
    return expectLater(
      _expectLiveStateViolations({
        'lib/src/runtime/bad_top_level_document.dart': '''
import '../api/canvas_document.dart';

final cachedDocument = CanvasDocument();
''',
      }, contains('lib/src/runtime/bad_top_level_document.dart')),
      completes,
    );
  });
}

void _testProjectionConstruction() {
  test('projection read-path check rejects direct document construction', () {
    return expectLater(
      _expectProjectionViolations({
        'lib/src/runtime/bad_projection_constructor.dart': '''
import '../api/canvas_document.dart';

CanvasDocument buildProjection() {
  return CanvasDocument();
}
''',
      }, contains('lib/src/runtime/bad_projection_constructor.dart')),
      completes,
    );
  });
}

void _testProjectionInvocations() {
  test('projection read-path check rejects non-read document invocations', () {
    return expectLater(
      _expectSingleProjectionViolation(
        {
          'lib/src/store/bad_projection_invocation.dart': '''
import 'committed_document.dart';
import 'document_projection_cache.dart';

CommittedDocument? admittedDocument;

void hotPathProjection(DocumentProjectionCache cache) {
  cache.projectionFor(admittedDocument!);
}
''',
        },
        path: 'lib/src/store/bad_projection_invocation.dart',
        message: 'public document projection invocation is read-path-only',
      ),
      completes,
    );
  });
}

void _testProjectionReturns() {
  test('projection read-path check rejects non-read document returns', () {
    return expectLater(
      _expectProjectionViolations({
        'lib/src/store/bad_projection_return.dart': '''
import '../api/canvas_document.dart';

CanvasDocument leakProjection(CanvasDocument document) {
  return document;
}
''',
      }, contains('lib/src/store/bad_projection_return.dart')),
      completes,
    );
  });
}

Future<void> _expectLiveStateViolations(
  Map<String, String> files,
  Matcher pathsMatcher,
) {
  return _withTemporaryProductionFiles(files, () async {
    final violations = await checkNoPublicDocumentLiveState();

    expect(violations.map((violation) => violation.path), pathsMatcher);
  });
}

Future<void> _expectProjectionViolations(
  Map<String, String> files,
  Matcher pathsMatcher,
) {
  return _withTemporaryProductionFiles(files, () async {
    final violations = await checkProjectionOnlyExplicitReadPaths();

    expect(violations.map((violation) => violation.path), pathsMatcher);
  });
}

Future<void> _expectSingleProjectionViolation(
  Map<String, String> files, {
  required String path,
  required String message,
}) {
  return _withTemporaryProductionFiles(files, () async {
    final violations = await checkProjectionOnlyExplicitReadPaths();
    final matching = violations.where((violation) => violation.path == path);

    expect(matching, hasLength(1));
    expect(matching.single.message, message);
  });
}

Future<void> _withTemporaryProductionFiles(
  Map<String, String> files,
  Future<void> Function() run,
) async {
  final createdFiles = <File>[];
  final createdDirectories = <Directory>[];

  try {
    for (final entry in files.entries) {
      final file = File('$repositoryRoot/${entry.key}');
      expect(file.existsSync(), isFalse);

      final directory = file.parent;
      if (!directory.existsSync()) {
        directory.createSync(recursive: true);
        createdDirectories.add(directory);
      }
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
    for (final directory in createdDirectories.reversed) {
      if (directory.existsSync()) {
        directory.deleteSync(recursive: true);
      }
    }
  }
}
