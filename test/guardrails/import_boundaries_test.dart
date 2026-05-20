import 'dart:io';

import 'package:test/test.dart';

import '../../tool/guardrails/src/core_boundary_checks.dart';
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
      final storeDirectory = Directory('$repositoryRoot/lib/src/store');
      final interactionDirectory = Directory(
        '$repositoryRoot/lib/src/interaction',
      );
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

        final result = await Process.run('dart', [
          'run',
          'tool/guardrails/run.dart',
          '--guardrail=core.import_boundaries',
        ], workingDirectory: repositoryRoot);
        final output = '${result.stdout}\n${result.stderr}';

        expect(result.exitCode, isNot(0));
        expect(output, contains('core.import_boundaries'));
        expect(output, contains('bad_import_boundary_fixture.dart'));
      } finally {
        if (createdBadInteractionFile && badInteractionFile.existsSync()) {
          badInteractionFile.deleteSync();
        }
        if (createdStoreFile && storeFile.existsSync()) {
          storeFile.deleteSync();
        }
        if (!interactionDirectoryExisted && interactionDirectory.existsSync()) {
          interactionDirectory.deleteSync(recursive: true);
        }
        if (!storeDirectoryExisted && storeDirectory.existsSync()) {
          storeDirectory.deleteSync(recursive: true);
        }
      }
    },
  );
}
