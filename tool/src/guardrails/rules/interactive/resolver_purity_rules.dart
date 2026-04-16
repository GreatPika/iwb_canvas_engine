import '../../core/guardrail_violation.dart';

GuardrailViolation? requireSourceTokens({
  required String source,
  required String filePath,
  required List<String> requiredTokens,
  required List<String> bannedTokens,
  List<RegExp> bannedPatterns = const <RegExp>[],
  required String message,
}) {
  for (final token in requiredTokens) {
    if (!source.contains(token)) {
      return GuardrailViolation(filePath: filePath, line: 1, message: message);
    }
  }
  for (final token in bannedTokens) {
    final offset = source.indexOf(token);
    if (offset < 0) {
      continue;
    }
    final line = '\n'.allMatches(source.substring(0, offset)).length + 1;
    return GuardrailViolation(filePath: filePath, line: line, message: message);
  }
  for (final pattern in bannedPatterns) {
    final match = pattern.firstMatch(source);
    if (match == null) {
      continue;
    }
    final offset = match.start;
    final line = '\n'.allMatches(source.substring(0, offset)).length + 1;
    return GuardrailViolation(filePath: filePath, line: line, message: message);
  }
  return null;
}

GuardrailViolation? requireTokenOrder({
  required String source,
  required String filePath,
  required List<String> orderedTokens,
  required String message,
  String? scopeRootStart,
  String? methodStart,
  String? blockStart,
}) {
  final maskedSource = _maskNonCodeText(source);
  final scopeRootOffset = scopeRootStart == null
      ? 0
      : _findMaskedTokenOffset(
          maskedSource: maskedSource,
          token: scopeRootStart,
        );
  if (scopeRootOffset < 0) {
    return GuardrailViolation(filePath: filePath, line: 1, message: message);
  }

  final methodScope = methodStart == null
      ? (
          body: source.substring(scopeRootOffset),
          maskedBody: maskedSource.substring(scopeRootOffset),
          bodyStartOffset: scopeRootOffset,
        )
      : _extractMethodBodyScope(
          source: source,
          maskedSource: maskedSource,
          methodStart: methodStart,
          searchStartOffset: scopeRootOffset,
        );
  if (methodScope == null) {
    return GuardrailViolation(
      filePath: filePath,
      line: _lineNumberAtOffset(source: source, offset: scopeRootOffset),
      message: message,
    );
  }

  final scopedSource = blockStart == null
      ? methodScope
      : _extractBlockBodyScope(
          source: methodScope.body,
          maskedSource: methodScope.maskedBody,
          blockStart: blockStart,
          bodyStartOffset: methodScope.bodyStartOffset,
        );
  if (scopedSource == null) {
    return GuardrailViolation(
      filePath: filePath,
      line: _lineNumberAtOffset(
        source: source,
        offset: methodScope.bodyStartOffset,
      ),
      message: message,
    );
  }

  final statements = _extractTopLevelStatements(
    source: scopedSource.maskedBody,
    bodyStartOffset: scopedSource.bodyStartOffset,
  );
  final normalizedTokens = orderedTokens
      .map((token) => _normalizeGuardrailToken(token))
      .toList(growable: false);

  var statementIndex = 0;
  for (final token in normalizedTokens) {
    var matchedIndex = -1;
    for (var i = statementIndex; i < statements.length; i++) {
      if (statements[i].normalized.startsWith(token)) {
        matchedIndex = i;
        break;
      }
    }
    if (matchedIndex < 0) {
      final failureOffset = statementIndex < statements.length
          ? statements[statementIndex].startOffset
          : scopedSource.bodyStartOffset;
      return GuardrailViolation(
        filePath: filePath,
        line: _lineNumberAtOffset(source: source, offset: failureOffset),
        message: message,
      );
    }
    statementIndex = matchedIndex + 1;
  }
  return null;
}

String _normalizeGuardrailToken(String source) =>
    source.replaceAll(RegExp(r'\s+'), ' ').trim();

