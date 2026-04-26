@Tags(['tool'])
library;

import 'dart:io';

import 'package:test/test.dart';

import '../support/tool_process_test_support.dart';

void main() {
  group('tool/audit_bridge_surfaces.dart', () {
    test('flags bridge surfaces that export raw backing symbols', () async {
      final sandbox = await _createSandbox();
      try {
        _writeViolatingFixture(sandbox);

        final result = await runSandboxTool(
          sandbox,
          'audit_bridge_surfaces.dart',
        );

        expect(result.exitCode, 1, reason: result.stderr.toString());
        expect(
          result.stdout.toString(),
          contains('lib/src/contract/internal/sample_fast_path.dart'),
        );
        expect(result.stdout.toString(), contains('raw-backing-type'));
        expect(result.stdout.toString(), contains('SampleBacking'));
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    });

    test(
      'stays quiet when bridge surfaces avoid raw backing exports',
      () async {
        final sandbox = await _createSandbox();
        try {
          _writeCleanFixture(sandbox);

          final result = await runSandboxTool(
            sandbox,
            'audit_bridge_surfaces.dart',
          );

          expect(result.exitCode, 0, reason: result.stderr.toString());
          expect(
            result.stdout.toString(),
            contains('Bridge surface audit passed'),
          );
        } finally {
          sandbox.deleteSync(recursive: true);
        }
      },
    );
  });
}

Future<Directory> _createSandbox() {
  return createToolSandbox(
    tempPrefix: 'iwb_canvas_engine_audit_bridge_surfaces_tool_test_',
    toolFiles: const <String>[
      'tool/audit_bridge_surfaces.dart',
      'tool/src/tool_command_result.dart',
    ],
  );
}

void _writeViolatingFixture(Directory sandbox) {
  writeSandboxFile(
    sandbox,
    'tool/src/import_boundaries/import_boundary_policy.dart',
    '''
const Map<String, Object> _bridgeSurfaceDescriptors = <String, Object>{
  '/lib/src/contract/internal/sample_fast_path.dart': Object(),
};
''',
  );
  writeSandboxFile(
    sandbox,
    'lib/src/contract/internal/sample_fast_path.dart',
    '''
export 'sample_backing.dart'
    show SampleBacking, sampleBackingFromValidated;
export 'sample_materialization.dart'
    show sampleFromValidatedBacking;
''',
  );
}

void _writeCleanFixture(Directory sandbox) {
  writeSandboxFile(
    sandbox,
    'tool/src/import_boundaries/import_boundary_policy.dart',
    '''
const Map<String, Object> _bridgeSurfaceDescriptors = <String, Object>{
  '/lib/src/contract/internal/sample_schema.dart': Object(),
};
''',
  );
  writeSandboxFile(sandbox, 'lib/src/contract/internal/sample_schema.dart', '''
export 'sample_parts.dart'
    show validateSampleSchemaFields, sampleSchemaFieldsFromValidated;
''');
}
