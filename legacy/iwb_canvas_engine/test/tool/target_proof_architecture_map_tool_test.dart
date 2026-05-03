@Tags(['tool'])
library;

import 'dart:io';

import 'package:test/test.dart';

void main() {
  group('proof architecture atlas migration smoke checks', () {
    test('proof overview routes to every proof family id', () {
      final source = File(
        'docs/proof_architecture/overview.md',
      ).readAsStringSync();

      for (final id in const <String>[
        'public_entrypoint_and_signature_proof',
        'guardrail_runner_and_artifact_model',
        'invariant_registry_and_proof_reachability',
        'verification_contract_and_workflow_drift',
      ]) {
        expect(source, contains('`$id`'));
        expect(source, contains('(families/$id.md)'));
      }
    });

    test('old target proof architecture directory is retired', () {
      expect(Directory('docs/target_proof_architecture').existsSync(), isFalse);
    });

    test('existing proof evidence moved under the proof atlas', () {
      for (final path in const <String>[
        'docs/proof_architecture/evidence/proof_inventory.json',
        'docs/proof_architecture/evidence/proof_inventory.md',
        'docs/proof_architecture/evidence/public_export_namespace.json',
        'docs/proof_architecture/evidence/public_export_namespace.md',
      ]) {
        expect(File(path).existsSync(), isTrue, reason: 'Missing $path');
      }
    });
  });
}
