@Tags(['tool'])
library;

import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/source/line_info.dart';
import 'package:test/test.dart';

void main() {
  group('guardrail implementation self-guard', () {
    test('covered inventory stays explicit and extendable', () {
      expect(
        coveredResolvedGuardrailSelfGuardFiles,
        orderedEquals(<String>[
          'tool/src/guardrails/core/resolved_surface_contract_support.dart',
          'tool/src/guardrails/core/semantic_sequence_routing_support.dart',
          'tool/src/guardrails/rules/controller/prepared_replace_boundary_rules.dart',
          'tool/src/guardrails/rules/interactive/mutation_boundary_rules.dart',
          'tool/src/guardrails/rules/interactive/resolved_entrypoint_guard_rules.dart',
          'tool/src/guardrails/rules/interactive/interactive_mutation_owner_guard_rules.dart',
          'tool/src/guardrails/rules/interactive/interactive_architecture_boundary_rules.dart',
          'tool/src/guardrails/rules/controller/write_only_mutation_rules.dart',
        ]),
      );
    });

    test(
      'migrated resolved guardrail owners avoid banned raw-source proof APIs',
      () async {
        final repoRoot = Directory.current.absolute;
        final analysisCollection = AnalysisContextCollection(
          includedPaths: <String>[repoRoot.path],
        );
        final violations = <_SelfGuardViolation>[];
        for (final repoRelativePath in coveredResolvedGuardrailSelfGuardFiles) {
          final file = File(
            '${repoRoot.path}${Platform.pathSeparator}$repoRelativePath',
          );
          expect(
            file.existsSync(),
            isTrue,
            reason: 'Missing $repoRelativePath',
          );
          final context = analysisCollection.contextFor(file.absolute.path);
          final result = await context.currentSession.getResolvedUnit(
            file.absolute.path,
          );
          expect(
            result,
            isA<ResolvedUnitResult>(),
            reason: 'Failed to resolve $repoRelativePath',
          );
          final resolved = result as ResolvedUnitResult;
          final collector = _SelfGuardCollector(
            filePath: repoRelativePath,
            lineInfo: resolved.lineInfo,
          );
          resolved.unit.accept(collector);
          violations.addAll(collector.violations);
        }
        expect(
          violations,
          isEmpty,
          reason: violations
              .map((violation) => violation.describe())
              .join('\n'),
        );
      },
    );

    test('detects readAsStringSync invocations via analyzer AST', () {
      final violations = _collectSnippetViolations('''
import 'dart:io';

void check(File file) {
  file.readAsStringSync();
}
''');
      expect(_bannedApis(violations), contains('readAsStringSync'));
    });

    test('detects readAsStringSync tear-offs via analyzer AST', () {
      final violations = _collectSnippetViolations('''
import 'dart:io';

void check(File file) {
  final reader = file.readAsStringSync;
  reader();
}
''');
      expect(_bannedApis(violations), contains('readAsStringSync'));
    });

    test('detects toSource invocations via analyzer AST', () {
      final violations = _collectSnippetViolations('''
import 'package:analyzer/dart/ast/ast.dart';

String emit(AstNode node) {
  return node.toSource();
}
''');
      expect(_bannedApis(violations), contains('toSource'));
    });

    test('detects toSource tear-offs via analyzer AST', () {
      final violations = _collectSnippetViolations('''
import 'package:analyzer/dart/ast/ast.dart';

void check(AstNode node) {
  final emitter = node.toSource;
  emitter();
}
''');
      expect(_bannedApis(violations), contains('toSource'));
    });

    test('detects requireSourceTokens invocations via analyzer AST', () {
      final violations = _collectSnippetViolations('''
void check() {
  requireSourceTokens();
}
''');
      expect(_bannedApis(violations), contains('requireSourceTokens'));
    });

    test('detects requireSourceTokens references via analyzer AST', () {
      final violations = _collectSnippetViolations('''
void check() {
  final fn = requireSourceTokens;
  fn();
}
''');
      expect(_bannedApis(violations), contains('requireSourceTokens'));
    });

    test('detects requireTokenOrder invocations via analyzer AST', () {
      final violations = _collectSnippetViolations('''
void check() {
  requireTokenOrder();
}
''');
      expect(_bannedApis(violations), contains('requireTokenOrder'));
    });

    test('detects requireTokenOrder references via analyzer AST', () {
      final violations = _collectSnippetViolations('''
void check() {
  final fn = requireTokenOrder;
  fn();
}
''');
      expect(_bannedApis(violations), contains('requireTokenOrder'));
    });

    test(
      'detects resolver_purity_rules.dart dependencies via analyzer AST',
      () {
        final violations = _collectSnippetViolations('''
part 'resolver_purity_rules.dart';
''');
        expect(_bannedApis(violations), contains('resolver_purity_rules.dart'));
      },
    );

    test('ignores ordinary diagnostic and path strings', () {
      final violations = _collectSnippetViolations('''
const String diagnostic = 'do not call readAsStringSync or toSource here';
const String path = 'resolver_purity_rules.dart';
''');
      expect(violations, isEmpty);
    });

    test('surface-contract support ownership stays single and explicit', () {
      final repoRoot = Directory.current.absolute;
      final coreDir = Directory(
        '${repoRoot.path}${Platform.pathSeparator}'
        'tool${Platform.pathSeparator}src${Platform.pathSeparator}'
        'guardrails${Platform.pathSeparator}core',
      );
      final surfaceSupportFiles =
          coreDir
              .listSync()
              .whereType<File>()
              .map((file) => file.path.replaceAll('\\', '/'))
              .where((path) => path.endsWith('surface_contract_support.dart'))
              .toList(growable: false)
            ..sort();
      expect(
        surfaceSupportFiles,
        orderedEquals(<String>[
          '${repoRoot.path.replaceAll('\\', '/')}/tool/src/guardrails/core/resolved_surface_contract_support.dart',
        ]),
      );
      expect(
        File(
          '${repoRoot.path}${Platform.pathSeparator}'
          'tool${Platform.pathSeparator}src${Platform.pathSeparator}'
          'guardrails${Platform.pathSeparator}core${Platform.pathSeparator}'
          'public_constructor_surface_support.dart',
        ).existsSync(),
        isFalse,
      );
    });

    test('shared surface-contract seam stays wired into intended consumers', () {
      final repoRoot = Directory.current.absolute;
      for (final repoRelativePath in _surfaceContractImportOwners) {
        final content = File(
          '${repoRoot.path}${Platform.pathSeparator}$repoRelativePath',
        ).readAsStringSync();
        expect(
          content,
          contains('resolved_surface_contract_support.dart'),
          reason:
              '$repoRelativePath must keep importing the shared surface-contract seam.',
        );
      }

      for (final entry in _surfaceContractApiConsumers.entries) {
        final content = File(
          '${repoRoot.path}${Platform.pathSeparator}${entry.key}',
        ).readAsStringSync();
        for (final helperName in entry.value) {
          expect(
            content,
            contains(helperName),
            reason:
                '${entry.key} must consume $helperName from the shared surface-contract seam.',
          );
        }
      }

      for (final repoRelativePath in _surfaceContractGuardedFiles) {
        final content = File(
          '${repoRoot.path}${Platform.pathSeparator}$repoRelativePath',
        ).readAsStringSync();
        for (final bannedName in _bannedParallelSurfaceHelpers) {
          expect(
            content,
            isNot(contains(bannedName)),
            reason:
                '$repoRelativePath must not reintroduce local parallel helper $bannedName.',
          );
        }
      }

      for (final repoRelativePath
          in _interactiveSurfaceContractDirectConsumers) {
        final content = File(
          '${repoRoot.path}${Platform.pathSeparator}$repoRelativePath',
        ).readAsStringSync();
        expect(
          content,
          isNot(contains('_classImplements(')),
          reason:
              '$repoRelativePath must not route interface proof through a family-local helper.',
        );
        expect(
          content,
          isNot(contains('_classHasOnlyUnnamedConstructor(')),
          reason:
              '$repoRelativePath must not route constructor proof through a family-local helper.',
        );
        expect(
          content,
          isNot(contains('_hasClassLikeDeclaration(')),
          reason:
              '$repoRelativePath must not route owner-surface proof through a family-local helper.',
        );
        expect(
          content,
          isNot(contains('_findClassMethodDeclaration(')),
          reason:
              '$repoRelativePath must not route member-surface proof through a family-local helper.',
        );
        expect(
          content,
          isNot(contains('_classOwnsMethod(')),
          reason:
              '$repoRelativePath must not route member-surface proof through a family-local helper.',
        );
        expect(
          content,
          isNot(contains('_findClassByName(')),
          reason:
              '$repoRelativePath must not route owner lookup through a family-local helper.',
        );
        expect(
          content,
          isNot(contains('_findMethodByName(')),
          reason:
              '$repoRelativePath must not route member lookup through a family-local helper.',
        );
      }
    });

    test(
      'semantic sequence/routing support ownership stays single and explicit',
      () {
        final repoRoot = Directory.current.absolute;
        final coreDir = Directory(
          '${repoRoot.path}${Platform.pathSeparator}'
          'tool${Platform.pathSeparator}src${Platform.pathSeparator}'
          'guardrails${Platform.pathSeparator}core',
        );
        final supportFiles =
            coreDir
                .listSync()
                .whereType<File>()
                .map((file) => file.path.replaceAll('\\', '/'))
                .where(
                  (path) =>
                      path.endsWith('semantic_sequence_routing_support.dart'),
                )
                .toList(growable: false)
              ..sort();
        expect(
          supportFiles,
          orderedEquals(<String>[
            '${repoRoot.path.replaceAll('\\', '/')}/tool/src/guardrails/core/semantic_sequence_routing_support.dart',
          ]),
        );
        expect(
          File(
            '${repoRoot.path}${Platform.pathSeparator}'
            'tool${Platform.pathSeparator}src${Platform.pathSeparator}'
            'guardrails${Platform.pathSeparator}rules${Platform.pathSeparator}'
            'interactive${Platform.pathSeparator}'
            'interactive_mutation_owner_sequence_support.dart',
          ).existsSync(),
          isFalse,
        );
      },
    );

    test(
      'shared semantic sequence/routing seam stays wired into intended consumers',
      () {
        final repoRoot = Directory.current.absolute;
        for (final repoRelativePath in _semanticSequenceImportOwners) {
          final content = File(
            '${repoRoot.path}${Platform.pathSeparator}$repoRelativePath',
          ).readAsStringSync();
          expect(
            content,
            contains('semantic_sequence_routing_support.dart'),
            reason:
                '$repoRelativePath must keep importing the shared semantic sequence/routing seam.',
          );
        }

        for (final entry in _semanticSequenceApiConsumers.entries) {
          final content = File(
            '${repoRoot.path}${Platform.pathSeparator}${entry.key}',
          ).readAsStringSync();
          for (final helperName in entry.value) {
            expect(
              content,
              contains(helperName),
              reason:
                  '${entry.key} must consume $helperName from the shared semantic sequence/routing seam.',
            );
          }
        }

        for (final repoRelativePath in _semanticSequenceGuardedFiles) {
          final content = File(
            '${repoRoot.path}${Platform.pathSeparator}$repoRelativePath',
          ).readAsStringSync();
          for (final bannedName in _bannedParallelSequenceHelpers) {
            expect(
              content,
              isNot(contains(bannedName)),
              reason:
                  '$repoRelativePath must not reintroduce local parallel sequence/routing helper $bannedName.',
            );
          }
        }

        for (final repoRelativePath
            in _semanticSequenceRoutingDirectConsumers) {
          final content = File(
            '${repoRoot.path}${Platform.pathSeparator}$repoRelativePath',
          ).readAsStringSync();
          expect(
            content,
            isNot(contains('interruptAlias')),
            reason:
                '$repoRelativePath must not expand direct routing proof to alias forwarding.',
          );
          expect(
            content,
            isNot(contains('_SelectionRoutingCollector(')),
            reason:
                '$repoRelativePath must not reintroduce a family-local invocation routing collector.',
          );
        }
      },
    );
  });
}

