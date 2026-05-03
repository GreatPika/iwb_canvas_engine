import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/analysis/utilities.dart';

import 'src/guardrails/rules/public/public_export_namespace_support.dart';
import 'src/guardrails/support/guardrail_context.dart';
import 'src/tool_command_result.dart';

Future<ToolCommandResult> runAuditBridgeSurfacesTool(
  List<String> args, {
  Directory? root,
}) async {
  final workingRoot = root ?? Directory.current;
  final jsonOutput = args.contains('--json');
  final targetArgs = args.where((arg) => !arg.startsWith('--')).toList();
  final targets = targetArgs.isEmpty
      ? _loadBridgeSurfaceTargets(workingRoot)
      : targetArgs;

  if (targets.isEmpty) {
    return const ToolCommandResult(
      exitCode: 1,
      stderr: 'FAIL: no bridge surfaces resolved for audit.\n',
    );
  }

  final guardrailContext = GuardrailContext.forDirectory(workingRoot);
  final violations = <_BridgeSurfaceViolation>[];
  for (final target in targets) {
    final file = File(
      target.startsWith('/')
          ? target
          : '${workingRoot.path}${Platform.pathSeparator}$target',
    );
    if (!file.existsSync()) {
      violations.add(
        _BridgeSurfaceViolation(
          filePath: target,
          categories: const <String>['missing-surface'],
          carrierCategories: const <String>[],
          symbols: const <String>[],
        ),
      );
      continue;
    }

    final resolvedLibrary = await guardrailContext.getResolvedLibraryResult(
      file.absolute.path,
    );
    if (resolvedLibrary == null) {
      violations.add(
        _BridgeSurfaceViolation(
          filePath: _repoRelativePath(workingRoot, file),
          categories: const <String>['unresolved-surface'],
          carrierCategories: const <String>[],
          symbols: const <String>[],
        ),
      );
      continue;
    }

    final exportedNames = <String>{
      ..._collectEffectivePublicNames(
        context: guardrailContext,
        resolvedLibrary: resolvedLibrary,
      ),
      ...await _collectConditionalExportAlternativeNames(
        context: guardrailContext,
        surfaceFile: file,
      ),
    };
    final carrierCategories = <String>{};
    final violationCategories = <String>{};
    final flaggedSymbols = <String>{};
    final carrierSymbols = <String>{};

    for (final name in exportedNames) {
      if (name.endsWith('Backing') && !name.endsWith('FromValidatedBacking')) {
        carrierCategories.add('raw-backing-type');
        carrierSymbols.add(name);
      }
      if (name.endsWith('BackingFromValidated')) {
        carrierCategories.add('raw-backing-builder');
        carrierSymbols.add(name);
      }
      if (name.endsWith('FromValidatedBacking')) {
        violationCategories.add('materialize-from-backing');
        flaggedSymbols.add(name);
      }
    }

    if (violationCategories.isEmpty) {
      continue;
    }
    flaggedSymbols.addAll(carrierSymbols);
    violations.add(
      _BridgeSurfaceViolation(
        filePath: _repoRelativePath(workingRoot, file),
        categories: violationCategories.toList()..sort(),
        carrierCategories: carrierCategories.toList()..sort(),
        symbols: flaggedSymbols.toList()..sort(),
      ),
    );
  }

  if (jsonOutput) {
    final payload = <String, Object?>{
      'summary': <String, Object?>{
        'surfaces': targets.length,
        'violations': violations.length,
      },
      'violations': violations
          .map((violation) => violation.toJson())
          .toList(growable: false),
    };
    return ToolCommandResult(
      exitCode: violations.isEmpty ? 0 : 1,
      stdout: '${const JsonEncoder.withIndent('  ').convert(payload)}\n',
    );
  }

  if (violations.isEmpty) {
    return ToolCommandResult(
      exitCode: 0,
      stdout:
          'Bridge surface audit passed: scanned ${targets.length} surface(s) '
          'with no generic backing materializer leaks.\n',
    );
  }

  final buffer = StringBuffer()
    ..writeln(
      'Bridge surface audit found ${violations.length} violating surface(s) '
      'across ${targets.length} target(s):',
    );
  for (final violation in violations) {
    buffer.writeln(
      '- ${violation.filePath}: ${violation.categories.join(', ')}',
    );
    if (violation.carrierCategories.isNotEmpty) {
      buffer.writeln(
        '  carrier exports: ${violation.carrierCategories.join(', ')}',
      );
    }
    if (violation.symbols.isNotEmpty) {
      buffer.writeln('  symbols: ${violation.symbols.join(', ')}');
    }
  }
  return ToolCommandResult(exitCode: 1, stdout: buffer.toString());
}

Future<void> main(List<String> args) async {
  final result = await runAuditBridgeSurfacesTool(args);
  writeToolCommandResult(result);
  exitCode = result.exitCode;
}

