import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';

import 'clone_analysis_models.dart';
import 'clone_parse_errors.dart';

class CloneBlockCollection {
  CloneBlockCollection({
    required this.blocks,
    required this.parseErrors,
    required this.scannedFiles,
  });

  final List<CodeBlock> blocks;
  final List<String> parseErrors;
  final int scannedFiles;
}

class ExecutableCollector extends GeneralizingAstVisitor<void> {
  ExecutableCollector({
    required this.filePath,
    required this.lineStarts,
    required this.minTokens,
    required this.excludeMain,
    required this.nextBlockId,
    required this.output,
  });

  final String filePath;
  final List<int> lineStarts;
  final int minTokens;
  final bool excludeMain;
  final int Function() nextBlockId;
  final List<CodeBlock> output;

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    _addBody(kind: 'method', name: node.name.lexeme, body: node.body);
    super.visitMethodDeclaration(node);
  }

  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {
    _addBody(
      kind: 'function',
      name: node.name.lexeme,
      body: node.functionExpression.body,
    );
    super.visitFunctionDeclaration(node);
  }

  @override
  void visitConstructorDeclaration(ConstructorDeclaration node) {
    final className = node.typeName?.name ?? '<unknown>';
    final ctorName = node.name?.lexeme;
    final fullName = (ctorName == null || ctorName.isEmpty)
        ? className
        : '$className.$ctorName';

    _addBody(kind: 'constructor', name: fullName, body: node.body);
    super.visitConstructorDeclaration(node);
  }

  void _addBody({
    required String kind,
    required String name,
    required FunctionBody body,
  }) {
    if (excludeMain && kind == 'function' && name == 'main') {
      return;
    }

    final normalized = _normalizeTokens(body.beginToken, body.endToken);
    if (normalized.tokens.length < minTokens) {
      return;
    }

    output.add(
      CodeBlock(
        id: nextBlockId(),
        filePath: filePath,
        kind: kind,
        name: name,
        startLine: offsetToLine(lineStarts, body.offset),
        endLine: offsetToLine(lineStarts, body.end),
        tokens: normalized.tokens,
        tokenLines: normalized.tokenLines,
      ),
    );
  }

  NormalizedTokens _normalizeTokens(Token start, Token end) {
    final tokens = <String>[];
    final tokenLines = <int>[];
    var current = start;

    while (true) {
      final normalized = _normalizeToken(current);
      if (normalized != null) {
        tokens.add(normalized);
        tokenLines.add(offsetToLine(lineStarts, current.offset));
      }

      if (identical(current, end)) {
        break;
      }

      final next = current.next;
      if (next == null) {
        break;
      }
      current = next;
    }

    return NormalizedTokens(tokens: tokens, tokenLines: tokenLines);
  }

  String? _normalizeToken(Token token) {
    final type = token.type;
    final lexeme = token.lexeme;

    if (_isIgnoredTokenType(type)) {
      return null;
    }

    if (type == TokenType.IDENTIFIER) {
      return 'ID';
    }

    final normalizedLiteral = _normalizeLiteralToken(type, lexeme);
    if (normalizedLiteral != null) {
      return normalizedLiteral;
    }

    return type.lexeme.isNotEmpty ? type.lexeme : lexeme;
  }
}

class NormalizedTokens {
  NormalizedTokens({required this.tokens, required this.tokenLines});

  final List<String> tokens;
  final List<int> tokenLines;
}

