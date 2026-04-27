@Tags(['tool'])
library;

import 'dart:io';

import 'package:test/test.dart';

import 'support/tool_process_test_support.dart';

const List<String> _architectureFamilyIds = <String>[
  'public_package_boundary',
  'contract_document_model_and_validated_fast_paths',
  'import_build_materialization',
  'serialization_and_schema',
  'core_scene_graph_geometry_and_spatial_indexes',
  'model_document_mutation_and_topology',
  'store_and_commit_path',
  'composition_root_and_facade',
  'interaction_runtime',
  'mutation_gateway',
  'view_runtime_and_pointer_hosting',
  'render_frame_admission_and_caches',
  'diagnostics_performance_and_debug_surfaces',
];

const List<String> _proofFamilyIds = <String>[
  'public_entrypoint_and_signature_proof',
  'guardrail_runner_and_artifact_model',
  'invariant_registry_and_proof_reachability',
  'verification_contract_and_workflow_drift',
];

const Map<String, List<String>> _architectureFamilyInvariantIds =
    <String, List<String>>{
      'public_package_boundary': <String>[
        'INV-G-PUBLIC-ENTRYPOINTS',
        'INV-ENG-NO-EXTERNAL-MUTATION',
        'INV-ENG-PUBLIC-SNAPSHOT-GLOBAL-VALIDITY',
        'INV-ENG-SHARED-SCENE-METADATA-CONTRACT',
        'INV-ENG-SAFE-TXN-API',
        'INV-ENG-PUBLIC-SURFACE-NO-MUTABLE-TYPES',
        'INV-ENG-PUBLIC-SIGNATURE-HERMETICITY',
      ],
      'contract_document_model_and_validated_fast_paths': <String>[
        'INV-ENG-NO-EXTERNAL-MUTATION',
        'INV-ENG-PUBLIC-SNAPSHOT-GLOBAL-VALIDITY',
        'INV-ENG-SHARED-SCENE-METADATA-CONTRACT',
        'INV-ENG-CONTRACT-ARCHITECTURE-BOUNDARY',
        'INV-ENG-BOUNDARY-HERMETIC-CONCRETE-TYPES',
      ],
      'import_build_materialization': <String>[
        'INV-ENG-VALIDATED-IMPORT-MATERIALIZATION-BOUNDARY',
        'INV-SER-IMPORT-DIAGNOSTIC-SURFACE',
      ],
      'serialization_and_schema': <String>[
        'INV-G-LAYER-BOUNDARIES',
        'INV-ENG-SHARED-SCENE-METADATA-CONTRACT',
        'INV-SER-JSON-NUMERIC-VALIDATION',
        'INV-SER-IMPORT-DIAGNOSTIC-SURFACE',
        'INV-SER-JSON-GRID-PALETTE-CONTRACTS',
        'INV-SER-SHARED-STROKE-POINT-LIMIT',
        'INV-SER-SHARED-PALETTE-ITEM-LIMIT',
        'INV-SER-TEXT-DIRECTION-EXPLICIT',
        'INV-SER-TYPED-LAYER-SPLIT',
        'INV-SER-CANONICAL-BACKGROUND-LAYER',
        'INV-SER-SCHEMA-VERSION-CONTRACT',
        'INV-SER-UNSUPPORTED-SCHEMA-VERSION-CODE',
      ],
      'core_scene_graph_geometry_and_spatial_indexes': <String>[
        'INV-G-NODEID-UNIQUE',
        'INV-G-LAYERID-UNIQUE',
        'INV-G-LAYER-Z-ORDER-BY-LIST',
        'INV-ENG-STROKE-RUNTIME-GEOMETRY-OWNER',
        'INV-ENG-PALETTE-RUNTIME-VALUE-OWNER',
        'INV-ENG-RUNTIME-NODE-VALUE-OWNERS',
        'INV-ENG-EVENTS-IMMUTABLE',
        'INV-ENG-CORE-ARCHITECTURE-BOUNDARY',
        'INV-ENG-POINTER-SETTINGS-VALIDATION',
        'INV-ENG-RENDER-HIT-BOUNDS-PARITY',
        'INV-ENG-PAINT-ADMISSION-BOUNDS-SOURCE',
        'INV-ENG-PATH-NODE-CACHE-INVALIDATION',
      ],
      'model_document_mutation_and_topology': <String>[
        'INV-G-NODEID-UNIQUE',
        'INV-G-LAYERID-UNIQUE',
        'INV-G-SELECTION-NORMALIZED',
        'INV-G-GRID-ENABLE-CELL-SIZE-RELATION',
        'INV-ENG-ID-INDEX-FROM-SCENE',
        'INV-ENG-RUNTIME-SCENE-STRUCTURE-OWNER',
        'INV-ENG-COMMITTED-STORE-METADATA-CONTRACT',
        'INV-ENG-RUNTIME-SCENE-VALIDITY-BACKSTOP',
        'INV-ENG-PALETTE-RUNTIME-VALUE-OWNER',
        'INV-ENG-RUNTIME-NODE-VALUE-OWNERS',
        'INV-ENG-MODEL-ARCHITECTURE-BOUNDARY',
      ],
      'store_and_commit_path': <String>[
        'INV-ENG-WRITE-ONLY-MUTATION',
        'INV-ENG-CONTROLLER-NO-FULL-VIEW-RENDER-STATE',
        'INV-ENG-TXN-WRITER-LIFETIME',
        'INV-ENG-TXN-ATOMIC-COMMIT',
        'INV-ENG-COMMITTED-SELECTION-REVISION-ALIGNMENT',
        'INV-ENG-TXN-FINALIZED-BEFORE-COMMIT-PLAN',
        'INV-ENG-TXN-COPY-ON-WRITE',
        'INV-ENG-WRITE-PROTOCOL',
        'INV-ENG-SIGNALS-AFTER-COMMIT',
        'INV-ENG-WRITE-NUMERIC-GUARDS',
        'INV-ENG-DISPOSE-FAIL-FAST',
        'INV-ENG-CONTROLLER-COMMIT-RUNTIME-BOUNDARY',
        'INV-ENG-SCENE-WRITE-TXN-ADAPTER-BOUNDARY',
        'INV-ENG-CLEAR-SCENE-RESULT-REMOVED-NODE-IDS-IMMUTABLE',
        'INV-ENG-COMMITTED-READ-SIDE-HERMETICITY',
      ],
      'composition_root_and_facade': <String>[
        'INV-G-LAYER-DAG',
        'INV-ENG-CONTROLLER-NO-FULL-VIEW-RENDER-STATE',
        'INV-ENG-CONTROLLER-COMMIT-RUNTIME-BOUNDARY',
        'INV-ENG-INTERACTIVE-ARCHITECTURE-BOUNDARY',
        'INV-ENG-VIEW-POINTER-SEMANTICS-BOUNDARY',
        'INV-ENG-VIEW-RENDER-READ-STATE-BOUNDARY',
      ],
      'interaction_runtime': <String>[
        'INV-ENG-INTERACTIVE-ASYNC-DELIVERY',
        'INV-ENG-INTERACTIVE-PUBLIC-LISTENER-REPAINT-INDEPENDENCE',
        'INV-ENG-INTERACTIVE-HANDLE-POINTER-NON-REENTRANT',
        'INV-ENG-INTERACTIVE-POINTER-FINITE',
        'INV-ENG-POINTER-SETTINGS-VALIDATION',
        'INV-ENG-INTERACTIVE-SINGLE-ACTIVE-POINTER',
        'INV-ENG-INTERACTIVE-GESTURE-BUFFER-SOFT-CAP',
        'INV-ENG-INTERACTIVE-CANCEL-STATE-RESET',
        'INV-ENG-INTERACTIVE-INTERRUPTION-SEMANTICS',
        'INV-ENG-INTERACTIVE-PREVIEW-COMMIT-ON-UP',
        'INV-ENG-INTERACTIVE-RESOLVER-PURITY',
        'INV-ENG-INTERACTIVE-MOVE-COMMIT-RESOLVER-NON-REENTRANT',
        'INV-ENG-INTERACTIVE-PUBLIC-MUTATION-EXCLUSIVITY',
        'INV-ENG-INTERACTIVE-ARCHITECTURE-BOUNDARY',
        'INV-ENG-INTERACTIVE-MUTATION-BOUNDARY',
        'INV-ENG-INTERACTIVE-POINTER-SESSION-LIFECYCLE',
        'INV-ENG-INTERACTIVE-DRAW-STYLE-SNAPSHOT',
        'INV-ENG-TIMESTAMP-MS-MONOTONIC',
        'INV-ENG-COMMITTED-READ-SIDE-HERMETICITY',
        'INV-ENG-PREPARED-REPLACE-SCENE-BOUNDARY-HERMETICITY',
      ],
      'mutation_gateway': <String>[
        'INV-ENG-WRITE-ONLY-MUTATION',
        'INV-ENG-PREPARED-REPLACE-SCENE-BOUNDARY-HERMETICITY',
        'INV-ENG-INTERACTIVE-RESOLVER-PURITY',
        'INV-ENG-INTERACTIVE-PUBLIC-MUTATION-EXCLUSIVITY',
        'INV-ENG-INTERACTIVE-MUTATION-BOUNDARY',
        'INV-ENG-COMMITTED-READ-SIDE-HERMETICITY',
      ],
      'view_runtime_and_pointer_hosting': <String>[
        'INV-ENG-CONTROLLER-NO-FULL-VIEW-RENDER-STATE',
        'INV-ENG-VIEW-POINTER-SLOT-LIFECYCLE',
        'INV-ENG-VIEW-ACTIVE-POINTER-GATE',
        'INV-ENG-VIEW-POINTER-SETTINGS-LIVE-APPLY',
        'INV-ENG-INTERACTIVE-POINTER-SESSION-LIFECYCLE',
        'INV-ENG-VIEW-RUNTIME-HOST-DEBUG-PROBES',
        'INV-ENG-VIEW-POINTER-SESSION-DETACH',
        'INV-ENG-VIEW-POINTER-SEMANTICS-BOUNDARY',
        'INV-ENG-VIEW-RENDER-READ-STATE-BOUNDARY',
        'INV-ENG-VIEW-RENDER-SURFACE-DEBUG-PROBES',
      ],
      'render_frame_admission_and_caches': <String>[
        'INV-ENG-EPOCH-INVALIDATION',
        'INV-ENG-PERFORMANCE-PROOF-CONTOUR',
        'INV-ENG-RENDER-HIT-BOUNDS-PARITY',
        'INV-ENG-RENDER-GEOMETRY-KEY-STABLE',
        'INV-ENG-RENDER-CACHE-SCAN-RESISTANT',
        'INV-ENG-SELECTION-BOUNDED-COMPOSITING',
        'INV-ENG-GRID-BOUNDED-ITERATION',
        'INV-ENG-SCENE-PAINTER-FRAME-RESOLUTION',
        'INV-ENG-PAINT-ADMISSION-BOUNDS-SOURCE',
        'INV-ENG-SCENE-PAINTER-MODULE-BOUNDARY',
      ],
      'diagnostics_performance_and_debug_surfaces': <String>[
        'INV-ENG-PERFORMANCE-PROOF-CONTOUR',
        'INV-ENG-VIEW-RUNTIME-HOST-DEBUG-PROBES',
        'INV-ENG-VIEW-RENDER-SURFACE-DEBUG-PROBES',
      ],
    };

