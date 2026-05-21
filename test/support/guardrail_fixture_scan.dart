import 'dart:io';

import 'package:test/test.dart';

import '../../tool/guardrails/src/repository_paths.dart';

final class GuardrailFixtureScan {
  const GuardrailFixtureScan({
    required this.sources,
    required this.analysisIncludedPaths,
  });

  final List<GuardrailSourceFile> sources;
  final List<String> analysisIncludedPaths;
}

Future<void> withGuardrailFixtureScan(
  Map<String, String> files,
  Future<void> Function(GuardrailFixtureScan scan) run,
) async {
  final fixtureRoot = Directory(
    '$repositoryRoot/.dart_tool/guardrail_test_fixtures',
  )..createSync(recursive: true);
  final root = fixtureRoot.createTempSync('case_');

  try {
    final sources = _writeFixtureSources(root, files);

    await run(
      GuardrailFixtureScan(
        sources: sources,
        analysisIncludedPaths: [root.path, '$repositoryRoot/lib'],
      ),
    );
  } finally {
    if (root.existsSync()) {
      root.deleteSync(recursive: true);
    }
  }
}

List<GuardrailSourceFile> _writeFixtureSources(
  Directory root,
  Map<String, String> files,
) {
  final sources = <GuardrailSourceFile>[];

  for (final entry in files.entries) {
    final file = File('${root.path}/${entry.key}');
    expect(file.existsSync(), isFalse);
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(entry.value);
    sources.add(
      GuardrailSourceFile(path: entry.key, absolutePath: file.absolute.path),
    );
  }

  return sources;
}
