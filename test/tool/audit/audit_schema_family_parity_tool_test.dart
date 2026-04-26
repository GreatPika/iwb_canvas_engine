@Tags(['tool'])
library;

import 'dart:io';

import 'package:test/test.dart';

import '../support/tool_process_test_support.dart';

void main() {
  group('tool/audit_schema_family_parity.dart', () {
    test('flags schema return drift and backing propagation drift', () async {
      final sandbox = await _createSandbox();
      try {
        _writeViolatingFixture(sandbox);

        final result = await runSandboxTool(
          sandbox,
          'audit_schema_family_parity.dart',
          args: const <String>[
            'lib/src/contract/internal/sample_schema_family.dart',
          ],
        );

        expect(result.exitCode, 1, reason: result.stderr.toString());
        expect(
          result.stdout.toString(),
          contains('validateSampleSchemaFields [schema-return]'),
        );
        expect(
          result.stdout.toString(),
          contains('sampleBackingFromValidated [backing-propagation'),
        );
        expect(result.stdout.toString(), contains('missing fields: b'));
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    });

    test('stays quiet when schema and backing families stay aligned', () async {
      final sandbox = await _createSandbox();
      try {
        _writeCleanFixture(sandbox);

        final result = await runSandboxTool(
          sandbox,
          'audit_schema_family_parity.dart',
          args: const <String>[
            'lib/src/contract/internal/clean_schema_family.dart',
          ],
        );

        expect(result.exitCode, 0, reason: result.stderr.toString());
        expect(
          result.stdout.toString(),
          contains('Schema family parity audit passed'),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    });
  });
}

Future<Directory> _createSandbox() {
  return createToolSandbox(
    tempPrefix: 'iwb_canvas_engine_audit_schema_family_parity_tool_test_',
    toolFiles: const <String>[
      'tool/audit_schema_family_parity.dart',
      'tool/src/tool_command_result.dart',
    ],
  );
}

void _writeViolatingFixture(Directory sandbox) {
  writeSandboxFile(
    sandbox,
    'lib/src/contract/internal/sample_schema_family.dart',
    '''
typedef SampleSchemaFields = ({
  int a,
  int b,
});

SampleSchemaFields validateSampleSchemaFields(
  SampleSchemaFields fields,
) => (
  a: fields.a,
);

SampleSchemaFields sampleSchemaFieldsFromValidated(
  SampleSchemaFields fields,
) => (
  a: fields.a,
  b: fields.b,
);

class SampleBacking {
  const SampleBacking({
    required this.a,
  });

  final int a;
}

SampleBacking sampleBackingFromValidated({
  required SampleSchemaFields fields,
}) {
  final resolvedFields = sampleSchemaFieldsFromValidated(fields);
  return SampleBacking(
    a: resolvedFields.a,
  );
}
''',
  );
}

void _writeCleanFixture(Directory sandbox) {
  writeSandboxFile(
    sandbox,
    'lib/src/contract/internal/clean_schema_family.dart',
    '''
typedef SampleSchemaFields = ({
  int a,
  int b,
});

SampleSchemaFields validateSampleSchemaFields(
  SampleSchemaFields fields,
) => (
  a: fields.a,
  b: fields.b,
);

SampleSchemaFields sampleSchemaFieldsFromValidated(
  SampleSchemaFields fields,
) => (
  a: fields.a,
  b: fields.b,
);

class SampleBacking {
  const SampleBacking({
    required this.a,
    required this.b,
  });

  final int a;
  final int b;
}

SampleBacking sampleBackingFromValidated({
  required SampleSchemaFields fields,
}) {
  final resolvedFields = sampleSchemaFieldsFromValidated(fields);
  return SampleBacking(
    a: resolvedFields.a,
    b: resolvedFields.b,
  );
}
''',
  );
}
