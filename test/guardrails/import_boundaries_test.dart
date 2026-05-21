import 'dart:io';

import 'package:test/test.dart';

import '../../tool/guardrails/src/core_boundary_checks.dart';
import '../../tool/guardrails/src/guardrail_violation.dart';
import '../../tool/guardrails/src/repository_paths.dart';

void main() {
  test(
    'production source paths obey import and retired-shape boundaries',
    () async {
      expect(await checkCoreBoundaries(), isEmpty);
    },
  );

  test(
    'runner rejects interaction imports through the core suite id',
    () async {
      final result = await _withTemporaryInteractionStoreImport(
        _runCoreImportBoundaryGuardrail,
      );
      final output = '${result.stdout}\n${result.stderr}';

      expect(result.exitCode, isNot(0));
      expect(output, contains('core.import_boundaries'));
      expect(output, contains('bad_import_boundary_fixture.dart'));
    },
  );

  test('api facade may import only the runtime composition root', () {
    expect(
      checkCoreBoundaryFile(
        path: 'lib/src/api/canvas_runtime.dart',
        content: "import '../runtime/runtime_root.dart';\n",
      ),
      isEmpty,
    );
    expect(
      checkCoreBoundaryFile(
        path: 'lib/src/api/canvas_runtime.dart',
        content: "import '../runtime/runtime_config.dart';\n",
      ),
      contains(
        isA<GuardrailViolation>().having(
          (violation) => violation.guardrailId,
          'guardrailId',
          'core.import_boundaries',
        ),
      ),
    );
  });
}

Future<ProcessResult> _withTemporaryInteractionStoreImport(
  Future<ProcessResult> Function() run,
) async {
  final storeDirectory = Directory('$repositoryRoot/lib/src/store');
  final interactionDirectory = Directory('$repositoryRoot/lib/src/interaction');
  final storeDirectoryExisted = storeDirectory.existsSync();
  final interactionDirectoryExisted = interactionDirectory.existsSync();
  final storeFile = File(
    '${storeDirectory.path}/guardrail_fixture_store_kernel.dart',
  );
  final badInteractionFile = File(
    '${interactionDirectory.path}/bad_import_boundary_fixture.dart',
  );
  var createdStoreFile = false;
  var createdBadInteractionFile = false;

  try {
    expect(storeFile.existsSync(), isFalse);
    expect(badInteractionFile.existsSync(), isFalse);

    storeDirectory.createSync(recursive: true);
    interactionDirectory.createSync(recursive: true);
    storeFile.writeAsStringSync('class DocumentStoreKernel {}\n');
    createdStoreFile = true;
    badInteractionFile.writeAsStringSync(
      "import '../store/guardrail_fixture_store_kernel.dart';\n",
    );
    createdBadInteractionFile = true;

    return await run();
  } finally {
    _deleteCreatedFile(createdBadInteractionFile, badInteractionFile);
    _deleteCreatedFile(createdStoreFile, storeFile);
    _deleteCreatedDirectory(interactionDirectoryExisted, interactionDirectory);
    _deleteCreatedDirectory(storeDirectoryExisted, storeDirectory);
  }
}

Future<ProcessResult> _runCoreImportBoundaryGuardrail() {
  return Process.run('dart', [
    'run',
    'tool/guardrails/run.dart',
    '--guardrail=core.import_boundaries',
  ], workingDirectory: repositoryRoot);
}

void _deleteCreatedFile(bool created, File file) {
  if (created && file.existsSync()) {
    file.deleteSync();
  }
}

void _deleteCreatedDirectory(bool existedBeforeTest, Directory directory) {
  if (!existedBeforeTest && directory.existsSync()) {
    directory.deleteSync(recursive: true);
  }
}