List<String> _loadBridgeSurfaceTargets(Directory root) {
  final policyFile = File(
    '${root.path}${Platform.pathSeparator}'
    'tool/src/import_boundaries/import_boundary_policy.dart',
  );
  if (!policyFile.existsSync()) {
    return const <String>[];
  }
  final parsed = parseString(
    path: policyFile.absolute.path,
    content: policyFile.readAsStringSync(),
    throwIfDiagnostics: false,
  );
  for (final declaration in parsed.unit.declarations) {
    if (declaration is! TopLevelVariableDeclaration) {
      continue;
    }
    for (final variable in declaration.variables.variables) {
      if (variable.name.lexeme != '_bridgeSurfaceDescriptors') {
        continue;
      }
      final initializer = variable.initializer;
      if (initializer is! SetOrMapLiteral) {
        return const <String>[];
      }
      final targets = <String>[];
      for (final element in initializer.elements.whereType<MapLiteralEntry>()) {
        final key = element.key;
        if (key case SimpleStringLiteral(:final value)) {
          targets.add(value.substring(1));
        }
      }
      targets.sort();
      return targets;
    }
  }
  return const <String>[];
}

List<String> _collectEffectivePublicNames({
  required GuardrailContext context,
  required ResolvedLibraryResult resolvedLibrary,
}) {
  return collectEffectivePublicExportNamespace(
    resolvedLibrary: resolvedLibrary,
    rootAbsPath: context.root.absolute.path,
    packageName: context.packageName,
  ).symbolNames;
}

Future<Set<String>> _collectConditionalExportAlternativeNames({
  required GuardrailContext context,
  required File surfaceFile,
}) async {
  final parsed = context.getParsedUnitResult(surfaceFile.absolute.path);
  if (parsed is! ParsedUnitResult) {
    return const <String>{};
  }

  final names = <String>{};
  for (final directive in parsed.unit.directives.whereType<ExportDirective>()) {
    if (directive.configurations.isEmpty) {
      continue;
    }
    final targetUris = <String?>[
      directive.uri.stringValue,
      for (final configuration in directive.configurations)
        configuration.uri.stringValue,
    ].nonNulls.toList(growable: false);
    for (final targetUri in targetUris) {
      final targetFile = _resolveLocalDartUri(
        context: context,
        sourceFile: surfaceFile,
        uriValue: targetUri,
      );
      if (targetFile == null || !targetFile.existsSync()) {
        continue;
      }
      final resolvedTarget = await context.getResolvedLibraryResult(
        targetFile.absolute.path,
      );
      if (resolvedTarget == null) {
        continue;
      }
      names.addAll(
        _applyExportCombinators(
          directive: directive,
          names: _collectEffectivePublicNames(
            context: context,
            resolvedLibrary: resolvedTarget,
          ),
        ),
      );
    }
  }
  return names;
}

Iterable<String> _applyExportCombinators({
  required ExportDirective directive,
  required Iterable<String> names,
}) {
  final showNames = directive.combinators
      .whereType<ShowCombinator>()
      .expand((combinator) => combinator.shownNames.map((name) => name.name))
      .toSet();
  final hiddenNames = directive.combinators
      .whereType<HideCombinator>()
      .expand((combinator) => combinator.hiddenNames.map((name) => name.name))
      .toSet();
  final visibleNames = showNames.isEmpty
      ? names
      : names.where(showNames.contains);
  return visibleNames.where((name) => !hiddenNames.contains(name));
}

File? _resolveLocalDartUri({
  required GuardrailContext context,
  required File sourceFile,
  required String uriValue,
}) {
  if (uriValue.startsWith('dart:')) {
    return null;
  }
  final selfPackagePrefix = 'package:${context.packageName}/';
  if (uriValue.startsWith(selfPackagePrefix)) {
    final packagePath = uriValue.substring(selfPackagePrefix.length);
    return File(
      '${context.root.path}${Platform.pathSeparator}lib'
      '${Platform.pathSeparator}'
      '${packagePath.replaceAll('/', Platform.pathSeparator)}',
    );
  }
  if (uriValue.startsWith('package:')) {
    return null;
  }
  return File(
    '${sourceFile.parent.path}${Platform.pathSeparator}'
    '${uriValue.replaceAll('/', Platform.pathSeparator)}',
  );
}

String _repoRelativePath(Directory root, File file) {
  final rootPath = root.path.endsWith(Platform.pathSeparator)
      ? root.path
      : '${root.path}${Platform.pathSeparator}';
  if (!file.path.startsWith(rootPath)) {
    return file.path;
  }
  return file.path.substring(rootPath.length).replaceAll(r'\', '/');
}

final class _BridgeSurfaceViolation {
  const _BridgeSurfaceViolation({
    required this.filePath,
    required this.categories,
    required this.carrierCategories,
    required this.symbols,
  });

  final String filePath;
  final List<String> categories;
  final List<String> carrierCategories;
  final List<String> symbols;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'filePath': filePath,
      'categories': categories,
      'carrierCategories': carrierCategories,
      'symbols': symbols,
    };
  }
}