CloneBlockCollection collectCloneBlocks({
  required String rootPath,
  required int minTokens,
  required bool excludeMain,
}) {
  final files = collectDartFiles(rootPath);
  final blocks = <CodeBlock>[];
  final parseErrors = <String>[];
  var nextId = 1;

  for (final file in files) {
    try {
      final content = File(file).readAsStringSync();
      final lineStarts = computeLineStarts(content);
      final result = parseString(
        content: content,
        path: file,
        throwIfDiagnostics: false,
      );
      parseErrors.addAll(
        formatCloneParseErrors(file, result.errors, result.lineInfo),
      );

      final collector = ExecutableCollector(
        filePath: file,
        lineStarts: lineStarts,
        minTokens: minTokens,
        excludeMain: excludeMain,
        nextBlockId: () => nextId++,
        output: blocks,
      );
      result.unit.accept(collector);
    } on Exception catch (error) {
      parseErrors.add('Failed to process $file: $error');
    }
  }

  return CloneBlockCollection(
    blocks: blocks,
    parseErrors: parseErrors,
    scannedFiles: files.length,
  );
}

List<String> collectDartFiles(String rootPath) {
  final root = Directory(rootPath);
  if (!root.existsSync()) {
    return <String>[];
  }

  final result = <String>[];
  for (final entity in root.listSync(recursive: true, followLinks: false)) {
    if (entity is! File) {
      continue;
    }
    final path = entity.path.replaceAll('\\', '/');
    if (_shouldSkipFile(path)) {
      continue;
    }
    result.add(entity.path);
  }

  result.sort();
  return result;
}

List<int> computeLineStarts(String source) {
  final starts = <int>[0];
  for (var i = 0; i < source.length; i++) {
    if (source.codeUnitAt(i) == 10) {
      starts.add(i + 1);
    }
  }
  return starts;
}

int offsetToLine(List<int> lineStarts, int offset) {
  var left = 0;
  var right = lineStarts.length - 1;
  var answer = 0;

  while (left <= right) {
    final mid = (left + right) >> 1;
    if (lineStarts[mid] <= offset) {
      answer = mid;
      left = mid + 1;
    } else {
      right = mid - 1;
    }
  }

  return answer + 1;
}

bool _isNumericToken(TokenType type) {
  return type == TokenType.INT ||
      type == TokenType.INT_WITH_SEPARATORS ||
      type == TokenType.DOUBLE ||
      type == TokenType.DOUBLE_WITH_SEPARATORS ||
      type == TokenType.HEXADECIMAL ||
      type == TokenType.HEXADECIMAL_WITH_SEPARATORS;
}

bool _isIgnoredTokenType(TokenType type) {
  return type == TokenType.EOF ||
      type == TokenType.SCRIPT_TAG ||
      type == TokenType.SINGLE_LINE_COMMENT ||
      type == TokenType.MULTI_LINE_COMMENT ||
      type == TokenType.RECOVERY ||
      type == TokenType.BAD_INPUT;
}

String? _normalizeLiteralToken(TokenType type, String lexeme) {
  if (_isNumericToken(type)) {
    return 'NUM';
  }
  if (type == TokenType.STRING || _looksLikeStringLiteral(lexeme)) {
    return 'STR';
  }
  if (_isBooleanLiteral(lexeme)) {
    return 'BOOL';
  }
  if (lexeme == 'null') {
    return 'NULL';
  }
  return null;
}

bool _isBooleanLiteral(String lexeme) {
  return lexeme == 'true' || lexeme == 'false';
}

bool _looksLikeStringLiteral(String source) {
  return source.startsWith("'") ||
      source.startsWith('"') ||
      source.startsWith("r'") ||
      source.startsWith('r"') ||
      source.startsWith("'''") ||
      source.startsWith('"""') ||
      source.startsWith("r'''") ||
      source.startsWith('r"""');
}

bool _shouldSkipFile(String path) {
  if (!path.endsWith('.dart')) {
    return true;
  }

  const ignoredFragments = <String>['/.dart_tool/', '/build/', '/.fvm/'];
  for (final fragment in ignoredFragments) {
    if (path.contains(fragment)) {
      return true;
    }
  }

  const ignoredSuffixes = <String>[
    '.g.dart',
    '.freezed.dart',
    '.mocks.dart',
    '.gen.dart',
    '.config.dart',
  ];
  for (final suffix in ignoredSuffixes) {
    if (path.endsWith(suffix)) {
      return true;
    }
  }

  return false;
}
