@Tags(['tool'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'support/tool_process_test_support.dart';

void main() {
  group('tool/check_invariant_coverage.dart', () {
    test(
      'passes when registry primaryProof points to matching marker',
      () async {
        final sandbox = await _createSandbox();
        try {
          _writeRegistry(sandbox, '''
const List<Invariant> invariants = <Invariant>[
  Invariant(
    id: 'INV-ENG-SAMPLE-CONTRACT',
    scope: 'sample',
    title: 'sample invariant',
    primaryProof: PrimaryProof(path: 'test/sample_test.dart'),
  ),
];
''');
          writeSandboxFile(sandbox, 'test/sample_test.dart', '''
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
      },
    );

    test(
      'passes when tool-backed invariant declares primary and tool proofs',
      () async {
        final sandbox = await _createSandbox();
        try {
          _writeRegistry(sandbox, '''
const List<Invariant> invariants = <Invariant>[
  Invariant(
    id: 'INV-ENG-SAMPLE-CONTRACT',
    scope: 'sample',
    title: 'sample invariant',
    primaryProof: PrimaryProof(path: 'test/tool/sample_tool_test.dart'),
    toolProof: ToolProof(
      enforcementPath: 'tool/check_sample.dart',
      regressionPath: 'test/tool/sample_tool_test.dart',
    ),
  ),
];
''');
          writeSandboxFile(sandbox, 'tool/check_sample.dart', '''
void main() {
  ${_invMarker('INV-ENG-SAMPLE-CONTRACT')}
}
''');
          writeSandboxFile(sandbox, 'test/tool/sample_tool_test.dart', '''
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
      },
    );

    test(
      'passes when guardrails claim surfaces exactly match the registry-backed contour',
      () async {
        final sandbox = await _createSandbox();
        try {
          _writeRegistry(sandbox, '''
const List<Invariant> invariants = <Invariant>[
  Invariant(
    id: 'INV-ENG-GUARDRAILS-TOOL',
    scope: 'sample',
    title: 'guardrails tool invariant',
    primaryProof: PrimaryProof(path: 'test/sample_test.dart'),
    toolProof: ToolProof(
      enforcementPath: 'tool/check_guardrails.dart',
      regressionPath: 'test/tool/guardrails/guardrails_sample_tool_test.dart',
    ),
  ),
  Invariant(
    id: 'INV-ENG-GUARDRAILS-PRIMARY',
    scope: 'sample',
    title: 'guardrails primary invariant',
    primaryProof: PrimaryProof(
      path: 'test/tool/guardrails/guardrails_sample_tool_test.dart',
    ),
  ),
];
''');
          writeSandboxFile(sandbox, 'test/sample_test.dart', '''
void main() {
  ${_invMarker('INV-ENG-GUARDRAILS-TOOL')}
}
''');
          writeSandboxFile(sandbox, 'tool/check_guardrails.dart', '''
void main() {
  ${_invMarker('INV-ENG-GUARDRAILS-TOOL')}
}
''');
          writeSandboxFile(
            sandbox,
            'test/tool/guardrails/guardrails_sample_tool_test.dart',
            '''
void main() {
  ${_invMarker('INV-ENG-GUARDRAILS-TOOL')}
  ${_invMarker('INV-ENG-GUARDRAILS-PRIMARY')}
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

    test('rejects overclaimed marker in tool/check_guardrails.dart', () async {
      final sandbox = await _createSandbox();
      try {
        _writeRegistry(sandbox, '''
const List<Invariant> invariants = <Invariant>[
  Invariant(
    id: 'INV-ENG-GUARDRAILS-TOOL',
    scope: 'sample',
    title: 'guardrails tool invariant',
    primaryProof: PrimaryProof(path: 'test/sample_test.dart'),
    toolProof: ToolProof(
      enforcementPath: 'tool/check_guardrails.dart',
      regressionPath: 'test/tool/guardrails/guardrails_sample_tool_test.dart',
    ),
  ),
  Invariant(
    id: 'INV-ENG-NON-GUARDRAILS',
    scope: 'sample',
    title: 'non-guardrails invariant',
    primaryProof: PrimaryProof(path: 'test/other_test.dart'),
  ),
];
''');
        writeSandboxFile(sandbox, 'test/sample_test.dart', '''
void main() {
  ${_invMarker('INV-ENG-GUARDRAILS-TOOL')}
}
''');
        writeSandboxFile(sandbox, 'test/other_test.dart', '''
void main() {
  ${_invMarker('INV-ENG-NON-GUARDRAILS')}
}
''');
        writeSandboxFile(sandbox, 'tool/check_guardrails.dart', '''
void main() {
  ${_invMarker('INV-ENG-GUARDRAILS-TOOL')}
  ${_invMarker('INV-ENG-NON-GUARDRAILS')}
}
''');
        writeSandboxFile(
          sandbox,
          'test/tool/guardrails/guardrails_sample_tool_test.dart',
          '''
void main() {
  ${_invMarker('INV-ENG-GUARDRAILS-TOOL')}
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
            '${_markerText('INV-ENG-NON-GUARDRAILS')}',
          ),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    });

    test(
      'rejects overclaimed marker in guardrails regression test file',
      () async {
        final sandbox = await _createSandbox();
        try {
          _writeRegistry(sandbox, '''
const List<Invariant> invariants = <Invariant>[
  Invariant(
    id: 'INV-ENG-GUARDRAILS-TOOL',
    scope: 'sample',
    title: 'guardrails tool invariant',
    primaryProof: PrimaryProof(path: 'test/sample_test.dart'),
    toolProof: ToolProof(
      enforcementPath: 'tool/check_guardrails.dart',
      regressionPath: 'test/tool/guardrails/guardrails_sample_tool_test.dart',
    ),
  ),
  Invariant(
    id: 'INV-ENG-OTHER-GUARDRAILS',
    scope: 'sample',
    title: 'other guardrails invariant',
    primaryProof: PrimaryProof(
      path: 'test/tool/guardrails/guardrails_other_tool_test.dart',
    ),
  ),
];
''');
          writeSandboxFile(sandbox, 'test/sample_test.dart', '''
void main() {
  ${_invMarker('INV-ENG-GUARDRAILS-TOOL')}
}
''');
          writeSandboxFile(
            sandbox,
            'test/tool/guardrails/guardrails_other_tool_test.dart',
            '''
void main() {
  ${_invMarker('INV-ENG-OTHER-GUARDRAILS')}
}
''',
          );
          writeSandboxFile(sandbox, 'tool/check_guardrails.dart', '''
void main() {
  ${_invMarker('INV-ENG-GUARDRAILS-TOOL')}
}
''');
          writeSandboxFile(
            sandbox,
            'test/tool/guardrails/guardrails_sample_tool_test.dart',
            '''
void main() {
  ${_invMarker('INV-ENG-GUARDRAILS-TOOL')}
  ${_invMarker('INV-ENG-OTHER-GUARDRAILS')}
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
              'test/tool/guardrails/guardrails_sample_tool_test.dart '
              'overclaims guardrails invariant '
              '${_markerText('INV-ENG-OTHER-GUARDRAILS')}',
            ),
          );
        } finally {
          sandbox.deleteSync(recursive: true);
        }
      },
    );

    test('rejects missing guardrails marker for a declared file', () async {
      final sandbox = await _createSandbox();
      try {
        _writeRegistry(sandbox, '''
const List<Invariant> invariants = <Invariant>[
  Invariant(
    id: 'INV-ENG-GUARDRAILS-TOOL',
    scope: 'sample',
    title: 'guardrails tool invariant',
    primaryProof: PrimaryProof(path: 'test/sample_test.dart'),
    toolProof: ToolProof(
      enforcementPath: 'tool/check_guardrails.dart',
      regressionPath: 'test/tool/guardrails/guardrails_sample_tool_test.dart',
    ),
  ),
  Invariant(
    id: 'INV-ENG-GUARDRAILS-PRIMARY',
    scope: 'sample',
    title: 'guardrails primary invariant',
    primaryProof: PrimaryProof(
      path: 'test/tool/guardrails/guardrails_sample_tool_test.dart',
    ),
  ),
];
''');
        writeSandboxFile(sandbox, 'test/sample_test.dart', '''
void main() {
  ${_invMarker('INV-ENG-GUARDRAILS-TOOL')}
}
''');
        writeSandboxFile(sandbox, 'tool/check_guardrails.dart', '''
void main() {
  ${_invMarker('INV-ENG-GUARDRAILS-TOOL')}
}
''');
        writeSandboxFile(
          sandbox,
          'test/tool/guardrails/guardrails_sample_tool_test.dart',
          '''
void main() {
  ${_invMarker('INV-ENG-GUARDRAILS-TOOL')}
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
            'INV-ENG-GUARDRAILS-PRIMARY is missing explicit proof marker in '
            'primaryProof '
            'test/tool/guardrails/guardrails_sample_tool_test.dart',
          ),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    });

    test(
      'preserves missing-file diagnostics before guardrails claim-honesty checks',
      () async {
        final sandbox = await _createSandbox();
        try {
          _writeRegistry(sandbox, '''
const List<Invariant> invariants = <Invariant>[
  Invariant(
    id: 'INV-ENG-GUARDRAILS-TOOL',
    scope: 'sample',
    title: 'guardrails tool invariant',
    primaryProof: PrimaryProof(path: 'test/sample_test.dart'),
    toolProof: ToolProof(
      enforcementPath: 'tool/check_guardrails.dart',
      regressionPath: 'test/tool/guardrails/guardrails_sample_tool_test.dart',
    ),
  ),
];
''');
          writeSandboxFile(sandbox, 'test/sample_test.dart', '''
void main() {
  ${_invMarker('INV-ENG-GUARDRAILS-TOOL')}
}
''');
          writeSandboxFile(sandbox, 'tool/check_guardrails.dart', '''
void main() {
  ${_invMarker('INV-ENG-GUARDRAILS-TOOL')}
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
              'INV-ENG-GUARDRAILS-TOOL toolProof.regressionPath missing: '
              'test/tool/guardrails/guardrails_sample_tool_test.dart',
            ),
          );
          expect(
            result.stderr.toString(),
            isNot(
              contains(
                'guardrails claim surfaces must match the registry-backed contour',
              ),
            ),
          );
        } finally {
          sandbox.deleteSync(recursive: true);
        }
      },
    );

    test(
      'allows navigation-only invariant refs in guardrails test files',
      () async {
        final sandbox = await _createSandbox();
        try {
          _writeRegistry(sandbox, '''
const List<Invariant> invariants = <Invariant>[
  Invariant(
    id: 'INV-ENG-GUARDRAILS-TOOL',
    scope: 'sample',
    title: 'guardrails tool invariant',
    primaryProof: PrimaryProof(path: 'test/sample_test.dart'),
    toolProof: ToolProof(
      enforcementPath: 'tool/check_guardrails.dart',
      regressionPath: 'test/tool/guardrails/guardrails_sample_tool_test.dart',
    ),
  ),
  Invariant(
    id: 'INV-ENG-NAVIGATION-ONLY',
    scope: 'sample',
    title: 'navigation-only invariant',
    primaryProof: PrimaryProof(path: 'test/navigation_test.dart'),
  ),
];
''');
          writeSandboxFile(sandbox, 'test/sample_test.dart', '''
void main() {
  ${_invMarker('INV-ENG-GUARDRAILS-TOOL')}
}
''');
          writeSandboxFile(sandbox, 'test/navigation_test.dart', '''
void main() {
  ${_invMarker('INV-ENG-NAVIGATION-ONLY')}
}
''');
          writeSandboxFile(sandbox, 'tool/check_guardrails.dart', '''
void main() {
  ${_invMarker('INV-ENG-GUARDRAILS-TOOL')}
}
''');
          writeSandboxFile(
            sandbox,
            'test/tool/guardrails/guardrails_sample_tool_test.dart',
            '''
void main() {
  ${_invMarker('INV-ENG-GUARDRAILS-TOOL')}
  // docs mention ${_markerText('INV-ENG-NAVIGATION-ONLY')}
  final expected = '${_markerText('INV-ENG-NAVIGATION-ONLY')}';
  if (expected.isEmpty) {
    throw StateError('unreachable');
  }
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

    test(
      'rejects comment-only marker outside the declared proof surface',
      () async {
        final sandbox = await _createSandbox();
        try {
          _writeRegistry(sandbox, '''
const List<Invariant> invariants = <Invariant>[
  Invariant(
    id: 'INV-ENG-SAMPLE-CONTRACT',
    scope: 'sample',
    title: 'sample invariant',
    primaryProof: PrimaryProof(path: 'test/declared_proof_test.dart'),
  ),
];
''');
          writeSandboxFile(sandbox, 'test/comment_only_test.dart', '''
void main() {
  ${_invMarker('INV-ENG-SAMPLE-CONTRACT')}
}
''');
          writeSandboxFile(
            sandbox,
            'test/declared_proof_test.dart',
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
              'INV-ENG-SAMPLE-CONTRACT is missing explicit proof marker in '
              'primaryProof test/declared_proof_test.dart',
            ),
          );
        } finally {
          sandbox.deleteSync(recursive: true);
        }
      },
    );

    test(
      'rejects navigation-only invariant refs inside a declared proof file',
      () async {
        final sandbox = await _createSandbox();
        try {
          _writeRegistry(sandbox, '''
const List<Invariant> invariants = <Invariant>[
  Invariant(
    id: 'INV-ENG-SAMPLE-CONTRACT',
    scope: 'sample',
    title: 'sample invariant',
    primaryProof: PrimaryProof(path: 'test/declared_proof_test.dart'),
  ),
];
''');
          writeSandboxFile(sandbox, 'test/declared_proof_test.dart', '''
void main() {
  final note = '${_markerText('INV-ENG-SAMPLE-CONTRACT')}';
  if (note.isEmpty) {
    throw StateError('unreachable');
  }
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
              'INV-ENG-SAMPLE-CONTRACT is missing explicit proof marker in '
              'primaryProof test/declared_proof_test.dart',
            ),
          );
        } finally {
          sandbox.deleteSync(recursive: true);
        }
      },
    );

    test('rejects invalid primary and tool proof path shapes', () async {
      final sandbox = await _createSandbox();
      try {
        _writeRegistry(sandbox, '''
const List<Invariant> invariants = <Invariant>[
  Invariant(
    id: 'INV-ENG-SAMPLE-CONTRACT',
    scope: 'sample',
    title: 'sample invariant',
    primaryProof: PrimaryProof(path: 'tool/check_sample.dart'),
    toolProof: ToolProof(
      enforcementPath: 'tool/src/check_sample.dart',
      regressionPath: 'test/sample_test.dart',
    ),
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
            'INV-ENG-SAMPLE-CONTRACT primaryProof.path must match '
            'test/**/*_test.dart: tool/check_sample.dart',
          ),
        );
        expect(
          result.stderr.toString(),
          contains(
            'INV-ENG-SAMPLE-CONTRACT toolProof.enforcementPath must match '
            'top-level tool/*.dart: tool/src/check_sample.dart',
          ),
        );
        expect(
          result.stderr.toString(),
          contains(
            'INV-ENG-SAMPLE-CONTRACT toolProof.regressionPath must match '
            'test/tool/**/*_test.dart: test/sample_test.dart',
          ),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    });

    test('rejects declared toolProof without tool regression path', () async {
      final sandbox = await _createSandbox();
      try {
        _writeRegistry(sandbox, '''
const List<Invariant> invariants = <Invariant>[
  Invariant(
    id: 'INV-ENG-SAMPLE-CONTRACT',
    scope: 'sample',
    title: 'sample invariant',
    primaryProof: PrimaryProof(path: 'test/sample_test.dart'),
    toolProof: ToolProof(enforcementPath: 'tool/check_sample.dart'),
  ),
];
''');
        writeSandboxFile(sandbox, 'test/sample_test.dart', '''
void main() {
  ${_invMarker('INV-ENG-SAMPLE-CONTRACT')}
}
''');
        writeSandboxFile(sandbox, 'tool/check_sample.dart', '''
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
            'INV-ENG-SAMPLE-CONTRACT toolProof.regressionPath is required',
          ),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    });

    test(
      'reports coverage by invariant when one invariant misses multiple tool proofs',
      () async {
        final sandbox = await _createSandbox();
        try {
          _writeRegistry(sandbox, '''
const List<Invariant> invariants = <Invariant>[
  Invariant(
    id: 'INV-ENG-SAMPLE-CONTRACT',
    scope: 'sample',
    title: 'sample invariant',
    primaryProof: PrimaryProof(path: 'test/sample_test.dart'),
    toolProof: ToolProof(
      enforcementPath: 'tool/check_sample.dart',
      regressionPath: 'test/tool/sample_tool_test.dart',
    ),
  ),
];
''');
          writeSandboxFile(sandbox, 'test/sample_test.dart', '''
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
            contains('FAIL: invariant proof coverage 0.0% (0/1). Missing:'),
          );
        } finally {
          sandbox.deleteSync(recursive: true);
        }
      },
    );

    test('rejects non-canonical invariant ids with underscores', () async {
      final sandbox = await _createSandbox();
      try {
        _writeRegistry(sandbox, '''
const List<Invariant> invariants = <Invariant>[
  Invariant(
    id: 'INV-ENG-BAD_ID',
    scope: 'sample',
    title: 'bad invariant',
    primaryProof: PrimaryProof(path: 'test/sample_test.dart'),
  ),
];
''');
        writeSandboxFile(sandbox, 'test/sample_test.dart', '''
void main() {
  ${_invMarker('INV-ENG-BAD_ID')}
}
''');

        final result = await runSandboxTool(
          sandbox,
          'check_invariant_coverage.dart',
        );

        expect(result.exitCode, isNonZero);
        expect(
          result.stderr.toString(),
          contains('non-canonical invariant id INV-ENG-BAD_ID'),
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
    required this.primaryProof,
    this.toolProof,
  });

  final String id;
  final String scope;
  final String title;
  final PrimaryProof primaryProof;
  final ToolProof? toolProof;
}

class PrimaryProof {
  const PrimaryProof({this.path});

  final String? path;
}

class ToolProof {
  const ToolProof({this.enforcementPath, this.regressionPath});

  final String? enforcementPath;
  final String? regressionPath;
}

$invariantsBody
''');
}

String _invMarker(String id) => '// INV:$id';

String _markerText(String id) => 'INV:$id';
