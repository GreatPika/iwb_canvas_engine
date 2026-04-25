@Tags(['tool'])
library;

import 'dart:io';

import 'package:test/test.dart';

void main() {
  group('docs/target_proof_architecture top-level map', () {
    test('README defines the normalized directory contract', () {
      final source = _read('docs/target_proof_architecture/README.md');

      _expectSections(source, const <String>[
        '## Purpose',
        '## Directory Roles',
        '## Mechanical Evidence',
        '## Verification Workflow',
        '## Update Rules',
      ]);
      _expectContainsAll(source, const <String>[
        'overview.md',
        'families/*.md',
        'proof_flows.md',
        'evidence/',
        'PLAN.md',
        'dart run tool/trace_export_namespace.dart lib/iwb_canvas_engine.dart --json-out=<file> --md-out=<file>',
        'dart run tool/trace_proof_inventory.dart --json-out=<file> --md-out=<file>',
        'dart run tool/check_public_api_surface.dart',
        'dart run tool/check_guardrails.dart',
        'dart run tool/check_invariant_coverage.dart',
        'dart run tool/run_tool_tests.dart test/tool/target_proof_architecture_map_tool_test.dart',
      ]);
    });

    test(
      'overview defines the proof-family registry and status vocabulary',
      () {
        final source = _read('docs/target_proof_architecture/overview.md');

        _expectSections(source, const <String>[
          '## Purpose',
          '## Verification Status Vocabulary',
          '## Proof Family Registry',
          '## Mechanical Evidence',
          '## Update Rules',
        ]);
        _expectContainsAll(source, const <String>[
          '`locked`',
          '`provisional`',
          '`docs stale`',
          'Public entrypoint and signature proof',
          'Guardrail runner and artifact model',
          'Invariant registry and proof reachability',
          'test/tool/target_proof_architecture_map_tool_test.dart',
        ]);

        final statuses = _registryStatuses(source);
        expect(statuses, hasLength(3));
        for (final status in statuses) {
          expect(_allowedStatuses, contains(status));
        }
      },
    );

    test('proof flows stays limited to committed proof registries', () {
      final source = _read('docs/target_proof_architecture/proof_flows.md');

      _expectSections(source, const <String>[
        '## Purpose',
        '## Proof-Flow Registry',
        '## Update Rules',
      ]);
      _expectContainsAll(source, const <String>[
        'Public export namespace',
        'Guardrail runner artifact pipeline',
        'Invariant proof registry',
      ]);

      final evidenceLinks = _evidenceLinks(source);
      expect(
        evidenceLinks,
        equals(<String>{
          'evidence/public_export_namespace.md',
          'evidence/proof_inventory.md',
        }),
      );
      for (final link in evidenceLinks) {
        expect(
          File('docs/target_proof_architecture/$link').existsSync(),
          isTrue,
          reason:
              'Missing proof-map evidence artifact docs/target_proof_architecture/$link',
        );
      }
    });

    test('public namespace family records the provisional namespace split', () {
      final source = _read(
        'docs/target_proof_architecture/families/public_entrypoint_and_signature_proof.md',
      );

      _expectSections(source, const <String>[
        '## Purpose',
        '## Target Rules',
        '## Owners',
        '## Forbidden Shapes',
        '## Mechanical Evidence',
        '## Status',
      ]);
      _expectContainsAll(source, const <String>[
        'tool/check_public_api_surface.dart',
        'tool/src/guardrails/rules/public/public_surface_rules.dart',
        'tool/src/guardrails/rules/public/public_signature_rules.dart',
        'trace_export_namespace.dart',
        '`provisional`',
      ]);
    });

    test('guardrail runner family records the shared artifact model', () {
      final source = _read(
        'docs/target_proof_architecture/families/guardrail_runner_and_artifact_model.md',
      );

      _expectSections(source, const <String>[
        '## Purpose',
        '## Target Rules',
        '## Owners',
        '## Forbidden Shapes',
        '## Mechanical Evidence',
        '## Status',
      ]);
      _expectContainsAll(source, const <String>[
        'tool/check_guardrails.dart',
        'tool/src/guardrails/guardrails_runner.dart',
        'tool/src/guardrails/guardrail_rule_inventory.dart',
        'tool/src/guardrails/core/guardrail_run_state.dart',
        'exportedSurfaces',
        'trace_proof_inventory.dart',
        '`provisional`',
      ]);
    });

    test('invariant family records the locked reachability model', () {
      final source = _read(
        'docs/target_proof_architecture/families/invariant_registry_and_proof_reachability.md',
      );

      _expectSections(source, const <String>[
        '## Purpose',
        '## Target Rules',
        '## Owners',
        '## Forbidden Shapes',
        '## Mechanical Evidence',
        '## Status',
      ]);
      _expectContainsAll(source, const <String>[
        'tool/invariant_registry.dart',
        'tool/check_invariant_coverage.dart',
        'tool/src/verification_contract/verification_contract_registry.dart',
        'trace_proof_inventory.dart',
        '`locked`',
      ]);
    });
  });
}

const Set<String> _allowedStatuses = <String>{
  'locked',
  'provisional',
  'docs stale',
};

String _read(String path) => File(path).readAsStringSync();

void _expectSections(String source, List<String> sections) {
  for (final section in sections) {
    expect(source, contains(section), reason: 'Missing section $section');
  }
}

void _expectContainsAll(String source, List<String> snippets) {
  for (final snippet in snippets) {
    expect(source, contains(snippet), reason: 'Missing snippet $snippet');
  }
}

Set<String> _evidenceLinks(String source) {
  final matches = RegExp(r'\((evidence/[^)]+\.md)\)').allMatches(source);
  return matches.map((match) => match.group(1)!).toSet();
}

List<String> _registryStatuses(String source) {
  final matches = RegExp(r'\|\s*`([^`]+)`\s*\|').allMatches(source);
  return matches.map((match) => match.group(1)!).toList(growable: false);
}
