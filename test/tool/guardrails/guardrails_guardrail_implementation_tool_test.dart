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
  });
}

const List<String> coveredResolvedGuardrailSelfGuardFiles = <String>[
  'tool/src/guardrails/rules/interactive/mutation_boundary_rules.dart',
  'tool/src/guardrails/rules/interactive/resolved_entrypoint_guard_rules.dart',
  'tool/src/guardrails/rules/interactive/interactive_mutation_owner_guard_rules.dart',
  'tool/src/guardrails/rules/interactive/interactive_architecture_boundary_rules.dart',
  'tool/src/guardrails/rules/controller/write_only_mutation_rules.dart',
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
