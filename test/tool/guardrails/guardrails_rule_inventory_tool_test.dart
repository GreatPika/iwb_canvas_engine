@Tags(['tool'])
library;

import 'dart:io';

import 'package:test/test.dart';

import '../../../tool/invariant_registry.dart';
import '../../../tool/src/guardrails/core/guardrail_rule.dart';
import '../../../tool/src/guardrails/core/guardrail_rule_metadata.dart';
import '../../../tool/src/guardrails/core/guardrail_run_state.dart';
import '../../../tool/src/guardrails/core/guardrail_violation.dart';
import '../../../tool/src/guardrails/guardrail_rule_inventory.dart';
import '../../../tool/src/guardrails/rules/public/public_signature_rules.dart';
import '../../../tool/src/guardrails/support/guardrail_context.dart';
import '../support/guardrails_tool_test_support.dart';
import '../support/public_entrypoint_contract.dart';
import '../support/tool_process_test_support.dart';

void main() {
  group('guardrail rule inventory', () {
    test('inventory rule ids stay unique and invariant ids resolve', () {
      final validation = validateInventory(
        inventory: guardrailRuleInventory,
        knownInvariantIds: invariantIdSet,
      );

      expect(validation.duplicateRuleIds, isEmpty);
      expect(validation.unknownInvariantIds, isEmpty);
    });

    test('inventory stays immutable at runtime', () {
      expect(
        () => guardrailRuleInventory.add(
          _testRule(
            id: 'forbidden',
            invariantIds: const <String>['INV-ENG-SAFE-TXN-API'],
          ),
        ),
        throwsUnsupportedError,
      );
    });

    test('tool invariant markers stay aligned with inventory ownership', () {
      final toolInvariantIds = _parseToolInvariantIds(
        File(
          '${Directory.current.path}/tool/check_guardrails.dart',
        ).readAsStringSync(),
      );

      expect(
        toolInvariantIds,
        orderedEquals(_inventoryInvariantIds(guardrailRuleInventory)),
      );
    });

    test(
      'runner uses the declarative inventory instead of direct stage calls',
      () {
        final content = File(
          '${Directory.current.path}/tool/src/guardrails/guardrails_runner.dart',
        ).readAsStringSync();

        expect(content, contains("import 'guardrail_rule_inventory.dart';"));
        expect(
          content,
          isNot(contains("import 'rules/public/public_surface_rules.dart';")),
        );
        expect(
          content,
          isNot(
            contains(
              'final publicSurfaceResult = await runPublicSurfaceGuardrails(',
            ),
          ),
        );
        expect(
          content,
          contains('for (final rule in guardrailRuleInventory) {'),
        );
      },
    );

    test('doc inventory and invariant map stay aligned with code', () {
      final content = File(
        '${Directory.current.path}/doc/guardrails_state_map.md',
      ).readAsStringSync();
      final documentedInventory = parseDocumentedInventory(content);
      final documentedInvariantMap = parseDocumentedInvariantMap(content);

      expect(
        documentedInventory,
        orderedEquals(
          guardrailRuleInventory.map(_documentedEntryForRule).toList(),
        ),
      );
      expect(
        documentedInvariantMap,
        equals(_expectedInvariantMap(guardrailRuleInventory)),
      );
    });

    test('exportedSurfaces handoff stays single-writer and single-reader', () {
      final exportedSurfacesWriters = guardrailRuleInventory
          .where(
            (rule) => rule.metadata.writesStateArtifacts.contains(
              GuardrailRunState.exportedSurfacesArtifact,
            ),
          )
          .map((rule) => rule.metadata.id)
          .toList(growable: false);
      final exportedSurfacesReaders = guardrailRuleInventory
          .where(
            (rule) => rule.metadata.readsStateArtifacts.contains(
              GuardrailRunState.exportedSurfacesArtifact,
            ),
          )
          .map((rule) => rule.metadata.id)
          .toList(growable: false);

      expect(
        exportedSurfacesWriters,
        orderedEquals(<String>['public-surface']),
      );
      expect(
        exportedSurfacesReaders,
        orderedEquals(<String>['public-signature']),
      );
    });

    test(
      'public-signature stage fails clearly without exportedSurfaces state',
      () async {
        final sandbox = await createGuardrailsSandbox();
        try {
          writeCanonicalPublicExportScaffold(sandbox);
          final context = GuardrailContext.forDirectory(sandbox);
          final state = GuardrailRunState();

          expect(
            () => state.runWithRuleContract(
              metadata: publicSignatureGuardrailRule.metadata,
              action: () => publicSignatureGuardrailRule.run(context, state),
            ),
            throwsA(
              isA<GuardrailToolFailure>().having(
                (failure) => failure.violation.message,
                'message',
                contains(
                  'declares runner artifact exportedSurfaces as required input before it exists',
                ),
              ),
            ),
          );
        } finally {
          sandbox.deleteSync(recursive: true);
        }
      },
    );

    test('runner contract rejects undeclared artifact writes', () async {
      final sandbox = await createGuardrailsSandbox();
      final state = GuardrailRunState();
      try {
        final context = GuardrailContext.forDirectory(sandbox);
        final rule = GuardrailRule(
          metadata: const GuardrailRuleMetadata(
            id: 'bad-writer',
            invariantIds: <String>['INV-ENG-SAFE-TXN-API'],
            area: 'test',
            description: 'test',
          ),
          run: (context, state) async {
            state.writeArtifact(
              artifactId: GuardrailRunState.exportedSurfacesArtifact,
              value: <String, Object>{},
            );
            return const <GuardrailViolation>[];
          },
        );

        expect(
          () => state.runWithRuleContract(
            metadata: rule.metadata,
            action: () => rule.run(context, state),
          ),
          throwsA(
            isA<GuardrailToolFailure>().having(
              (failure) => failure.violation.message,
              'message',
              contains('wrote undeclared runner artifact exportedSurfaces'),
            ),
          ),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    });

    test('runner contract rejects declared but unread artifacts', () async {
      final sandbox = await createGuardrailsSandbox();
      final state = GuardrailRunState();
      try {
        final context = GuardrailContext.forDirectory(sandbox);
        final preloadRule = GuardrailRule(
          metadata: const GuardrailRuleMetadata(
            id: 'preload-writer',
            invariantIds: <String>['INV-ENG-SAFE-TXN-API'],
            area: 'test',
            description: 'test',
            writesStateArtifacts: <String>[
              GuardrailRunState.exportedSurfacesArtifact,
            ],
          ),
          run: (context, state) async {
            state.writeArtifact(
              artifactId: GuardrailRunState.exportedSurfacesArtifact,
              value: <String, Object>{},
            );
            return const <GuardrailViolation>[];
          },
        );
        await state.runWithRuleContract(
          metadata: preloadRule.metadata,
          action: () => preloadRule.run(context, state),
        );

        final rule = GuardrailRule(
          metadata: const GuardrailRuleMetadata(
            id: 'lazy-reader',
            invariantIds: <String>['INV-ENG-PUBLIC-SIGNATURE-HERMETICITY'],
            area: 'test',
            description: 'test',
            readsStateArtifacts: <String>[
              GuardrailRunState.exportedSurfacesArtifact,
            ],
          ),
          run: (context, state) async => const <GuardrailViolation>[],
        );

        expect(
          () => state.runWithRuleContract(
            metadata: rule.metadata,
            action: () => rule.run(context, state),
          ),
          throwsA(
            isA<GuardrailToolFailure>().having(
              (failure) => failure.violation.message,
              'message',
              contains('declared unread runner artifacts exportedSurfaces'),
            ),
          ),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    });

    test('real tool keeps inventory order and fail-fast behavior', () async {
      final sandbox = await createGuardrailsSandbox();
      try {
        writeCanonicalPublicExportScaffold(sandbox);
        writeMinimalControllerStore(sandbox);
        writeSandboxFile(
          sandbox,
          'lib/iwb_canvas_engine.dart',
          "${canonicalPublicEntrypoint()}export 'src/core/scene.dart';\n",
        );
        writeSandboxFile(sandbox, 'lib/src/model/document.dart', '''
part 'rogue.part.dart';
''');
        writeSandboxFile(sandbox, 'lib/src/model/rogue.part.dart', '// stub\n');

        final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
        final stderr = result.stderr.toString();

        expect(result.exitCode, isNonZero);
        expect(stderr, contains('public export violation:'));
        expect(
          stderr,
          contains(
            'lib/iwb_canvas_engine.dart must not export mutable core model',
          ),
        );
        expect(stderr, isNot(contains('model architecture violation:')));
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    });

    test('duplicate rule ids are rejected by inventory validation', () {
      final duplicatedInventory = <GuardrailRule>[
        _testRule(
          id: 'duplicate',
          invariantIds: const <String>['INV-ENG-SAFE-TXN-API'],
        ),
        _testRule(
          id: 'duplicate',
          invariantIds: const <String>['INV-ENG-PUBLIC-SIGNATURE-HERMETICITY'],
        ),
      ];

      final validation = validateInventory(
        inventory: duplicatedInventory,
        knownInvariantIds: invariantIdSet,
      );

      expect(validation.duplicateRuleIds, orderedEquals(<String>['duplicate']));
    });

    test('unknown invariant ids are rejected by inventory validation', () {
      final validation = validateInventory(
        inventory: <GuardrailRule>[
          _testRule(
            id: 'broken',
            invariantIds: const <String>['INV-ENG-NOT-REAL'],
          ),
        ],
        knownInvariantIds: invariantIdSet,
      );

      expect(
        validation.unknownInvariantIds,
        orderedEquals(<String>['INV-ENG-NOT-REAL']),
      );
    });

    test(
      'doc drift is rejected when documented inventory omits a state read',
      () {
        const content = '''
## Declarative Runner Inventory
- `public-signature` | area=`public` | file=`rules/public/public_signature_rules.dart` | invariants=`INV-ENG-PUBLIC-SIGNATURE-HERMETICITY` | reads=`none` | writes=`none`

## Invariant-to-Rule Map
- `INV-ENG-PUBLIC-SIGNATURE-HERMETICITY` -> `public-signature`
''';

        expect(
          parseDocumentedInventory(content),
          isNot(
            orderedEquals(<DocumentedRuleEntry>[
              const DocumentedRuleEntry(
                id: 'public-signature',
                area: 'public',
                file: 'rules/public/public_signature_rules.dart',
                invariants: <String>['INV-ENG-PUBLIC-SIGNATURE-HERMETICITY'],
                reads: <String>[GuardrailRunState.exportedSurfacesArtifact],
                writes: <String>[],
              ),
            ]),
          ),
        );
      },
    );
  });
}

final Set<String> invariantIdSet = invariants
    .map((invariant) => invariant.id)
    .toSet();

InventoryValidation validateInventory({
  required List<GuardrailRule> inventory,
  required Set<String> knownInvariantIds,
}) {
  final counts = <String, int>{};
  final unknownInvariantIds = <String>{};
  for (final rule in inventory) {
    counts.update(rule.metadata.id, (value) => value + 1, ifAbsent: () => 1);
    for (final invariantId in rule.metadata.invariantIds) {
      if (!knownInvariantIds.contains(invariantId)) {
        unknownInvariantIds.add(invariantId);
      }
    }
  }

  final duplicateRuleIds =
      counts.entries
          .where((entry) => entry.value > 1)
          .map((entry) => entry.key)
          .toList(growable: false)
        ..sort();
  final sortedUnknownInvariantIds = unknownInvariantIds.toList(growable: false)
    ..sort();

  return InventoryValidation(
    duplicateRuleIds: duplicateRuleIds,
    unknownInvariantIds: sortedUnknownInvariantIds,
  );
}

List<DocumentedRuleEntry> parseDocumentedInventory(String content) {
  final section = _sectionBody(content, 'Declarative Runner Inventory');
  final matches = RegExp(
    r"- `([^`]+)` \| area=`([^`]+)` \| file=`([^`]+)` \| invariants=`([^`]*)` \| reads=`([^`]*)` \| writes=`([^`]*)`",
    multiLine: true,
  ).allMatches(section);
  return matches
      .map(
        (match) => DocumentedRuleEntry(
          id: _requireGroup(match, 1),
          area: _requireGroup(match, 2),
          file: _requireGroup(match, 3),
          invariants: _splitList(_requireGroup(match, 4)),
          reads: _splitList(_requireGroup(match, 5)),
          writes: _splitList(_requireGroup(match, 6)),
        ),
      )
      .toList(growable: false);
}

Map<String, List<String>> parseDocumentedInvariantMap(String content) {
  final section = _sectionBody(content, 'Invariant-to-Rule Map');
  final matches = RegExp(
    r"- `([^`]+)` -> `([^`]+)`(?:, `([^`]+)`)?(?:, `([^`]+)`)?",
    multiLine: true,
  ).allMatches(section);
  final result = <String, List<String>>{};
  for (final match in matches) {
    final rules = <String?>[
      match.group(2),
      match.group(3),
      match.group(4),
    ].whereType<String>().toList(growable: false)..sort();
    result[_requireGroup(match, 1)] = rules;
  }
  return result;
}

List<String> _parseToolInvariantIds(String content) {
  return (RegExp(r'^// INV:([A-Z0-9-]+)$', multiLine: true)
      .allMatches(content)
      .map((match) => _requireGroup(match, 1))
      .toList(growable: false)
    ..sort());
}

List<String> _inventoryInvariantIds(List<GuardrailRule> inventory) {
  final ids = <String>{};
  for (final rule in inventory) {
    ids.addAll(rule.metadata.invariantIds);
  }
  return ids.toList(growable: false)..sort();
}

DocumentedRuleEntry _documentedEntryForRule(GuardrailRule rule) {
  return DocumentedRuleEntry(
    id: rule.metadata.id,
    area: rule.metadata.area,
    file: _requireRuleFile(rule.metadata.id),
    invariants: rule.metadata.invariantIds,
    reads: rule.metadata.readsStateArtifacts,
    writes: rule.metadata.writesStateArtifacts,
  );
}

Map<String, List<String>> _expectedInvariantMap(List<GuardrailRule> inventory) {
  final result = <String, List<String>>{};
  for (final rule in inventory) {
    for (final invariantId in rule.metadata.invariantIds) {
      result.putIfAbsent(invariantId, () => <String>[]).add(rule.metadata.id);
    }
  }
  for (final entry in result.entries) {
    entry.value.sort();
  }
  return result;
}

List<String> _splitList(String raw) {
  if (raw == 'none' || raw.isEmpty) {
    return const <String>[];
  }
  return raw.split(', ').toList(growable: false);
}

String _sectionBody(String content, String title) {
  final pattern = RegExp(
    '^## $title\\n([\\s\\S]*?)(?=^## |\\z)',
    multiLine: true,
  );
  final match = pattern.firstMatch(content);
  if (match == null) {
    fail('Missing section: $title');
  }
  return _requireGroup(match, 1);
}

GuardrailRule _testRule({
  required String id,
  required List<String> invariantIds,
}) {
  return GuardrailRule(
    metadata: GuardrailRuleMetadata(
      id: id,
      invariantIds: invariantIds,
      area: 'test',
      description: 'test',
    ),
    run: (context, state) async => const <GuardrailViolation>[],
  );
}

const Map<String, String> _ruleFileById = <String, String>{
  'public-surface': 'rules/public/public_surface_rules.dart',
  'public-signature': 'rules/public/public_signature_rules.dart',
  'interactive-api': 'rules/interactive/mutation_boundary_rules.dart',
  'controller-api': 'rules/controller/write_only_mutation_rules.dart',
  'model-architecture': 'rules/model/model_architecture_rules.dart',
  'contract-architecture': 'rules/contract/contract_architecture_rules.dart',
};

final class InventoryValidation {
  const InventoryValidation({
    required this.duplicateRuleIds,
    required this.unknownInvariantIds,
  });

  final List<String> duplicateRuleIds;
  final List<String> unknownInvariantIds;
}

final class DocumentedRuleEntry {
  const DocumentedRuleEntry({
    required this.id,
    required this.area,
    required this.file,
    required this.invariants,
    required this.reads,
    required this.writes,
  });

  final String id;
  final String area;
  final String file;
  final List<String> invariants;
  final List<String> reads;
  final List<String> writes;

  @override
  bool operator ==(Object other) {
    return other is DocumentedRuleEntry &&
        id == other.id &&
        area == other.area &&
        file == other.file &&
        _listEquals(invariants, other.invariants) &&
        _listEquals(reads, other.reads) &&
        _listEquals(writes, other.writes);
  }

  @override
  int get hashCode => Object.hash(
    id,
    area,
    file,
    Object.hashAll(invariants),
    Object.hashAll(reads),
    Object.hashAll(writes),
  );
}

bool _listEquals(List<String> left, List<String> right) {
  if (left.length != right.length) {
    return false;
  }
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) {
      return false;
    }
  }
  return true;
}

String _requireGroup(RegExpMatch match, int group) {
  final value = match.group(group);
  if (value == null) {
    fail('Missing regex group $group for match ${match.group(0)}');
  }
  return value;
}

String _requireRuleFile(String ruleId) {
  final file = _ruleFileById[ruleId];
  if (file == null) {
    fail('Missing documented owner file for guardrail rule $ruleId');
  }
  return file;
}