void main() {
  group('check_architecture_atlas', () {
    test('accepts a complete fixture atlas', () async {
      final sandbox = await _createAtlasSandbox();
      addTearDown(() => sandbox.deleteSync(recursive: true));
      _writeCompleteAtlas(sandbox);

      final result = await _runChecker(sandbox);

      expect(result.exitCode, 0, reason: result.stderr.toString());
      expect(
        result.stdout,
        contains(
          'Architecture atlas OK (13 architecture families, 4 proof families).',
        ),
      );
    });

    test('preserves explicit docs root when repo root appears later', () async {
      final sandbox = await _createAtlasSandbox();
      final alternateRepoRoot = await Directory.systemTemp.createTemp(
        'architecture_atlas_repo_root_',
      );
      addTearDown(() => sandbox.deleteSync(recursive: true));
      addTearDown(() => alternateRepoRoot.deleteSync(recursive: true));
      _writeCompleteAtlas(sandbox);
      _writeCommandStubs(alternateRepoRoot);

      final result = await _runCheckerWithArgs(sandbox, <String>[
        '--docs-root=${sandbox.path}/docs',
        '--repo-root=${alternateRepoRoot.path}',
      ]);

      expect(result.exitCode, 0, reason: result.stderr.toString());
    });

    test(
      'accepts a known issue status only when it links a KI entry',
      () async {
        final sandbox = await _createAtlasSandbox();
        addTearDown(() => sandbox.deleteSync(recursive: true));
        _writeCompleteAtlas(
          sandbox,
          architectureStatusOverrides: const <String, String>{
            'public_package_boundary':
                '`known issue`\n\n'
                'Tracked by [KI-2](../../KNOWN_ISSUES.md#ki-2).',
          },
        );

        final result = await _runChecker(sandbox);

        expect(result.exitCode, 0, reason: result.stderr.toString());
      },
    );

    test('rejects plain-text known issue references', () async {
      final sandbox = await _createAtlasSandbox();
      addTearDown(() => sandbox.deleteSync(recursive: true));
      _writeCompleteAtlas(
        sandbox,
        architectureStatusOverrides: const <String, String>{
          'public_package_boundary':
              '`known issue`\n\n'
              'Tracked by KI-2 in KNOWN_ISSUES.md.',
        },
      );

      final result = await _runChecker(sandbox);

      expect(result.exitCode, isNot(0));
      expect(
        result.stderr,
        contains('status `known issue` must link a KI id to KNOWN_ISSUES.md'),
      );
    });

    test('rejects missing family docs', () async {
      final sandbox = await _createAtlasSandbox();
      addTearDown(() => sandbox.deleteSync(recursive: true));
      _writeCompleteAtlas(sandbox);
      File(
        '${sandbox.path}/docs/architecture/families/public_package_boundary.md',
      ).deleteSync();

      final result = await _runChecker(sandbox);

      expect(result.exitCode, isNot(0));
      _expectFailure(
        result,
        'Missing architecture family `public_package_boundary`',
      );
    });

    test('rejects missing, duplicate, and unknown family ids', () async {
      final sandbox = await _createAtlasSandbox();
      addTearDown(() => sandbox.deleteSync(recursive: true));
      _writeCompleteAtlas(sandbox);
      _writeArchitectureOverview(sandbox, <String>[
        ..._architectureFamilyIds.skip(1),
        'composition_root_and_facade',
        'unknown_family',
      ]);

      final result = await _runChecker(sandbox);

      _expectFailure(
        result,
        'missing expected family `public_package_boundary`',
      );
      expect(
        result.stderr,
        contains('duplicates family id `composition_root_and_facade`'),
      );
      expect(
        result.stderr,
        contains('contains unknown family id `unknown_family`'),
      );
    });

    test('rejects missing and orphan evidence artifacts', () async {
      final sandbox = await _createAtlasSandbox();
      addTearDown(() => sandbox.deleteSync(recursive: true));
      _writeCompleteAtlas(sandbox);
      File(
        '${sandbox.path}/docs/architecture/evidence/runtime_trace.json',
      ).deleteSync();
      writeSandboxFile(
        sandbox,
        'docs/architecture/evidence/orphan.json',
        '{"orphan": true}',
      );

      final result = await _runChecker(sandbox);

      _expectFailure(
        result,
        'links missing evidence `../evidence/runtime_trace.json`',
      );
      expect(
        result.stderr,
        contains(
          'architecture/evidence/orphan.json is committed evidence but is not referenced',
        ),
      );
    });

    test('rejects missing proof family links for engine families', () async {
      final sandbox = await _createAtlasSandbox();
      addTearDown(() => sandbox.deleteSync(recursive: true));
      _writeCompleteAtlas(
        sandbox,
        architectureBodyOverrides: const <String, String>{
          'public_package_boundary': _familyBodyWithoutProofLinks,
        },
      );

      final result = await _runChecker(sandbox);

      expect(result.exitCode, isNot(0));
      _expectFailure(
        result,
        'architecture/families/public_package_boundary.md is missing `## Proof Links`',
      );
    });

    test('rejects unknown invariant ids', () async {
      final sandbox = await _createAtlasSandbox();
      addTearDown(() => sandbox.deleteSync(recursive: true));
      _writeCompleteAtlas(
        sandbox,
        architectureExtraProofLinks: const <String, String>{
          'public_package_boundary': '- Invariant: `INV-ENG-NOT-REAL`',
        },
      );

      final result = await _runChecker(sandbox);

      expect(result.exitCode, isNot(0));
      _expectFailure(result, 'references unknown invariant `INV-ENG-NOT-REAL`');
    });

    test('rejects missing expected family invariant ids', () async {
      final sandbox = await _createAtlasSandbox();
      addTearDown(() => sandbox.deleteSync(recursive: true));
      _writeCompleteAtlas(
        sandbox,
        architectureBodyOverrides: <String, String>{
          'serialization_and_schema': _architectureFamilyBody(
            id: 'serialization_and_schema',
            status: '`locked`',
            command:
                'dart run tool/lsp_trace_symbol.dart lib/src/view/runtime.dart SceneViewRuntime --json-out=docs/architecture/evidence/runtime_trace.json --mermaid-out=docs/architecture/evidence/runtime_trace.md',
            invariantIds:
                _architectureFamilyInvariantIds['serialization_and_schema']!
                    .where((id) => id != 'INV-SER-JSON-NUMERIC-VALIDATION'),
          ),
        },
      );

      final result = await _runChecker(sandbox);

      expect(result.exitCode, isNot(0));
      _expectFailure(
        result,
        'serialization_and_schema.md is missing expected invariant links: '
        '`INV-SER-JSON-NUMERIC-VALIDATION`',
      );
    });

    test('rejects missing command files', () async {
      final sandbox = await _createAtlasSandbox();
      addTearDown(() => sandbox.deleteSync(recursive: true));
      _writeCompleteAtlas(sandbox);
      File('${sandbox.path}/tool/lsp_trace_symbol.dart').deleteSync();

      final result = await _runChecker(sandbox);

      expect(result.exitCode, isNot(0));
      _expectFailure(
        result,
        'references missing command `tool/lsp_trace_symbol.dart`',
      );
    });

    test('rejects unsupported generated evidence commands', () async {
      final sandbox = await _createAtlasSandbox();
      addTearDown(() => sandbox.deleteSync(recursive: true));
      _writeCompleteAtlas(
        sandbox,
        architectureCommandOverrides: const <String, String>{
          'public_package_boundary':
              'dart run tool/check_guardrails.dart --json-out=docs/architecture/evidence/runtime_trace.json',
        },
      );

      final result = await _runChecker(sandbox);

      expect(result.exitCode, isNot(0));
      _expectFailure(
        result,
        'uses unsupported generated evidence command `tool/check_guardrails.dart`',
      );
    });

    test('rejects flutter test commands for tool tests', () async {
      final sandbox = await _createAtlasSandbox();
      addTearDown(() => sandbox.deleteSync(recursive: true));
      _writeCompleteAtlas(
        sandbox,
        architectureCommandOverrides: const <String, String>{
          'diagnostics_performance_and_debug_surfaces':
              'dart run tool/check_verification_contract.dart`\n'
              '- Tool tests: `flutter test --no-pub test/tool',
        },
      );

      final result = await _runChecker(sandbox);

      expect(result.exitCode, isNot(0));
      _expectFailure(
        result,
        'must run test/tool/** through `dart run tool/run_tool_tests.dart`',
      );
    });

    test('rejects stale generated evidence artifacts', () async {
      final sandbox = await _createAtlasSandbox();
      addTearDown(() => sandbox.deleteSync(recursive: true));
      _writeCompleteAtlas(sandbox);
      writeSandboxFile(
        sandbox,
        'docs/proof_architecture/evidence/proof_inventory.json',
        '{"proof": false}\n',
      );
      writeSandboxFile(
        sandbox,
        'docs/architecture/evidence/runtime_trace.md',
        'flowchart stale\n',
      );

      final result = await _runChecker(sandbox);

      _expectFailure(
        result,
        'proof_architecture/evidence/proof_inventory.json is stale',
      );
      expect(
        result.stderr,
        contains('architecture/evidence/runtime_trace.md is stale'),
      );
    });

    test(
      'rejects unknown statuses and unlinked known issue statuses',
      () async {
        final sandbox = await _createAtlasSandbox();
        addTearDown(() => sandbox.deleteSync(recursive: true));
        _writeCompleteAtlas(
          sandbox,
          architectureStatusOverrides: const <String, String>{
            'public_package_boundary': '`provisional`',
            'composition_root_and_facade': '`known issue`',
          },
        );

        final result = await _runChecker(sandbox);

        expect(result.exitCode, isNot(0));
        _expectFailure(result, 'must declare exactly one status');
        expect(
          result.stderr,
          contains('status `known issue` must link a KI id to KNOWN_ISSUES.md'),
        );
      },
    );
  });
}