int _findMaskedTokenOffset({
  required String maskedSource,
  required String token,
  int startOffset = 0,
}) => maskedSource.indexOf(token, startOffset);

int _lineNumberAtOffset({required String source, required int offset}) {
  final safeOffset = offset.clamp(0, source.length);
  return '\n'.allMatches(source.substring(0, safeOffset)).length + 1;
}

String _maskNonCodeText(String source) {
  final masked = source.split('');
  var index = 0;

  while (index < source.length) {
    final stringLiteral = _matchStringLiteralStart(
      source: source,
      index: index,
    );
    if (stringLiteral != null) {
      final start = index;
      index += stringLiteral.openingLength;
      while (index < source.length) {
        if (stringLiteral.triple) {
          if (index + 2 < source.length &&
              source[index] == stringLiteral.quote &&
              source[index + 1] == stringLiteral.quote &&
              source[index + 2] == stringLiteral.quote) {
            index += 3;
            break;
          }
          index += 1;
          continue;
        }
        if (!stringLiteral.raw &&
            source[index] == r'\' &&
            index + 1 < source.length) {
          index += 2;
          continue;
        }
        if (source[index] == stringLiteral.quote) {
          index += 1;
          break;
        }
        index += 1;
      }
      _maskCharacters(masked, start: start, end: index);
      continue;
    }

    if (index + 1 < source.length &&
        source[index] == '/' &&
        source[index + 1] == '/') {
      final start = index;
      index += 2;
      while (index < source.length && source[index] != '\n') {
        index += 1;
      }
      _maskCharacters(masked, start: start, end: index);
      continue;
    }

    if (index + 1 < source.length &&
        source[index] == '/' &&
        source[index + 1] == '*') {
      final start = index;
      index += 2;
      var depth = 1;
      while (index < source.length && depth > 0) {
        if (index + 1 < source.length &&
            source[index] == '/' &&
            source[index + 1] == '*') {
          depth += 1;
          index += 2;
          continue;
        }
        if (index + 1 < source.length &&
            source[index] == '*' &&
            source[index + 1] == '/') {
          depth -= 1;
          index += 2;
          continue;
        }
        index += 1;
      }
      _maskCharacters(masked, start: start, end: index);
      continue;
    }

    index += 1;
  }

  return masked.join();
}

void _maskCharacters(
  List<String> source, {
  required int start,
  required int end,
}) {
  final safeEnd = end > source.length ? source.length : end;
  for (var i = start; i < safeEnd; i++) {
    if (source[i] == '\n' || source[i] == '\r') {
      continue;
    }
    source[i] = ' ';
  }
}

({int openingLength, String quote, bool raw, bool triple})?
_matchStringLiteralStart({required String source, required int index}) {
  final char = source[index];
  if (char == 'r' || char == 'R') {
    if (index + 1 >= source.length) {
      return null;
    }
    final quote = source[index + 1];
    if (quote != "'" && quote != '"') {
      return null;
    }
    final triple =
        index + 3 < source.length &&
        source[index + 2] == quote &&
        source[index + 3] == quote;
    return (
      openingLength: triple ? 4 : 2,
      quote: quote,
      raw: true,
      triple: triple,
    );
  }

  if (char != "'" && char != '"') {
    return null;
  }

  final triple =
      index + 2 < source.length &&
      source[index + 1] == char &&
      source[index + 2] == char;
  return (
    openingLength: triple ? 3 : 1,
    quote: char,
    raw: false,
    triple: triple,
  );
}

