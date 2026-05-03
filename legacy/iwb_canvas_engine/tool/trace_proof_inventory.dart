import 'dart:convert';
import 'dart:io';

import 'invariant_registry.dart';
import 'src/guardrails/guardrail_rule_inventory.dart';
import 'src/verification_contract/verification_contract_registry.dart';
import 'src/tool_command_result.dart';

Future<ToolCommandResult> runTraceProofInventoryTool(
  List<String> args, {
  Directory? root,
}) async {
  final workingRoot = root ?? Directory.current;
  final jsonOutput = args.contains('--json');
  final jsonOutPath = _parseStringFlag(args, '--json-out');
  final markdownOutput = args.contains('--md');
  final markdownOutPath = _parseStringFlag(args, '--md-out');

  final report = _buildReport();
  final reportJson = const JsonEncoder.withIndent('  ').convert(report);
  final reportMarkdown = _renderMermaidDocument(report);

  if (jsonOutPath != null) {
    _writeOutputFile(workingRoot, jsonOutPath, '$reportJson\n');
  }
  if (markdownOutPath != null) {
    _writeOutputFile(workingRoot, markdownOutPath, '$reportMarkdown\n');
  }

  if (jsonOutput) {
    return ToolCommandResult(exitCode: 0, stdout: '$reportJson\n');
  }
  if (markdownOutput) {
    return ToolCommandResult(exitCode: 0, stdout: '$reportMarkdown\n');
  }

  return ToolCommandResult(exitCode: 0, stdout: _renderSummary(report));
}

Future<void> main(List<String> args) async {
  final result = await runTraceProofInventoryTool(args);
  writeToolCommandResult(result);
  exitCode = result.exitCode;
}

Map<String, Object?> _buildReport() {
  final guardrailRules = guardrailRuleInventory
      .map(
        (rule) => <String, Object?>{
          'id': rule.metadata.id,
          'area': rule.metadata.area,
          'description': rule.metadata.description,
          'invariantIds': rule.metadata.invariantIds,
          'readsStateArtifacts': rule.metadata.readsStateArtifacts,
          'writesStateArtifacts': rule.metadata.writesStateArtifacts,
        },
      )
      .toList(growable: false);

  final artifactIds = <String>{
    for (final rule in guardrailRuleInventory)
      ...rule.metadata.readsStateArtifacts,
    for (final rule in guardrailRuleInventory)
      ...rule.metadata.writesStateArtifacts,
  }.toList(growable: false)..sort();

  final runnerArtifacts = artifactIds
      .map(
        (artifactId) => <String, Object?>{
          'id': artifactId,
          'writers':
              guardrailRuleInventory
                  .where(
                    (rule) =>
                        rule.metadata.writesStateArtifacts.contains(artifactId),
                  )
                  .map((rule) => rule.metadata.id)
                  .toList(growable: false)
                ..sort(),
          'readers':
              guardrailRuleInventory
                  .where(
                    (rule) =>
                        rule.metadata.readsStateArtifacts.contains(artifactId),
                  )
                  .map((rule) => rule.metadata.id)
                  .toList(growable: false)
                ..sort(),
        },
      )
      .toList(growable: false);

  final invariantRows = invariants
      .map(
        (invariant) => <String, Object?>{
          'id': invariant.id,
          'scope': invariant.scope,
          'title': invariant.title,
          'requiredProofs': invariant.requiredProofs
              .map(
                (proof) => <String, Object?>{
                  'path': proof.path,
                  'stepId': proof.stepId,
                },
              )
              .toList(growable: false),
          'regressionProofs': invariant.regressionProofs
              .map((proof) => <String, Object?>{'path': proof.path})
              .toList(growable: false),
        },
      )
      .toList(growable: false);

  final requiredProofCountsByStep = <String, int>{};
  for (final invariant in invariants) {
    for (final proof in invariant.requiredProofs) {
      requiredProofCountsByStep.update(
        proof.stepId,
        (count) => count + 1,
        ifAbsent: () => 1,
      );
    }
  }
  final sortedRequiredProofCountsByStep =
      requiredProofCountsByStep.entries.toList(growable: false)
        ..sort((left, right) => left.key.compareTo(right.key));

  final guardrailBackedInvariantIds =
      invariants
          .where(
            (invariant) => invariant.requiredProofs.any(
              (proof) => proof.path == 'tool/check_guardrails.dart',
            ),
          )
          .map((invariant) => invariant.id)
          .toList(growable: false)
        ..sort();

  return <String, Object?>{
    'guardrailRules': guardrailRules,
    'runnerArtifacts': runnerArtifacts,
    'invariants': invariantRows,
    'requiredProofCountsByStep': sortedRequiredProofCountsByStep
        .map(
          (entry) => <String, Object?>{
            'stepId': entry.key,
            'count': entry.value,
          },
        )
        .toList(growable: false),
    'guardrailBackedInvariantIds': guardrailBackedInvariantIds,
    'requiredCodeChangePreset': <String, Object?>{
      'id': requiredCodeChangePresetDefinition.id,
      'stepIds': requiredCodeChangePresetDefinition.stepIds,
    },
  };
}

