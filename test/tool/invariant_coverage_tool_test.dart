@Tags(['tool'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'support/tool_process_test_support.dart';

void main() {
  group('tool/check_invariant_coverage.dart', () {
    test('passes when registry proofPath points to matching marker', () async {
      final sandbox = await _createSandbox();
      try {
        _writeRegistry(sandbox, '''
const List<Invariant> invariants = <Invariant>[
  Invariant(
    id: 'INV-ENG-SAMPLE-CONTRACT',
    scope: 'sample',
    title: 'sample invariant',
    proofPath: 'test/sample_test.dart',
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
    });

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
    proofPath: 'test/declared_proof_test.dart',
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
              'test/declared_proof_test.dart',
            ),
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
    proofPath: 'test/sample_test.dart',
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
    required this.proofPath,
  });

  final String id;
  final String scope;
  final String title;
  final String proofPath;
}

$invariantsBody
''');
}

String _invMarker(String id) => '// INV:$id';