const List<String> coveredResolvedGuardrailSelfGuardFiles = <String>[
  'tool/src/guardrails/core/resolved_surface_contract_support.dart',
  'tool/src/guardrails/core/semantic_sequence_routing_support.dart',
  'tool/src/guardrails/rules/controller/prepared_replace_boundary_rules.dart',
  'tool/src/guardrails/rules/interactive/mutation_boundary_rules.dart',
  'tool/src/guardrails/rules/interactive/resolved_entrypoint_guard_rules.dart',
  'tool/src/guardrails/rules/interactive/interactive_mutation_owner_guard_rules.dart',
  'tool/src/guardrails/rules/interactive/interactive_architecture_boundary_rules.dart',
  'tool/src/guardrails/rules/controller/write_only_mutation_rules.dart',
];

const List<String> _surfaceContractImportOwners = <String>[
  'tool/src/guardrails/rules/controller/write_only_mutation_rules.dart',
  'tool/src/guardrails/rules/interactive/mutation_boundary_rules.dart',
];

const List<String> _semanticSequenceImportOwners = <String>[
  'tool/src/guardrails/rules/controller/write_only_mutation_rules.dart',
  'tool/src/guardrails/rules/interactive/mutation_boundary_rules.dart',
];

const Map<String, List<String>>
_semanticSequenceApiConsumers = <String, List<String>>{
  'tool/src/guardrails/rules/interactive/resolved_entrypoint_guard_rules.dart':
      <String>['scanEntrypointGuard'],
  'tool/src/guardrails/rules/interactive/interactive_mutation_owner_guard_rules.dart':
      <String>[
        'evaluateRequiredGuardSequence',
        'isAllowedPurePreludeStatement',
        'extractStatementExpression',
        'hasNamedArgumentMatching',
      ],
  'tool/src/guardrails/rules/controller/write_only_mutation_rules.dart':
      <String>['analyzeDirectInvocationRouting'],
};

