import 'dart:convert';
import 'dart:io';

import 'audit_bridge_surfaces.dart';
import 'audit_patch_field_admission.dart';
import 'audit_post_commit_cleanup_order.dart';
import 'audit_route_expectations.dart';
import 'audit_schema_family_parity.dart';
import 'audit_terminal_cleanup_safety.dart';
import 'audit_validated_backing_structure.dart';
import 'audit_validated_materialization_paths.dart';
import 'src/tool_command_result.dart';

typedef _AuditRunner =
    Future<ToolCommandResult> Function(List<String> args, {Directory? root});

Future<ToolCommandResult> runRepositoryAuditsTool(
  List<String> args, {
  Directory? root,
}) async {
  final workingRoot = root ?? Directory.current;
  final jsonOutput = args.contains('--json');
  final selectedTools = _parseSelectedTools(args);

  final audits =
      <_AuditSpec>[
            _AuditSpec(
              name: 'route_expectations',
              description: 'Critical route bypass audit',
              run: runAuditRouteExpectationsTool,
            ),
            _AuditSpec(
              name: 'patch_field_admission',
              description: 'Non-nullable PatchField passthrough audit',
              run: runAuditPatchFieldAdmissionTool,
            ),
            _AuditSpec(
              name: 'post_commit_cleanup_order',
              description: 'Post-commit side-effect cleanup order audit',
              run: runAuditPostCommitCleanupOrderTool,
            ),
            _AuditSpec(
              name: 'schema_family_parity',
              description: 'Schema-family parity audit',
              run: runAuditSchemaFamilyParityTool,
            ),
            _AuditSpec(
              name: 'validated_materialization_paths',
              description: 'Validated materialization path audit',
              run: runAuditValidatedMaterializationPathsTool,
            ),
            _AuditSpec(
              name: 'validated_backing_structure',
              description: 'Validated backing structure audit',
              run: runAuditValidatedBackingStructureTool,
            ),
            _AuditSpec(
              name: 'bridge_surfaces',
              description: 'Bridge surface raw-backing leak audit',
              run: runAuditBridgeSurfacesTool,
            ),
            _AuditSpec(
              name: 'terminal_cleanup_safety',
              description: 'Terminal exception-safe cleanup audit',
              run: runAuditTerminalCleanupSafetyTool,
            ),
          ]
          .where(
            (audit) =>
                selectedTools == null || selectedTools.contains(audit.name),
          )
          .toList(growable: false);

  if (audits.isEmpty) {
    return const ToolCommandResult(
      exitCode: 1,
      stderr: 'FAIL: no repository audits selected.\n',
    );
  }

  final results = <_AuditExecutionResult>[];
  for (final audit in audits) {
    final result = await audit.run(const <String>[], root: workingRoot);
    results.add(_AuditExecutionResult(audit: audit, result: result));
  }

  final exitCode = results.any((item) => item.result.exitCode == 2)
      ? 2
      : results.any((item) => item.result.exitCode != 0)
      ? 1
      : 0;

  if (jsonOutput) {
    final payload = <String, Object?>{
      'summary': <String, Object?>{
        'total': results.length,
        'passed': results.where((item) => item.result.exitCode == 0).length,
        'failed': results.where((item) => item.result.exitCode == 1).length,
        'errors': results.where((item) => item.result.exitCode == 2).length,
      },
      'results': results
          .map(
            (item) => <String, Object?>{
              'name': item.audit.name,
              'description': item.audit.description,
              'exitCode': item.result.exitCode,
              'stdout': item.result.stdout,
              'stderr': item.result.stderr,
            },
          )
          .toList(growable: false),
    };
    return ToolCommandResult(
      exitCode: exitCode,
      stdout: '${const JsonEncoder.withIndent('  ').convert(payload)}\n',
    );
  }

  final buffer = StringBuffer()
    ..writeln(
      'Repository audits summary: '
      'total=${results.length}, '
      'passed=${results.where((item) => item.result.exitCode == 0).length}, '
      'failed=${results.where((item) => item.result.exitCode == 1).length}, '
      'errors=${results.where((item) => item.result.exitCode == 2).length}',
    );
  for (final item in results) {
    final status = switch (item.result.exitCode) {
      0 => 'PASS',
      1 => 'FAIL',
      _ => 'ERROR',
    };
    buffer.writeln('- $status: ${item.audit.name} (${item.audit.description})');
    final stdout = item.result.stdout.trimRight();
    if (stdout.isNotEmpty) {
      for (final line in stdout.split('\n')) {
        buffer.writeln('  $line');
      }
    }
    final stderr = item.result.stderr.trimRight();
    if (stderr.isNotEmpty) {
      for (final line in stderr.split('\n')) {
        buffer.writeln('  $line');
      }
    }
  }
  return ToolCommandResult(exitCode: exitCode, stdout: buffer.toString());
}

Future<void> main(List<String> args) async {
  final result = await runRepositoryAuditsTool(args);
  writeToolCommandResult(result);
  exitCode = result.exitCode;
}

Set<String>? _parseSelectedTools(List<String> args) {
  final values = <String>{};
  for (final arg in args) {
    if (!arg.startsWith('--tool=')) {
      continue;
    }
    final raw = arg.substring('--tool='.length);
    for (final item in raw.split(',')) {
      final trimmed = item.trim();
      if (trimmed.isNotEmpty) {
        values.add(trimmed);
      }
    }
  }
  return values.isEmpty ? null : values;
}

final class _AuditSpec {
  const _AuditSpec({
    required this.name,
    required this.description,
    required this.run,
  });

  final String name;
  final String description;
  final _AuditRunner run;
}

final class _AuditExecutionResult {
  const _AuditExecutionResult({required this.audit, required this.result});

  final _AuditSpec audit;
  final ToolCommandResult result;
}
