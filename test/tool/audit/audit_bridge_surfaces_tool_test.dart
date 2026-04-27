@Tags(['tool'])
library;

import 'dart:io';

import 'package:test/test.dart';

import '../support/tool_process_test_support.dart';

void main() {
  group('tool/audit_bridge_surfaces.dart', () {
    test(
      'flags bridge surfaces that export generic backing materializers',
      () async {
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
          expect(
            result.stdout.toString(),
            contains('materialize-from-backing'),
          );
          expect(result.stdout.toString(), contains('carrier exports'));
          expect(result.stdout.toString(), contains('SampleBacking'));
        } finally {
          sandbox.deleteSync(recursive: true);
        }
      },
    );

    test(
      'flags generic backing materializers declared on the bridge surface',
      () async {
        final sandbox = await _createSandbox();
        try {
          _writeDirectDeclarationFixture(sandbox);

          final result = await runSandboxTool(
            sandbox,
            'audit_bridge_surfaces.dart',
          );

          expect(result.exitCode, 1, reason: result.stderr.toString());
          expect(
            result.stdout.toString(),
            contains('sampleFromValidatedBacking'),
          );
          expect(result.stdout.toString(), isNot(contains('carrier exports')));
          expect(result.stdout.toString(), isNot(contains('raw-backing-type')));
        } finally {
          sandbox.deleteSync(recursive: true);
        }
      },
    );

    test(
      'flags generic backing materializers declared in bridge surface parts',
      () async {
        final sandbox = await _createSandbox();
        try {
          _writeSurfacePartDeclarationFixture(sandbox);

          final result = await runSandboxTool(
            sandbox,
            'audit_bridge_surfaces.dart',
          );

          expect(result.exitCode, 1, reason: result.stderr.toString());
          expect(
            result.stdout.toString(),
            contains('sampleFromValidatedBacking'),
          );
        } finally {
          sandbox.deleteSync(recursive: true);
        }
      },
    );

    test('flags generic backing materializers exported without show', () async {
      final sandbox = await _createSandbox();
      try {
        _writeImplicitExportFixture(sandbox);

        final result = await runSandboxTool(
          sandbox,
          'audit_bridge_surfaces.dart',
        );

        expect(result.exitCode, 1, reason: result.stderr.toString());
        expect(
          result.stdout.toString(),
          contains('sampleFromValidatedBacking'),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    });

    test('flags generic backing materializers exported through hide', () async {
      final sandbox = await _createSandbox();
      try {
        _writeHideExportFixture(sandbox);

        final result = await runSandboxTool(
          sandbox,
          'audit_bridge_surfaces.dart',
        );

        expect(result.exitCode, 1, reason: result.stderr.toString());
        expect(
          result.stdout.toString(),
          contains('sampleFromValidatedBacking'),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    });

    test('allows generic backing materializers hidden by combinator', () async {
      final sandbox = await _createSandbox();
      try {
        _writeHiddenMaterializerFixture(sandbox);

        final result = await runSandboxTool(
          sandbox,
          'audit_bridge_surfaces.dart',
        );

        expect(result.exitCode, 0, reason: result.stderr.toString());
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    });

    test(
      'flags generic backing materializers revealed by a later export edge',
      () async {
        final sandbox = await _createSandbox();
        try {
          _writeHiddenThenRevealedMaterializerFixture(sandbox);

          final result = await runSandboxTool(
            sandbox,
            'audit_bridge_surfaces.dart',
          );

          expect(result.exitCode, 1, reason: result.stderr.toString());
          expect(
            result.stdout.toString(),
            contains('sampleFromValidatedBacking'),
          );
        } finally {
          sandbox.deleteSync(recursive: true);
        }
      },
    );

    test('flags generic backing materializers declared in parts', () async {
      final sandbox = await _createSandbox();
      try {
        _writePartExportFixture(sandbox);

        final result = await runSandboxTool(
          sandbox,
          'audit_bridge_surfaces.dart',
        );

        expect(result.exitCode, 1, reason: result.stderr.toString());
        expect(
          result.stdout.toString(),
          contains('sampleFromValidatedBacking'),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    });

    test(
      'flags generic backing materializers exported through package self',
      () async {
        final sandbox = await _createSandbox();
        try {
          _writePackageSelfExportFixture(sandbox);

          final result = await runSandboxTool(
            sandbox,
            'audit_bridge_surfaces.dart',
          );

          expect(result.exitCode, 1, reason: result.stderr.toString());
          expect(
            result.stdout.toString(),
            contains('sampleFromValidatedBacking'),
          );
        } finally {
          sandbox.deleteSync(recursive: true);
        }
      },
    );

    test(
      'flags generic backing materializers in conditional exports',
      () async {
        final sandbox = await _createSandbox();
        try {
          _writeConditionalExportFixture(sandbox);

          final result = await runSandboxTool(
            sandbox,
            'audit_bridge_surfaces.dart',
          );

          expect(result.exitCode, 1, reason: result.stderr.toString());
          expect(
            result.stdout.toString(),
            contains('sampleFromValidatedBacking'),
          );
        } finally {
          sandbox.deleteSync(recursive: true);
        }
      },
    );

    test(
      'allows carrier exports when generic backing materializers are absent',
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
      'tool/src/guardrails/rules/public/public_export_namespace_support.dart',
      'tool/src/guardrails/support/guardrail_context.dart',
      'tool/src/guardrails/support/guardrail_path_utils.dart',
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
  _writeSampleBacking(sandbox);
  _writeSampleMaterialization(sandbox);
}

void _writeDirectDeclarationFixture(Directory sandbox) {
  _writeBridgePolicy(sandbox, 'sample_fast_path.dart');
  writeSandboxFile(
    sandbox,
    'lib/src/contract/internal/sample_fast_path.dart',
    '''
Object sampleFromValidatedBacking(Object backing) => backing;
''',
  );
}

void _writeSurfacePartDeclarationFixture(Directory sandbox) {
  _writeBridgePolicy(sandbox, 'sample_fast_path.dart');
  writeSandboxFile(
    sandbox,
    'lib/src/contract/internal/sample_fast_path.dart',
    '''
library sample_fast_path;

part 'sample_fast_path_part.dart';
''',
  );
  writeSandboxFile(
    sandbox,
    'lib/src/contract/internal/sample_fast_path_part.dart',
    '''
part of sample_fast_path;

Object sampleFromValidatedBacking(Object backing) => backing;
''',
  );
}

void _writeImplicitExportFixture(Directory sandbox) {
  _writeBridgePolicy(sandbox, 'sample_fast_path.dart');
  writeSandboxFile(
    sandbox,
    'lib/src/contract/internal/sample_fast_path.dart',
    '''
export 'sample_materialization.dart';
''',
  );
  _writeSampleMaterialization(sandbox);
}

void _writeHideExportFixture(Directory sandbox) {
  _writeBridgePolicy(sandbox, 'sample_fast_path.dart');
  writeSandboxFile(
    sandbox,
    'lib/src/contract/internal/sample_fast_path.dart',
    '''
export 'sample_materialization.dart' hide unrelatedHelper;
''',
  );
  _writeSampleMaterialization(sandbox);
}

void _writeHiddenMaterializerFixture(Directory sandbox) {
  _writeBridgePolicy(sandbox, 'sample_fast_path.dart');
  writeSandboxFile(
    sandbox,
    'lib/src/contract/internal/sample_fast_path.dart',
    '''
export 'sample_materialization.dart' hide sampleFromValidatedBacking;
''',
  );
  _writeSampleMaterialization(sandbox);
}

void _writeHiddenThenRevealedMaterializerFixture(Directory sandbox) {
  _writeBridgePolicy(sandbox, 'sample_fast_path.dart');
  writeSandboxFile(
    sandbox,
    'lib/src/contract/internal/sample_fast_path.dart',
    '''
export 'sample_materialization.dart' hide sampleFromValidatedBacking;
export 'sample_materialization.dart';
''',
  );
  _writeSampleMaterialization(sandbox);
}

void _writePartExportFixture(Directory sandbox) {
  _writeBridgePolicy(sandbox, 'sample_fast_path.dart');
  writeSandboxFile(
    sandbox,
    'lib/src/contract/internal/sample_fast_path.dart',
    '''
export 'sample_materialization.dart';
''',
  );
  writeSandboxFile(
    sandbox,
    'lib/src/contract/internal/sample_materialization.dart',
    '''
library sample_materialization;

part 'sample_materialization_part.dart';
''',
  );
  writeSandboxFile(
    sandbox,
    'lib/src/contract/internal/sample_materialization_part.dart',
    '''
part of sample_materialization;

Object sampleFromValidatedBacking(Object backing) => backing;
''',
  );
}

void _writePackageSelfExportFixture(Directory sandbox) {
  _writeBridgePolicy(sandbox, 'sample_fast_path.dart');
  writeSandboxFile(
    sandbox,
    'lib/src/contract/internal/sample_fast_path.dart',
    '''
export 'package:iwb_canvas_engine/src/contract/internal/sample_materialization.dart';
''',
  );
  _writeSampleMaterialization(sandbox);
}

void _writeConditionalExportFixture(Directory sandbox) {
  _writeBridgePolicy(sandbox, 'sample_fast_path.dart');
  writeSandboxFile(
    sandbox,
    'lib/src/contract/internal/sample_fast_path.dart',
    '''
export 'clean_materialization.dart'
    if (dart.library.io) 'sample_materialization.dart';
''',
  );
  writeSandboxFile(
    sandbox,
    'lib/src/contract/internal/clean_materialization.dart',
    '''
Object sampleFromValidated(Object backing) => backing;
''',
  );
  _writeSampleMaterialization(sandbox);
}

void _writeCleanFixture(Directory sandbox) {
  _writeBridgePolicy(sandbox, 'sample_schema.dart');
  writeSandboxFile(sandbox, 'lib/src/contract/internal/sample_schema.dart', '''
export 'sample_parts.dart'
    show SampleBacking, sampleBackingFromValidated, sampleFromValidated;
''');
}

void _writeBridgePolicy(Directory sandbox, String fileName) {
  writeSandboxFile(
    sandbox,
    'tool/src/import_boundaries/import_boundary_policy.dart',
    '''
const Map<String, Object> _bridgeSurfaceDescriptors = <String, Object>{
  '/lib/src/contract/internal/$fileName': Object(),
};
''',
  );
}

void _writeSampleMaterialization(Directory sandbox) {
  writeSandboxFile(
    sandbox,
    'lib/src/contract/internal/sample_materialization.dart',
    '''
Object unrelatedHelper() => Object();

Object sampleFromValidatedBacking(Object backing) => backing;
''',
  );
}

void _writeSampleBacking(Directory sandbox) {
  writeSandboxFile(sandbox, 'lib/src/contract/internal/sample_backing.dart', '''
final class SampleBacking {
  const SampleBacking();
}

SampleBacking sampleBackingFromValidated(Object value) => const SampleBacking();
''');
}