const Map<String, List<String>>
_surfaceContractApiConsumers = <String, List<String>>{
  'tool/src/guardrails/rules/controller/prepared_replace_boundary_rules.dart':
      <String>[
        'validateExactPublicTopLevelSurface',
        'validateExactPublicMemberSurface',
        'validateExactImplementedInterfaces',
        'validateExactMethodSignature',
      ],
  'tool/src/guardrails/rules/interactive/interactive_mutation_owner_guard_rules.dart':
      <String>['findClassDeclarationByName', 'findMethodDeclarationByName'],
  'tool/src/guardrails/rules/interactive/interactive_architecture_boundary_view_rules.dart':
      <String>[
        'hasClassLikeDeclaration',
        'findClassMethodDeclarationInParsedUnit',
        'classOwnsMethod',
      ],
  'tool/src/guardrails/rules/interactive/interactive_architecture_boundary_facade_rules.dart':
      <String>['findClassDeclarationByName', 'classImplementsNamedInterface'],
  'tool/src/guardrails/rules/interactive/interactive_architecture_boundary_view_surface_rules.dart':
      <String>[
        'findClassDeclarationByName',
        'findMethodDeclarationByName',
        'classHasOnlyUnnamedConstructor',
      ],
  'tool/src/guardrails/rules/interactive/interactive_architecture_boundary_pointer_rules.dart':
      <String>[
        'findClassDeclarationByName',
        'findMethodDeclarationByName',
        'classImplementsNamedInterface',
      ],
};

