@Tags(['tool'])
library;

import 'dart:io';

import 'package:test/test.dart';

void main() {
  group('guardrail fixture manifest support ownership', () {
    test('interactive canonical scene-controller scaffold only lives in support', () {
      const interactiveSuiteFiles = <String>{
        'test/tool/guardrails/guardrails_interactive_api_tool_test.dart',
        'test/tool/guardrails/guardrails_interactive_resolved_entrypoint_guard_tool_test.dart',
      };
      final interactivePartFiles =
          Directory(
            'test/tool/guardrails/interactive_api',
          ).listSync(recursive: true).whereType<File>().where((file) {
            return file.path.endsWith('.dart');
          });
      final candidateFiles = <String>{
        ...interactiveSuiteFiles,
        ...interactivePartFiles.map(_normalizePath),
      };

      for (final path in candidateFiles) {
        final source = File(path).readAsStringSync();
        final canonicalShapeMarkers = <String>[
          'final SceneControllerGraphHandle _graph = createSceneControllerGraph(',
          'Object get actions => _graph.actions;',
          'Object get editTextRequests => _graph.editTextRequests;',
          'SceneViewRuntime sceneControllerViewRuntimeOf(SceneController controller)',
        ];
        final matchedMarkerCount = canonicalShapeMarkers
            .where(source.contains)
            .length;
        expect(
          matchedMarkerCount >= 2,
          isFalse,
          reason:
              'Interactive suite file must not own canonical scene-controller scaffold: $path',
        );
      }

      final manifestSource = File(
        'test/tool/support/guardrail_fixture_manifest.dart',
      ).readAsStringSync();
      expect(
        manifestSource.contains(
          'classDeclaration = \'class SceneController {\'',
        ),
        isTrue,
        reason:
            'Manifest owner must keep the canonical scene-controller shape fields.',
      );
      expect(
        manifestSource.contains('graphMembers ='),
        isTrue,
        reason:
            'Manifest owner must keep the canonical graph-member scaffold fields.',
      );

      final writerSource = File(
        'test/tool/support/guardrail_fixture_writer.dart',
      ).readAsStringSync();
      expect(
        writerSource.contains(
          'SceneViewRuntime sceneControllerViewRuntimeOf(SceneController controller)',
        ),
        isTrue,
        reason:
            'Writer owner must keep the canonical scene-controller scaffold materialization.',
      );
    });

    test('controller committed-mutation scaffold only lives in support', () {
      final controllerSource = File(
        'test/tool/guardrails/guardrails_controller_api_tool_test.dart',
      ).readAsStringSync();
      final canonicalControllerMarkers = <String>[
        'typedef SceneControllerCommittedMutationWriteResult<T> = ({',
        'bool setBackgroundColor(Color value);',
        'bool replaceSelection(Iterable<NodeId> nodeIds);',
        'NodeId commitDrawLineFromWorldSegment({',
        'SceneStoreControllerCommittedMutationAccess(this._storeController);',
      ];
      final matchedMarkerCount = canonicalControllerMarkers
          .where(controllerSource.contains)
          .length;
      expect(
        matchedMarkerCount >= 4,
        isFalse,
        reason:
            'Controller suite must not own canonical committed-mutation scaffold.',
      );

      final manifestSource = File(
        'test/tool/support/guardrail_fixture_manifest.dart',
      ).readAsStringSync();
      expect(
        manifestSource.contains('interfaceReplaceSceneDeclaration ='),
        isTrue,
        reason:
            'Manifest owner must keep the canonical controller replaceScene shape fields.',
      );
      expect(
        manifestSource.contains('adapterReplaceSceneDeclaration ='),
        isTrue,
        reason:
            'Manifest owner must keep the canonical controller adapter shape fields.',
      );

      final writerSource = File(
        'test/tool/support/guardrail_fixture_writer.dart',
      ).readAsStringSync();
      expect(
        writerSource.contains(
          'abstract interface class SceneControllerCommittedMutationAccess {',
        ),
        isTrue,
        reason:
            'Writer owner must keep the canonical committed-mutation scaffold materialization.',
      );
      expect(
        writerSource.contains(
          'final class SceneStoreControllerCommittedMutationAccess',
        ),
        isTrue,
        reason:
            'Writer owner must keep the canonical committed-mutation adapter materialization.',
      );
    });

    test('public and rule-inventory suites no longer import the legacy seam', () {
      const migratedSuites = <String>[
        'test/tool/guardrails/guardrails_public_surface_tool_test.dart',
        'test/tool/guardrails/guardrails_public_signature_hermeticity_tool_test.dart',
        'test/tool/guardrails/guardrails_rule_inventory_tool_test.dart',
      ];

      for (final path in migratedSuites) {
        final source = File(path).readAsStringSync();
        expect(
          source.contains(
            "import '../support/guardrails_tool_test_support.dart';",
          ),
          isFalse,
          reason: 'Migrated suite must not import the legacy seam: $path',
        );
      }

      final manifestSource = File(
        'test/tool/support/guardrail_fixture_manifest.dart',
      ).readAsStringSync();
      expect(
        manifestSource.contains('GuardrailPublicExportScaffoldManifest'),
        isTrue,
        reason:
            'Manifest owner must keep the canonical public export scaffold manifest.',
      );

      final writerSource = File(
        'test/tool/support/guardrail_fixture_writer.dart',
      ).readAsStringSync();
      expect(
        writerSource.contains('void writeCanonicalPublicExportScaffold('),
        isTrue,
        reason:
            'Writer owner must keep the canonical public export scaffold materialization.',
      );
    });

    test('contract, model, and layout suites no longer import the legacy seam', () {
      const migratedSuites = <String>[
        'test/tool/guardrails/guardrails_contract_architecture_tool_test.dart',
        'test/tool/guardrails/guardrails_model_architecture_tool_test.dart',
        'test/tool/guardrails/guardrails_layout_and_entrypoints_tool_test.dart',
      ];

      for (final path in migratedSuites) {
        final source = File(path).readAsStringSync();
        expect(
          source.contains(
            "import '../support/guardrails_tool_test_support.dart';",
          ),
          isFalse,
          reason: 'Migrated suite must not import the legacy seam: $path',
        );
      }

      final layoutSource = File(
        'test/tool/guardrails/guardrails_layout_and_entrypoints_tool_test.dart',
      ).readAsStringSync();
      expect(
        layoutSource.contains('void writeCanonicalPublicExportScaffold('),
        isFalse,
        reason:
            'Layout suite must not reclaim canonical public scaffold materialization.',
      );
    });

    test(
      'legacy support file stays retired and import-boundaries use successor seams',
      () {
        expect(
          File(
            'test/tool/support/guardrails_tool_test_support.dart',
          ).existsSync(),
          isFalse,
          reason: 'Legacy mixed support file must stay retired.',
        );

        const importBoundarySuites = <String>[
          'test/tool/import_boundaries/import_boundaries_controller_structure_tool_test.dart',
          'test/tool/import_boundaries/import_boundaries_layer_dag_tool_test.dart',
          'test/tool/import_boundaries/import_boundaries_external_packages_tool_test.dart',
          'test/tool/import_boundaries/import_boundaries_layout_tool_test.dart',
        ];
        for (final path in importBoundarySuites) {
          final source = File(path).readAsStringSync();
          expect(
            source.contains(
              "import '../support/guardrails_tool_test_support.dart';",
            ),
            isFalse,
            reason:
                'Import-boundaries suite must not import the legacy seam: $path',
          );
        }
      },
    );
  });
}

String _normalizePath(File file) {
  return file.path.replaceAll('\\', '/');
}