Future<Directory> _createAtlasSandbox() async {
  final sandbox = await createToolSandbox(
    tempPrefix: 'architecture_atlas_tool_test_',
    toolFiles: const <String>[
      'tool/check_architecture_atlas.dart',
      'tool/invariant_registry.dart',
    ],
    includeAnalyzer: false,
  );

  _writeCommandStubs(sandbox);

  return sandbox;
}

void _writeCommandStubs(Directory sandbox) {
  writeSandboxFile(sandbox, 'tool/lsp_trace_symbol.dart', _generatedToolStub);
  writeSandboxFile(
    sandbox,
    'tool/trace_export_namespace.dart',
    _generatedToolStub,
  );
  writeSandboxFile(
    sandbox,
    'tool/trace_proof_inventory.dart',
    _generatedToolStub,
  );
  writeSandboxFile(sandbox, 'tool/check_guardrails.dart', 'void main() {}\n');
  writeSandboxFile(
    sandbox,
    'tool/audit_bridge_surfaces.dart',
    'void main() {}\n',
  );
}

Future<ProcessResult> _runChecker(Directory sandbox) {
  return _runCheckerWithArgs(sandbox, <String>[
    '--docs-root=${sandbox.path}/docs',
  ]);
}

Future<ProcessResult> _runCheckerWithArgs(
  Directory sandbox,
  List<String> args,
) {
  return runSandboxTool(sandbox, 'check_architecture_atlas.dart', args: args);
}

