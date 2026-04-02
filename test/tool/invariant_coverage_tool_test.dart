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
