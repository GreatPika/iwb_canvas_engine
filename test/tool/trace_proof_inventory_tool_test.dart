@Tags(['tool'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

import '../../tool/trace_proof_inventory.dart' as trace_proof_inventory_tool;

void main() {
  group('tool/trace_proof_inventory.dart', () {
    test(
      'reports the current guardrail and invariant inventory summary',
      () async {
        final sandbox = await Directory.systemTemp.createTemp(
          'iwb_canvas_engine_trace_proof_inventory_tool_test_',
        );
        try {
          final result = await trace_proof_inventory_tool
              .runTraceProofInventoryTool(const <String>[], root: sandbox);

          expect(result.exitCode, 0, reason: result.stderr.toString());
          expect(result.stdout.toString(), contains('Guardrail rules: 6'));
          expect(result.stdout.toString(), contains('Runner artifacts: 2'));
          expect(result.stdout.toString(), contains('Invariants: 101'));
        } finally {
          sandbox.deleteSync(recursive: true);
        }
      },
    );

    test('writes json and markdown artifacts', () async {
      final sandbox = await Directory.systemTemp.createTemp(
        'iwb_canvas_engine_trace_proof_inventory_artifacts_test_',
      );
      try {
        final result = await trace_proof_inventory_tool
            .runTraceProofInventoryTool(const <String>[
              '--json-out=artifacts/proof_inventory.json',
              '--md-out=artifacts/proof_inventory.md',
            ], root: sandbox);

        expect(result.exitCode, 0, reason: result.stderr.toString());
        final jsonFile = File('${sandbox.path}/artifacts/proof_inventory.json');
        final markdownFile = File(
          '${sandbox.path}/artifacts/proof_inventory.md',
        );
        expect(jsonFile.existsSync(), isTrue);
        expect(markdownFile.existsSync(), isTrue);

        final jsonMap =
            jsonDecode(jsonFile.readAsStringSync()) as Map<String, Object?>;
        final artifacts = (jsonMap['runnerArtifacts'] as List<Object?>)
            .cast<Map<String, Object?>>();
        expect(
          artifacts.any(
            (artifact) =>
                artifact['id'] == 'exportedSurfaces' &&
                (artifact['writers'] as List<Object?>).contains(
                  'public-surface',
                ) &&
                (artifact['readers'] as List<Object?>).isEmpty,
          ),
          isTrue,
        );
        expect(
          artifacts.any(
            (artifact) =>
                artifact['id'] == 'effectivePublicExportNamespace' &&
                (artifact['writers'] as List<Object?>).contains(
                  'public-surface',
                ) &&
                (artifact['readers'] as List<Object?>).contains(
                  'public-signature',
                ),
          ),
          isTrue,
        );
        expect(
          markdownFile.readAsStringSync(),
          contains('# Proof Inventory Trace'),
        );
        expect(markdownFile.readAsStringSync(), contains('```mermaid'));
        expect(
          markdownFile.readAsStringSync(),
          contains('tool/check_guardrails.dart'),
        );
        expect(markdownFile.readAsStringSync(), contains('public-surface'));
        expect(
          markdownFile.readAsStringSync(),
          contains('artifact: exportedSurfaces'),
        );
        expect(
          markdownFile.readAsStringSync(),
          contains('artifact: effectivePublicExportNamespace'),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    });

    test('committed proof inventory artifacts are fresh', () async {
      final sandbox = await Directory.systemTemp.createTemp(
        'iwb_canvas_engine_trace_proof_inventory_freshness_test_',
      );
      try {
        final generatedJson = '${sandbox.path}/proof_inventory.generated.json';
        final generatedMarkdown =
            '${sandbox.path}/proof_inventory.generated.md';
        final result = await trace_proof_inventory_tool
            .runTraceProofInventoryTool(<String>[
              '--json-out=$generatedJson',
              '--md-out=$generatedMarkdown',
            ]);

        expect(result.exitCode, 0, reason: result.stderr.toString());
        expect(
          File(
            'docs/proof_architecture/evidence/proof_inventory.json',
          ).readAsStringSync(),
          File(generatedJson).readAsStringSync(),
        );
        expect(
          File(
            'docs/proof_architecture/evidence/proof_inventory.md',
          ).readAsStringSync(),
          File(generatedMarkdown).readAsStringSync(),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    });
  });
}