void _expectFailure(ProcessResult result, String message) {
  expect(result.exitCode, isNot(0), reason: result.stdout.toString());
  expect(result.stderr, contains(message));
}

void _writeCompleteAtlas(
  Directory sandbox, {
  Map<String, String> architectureStatusOverrides = const <String, String>{},
  Map<String, String> architectureBodyOverrides = const <String, String>{},
  Map<String, String> architectureCommandOverrides = const <String, String>{},
  Map<String, String> architectureExtraProofLinks = const <String, String>{},
}) {
  writeSandboxFile(
    sandbox,
    'docs/ARCHITECTURE_ATLAS.md',
    '# Architecture Atlas\n\n'
        '- [Engine architecture](architecture/overview.md)\n'
        '- [Proof architecture](proof_architecture/overview.md)\n',
  );
  _writeArchitectureOverview(sandbox, _architectureFamilyIds);
  _writeProofOverview(sandbox, _proofFamilyIds);
  writeSandboxFile(
    sandbox,
    'docs/architecture/execution_flows.md',
    '# Execution Flows\n\n'
        '## Flow Registry\n\n'
        '- Runtime trace: [runtime_trace.md](evidence/runtime_trace.md)\n'
        '- Command: `dart run tool/lsp_trace_symbol.dart lib/src/view/runtime.dart SceneViewRuntime --json-out=docs/architecture/evidence/runtime_trace.json --mermaid-out=docs/architecture/evidence/runtime_trace.md`\n',
  );
  writeSandboxFile(
    sandbox,
    'docs/proof_architecture/proof_flows.md',
    '# Proof Flows\n\n'
        '## Flow Registry\n\n'
        '- Proof inventory: [proof_inventory.md](evidence/proof_inventory.md)\n'
        '- Command: `dart run tool/trace_proof_inventory.dart --json-out=docs/proof_architecture/evidence/proof_inventory.json --md-out=docs/proof_architecture/evidence/proof_inventory.md`\n',
  );

  for (final id in _architectureFamilyIds) {
    final command =
        architectureCommandOverrides[id] ??
        'dart run tool/lsp_trace_symbol.dart lib/src/view/runtime.dart SceneViewRuntime --json-out=docs/architecture/evidence/runtime_trace.json --mermaid-out=docs/architecture/evidence/runtime_trace.md';
    final status = architectureStatusOverrides[id] ?? '`locked`';
    final body =
        architectureBodyOverrides[id] ??
        _architectureFamilyBody(
          id: id,
          status: status,
          command: command,
          extraProofLinks: architectureExtraProofLinks[id],
        );
    writeSandboxFile(
      sandbox,
      'docs/architecture/families/$id.md',
      '# $id\n\n$body',
    );
  }

  for (final id in _proofFamilyIds) {
    writeSandboxFile(
      sandbox,
      'docs/proof_architecture/families/$id.md',
      '# $id\n\n${_proofFamilyBody()}',
    );
  }

  writeSandboxFile(
    sandbox,
    'docs/architecture/evidence/runtime_trace.json',
    '{"trace": true}\n',
  );
  writeSandboxFile(
    sandbox,
    'docs/architecture/evidence/runtime_trace.md',
    'flowchart TD\n',
  );
  writeSandboxFile(
    sandbox,
    'docs/proof_architecture/evidence/proof_inventory.json',
    '{"proof": true}\n',
  );
  writeSandboxFile(
    sandbox,
    'docs/proof_architecture/evidence/proof_inventory.md',
    '# Proof inventory\n',
  );
}

