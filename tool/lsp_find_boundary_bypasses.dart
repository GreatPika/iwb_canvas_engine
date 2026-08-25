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
  final mustPass = toolCommandRepeatedStringFlag(args, '--must-pass');
  if (mustPass.isEmpty) {
    return const ToolCommandResult(
      exitCode: 1,
      stderr: 'FAIL: at least one --must-pass target is required.\n',
    );
  }
  final jsonOutput = args.contains('--json');
  final request = _BoundaryAuditRequest.fromArgs(args, workingRoot, mustPass);
  final methods = _listMethodsForRequest(request);
  final client = await LanguageServerClient.start(root: request.root);

  try {
    return await _runBoundaryAudit(
      client: client,
      request: request,
      methods: methods,
      jsonOutput: jsonOutput,
    );
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

List<String> _listMethodsForRequest(_BoundaryAuditRequest request) =>
    _listClassMethods(
      root: request.root,
      repoRelativePath: request.repoRelativePath,
      className: request.className,
      includePrivate: request.includePrivate,
    );

Future<ToolCommandResult> _runBoundaryAudit({
  required LanguageServerClient client,
  required _BoundaryAuditRequest request,
  required List<String> methods,
  required bool jsonOutput,
}) async {
  final failures = <Map<String, Object?>>[];
  for (final methodName in methods) {
    final failure = await _findMethodBypass(
      client,
      request: request,
      methodName: methodName,
    );
    if (failure != null) {
      failures.add(failure);
    }
  }
  return _resultForFailures(
    className: request.className,
    mustPass: request.mustPass,
    failures: failures,
    jsonOutput: jsonOutput,
  );
}

Future<Map<String, Object?>?> _findMethodBypass(
  LanguageServerClient client, {
  required _BoundaryAuditRequest request,
  required String methodName,
}) async {
  final symbol = locateSymbol(
    root: request.root,
    repoRelativePath: request.repoRelativePath,
    query: '${request.className}.$methodName',
  );
  final start = await prepareCallItemForSymbol(client, symbol);
  if (start == null) {
    return null;
  }
  final flow = await tracePrimaryOutgoingFlow(
    client,
    start,
    depth: request.depth,
    includeExternal: false,
  );
  final labels = <String>[
    flow.start.label,
    ...flow.steps.map((step) => step.item.label),
  ];
  if (request.mustPass.any(
    (target) => labels.any((label) => _matchesRequiredTarget(label, target)),
  )) {
    return null;
  }
  return <String, Object?>{
    'method': '${request.className}.$methodName',
    'mustPass': request.mustPass,
    'flow': labels,
  };
}

ToolCommandResult _resultForFailures({
  required String className,
  required List<String> mustPass,
  required List<Map<String, Object?>> failures,
  required bool jsonOutput,
}) => ToolCommandResult(
  exitCode: failures.isEmpty ? 0 : 1,
  stdout: jsonOutput
      ? '${encodeToolCommandJson(failures)}\n'
      : _renderTextReport(className, mustPass, failures),
);

String _renderTextReport(
  String className,
  List<String> mustPass,
  List<Map<String, Object?>> failures,
) {
  final buffer = StringBuffer();
  if (failures.isEmpty) {
    buffer.writeln(
      'No boundary bypasses found in $className for ${mustPass.join(', ')}.',
    );
    return buffer.toString();
  }
  buffer.writeln(
    'Boundary bypass candidates in $className for ${mustPass.join(', ')}:',
  );
  for (final failure in failures) {
    buffer.writeln('- ${failure['method']}');
    for (final step in failure['flow'] as List<String>) {
      buffer.writeln('  flow: $step');
    }
  }
  return buffer.toString();
}

final class _BoundaryAuditRequest {
  const _BoundaryAuditRequest({
    required this.root,
    required this.repoRelativePath,
    required this.className,
    required this.mustPass,
    required this.depth,
    required this.includePrivate,
  });

  factory _BoundaryAuditRequest.fromArgs(
    List<String> args,
    Directory root,
    List<String> mustPass,
  ) => _BoundaryAuditRequest(
    root: root,
    repoRelativePath: args[0],
    className: args[1],
    mustPass: mustPass,
    depth: toolCommandIntFlag(args, '--depth') ?? 5,
    includePrivate: args.contains('--include-private'),
  );

  final Directory root;
  final String repoRelativePath;
  final String className;
  final List<String> mustPass;
  final int depth;
  final bool includePrivate;
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
