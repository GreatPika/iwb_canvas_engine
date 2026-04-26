@Tags(['tool'])
library;

import 'dart:io';

import 'package:test/test.dart';

import '../support/tool_process_test_support.dart';

void main() {
  group('tool/audit_patch_field_admission.dart', () {
    test(
      'flags direct passthrough for non-nullable PatchField values',
      () async {
        final sandbox = await _createSandbox();
        try {
          _writeViolatingFixture(sandbox);

          final result = await runSandboxTool(
            sandbox,
            'audit_patch_field_admission.dart',
            args: const <String>[
              'lib/src/contract/internal/sample_patch_schema.dart',
            ],
          );

          expect(result.exitCode, 1, reason: result.stderr.toString());
          expect(
            result.stdout.toString(),
            contains('validateSamplePatchSchemaFields.flag'),
          );
          expect(result.stdout.toString(), isNot(contains('label')));
          expect(result.stdout.toString(), isNot(contains('size')));
        } finally {
          sandbox.deleteSync(recursive: true);
        }
      },
    );

    test(
      'stays quiet when non-nullable fields go through validators',
      () async {
        final sandbox = await _createSandbox();
        try {
          _writeCleanFixture(sandbox);

          final result = await runSandboxTool(
            sandbox,
            'audit_patch_field_admission.dart',
            args: const <String>[
              'lib/src/contract/internal/clean_patch_schema.dart',
            ],
          );

          expect(result.exitCode, 0, reason: result.stderr.toString());
          expect(
            result.stdout.toString(),
            contains('PatchField admission audit passed'),
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
    tempPrefix: 'iwb_canvas_engine_audit_patch_field_admission_tool_test_',
    toolFiles: const <String>[
      'tool/audit_patch_field_admission.dart',
      'tool/src/tool_command_result.dart',
    ],
  );
}

void _writeViolatingFixture(Directory sandbox) {
  writeSandboxFile(
    sandbox,
    'lib/src/contract/internal/sample_patch_schema.dart',
    '''
typedef SamplePatchSchemaFields = ({
  PatchField<bool> flag,
  PatchField<String?> label,
  PatchField<double> size,
});

class PatchField<T> {
  const PatchField();
}

SamplePatchSchemaFields validateSamplePatchSchemaFields(
  SamplePatchSchemaFields fields,
) {
  return (
    flag: fields.flag,
    label: fields.label,
    size: _validateNonNullablePatchField(
      fields.size,
      name: 'size',
      transformValue: (value) => value,
    ),
  );
}

PatchField<T> _validateNonNullablePatchField<T>(
  PatchField<T> patch, {
  required String name,
  required T Function(T value) transformValue,
}) => patch;
''',
  );
}

void _writeCleanFixture(Directory sandbox) {
  writeSandboxFile(
    sandbox,
    'lib/src/contract/internal/clean_patch_schema.dart',
    '''
typedef CleanPatchSchemaFields = ({
  PatchField<bool> flag,
  PatchField<String?> label,
});

class PatchField<T> {
  const PatchField();
}

CleanPatchSchemaFields validateCleanPatchSchemaFields(
  CleanPatchSchemaFields fields,
) => (
  flag: _validateNonNullablePatchField(
    fields.flag,
    name: 'flag',
    transformValue: (value) => value,
  ),
  label: fields.label,
);

PatchField<T> _validateNonNullablePatchField<T>(
  PatchField<T> patch, {
  required String name,
  required T Function(T value) transformValue,
}) => patch;
''',
  );
}