const List<String> _surfaceContractGuardedFiles = <String>[
  'tool/src/guardrails/rules/controller/prepared_replace_boundary_rules.dart',
  'tool/src/guardrails/rules/controller/write_only_mutation_rules.dart',
  'tool/src/guardrails/rules/interactive/mutation_boundary_rules.dart',
  'tool/src/guardrails/rules/interactive/interactive_mutation_owner_guard_rules.dart',
  'tool/src/guardrails/rules/interactive/interactive_architecture_boundary_rules.dart',
];

const List<String> _semanticSequenceGuardedFiles = <String>[
  'tool/src/guardrails/rules/controller/write_only_mutation_rules.dart',
  'tool/src/guardrails/rules/interactive/resolved_entrypoint_guard_rules.dart',
  'tool/src/guardrails/rules/interactive/interactive_mutation_owner_guard_rules.dart',
];

const List<String> _semanticSequenceRoutingDirectConsumers = <String>[
  'tool/src/guardrails/rules/controller/write_only_mutation_rules.dart',
  'tool/src/guardrails/rules/interactive/interactive_mutation_owner_guard_rules.dart',
];

const List<String> _interactiveSurfaceContractDirectConsumers = <String>[
  'tool/src/guardrails/rules/interactive/interactive_mutation_owner_guard_rules.dart',
  'tool/src/guardrails/rules/interactive/interactive_architecture_boundary_view_rules.dart',
  'tool/src/guardrails/rules/interactive/interactive_architecture_boundary_facade_rules.dart',
  'tool/src/guardrails/rules/interactive/interactive_architecture_boundary_view_surface_rules.dart',
  'tool/src/guardrails/rules/interactive/interactive_architecture_boundary_pointer_rules.dart',
];

const List<String> _bannedParallelSurfaceHelpers = <String>[
  '_publicTopLevelSurfaceViolation',
  '_publicMemberSurfaceViolation',
  '_singleUnnamedPublicConstructorViolation',
  '_explicitPublicConstructorViolation',
  '_preparedReplaceMethodSignatureViolation',
];

