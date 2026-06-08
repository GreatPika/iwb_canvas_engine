import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';

import 'src/lsp/language_server_client.dart';
import 'src/lsp/symbol_locator.dart';
import 'src/lsp/trace_support.dart';
import 'src/tool_command_result.dart';

Future<ToolCommandResult> runLspFindBoundaryBypassesTool(
  List<String> args, {
  Directory? root,
}) async {
  if (args.length < 2) {
    return const ToolCommandResult(
      exitCode: 1,
      stderr:
          'Usage: dart run tool/lsp_find_boundary_bypasses.dart <file> <class> '
          '--must-pass=<Class|Class.method> [--depth=N] [--json]\n',
    );
  }

  final workingRoot = root ?? Directory.current;
  final repoRelativePath = args[0];
  final className = args[1];
  final mustPass = _parseRepeatedFlag(args, '--must-pass');
  if (mustPass.isEmpty) {
    return const ToolCommandResult(
      exitCode: 1,
      stderr: 'FAIL: at least one --must-pass target is required.\n',
    );
  }
  final depth = _parseIntFlag(args, '--depth') ?? 5;
  final includePrivate = args.contains('--include-private');
  final jsonOutput = args.contains('--json');

  final methods = _listClassMethods(
    root: workingRoot,
    repoRelativePath: repoRelativePath,
    className: className,
    includePrivate: includePrivate,
  );

  final client = await LanguageServerClient.start(root: workingRoot);
  try {
    final failures = <Map<String, Object?>>[];
    for (final methodName in methods) {
      final symbol = locateSymbol(
        root: workingRoot,
        repoRelativePath: repoRelativePath,
        query: '$className.$methodName',
      );
      final start = await prepareCallItemForSymbol(client, symbol);
      if (start == null) {
        continue;
      }
      final flow = await tracePrimaryOutgoingFlow(
        client,
        start,
        depth: depth,
        includeExternal: false,
      );
      final labels = <String>[
        flow.start.label,
        ...flow.steps.map((step) => step.item.label),
      ];
      final matched = mustPass.any((requiredTarget) {
        return labels.any(
          (label) => _matchesRequiredTarget(label, requiredTarget),
        );
      });
      if (matched) {
        continue;
      }
      failures.add(<String, Object?>{
        'method': '$className.$methodName',
        'mustPass': mustPass,
        'flow': labels,
      });
    }

    if (jsonOutput) {
      return ToolCommandResult(
        exitCode: failures.isEmpty ? 0 : 1,
        stdout: '${const JsonEncoder.withIndent('  ').convert(failures)}\n',
      );
    }

    final buffer = StringBuffer();
    if (failures.isEmpty) {
      buffer.writeln(
        'No boundary bypasses found in $className '
        'for ${mustPass.join(', ')}.',
      );
      return ToolCommandResult(exitCode: 0, stdout: buffer.toString());
    }
    buffer.writeln(
      'Boundary bypass candidates in $className '
      'for ${mustPass.join(', ')}:',
    );
    for (final failure in failures) {
      buffer.writeln('- ${failure['method']}');
      for (final step in failure['flow'] as List<String>) {
        buffer.writeln('  flow: $step');
      }
    }
    return ToolCommandResult(exitCode: 1, stdout: buffer.toString());
  } on SymbolLocateFailure catch (error) {
    return ToolCommandResult(exitCode: 1, stderr: 'FAIL: ${error.message}\n');
  } on LanguageServerError catch (error) {
    return ToolCommandResult(
      exitCode: 1,
      stderr: 'FAIL: LSP boundary check failed: ${error.message}\n',
    );
  } finally {
    await client.close();
  }
}

Future<void> main(List<String> args) async {
  final result = await runLspFindBoundaryBypassesTool(args);
  writeToolCommandResult(result);
  exitCode = result.exitCode;
}

List<String> _listClassMethods({
  required Directory root,
  required String repoRelativePath,
  required String className,
  required bool includePrivate,
}) {
  final file = File('${root.path}${Platform.pathSeparator}$repoRelativePath');
  if (!file.existsSync()) {
    throw SymbolLocateFailure('File not found: $repoRelativePath');
  }
  final parsed = parseString(
    path: file.path,
    content: file.readAsStringSync(),
    throwIfDiagnostics: false,
  );
  for (final declaration
      in parsed.unit.declarations.whereType<ClassDeclaration>()) {
    if (_className(declaration) != className) {
      continue;
    }
    return declaration.body.members
        .whereType<MethodDeclaration>()
        .map((member) => member.name.lexeme)
        .where((name) => includePrivate || !name.startsWith('_'))
        .where(
          (name) => name != 'toString' && name != 'hashCode' && name != '==',
        )
        .toList(growable: false);
  }
  throw SymbolLocateFailure(
    'Class "$className" not found in $repoRelativePath.',
  );
}

String _className(ClassDeclaration declaration) {
  final namePart = declaration.namePart;
  return switch (namePart) {
    NameWithTypeParameters(:final typeName) => typeName.lexeme,
    PrimaryConstructorDeclaration() => namePart.beginToken.lexeme,
  };
}

bool _matchesRequiredTarget(String label, String requiredTarget) {
  if (requiredTarget.contains('.')) {
    return label == requiredTarget;
  }
  return label == requiredTarget || label.startsWith('$requiredTarget.');
}

List<String> _parseRepeatedFlag(List<String> args, String name) {
  final values = <String>[];
  for (final argument in args) {
    if (argument.startsWith('$name=')) {
      values.add(argument.replaceFirst('$name=', ''));
    }
  }
  return List<String>.unmodifiable(values);
}

int? _parseIntFlag(List<String> args, String name) {
  for (final argument in args) {
    if (argument.startsWith('$name=')) {
      return int.tryParse(argument.replaceFirst('$name=', ''));
    }
  }
  return null;
}
