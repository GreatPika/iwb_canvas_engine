@Tags(['tool'])
library;

import 'dart:io';

import 'package:test/test.dart';

import 'support/tool_process_test_support.dart';

void main() {
  group('tool/check_invariant_coverage.dart', () {
    test('invariant registry uses required/regression proof roles', () {
      final content = File(
        '${Directory.current.path}/tool/invariant_registry.dart',
      ).readAsStringSync();

      expect(content, contains('requiredProofs'));
      expect(content, contains('regressionProofs'));
      expect(content, isNot(contains('primaryProof')));
      expect(content, isNot(contains('toolProof')));
    });

    test('passes when required proof points to matching marker', () async {
      final sandbox = await _createSandbox();
      try {
        _writeRegistry(sandbox, '''
const List<Invariant> invariants = <Invariant>[
  Invariant(
    id: 'INV-ENG-SAMPLE-CONTRACT',
    scope: 'sample',
    title: 'sample invariant',
    requiredProofs: <RequiredProof>[
      RequiredProof(path: 'test/core/sample_test.dart', stepId: 'scope_core'),
    ],
  ),
];
''');
        writeSandboxFile(sandbox, 'test/core/sample_test.dart', '''
void main() {
  ${_invMarker('INV-ENG-SAMPLE-CONTRACT')}
}
''');

        final result = await runSandboxTool(
          sandbox,
          'check_invariant_coverage.dart',
        );

        expect(result.exitCode, 0, reason: result.stderr.toString());
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    });

    test('passes when required proof uses the example scope surface', () async {
      final sandbox = await _createSandbox();
      try {
        _writeRegistry(sandbox, '''
const List<Invariant> invariants = <Invariant>[
  Invariant(
    id: 'INV-ENG-EXAMPLE-CONTRACT',
    scope: 'sample',
    title: 'example invariant',
    requiredProofs: <RequiredProof>[
      RequiredProof(
        path: 'example/test/example_surface_test.dart',
        stepId: 'scope_example',
      ),
    ],
  ),
];
''');
        writeSandboxFile(sandbox, 'example/test/example_surface_test.dart', '''
void main() {
  ${_invMarker('INV-ENG-EXAMPLE-CONTRACT')}
}
''');

        final result = await runSandboxTool(
          sandbox,
          'check_invariant_coverage.dart',
        );

        expect(result.exitCode, 0, reason: result.stderr.toString());
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    });

    test(
      'passes when required tool proof and regression proof both match markers',
      () async {
        final sandbox = await _createSandbox();
        try {
          _writeRegistry(sandbox, '''
const List<Invariant> invariants = <Invariant>[
  Invariant(
    id: 'INV-ENG-GUARDRAILS-CONTRACT',
    scope: 'sample',
    title: 'sample guardrails invariant',
    requiredProofs: <RequiredProof>[
      RequiredProof(path: 'tool/check_guardrails.dart', stepId: 'guardrails'),
    ],
    regressionProofs: <RegressionProof>[
      RegressionProof(path: 'test/tool/guardrails/guardrails_sample_tool_test.dart'),
    ],
  ),
];
''');
          writeSandboxFile(sandbox, 'tool/check_guardrails.dart', '''
void main() {
  ${_invMarker('INV-ENG-GUARDRAILS-CONTRACT')}
}
''');
          writeSandboxFile(
            sandbox,
            'test/tool/guardrails/guardrails_sample_tool_test.dart',
            '''
void main() {
  ${_invMarker('INV-ENG-GUARDRAILS-CONTRACT')}
}
''',
          );

          final result = await runSandboxTool(
            sandbox,
            'check_invariant_coverage.dart',
          );

          expect(result.exitCode, 0, reason: result.stderr.toString());
        } finally {
          sandbox.deleteSync(recursive: true);
        }
      },
    );

    test('rejects required proof step outside required_code_change', () async {
      final sandbox = await _createSandbox();
      try {
        _writeRegistry(sandbox, '''
const List<Invariant> invariants = <Invariant>[
  Invariant(
    id: 'INV-ENG-SAMPLE-CONTRACT',
    scope: 'sample',
    title: 'sample invariant',
    requiredProofs: <RequiredProof>[
      RequiredProof(path: 'test/core/sample_test.dart', stepId: 'tool_tests'),
    ],
  ),
];
''');
        writeSandboxFile(sandbox, 'test/core/sample_test.dart', '''
void main() {
  ${_invMarker('INV-ENG-SAMPLE-CONTRACT')}
}
''');

        final result = await runSandboxTool(
          sandbox,
          'check_invariant_coverage.dart',
        );

        expect(result.exitCode, isNonZero);
        expect(
          result.stderr.toString(),
          contains(
            'INV-ENG-SAMPLE-CONTRACT requiredProofs[0].stepId must be reachable '
            'from required_code_change: tool_tests',
          ),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    });

    test(
      'rejects required proof path that is not reachable by its step',
      () async {
        final sandbox = await _createSandbox();
        try {
          _writeRegistry(sandbox, '''
const List<Invariant> invariants = <Invariant>[
  Invariant(
    id: 'INV-ENG-SAMPLE-CONTRACT',
    scope: 'sample',
    title: 'sample invariant',
    requiredProofs: <RequiredProof>[
      RequiredProof(
        path: 'test/public_api/sample_test.dart',
        stepId: 'scope_core',
      ),
    ],
  ),
];
''');
          writeSandboxFile(sandbox, 'test/public_api/sample_test.dart', '''
void main() {
  ${_invMarker('INV-ENG-SAMPLE-CONTRACT')}
}
''');

          final result = await runSandboxTool(
            sandbox,
            'check_invariant_coverage.dart',
          );

          expect(result.exitCode, isNonZero);
          expect(
            result.stderr.toString(),
            contains(
              'INV-ENG-SAMPLE-CONTRACT requiredProofs[0] must be reachable by '
              'scope_core: test/public_api/sample_test.dart',
            ),
          );
        } finally {
          sandbox.deleteSync(recursive: true);
        }
      },
    );

    test('rejects unknown required proof step ids', () async {
      final sandbox = await _createSandbox();
      try {
        _writeRegistry(sandbox, '''
const List<Invariant> invariants = <Invariant>[
  Invariant(
    id: 'INV-ENG-SAMPLE-CONTRACT',
    scope: 'sample',
    title: 'sample invariant',
    requiredProofs: <RequiredProof>[
      RequiredProof(path: 'test/core/sample_test.dart', stepId: 'unknown_step'),
    ],
  ),
];
''');
        writeSandboxFile(sandbox, 'test/core/sample_test.dart', '''
void main() {
  ${_invMarker('INV-ENG-SAMPLE-CONTRACT')}
}
''');

        final result = await runSandboxTool(
          sandbox,
          'check_invariant_coverage.dart',
        );

        expect(result.exitCode, isNonZero);
        expect(
          result.stderr.toString(),
          contains(
            'INV-ENG-SAMPLE-CONTRACT requiredProofs[0].stepId must reference a known verification step: unknown_step',
          ),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    });

    test('rejects missing explicit marker in regression proof file', () async {
      final sandbox = await _createSandbox();
      try {
        _writeRegistry(sandbox, '''
const List<Invariant> invariants = <Invariant>[
  Invariant(
    id: 'INV-ENG-GUARDRAILS-CONTRACT',
    scope: 'sample',
    title: 'sample guardrails invariant',
    requiredProofs: <RequiredProof>[
      RequiredProof(path: 'tool/check_guardrails.dart', stepId: 'guardrails'),
    ],
    regressionProofs: <RegressionProof>[
      RegressionProof(path: 'test/tool/guardrails/guardrails_sample_tool_test.dart'),
    ],
  ),
];
''');
        writeSandboxFile(sandbox, 'tool/check_guardrails.dart', '''
void main() {
  ${_invMarker('INV-ENG-GUARDRAILS-CONTRACT')}
}
''');
        writeSandboxFile(
          sandbox,
          'test/tool/guardrails/guardrails_sample_tool_test.dart',
          'void main() {}\n',
        );

        final result = await runSandboxTool(
          sandbox,
          'check_invariant_coverage.dart',
        );

        expect(result.exitCode, isNonZero);
        expect(
          result.stderr.toString(),
          contains(
            'INV-ENG-GUARDRAILS-CONTRACT is missing explicit proof marker in '
            'regressionProofs[0] '
            'test/tool/guardrails/guardrails_sample_tool_test.dart',
          ),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    });

    test(
      'rejects overclaimed guardrails marker outside declared contour',
      () async {
        final sandbox = await _createSandbox();
        try {
          _writeRegistry(sandbox, '''
const List<Invariant> invariants = <Invariant>[
  Invariant(
    id: 'INV-ENG-GUARDRAILS-CONTRACT',
    scope: 'sample',
    title: 'sample guardrails invariant',
    requiredProofs: <RequiredProof>[
      RequiredProof(path: 'tool/check_guardrails.dart', stepId: 'guardrails'),
    ],
    regressionProofs: <RegressionProof>[
      RegressionProof(path: 'test/tool/guardrails/guardrails_sample_tool_test.dart'),
    ],
  ),
  Invariant(
    id: 'INV-ENG-OTHER-CONTRACT',
    scope: 'sample',
    title: 'other invariant',
    requiredProofs: <RequiredProof>[
      RequiredProof(path: 'test/core/other_test.dart', stepId: 'scope_core'),
    ],
  ),
];
''');
          writeSandboxFile(sandbox, 'tool/check_guardrails.dart', '''
void main() {
  ${_invMarker('INV-ENG-GUARDRAILS-CONTRACT')}
  ${_invMarker('INV-ENG-OTHER-CONTRACT')}
}
''');
          writeSandboxFile(sandbox, 'test/core/other_test.dart', '''
void main() {
  ${_invMarker('INV-ENG-OTHER-CONTRACT')}
}
''');
          writeSandboxFile(
            sandbox,
            'test/tool/guardrails/guardrails_sample_tool_test.dart',
            '''
void main() {
  ${_invMarker('INV-ENG-GUARDRAILS-CONTRACT')}
}
''',
          );

          final result = await runSandboxTool(
            sandbox,
            'check_invariant_coverage.dart',
          );

          expect(result.exitCode, isNonZero);
          expect(
            result.stderr.toString(),
            contains(
              'tool/check_guardrails.dart overclaims guardrails invariant '
              '${_markerText('INV-ENG-OTHER-CONTRACT')}',
            ),
          );
        } finally {
          sandbox.deleteSync(recursive: true);
        }
      },
    );

    test('rejects invalid required and regression proof path shapes', () async {
      final sandbox = await _createSandbox();
      try {
        _writeRegistry(sandbox, '''
const List<Invariant> invariants = <Invariant>[
  Invariant(
    id: 'INV-ENG-SAMPLE-CONTRACT',
    scope: 'sample',
    title: 'sample invariant',
    requiredProofs: <RequiredProof>[
      RequiredProof(path: 'tool/src/check_sample.dart', stepId: 'guardrails'),
      RequiredProof(path: 'lib/src/sample.dart', stepId: 'scope_core'),
    ],
    regressionProofs: <RegressionProof>[
      RegressionProof(path: 'tool/sample_test.dart'),
    ],
  ),
];
''');

        final result = await runSandboxTool(
          sandbox,
          'check_invariant_coverage.dart',
        );

        expect(result.exitCode, isNonZero);
        expect(
          result.stderr.toString(),
          contains(
            'INV-ENG-SAMPLE-CONTRACT requiredProofs[0].path must match '
            'top-level tool/*.dart: tool/src/check_sample.dart',
          ),
        );
        expect(
          result.stderr.toString(),
          contains(
            'INV-ENG-SAMPLE-CONTRACT requiredProofs[1].path must match '
            'test/**/*_test.dart or top-level tool/*.dart: lib/src/sample.dart',
          ),
        );
        expect(
          result.stderr.toString(),
          contains(
            'INV-ENG-SAMPLE-CONTRACT regressionProofs[0].path must match '
            'test/**/*_test.dart: tool/sample_test.dart',
          ),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    });
  });
}

Future<Directory> _createSandbox() {
  return createToolSandbox(
    tempPrefix: 'iwb_canvas_engine_invariant_coverage_tool_test_',
    toolFiles: const <String>[
      'tool/check_invariant_coverage.dart',
      'tool/invariant_registry.dart',
      'tool/src/verification_contract',
    ],
    includeAnalyzer: false,
  );
}

void _writeRegistry(Directory sandbox, String invariantsBody) {
  writeSandboxFile(sandbox, 'tool/invariant_registry.dart', '''
library;

class Invariant {
  const Invariant({
    required this.id,
    required this.scope,
    required this.title,
    required this.requiredProofs,
    this.regressionProofs = const <RegressionProof>[],
  });

  final String id;
  final String scope;
  final String title;
  final List<RequiredProof> requiredProofs;
  final List<RegressionProof> regressionProofs;
}

class RequiredProof {
  const RequiredProof({required this.path, required this.stepId});

  final String path;
  final String stepId;
}

class RegressionProof {
  const RegressionProof({required this.path});

  final String path;
}

$invariantsBody
''');
}

String _invMarker(String id) => '// INV:$id';

String _markerText(String id) => 'INV:$id';