void _writeArchitectureOverview(Directory sandbox, List<String> ids) {
  writeSandboxFile(
    sandbox,
    'docs/architecture/overview.md',
    '# Engine Architecture\n\n'
        '## Owner Family Registry\n\n'
        '| Family id | Family | Status |\n'
        '| --- | --- | --- |\n'
        '${ids.map((id) => '| `$id` | [Family](families/$id.md) | `locked` |').join('\n')}\n',
  );
}

void _writeProofOverview(Directory sandbox, List<String> ids) {
  writeSandboxFile(
    sandbox,
    'docs/proof_architecture/overview.md',
    '# Proof Architecture\n\n'
        '## Proof Family Registry\n\n'
        '| Family id | Family | Status |\n'
        '| --- | --- | --- |\n'
        '${ids.map((id) => '| `$id` | [Family](families/$id.md) | `locked` |').join('\n')}\n',
  );
}

String _architectureFamilyBody({
  required String id,
  required String status,
  required String command,
  String? extraProofLinks,
  Iterable<String>? invariantIds,
}) {
  final invariantLines = (invariantIds ?? _architectureFamilyInvariantIds[id]!)
      .map((invariantId) => '- Invariant: `$invariantId`')
      .join('\n');
  return '## Purpose\n\n'
      'Fixture purpose.\n\n'
      '## Target Rules\n\n'
      '- Fixture target rule.\n\n'
      '## Owners\n\n'
      '- Fixture owner.\n\n'
      '## Forbidden Shapes\n\n'
      '- Fixture forbidden shape.\n\n'
      '## Mechanical Evidence\n\n'
      '- Runtime evidence: [runtime_trace.json](../evidence/runtime_trace.json)\n'
      '- Runtime diagram: [runtime_trace.md](../evidence/runtime_trace.md)\n'
      '- Command: `$command`\n\n'
      '## Proof Links\n\n'
      '- Proof family: [public entrypoint](../../proof_architecture/families/public_entrypoint_and_signature_proof.md)\n'
      '$invariantLines\n'
      '- Guardrail: `dart run tool/check_guardrails.dart`\n'
      '${extraProofLinks == null ? '' : '$extraProofLinks\n'}'
      '\n'
      '## Status\n\n'
      '$status\n\n'
      '## Update Triggers\n\n'
      '- Fixture trigger.\n';
}

