import 'dart:io';

import 'package:test/test.dart';

import '../../tool/guardrails/src/repository_paths.dart';

const _publicEngineImport =
    'import \'package:iwb_canvas_engine/iwb_canvas_engine.dart\';';

const _retiredExampleSymbols = [
  'SceneController',
  'SceneView',
  'SceneSnapshot',
  'ContentLayerSnapshot',
  'PointerInputSettings',
  'CanvasMode',
  'DrawTool',
  'EditTextRequested',
  'NodeId',
  'NodePatch',
  'TextNodeSnapshot',
  'TextNodePatch',
  'CommonNodePatch',
  'PatchField',
  'NodeSpec',
  'RectNodeSpec',
  'TextNodeSpec',
  'ImageNodeSpec',
  'Transform2D',
  'encodeSceneToJson',
  'decodeSceneFromJson',
];

const _engineAdapterSymbols = [
  'AppCanvasPort',
  'LegacyEngineAdapter',
  'NextEngineAdapter',
];

void main() {
  _registerEngineImportBoundaryTest();
  _registerRetiredSeamBoundaryTest();
  _registerNoProductionLibDiffTest();
  _registerProductionAdapterBoundaryTest();
}

void _registerEngineImportBoundaryTest() {
  test('example imports the engine only through the public barrel', () {
    final violations = <String>[];
    for (final file in _exampleDartFiles()) {
      final source = File(file.absolutePath).readAsStringSync();
      final engineImports = _importLines(
        source,
      ).where((line) => line.contains('package:iwb_canvas_engine/')).toList();
      for (final line in engineImports) {
        if (line != _publicEngineImport) {
          violations.add('${file.path}: $line');
        }
      }
    }

    expect(violations, isEmpty);
  });
}

void _registerRetiredSeamBoundaryTest() {
  test('example sources do not reference private or retired seams', () {
    final violations = <String>[];
    for (final file in _exampleDartFiles()) {
      final source = File(file.absolutePath).readAsStringSync();
      _recordForbiddenPathMentions(file.path, source, violations);
      _recordRetiredSymbolMentions(file.path, source, violations);
    }

    expect(violations, isEmpty);
  });
}

void _registerProductionAdapterBoundaryTest() {
  test(
    'production engine source does not contain app adapter responsibilities',
    () {
      final violations = <String>[];
      for (final file in dartSourceFilesUnder('lib')) {
        final source = File(file.absolutePath).readAsStringSync();
        for (final symbol in _engineAdapterSymbols) {
          if (_containsIdentifier(source, symbol)) {
            violations.add('${file.path}: $symbol');
          }
        }
      }

      expect(violations, isEmpty);
    },
  );
}

void _registerNoProductionLibDiffTest() {
  test('example step diff does not modify production lib source', () {
    final diffRange = _exampleBoundaryDiffRange();
    final changedPaths = diffRange == null
        ? _currentChangedPaths()
        : _gitChangedPaths([
            'diff',
            '--name-only',
            '${diffRange.base}..${diffRange.head}',
          ]);
    if (!changedPaths.any(_isExampleBoundaryPath)) {
      markTestSkipped(
        diffRange == null
            ? 'Set EXAMPLE_BOUNDARY_DIFF_BASE and EXAMPLE_BOUNDARY_DIFF_HEAD '
                  'when reviewing a committed example boundary step diff; '
                  'the current working tree has no example/** changes to '
                  'classify.'
            : 'The committed example boundary diff range has no example/** '
                  'changes to classify.',
      );

      return;
    }
    final productionLibPaths = changedPaths.where(_isProductionLibPath);

    expect(
      productionLibPaths.toSet(),
      isEmpty,
      reason: 'Production lib/** changes require a separate engine contract.',
    );
  });
}

({String base, String head})? _exampleBoundaryDiffRange() {
  final base = Platform.environment['EXAMPLE_BOUNDARY_DIFF_BASE'];
  final head = Platform.environment['EXAMPLE_BOUNDARY_DIFF_HEAD'];
  if (base != null && base.isNotEmpty && head != null && head.isNotEmpty) {
    return (base: base, head: head);
  }

  return null;
}

List<String> _currentChangedPaths() {
  return {
    ..._gitChangedPaths(['diff', '--name-only']),
    ..._gitChangedPaths(['diff', '--cached', '--name-only']),
    ..._gitChangedPaths(['ls-files', '--others', '--exclude-standard']),
  }.toList();
}

List<String> _gitChangedPaths(List<String> arguments) {
  final result = Process.runSync('git', arguments);
  expect(result.exitCode, 0, reason: _processOutput(result));

  return (result.stdout as String)
      .split('\n')
      .map((path) => path.trim())
      .where((path) => path.isNotEmpty)
      .toList();
}

Iterable<GuardrailSourceFile> _exampleDartFiles() {
  return dartSourceFilesUnder('example').where((file) {
    return !_isGeneratedExamplePath(file.path);
  });
}

bool _isExampleBoundaryPath(String path) {
  return path.startsWith('example/') && !_isGeneratedExamplePath(path);
}

bool _isProductionLibPath(String path) {
  return path.startsWith('lib/');
}

bool _isGeneratedExamplePath(String path) {
  return path.startsWith('example/.dart_tool/') ||
      path.startsWith('example/build/');
}

Iterable<String> _importLines(String source) {
  return source
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.startsWith('import '));
}

void _recordForbiddenPathMentions(
  String path,
  String source,
  List<String> violations,
) {
  final importLines = _importLines(source).toList();
  for (final line in importLines) {
    if (line.contains('package:iwb_canvas_engine/src/') ||
        line.contains('/lib/src/') ||
        line.contains('../lib/src/') ||
        line.contains('legacy/')) {
      violations.add('$path: $line');
    }
  }
}

void _recordRetiredSymbolMentions(
  String path,
  String source,
  List<String> violations,
) {
  for (final symbol in [..._retiredExampleSymbols, ..._engineAdapterSymbols]) {
    if (_containsIdentifier(source, symbol)) {
      violations.add('$path: $symbol');
    }
  }
}

bool _containsIdentifier(String source, String identifier) {
  return RegExp('\\b${RegExp.escape(identifier)}\\b').hasMatch(source);
}

String _processOutput(ProcessResult result) {
  return '''
stdout:
${result.stdout}

stderr:
${result.stderr}
''';
}