const List<String> _bannedParallelSequenceHelpers = <String>[
  '_scanEntrypointGuard',
  '_evaluateMutationOwnerGuardedSequence',
  '_evaluateSetCameraOffsetSequence',
  '_SelectionRoutingCollector',
];

List<_SelfGuardViolation> _collectSnippetViolations(String content) {
  final parsed = parseString(
    content: content,
    path: '/guardrail_self_guard_test.dart',
    throwIfDiagnostics: false,
  );
  final collector = _SelfGuardCollector(
    filePath: '/guardrail_self_guard_test.dart',
    lineInfo: parsed.lineInfo,
  );
  parsed.unit.accept(collector);
  return collector.violations;
}

Iterable<String> _bannedApis(Iterable<_SelfGuardViolation> violations) sync* {
  for (final violation in violations) {
    yield violation.api;
  }
}

final class _SelfGuardCollector extends RecursiveAstVisitor<void> {
  _SelfGuardCollector({required this.filePath, required this.lineInfo});

  final String filePath;
  final LineInfo lineInfo;
  final List<_SelfGuardViolation> violations = <_SelfGuardViolation>[];

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final name = node.methodName.name;
    if (_isBannedApiName(name)) {
      _record(api: name, offset: node.methodName.offset);
    }
    super.visitMethodInvocation(node);
  }

  @override
  void visitPropertyAccess(PropertyAccess node) {
    final name = node.propertyName.name;
    if (_isBannedApiName(name) && !_isInvokedPropertyName(node.propertyName)) {
      _record(api: name, offset: node.propertyName.offset);
    }
    super.visitPropertyAccess(node);
  }

  @override
  void visitPrefixedIdentifier(PrefixedIdentifier node) {
    final name = node.identifier.name;
    if (_isBannedApiName(name) && !_isInvokedPropertyName(node.identifier)) {
      _record(api: name, offset: node.identifier.offset);
    }
    super.visitPrefixedIdentifier(node);
  }

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    final name = node.name;
    if (_isBannedFreeFunctionName(name) && _isBareReference(node)) {
      _record(api: name, offset: node.offset);
    }
    super.visitSimpleIdentifier(node);
  }

  @override
  void visitImportDirective(ImportDirective node) {
    _checkDeletedDependency(node.uri.stringValue, node.uri.offset);
    super.visitImportDirective(node);
  }

  @override
  void visitExportDirective(ExportDirective node) {
    _checkDeletedDependency(node.uri.stringValue, node.uri.offset);
    super.visitExportDirective(node);
  }

  @override
  void visitPartDirective(PartDirective node) {
    _checkDeletedDependency(node.uri.stringValue, node.uri.offset);
    super.visitPartDirective(node);
  }

  void _checkDeletedDependency(String? uri, int offset) {
    if (uri == null || !uri.endsWith('resolver_purity_rules.dart')) {
      return;
    }
    _record(api: 'resolver_purity_rules.dart', offset: offset);
  }

  void _record({required String api, required int offset}) {
    violations.add(
      _SelfGuardViolation(
        filePath: filePath,
        line: lineInfo.getLocation(offset).lineNumber,
        api: api,
      ),
    );
  }
}

bool _isBannedApiName(String name) {
  return name == 'readAsStringSync' ||
      name == 'toSource' ||
      name == 'requireSourceTokens' ||
      name == 'requireTokenOrder';
}

bool _isBannedFreeFunctionName(String name) {
  return name == 'requireSourceTokens' || name == 'requireTokenOrder';
}

bool _isInvokedPropertyName(SimpleIdentifier identifier) {
  final parent = identifier.parent;
  return parent is MethodInvocation && identical(parent.methodName, identifier);
}

bool _isBareReference(SimpleIdentifier identifier) {
  final parent = identifier.parent;
  if (parent is MethodInvocation && identical(parent.methodName, identifier)) {
    return false;
  }
  if (parent is PrefixedIdentifier &&
      identical(parent.identifier, identifier)) {
    return false;
  }
  if (parent is PropertyAccess && identical(parent.propertyName, identifier)) {
    return false;
  }
  if (parent is NamedType && identical(parent.name, identifier)) {
    return false;
  }
  return true;
}

final class _SelfGuardViolation {
  const _SelfGuardViolation({
    required this.filePath,
    required this.line,
    required this.api,
  });

  final String filePath;
  final int line;
  final String api;

  String describe() =>
      '$filePath:$line reintroduced banned guardrail proof API: $api';
}
