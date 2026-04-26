@Tags(['tool'])
library;

import 'dart:io';

import 'package:test/test.dart';

import '../support/tool_process_test_support.dart';

void main() {
  group('tool/run_repository_audits.dart', () {
    test('runs a selected audit through the shared runner', () async {
      final sandbox = await _createSandbox();
      try {
        _writeFixture(sandbox);

        final result = await runSandboxTool(
          sandbox,
          'run_repository_audits.dart',
          args: const <String>['--tool=bridge_surfaces'],
        );

        expect(result.exitCode, 1, reason: result.stderr.toString());
        expect(
          result.stdout.toString(),
          contains('Repository audits summary: total=1, passed=0, failed=1'),
        );
        expect(result.stdout.toString(), contains('bridge_surfaces'));
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    });
  });
}

Future<Directory> _createSandbox() {
  return createToolSandbox(
    tempPrefix: 'iwb_canvas_engine_run_repository_audits_tool_test_',
    toolFiles: const <String>[
      'tool/run_repository_audits.dart',
      'tool/audit_route_expectations.dart',
      'tool/audit_patch_field_admission.dart',
      'tool/audit_post_commit_cleanup_order.dart',
      'tool/audit_schema_family_parity.dart',
      'tool/audit_terminal_cleanup_safety.dart',
      'tool/audit_validated_materialization_paths.dart',
      'tool/audit_bridge_surfaces.dart',
      'tool/src/lsp',
      'tool/src/tool_command_result.dart',
    ],
  );
}

void _writeFixture(Directory sandbox) {
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
''',
  );
}
