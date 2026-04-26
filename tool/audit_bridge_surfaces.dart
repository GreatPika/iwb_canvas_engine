import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';

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
          symbols: const <String>[],
        ),
      );
      continue;
    }

    final parsed = parseString(
      path: file.absolute.path,
      content: file.readAsStringSync(),
      throwIfDiagnostics: false,
    );
    final exportedNames = _collectExportedNames(parsed.unit);
    final categories = <String>{};
    final flaggedSymbols = <String>{};

    for (final name in exportedNames) {
      if (name.endsWith('Backing')) {
        categories.add('raw-backing-type');
        flaggedSymbols.add(name);
      }
      if (name.endsWith('BackingFromValidated')) {
        categories.add('raw-backing-builder');
        flaggedSymbols.add(name);
      }
      if (name.endsWith('FromValidatedBacking')) {
        categories.add('materialize-from-backing');
        flaggedSymbols.add(name);
      }
    }

    if (categories.isEmpty) {
      continue;
    }
    violations.add(
      _BridgeSurfaceViolation(
        filePath: _repoRelativePath(workingRoot, file),
        categories: categories.toList()..sort(),
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
          'with no raw backing leaks.\n',
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

List<String> _collectExportedNames(CompilationUnit unit) {
  final names = <String>[];
  for (final directive in unit.directives.whereType<ExportDirective>()) {
    final shows = directive.combinators.whereType<ShowCombinator>();
    for (final combinator in shows) {
      names.addAll(combinator.shownNames.map((name) => name.name));
    }
  }
  return names;
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
    required this.symbols,
  });

  final String filePath;
  final List<String> categories;
  final List<String> symbols;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'filePath': filePath,
      'categories': categories,
      'symbols': symbols,
    };
  }
}