({String body, String maskedBody, int bodyStartOffset})?
_extractMethodBodyScope({
  required String source,
  required String maskedSource,
  required String methodStart,
  int searchStartOffset = 0,
}) {
  final startIndex = _findMaskedTokenOffset(
    maskedSource: maskedSource,
    token: methodStart,
    startOffset: searchStartOffset,
  );
  if (startIndex < 0) {
    return null;
  }

  var bodyStart = -1;
  var parenDepth = 0;
  for (var i = startIndex; i < maskedSource.length; i++) {
    final char = maskedSource[i];
    if (char == '(') {
      parenDepth += 1;
    } else if (char == ')') {
      if (parenDepth > 0) {
        parenDepth -= 1;
      }
    } else if (char == '{' && parenDepth == 0) {
      bodyStart = i;
      break;
    }
  }
  if (bodyStart < 0) {
    return null;
  }

  var depth = 1;
  for (var i = bodyStart + 1; i < maskedSource.length; i++) {
    final char = maskedSource[i];
    if (char == '{') {
      depth += 1;
    } else if (char == '}') {
      depth -= 1;
      if (depth == 0) {
        return (
          body: source.substring(bodyStart + 1, i),
          maskedBody: maskedSource.substring(bodyStart + 1, i),
          bodyStartOffset: bodyStart + 1,
        );
      }
    }
  }
  return null;
}

({String body, String maskedBody, int bodyStartOffset})?
_extractBlockBodyScope({
  required String source,
  required String maskedSource,
  required String blockStart,
  required int bodyStartOffset,
}) {
  final startIndex = _findMaskedTokenOffset(
    maskedSource: maskedSource,
    token: blockStart,
  );
  if (startIndex < 0) {
    return null;
  }

  var blockBodyStart = -1;
  var parenDepth = 0;
  for (var i = startIndex; i < maskedSource.length; i++) {
    final char = maskedSource[i];
    if (char == '(') {
      parenDepth += 1;
    } else if (char == ')') {
      if (parenDepth > 0) {
        parenDepth -= 1;
      }
    } else if (char == '{' && parenDepth == 0) {
      blockBodyStart = i;
      break;
    }
  }
  if (blockBodyStart < 0) {
    return null;
  }

  var depth = 1;
  for (var i = blockBodyStart + 1; i < maskedSource.length; i++) {
    final char = maskedSource[i];
    if (char == '{') {
      depth += 1;
    } else if (char == '}') {
      depth -= 1;
      if (depth == 0) {
        return (
          body: source.substring(blockBodyStart + 1, i),
          maskedBody: maskedSource.substring(blockBodyStart + 1, i),
          bodyStartOffset: bodyStartOffset + blockBodyStart + 1,
        );
      }
    }
  }
  return null;
}

List<({String normalized, int startOffset})> _extractTopLevelStatements({
  required String source,
  required int bodyStartOffset,
}) {
  final statements = <({String normalized, int startOffset})>[];
  var statementStart = -1;
  var parenDepth = 0;
  var bracketDepth = 0;
  var braceDepth = 0;

  for (var i = 0; i < source.length; i++) {
    final char = source[i];
    if (braceDepth == 0 && statementStart < 0 && char.trim().isNotEmpty) {
      statementStart = i;
    }

    if (char == '(') {
      parenDepth += 1;
      continue;
    }
    if (char == ')') {
      if (parenDepth > 0) {
        parenDepth -= 1;
      }
      continue;
    }
    if (char == '[') {
      bracketDepth += 1;
      continue;
    }
    if (char == ']') {
      if (bracketDepth > 0) {
        bracketDepth -= 1;
      }
      continue;
    }
    if (char == '{') {
      if (parenDepth == 0 && bracketDepth == 0) {
        braceDepth += 1;
        if (braceDepth == 1) {
          statementStart = -1;
        }
      }
      continue;
    }
    if (char == '}') {
      if (parenDepth == 0 && bracketDepth == 0 && braceDepth > 0) {
        braceDepth -= 1;
      }
      continue;
    }
    if (char == ';' &&
        parenDepth == 0 &&
        bracketDepth == 0 &&
        braceDepth == 0 &&
        statementStart >= 0) {
      final statement = _normalizeGuardrailToken(
        source.substring(statementStart, i + 1),
      );
      if (statement.isNotEmpty) {
        statements.add((
          normalized: statement,
          startOffset: bodyStartOffset + statementStart,
        ));
      }
      statementStart = -1;
    }
  }

  return statements;
}