String _proofFamilyBody() {
  return '## Purpose\n\n'
      'Fixture purpose.\n\n'
      '## Target Rules\n\n'
      '- Fixture target rule.\n\n'
      '## Owners\n\n'
      '- Fixture owner.\n\n'
      '## Forbidden Shapes\n\n'
      '- Fixture forbidden shape.\n\n'
      '## Mechanical Evidence\n\n'
      '- Proof inventory: [proof_inventory.json](../evidence/proof_inventory.json)\n'
      '- Proof inventory summary: [proof_inventory.md](../evidence/proof_inventory.md)\n'
      '- Command: `dart run tool/trace_proof_inventory.dart --json-out=docs/proof_architecture/evidence/proof_inventory.json --md-out=docs/proof_architecture/evidence/proof_inventory.md`\n\n'
      '## Status\n\n'
      '`locked`\n\n'
      '## Update Triggers\n\n'
      '- Fixture trigger.\n';
}

const String _familyBodyWithoutProofLinks =
    '## Purpose\n\n'
    'Fixture purpose.\n\n'
    '## Target Rules\n\n'
    '- Fixture target rule.\n\n'
    '## Owners\n\n'
    '- Fixture owner.\n\n'
    '## Forbidden Shapes\n\n'
    '- Fixture forbidden shape.\n\n'
    '## Mechanical Evidence\n\n'
    '- Runtime evidence: [runtime_trace.json](../evidence/runtime_trace.json)\n'
    '- Command: `dart run tool/lsp_trace_symbol.dart lib/src/view/runtime.dart SceneViewRuntime --json-out=docs/architecture/evidence/runtime_trace.json --mermaid-out=docs/architecture/evidence/runtime_trace.md`\n\n'
    '## Status\n\n'
    '`locked`\n\n'
    '## Update Triggers\n\n'
    '- Fixture trigger.\n';

const String _generatedToolStub = r'''
import 'dart:io';

void main(List<String> args) {
  for (final arg in args) {
    if (arg.startsWith('--json-out=')) {
      final path = arg.substring('--json-out='.length);
      final content = path.contains('proof_inventory')
          ? '{"proof": true}\n'
          : '{"trace": true}\n';
      _write(path, content);
    }
    if (arg.startsWith('--md-out=')) {
      _write(arg.substring('--md-out='.length), '# Proof inventory\n');
    }
    if (arg.startsWith('--mermaid-out=')) {
      _write(arg.substring('--mermaid-out='.length), 'flowchart TD\n');
    }
  }
}

void _write(String path, String content) {
  final file = File(path);
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(content);
}
''';