String _renderSummary(Map<String, Object?> report) {
  final rules = report['guardrailRules'] as List<Object?>? ?? const <Object?>[];
  final artifacts =
      report['runnerArtifacts'] as List<Object?>? ?? const <Object?>[];
  final invariantRows =
      report['invariants'] as List<Object?>? ?? const <Object?>[];
  final guardrailBacked =
      report['guardrailBackedInvariantIds'] as List<Object?>? ??
      const <Object?>[];

  return 'Guardrail rules: ${rules.length}\n'
      'Runner artifacts: ${artifacts.length}\n'
      'Invariants: ${invariantRows.length}\n'
      'Guardrail-backed invariants: ${guardrailBacked.length}\n';
}

String _renderMermaidDocument(Map<String, Object?> report) {
  final buffer = StringBuffer()
    ..writeln('# Proof Inventory Trace')
    ..writeln()
    ..writeln('```mermaid')
    ..writeln(_renderMermaid(report))
    ..writeln('```')
    ..writeln()
    ..writeln('Inventory summary:')
    ..writeln(
      '- Guardrail rules: ${(report['guardrailRules'] as List<Object?>).length}',
    )
    ..writeln(
      '- Runner artifacts: ${(report['runnerArtifacts'] as List<Object?>).length}',
    )
    ..writeln('- Invariants: ${(report['invariants'] as List<Object?>).length}')
    ..writeln(
      '- Guardrail-backed invariants: ${(report['guardrailBackedInvariantIds'] as List<Object?>).length}',
    );
  return buffer.toString().trimRight();
}

String _renderMermaid(Map<String, Object?> report) {
  final buffer = StringBuffer()..writeln('flowchart LR');
  final nodeIds = <String, String>{};
  var nextId = 0;

  String nodeIdFor(String key) =>
      nodeIds.putIfAbsent(key, () => 'N${nextId++}');

  String quote(String value) => value.replaceAll('"', r'\"');

  final guardrailsStepId = nodeIdFor('step:guardrails');
  final guardrailBackedCount =
      (report['guardrailBackedInvariantIds'] as List<Object?>).length;
  buffer.writeln(
    '  $guardrailsStepId["tool/check_guardrails.dart\\n$guardrailBackedCount guardrail-backed invariants"]',
  );

  for (final rule
      in (report['guardrailRules'] as List<Object?>)
          .cast<Map<String, Object?>>()) {
    final ruleId = rule['id'] as String;
    final invariants = (rule['invariantIds'] as List<Object?>).length;
    final ruleNodeId = nodeIdFor('rule:$ruleId');
    buffer.writeln(
      '  $ruleNodeId["${quote(ruleId)}\\n${quote(rule['area'] as String)}\\n$invariants invariants"]',
    );
    buffer.writeln('  $guardrailsStepId --> $ruleNodeId');
  }

  for (final artifact
      in (report['runnerArtifacts'] as List<Object?>)
          .cast<Map<String, Object?>>()) {
    final artifactId = artifact['id'] as String;
    final artifactNodeId = nodeIdFor('artifact:$artifactId');
    buffer.writeln('  $artifactNodeId["artifact: ${quote(artifactId)}"]');
    for (final writer
        in (artifact['writers'] as List<Object?>).cast<String>()) {
      buffer.writeln('  ${nodeIdFor('rule:$writer')} --> $artifactNodeId');
    }
    for (final reader
        in (artifact['readers'] as List<Object?>).cast<String>()) {
      buffer.writeln('  $artifactNodeId --> ${nodeIdFor('rule:$reader')}');
    }
  }

  return buffer.toString().trimRight();
}

String? _parseStringFlag(List<String> args, String flag) {
  final prefix = '$flag=';
  for (final arg in args) {
    if (arg.startsWith(prefix)) {
      return arg.substring(prefix.length);
    }
  }
  return null;
}

void _writeOutputFile(Directory root, String relativePath, String content) {
  final target = File(
    relativePath.startsWith('/')
        ? relativePath
        : '${root.path}${Platform.pathSeparator}$relativePath',
  );
  target.parent.createSync(recursive: true);
  target.writeAsStringSync(content);
}
