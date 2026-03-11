import 'dart:io';
import 'dart:math' as math;

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';

const String _usage = '''
Usage:
  dart run tool/analysis/find_similar_clones.dart [rootPath] [minTokens] [kGramSize] [windowSize] [minSharedFingerprints] [minOverlap] [maxBucketSize]

Arguments:
  rootPath               Directory to scan. Defaults to .
  minTokens              Minimum normalized token count per block. Defaults to 40
  kGramSize              Fingerprint k-gram size. Defaults to 25
  windowSize             Winnowing window size. Defaults to 4
  minSharedFingerprints  Minimum shared fingerprints for a reported pair. Defaults to 3
  minOverlap             Minimum overlap ratio in the range 0..1. Defaults to 0.35
  maxBucketSize          Ignore fingerprints that occur in more than this many blocks. Defaults to 20

Examples:
  dart run tool/analysis/find_similar_clones.dart
  dart run tool/analysis/find_similar_clones.dart . 60 30 5 4 0.55 12
  dart run tool/analysis/find_similar_clones.dart lib 50 30 5 4 0.55 12
''';

void main(List<String> args) {
  if (args.contains('--help') || args.contains('-h')) {
    stdout.writeln(_usage.trim());
    return;
  }

  final config = Config.fromArgs(args);
  final validationError = config.validate();
  if (validationError != null) {
    stderr.writeln(validationError);
    stderr.writeln('');
    stderr.writeln(_usage.trim());
    exitCode = 64;
    return;
  }

  final files = _collectDartFiles(config.rootPath);
  if (files.isEmpty) {
    stderr.writeln('Dart-файлы не найдены.');
    exitCode = 1;
    return;
  }

  final blocks = <CodeBlock>[];
  final vocabulary = Vocabulary();

  for (final file in files) {
    try {
      final content = File(file).readAsStringSync();
      final lineStarts = _computeLineStarts(content);

      final result = parseString(
        content: content,
        path: file,
        throwIfDiagnostics: false,
      );

      final collector = ExecutableCollector(
        filePath: file,
        lineStarts: lineStarts,
        minTokens: config.minTokens,
        output: blocks,
      );

      result.unit.accept(collector);
    } catch (e) {
      stderr.writeln('Не удалось обработать $file: $e');
    }
  }

  if (blocks.isEmpty) {
    stdout.writeln('Подходящих функций или методов не найдено.');
    return;
  }

  // Convert normalized tokens into numeric ids and compute fingerprints.
  for (final block in blocks) {
    block.tokenIds = block.tokens.map(vocabulary.intern).toList();

    final hashes = buildKGramHashes(
      tokenIds: block.tokenIds,
      kGramSize: config.kGramSize,
    );

    block.fingerprints = selectFingerprints(
      hashes: hashes,
      windowSize: config.windowSize,
    );
  }

  final byId = <int, CodeBlock>{for (final block in blocks) block.id: block};

  final fingerprintIndex = <int, List<FingerprintOccurrence>>{};

  // Build an index of fingerprints across blocks.
  for (final block in blocks) {
    final seenHashesInBlock = <int>{};

    for (final fp in block.fingerprints) {
      // Similarity scoring works better when each hash contributes only once
      // per block.
      if (!seenHashesInBlock.add(fp.hash)) continue;

      fingerprintIndex
          .putIfAbsent(fp.hash, () => [])
          .add(
            FingerprintOccurrence(
              blockId: block.id,
              tokenPosition: fp.tokenPosition,
            ),
          );
    }
  }

  final pairStats = <String, PairStat>{};

  for (final entry in fingerprintIndex.entries) {
    final occurrences = entry.value;

    // Very common fingerprints are usually noisy and create false positives.
    if (occurrences.length > config.maxBucketSize) {
      continue;
    }

    for (var i = 0; i < occurrences.length; i++) {
      for (var j = i + 1; j < occurrences.length; j++) {
        final left = occurrences[i];
        final right = occurrences[j];

        if (left.blockId == right.blockId) continue;

        final aId = math.min(left.blockId, right.blockId);
        final bId = math.max(left.blockId, right.blockId);
        final aBlock = byId[aId]!;
        final bBlock = byId[bId]!;
        if (_isNestedPairInSameFile(aBlock, bBlock)) {
          continue;
        }
        final key = '$aId:$bId';

        final stat = pairStats.putIfAbsent(
          key,
          () => PairStat(aId: aId, bId: bId),
        );

        if (!stat.hasSample) {
          if (left.blockId == aId) {
            stat.samplePosA = left.tokenPosition;
            stat.samplePosB = right.tokenPosition;
          } else {
            stat.samplePosA = right.tokenPosition;
            stat.samplePosB = left.tokenPosition;
          }
          stat.hasSample = true;
        }

        stat.sharedFingerprints += 1;
      }
    }
  }

  final results = <SimilarityResult>[];

  for (final stat in pairStats.values) {
    final a = byId[stat.aId]!;
    final b = byId[stat.bId]!;

    if (a.fingerprints.isEmpty || b.fingerprints.isEmpty) continue;

    final shared = stat.sharedFingerprints;
    final minFp = math.min(a.fingerprintCount, b.fingerprintCount);
    final unionFp = a.fingerprintCount + b.fingerprintCount - shared;

    if (minFp == 0 || unionFp <= 0) continue;

    final overlap = shared / minFp;
    final jaccard = shared / unionFp;

    if (shared < config.minSharedFingerprints) continue;
    if (overlap < config.minOverlap) continue;

    final sampleAStart = _tokenPosToLine(a, stat.samplePosA);
    final sampleAEnd = _tokenPosToLine(
      a,
      math.min(stat.samplePosA + config.kGramSize - 1, a.tokenLines.length - 1),
    );

    final sampleBStart = _tokenPosToLine(b, stat.samplePosB);
    final sampleBEnd = _tokenPosToLine(
      b,
      math.min(stat.samplePosB + config.kGramSize - 1, b.tokenLines.length - 1),
    );

    results.add(
      SimilarityResult(
        a: a,
        b: b,
        sharedFingerprints: shared,
        overlap: overlap,
        jaccard: jaccard,
        sampleAStartLine: sampleAStart,
        sampleAEndLine: sampleAEnd,
        sampleBStartLine: sampleBStart,
        sampleBEndLine: sampleBEnd,
      ),
    );
  }

  results.sort((x, y) {
    final cmp1 = y.overlap.compareTo(x.overlap);
    if (cmp1 != 0) return cmp1;

    final cmp2 = y.sharedFingerprints.compareTo(x.sharedFingerprints);
    if (cmp2 != 0) return cmp2;

    return (y.a.tokens.length + y.b.tokens.length).compareTo(
      x.a.tokens.length + x.b.tokens.length,
    );
  });

  if (results.isEmpty) {
    stdout.writeln('Похожие фрагменты не найдены.');
    return;
  }

  stdout.writeln('Найдено похожих пар: ${results.length}');
  stdout.writeln('');
  stdout.writeln('Параметры:');
  stdout.writeln('  minTokens=${config.minTokens}');
  stdout.writeln('  kGramSize=${config.kGramSize}');
  stdout.writeln('  windowSize=${config.windowSize}');
  stdout.writeln('  minSharedFingerprints=${config.minSharedFingerprints}');
  stdout.writeln('  minOverlap=${config.minOverlap}');
  stdout.writeln('  maxBucketSize=${config.maxBucketSize}');
  stdout.writeln('');

  for (var i = 0; i < results.length; i++) {
    final r = results[i];

    stdout.writeln('Пара ${i + 1}');
    stdout.writeln(
      '  overlap=${(r.overlap * 100).toStringAsFixed(1)}%  '
      'jaccard=${(r.jaccard * 100).toStringAsFixed(1)}%  '
      'sharedFingerprints=${r.sharedFingerprints}',
    );

    stdout.writeln(
      '  A: ${r.a.filePath}:${r.a.startLine}-${r.a.endLine}  ${r.a.kind} ${r.a.name}',
    );
    stdout.writeln(
      '     пример общего окна: строки ${r.sampleAStartLine}-${r.sampleAEndLine}',
    );

    stdout.writeln(
      '  B: ${r.b.filePath}:${r.b.startLine}-${r.b.endLine}  ${r.b.kind} ${r.b.name}',
    );
    stdout.writeln(
      '     пример общего окна: строки ${r.sampleBStartLine}-${r.sampleBEndLine}',
    );

    stdout.writeln('');
  }
}

class Config {
  Config({
    required this.rootPath,
    required this.minTokens,
    required this.kGramSize,
    required this.windowSize,
    required this.minSharedFingerprints,
    required this.minOverlap,
    required this.maxBucketSize,
  });

  final String rootPath;
  final int minTokens;
  final int kGramSize;
  final int windowSize;
  final int minSharedFingerprints;
  final double minOverlap;
  final int maxBucketSize;

  String? validate() {
    if (rootPath.isEmpty) {
      return 'rootPath must not be empty.';
    }
    if (minTokens <= 0) {
      return 'minTokens must be > 0.';
    }
    if (kGramSize <= 0) {
      return 'kGramSize must be > 0.';
    }
    if (windowSize <= 0) {
      return 'windowSize must be > 0.';
    }
    if (minSharedFingerprints <= 0) {
      return 'minSharedFingerprints must be > 0.';
    }
    if (minOverlap < 0 || minOverlap > 1) {
      return 'minOverlap must be in the range 0..1.';
    }
    if (maxBucketSize <= 0) {
      return 'maxBucketSize must be > 0.';
    }
    return null;
  }

  factory Config.fromArgs(List<String> args) {
    return Config(
      rootPath: args.isNotEmpty ? args[0] : '.',
      minTokens: args.length > 1 ? int.tryParse(args[1]) ?? 40 : 40,
      kGramSize: args.length > 2 ? int.tryParse(args[2]) ?? 25 : 25,
      windowSize: args.length > 3 ? int.tryParse(args[3]) ?? 4 : 4,
      minSharedFingerprints: args.length > 4 ? int.tryParse(args[4]) ?? 3 : 3,
      minOverlap: args.length > 5 ? double.tryParse(args[5]) ?? 0.35 : 0.35,
      maxBucketSize: args.length > 6 ? int.tryParse(args[6]) ?? 20 : 20,
    );
  }
}

class CodeBlock {
  CodeBlock({
    required this.id,
    required this.filePath,
    required this.kind,
    required this.name,
    required this.startLine,
    required this.endLine,
    required this.tokens,
    required this.tokenLines,
  });

  final int id;
  final String filePath;
  final String kind;
  final String name;
  final int startLine;
  final int endLine;
  final List<String> tokens;
  final List<int> tokenLines;

  late final List<int> tokenIds;
  late final List<Fingerprint> fingerprints;

  int get fingerprintCount => fingerprints.length;
}

class Fingerprint {
  Fingerprint({required this.hash, required this.tokenPosition});

  final int hash;
  final int tokenPosition;
}

class FingerprintOccurrence {
  FingerprintOccurrence({required this.blockId, required this.tokenPosition});

  final int blockId;
  final int tokenPosition;
}

class PairStat {
  PairStat({required this.aId, required this.bId});

  final int aId;
  final int bId;

  int sharedFingerprints = 0;
  int samplePosA = 0;
  int samplePosB = 0;
  bool hasSample = false;
}

class SimilarityResult {
  SimilarityResult({
    required this.a,
    required this.b,
    required this.sharedFingerprints,
    required this.overlap,
    required this.jaccard,
    required this.sampleAStartLine,
    required this.sampleAEndLine,
    required this.sampleBStartLine,
    required this.sampleBEndLine,
  });

  final CodeBlock a;
  final CodeBlock b;
  final int sharedFingerprints;
  final double overlap;
  final double jaccard;
  final int sampleAStartLine;
  final int sampleAEndLine;
  final int sampleBStartLine;
  final int sampleBEndLine;
}

class Vocabulary {
  final Map<String, int> _ids = {};
  int _nextId = 1;

  int intern(String token) {
    return _ids.putIfAbsent(token, () => _nextId++);
  }
}

class ExecutableCollector extends GeneralizingAstVisitor<void> {
  ExecutableCollector({
    required this.filePath,
    required this.lineStarts,
    required this.minTokens,
    required this.output,
  });

  final String filePath;
  final List<int> lineStarts;
  final int minTokens;
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
    final className = node.returnType.toSource();
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
    final normalized = _normalizeTokens(body.beginToken, body.endToken);
    if (normalized.tokens.length < minTokens) return;

    output.add(
      CodeBlock(
        id: output.length + 1,
        filePath: filePath,
        kind: kind,
        name: name,
        startLine: _offsetToLine(lineStarts, body.offset),
        endLine: _offsetToLine(lineStarts, body.end),
        tokens: normalized.tokens,
        tokenLines: normalized.tokenLines,
      ),
    );
  }

  NormalizedTokens _normalizeTokens(Token start, Token end) {
    final tokens = <String>[];
    final tokenLines = <int>[];

    Token current = start;

    while (true) {
      final normalized = _normalizeToken(current);
      if (normalized != null) {
        tokens.add(normalized);
        tokenLines.add(_offsetToLine(lineStarts, current.offset));
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

    if (type == TokenType.EOF ||
        type == TokenType.SCRIPT_TAG ||
        type == TokenType.SINGLE_LINE_COMMENT ||
        type == TokenType.MULTI_LINE_COMMENT ||
        type == TokenType.RECOVERY ||
        type == TokenType.BAD_INPUT) {
      return null;
    }

    if (type == TokenType.IDENTIFIER) {
      return 'ID';
    }

    if (type == TokenType.INT ||
        type == TokenType.INT_WITH_SEPARATORS ||
        type == TokenType.DOUBLE ||
        type == TokenType.DOUBLE_WITH_SEPARATORS ||
        type == TokenType.HEXADECIMAL ||
        type == TokenType.HEXADECIMAL_WITH_SEPARATORS) {
      return 'NUM';
    }

    if (type == TokenType.STRING || _looksLikeStringLiteral(lexeme)) {
      return 'STR';
    }

    if (lexeme == 'true' || lexeme == 'false') {
      return 'BOOL';
    }

    if (lexeme == 'null') {
      return 'NULL';
    }

    return type.lexeme.isNotEmpty ? type.lexeme : lexeme;
  }

  bool _looksLikeStringLiteral(String s) {
    return s.startsWith("'") ||
        s.startsWith('"') ||
        s.startsWith("r'") ||
        s.startsWith('r"') ||
        s.startsWith("'''") ||
        s.startsWith('"""') ||
        s.startsWith("r'''") ||
        s.startsWith('r"""');
  }
}

class NormalizedTokens {
  NormalizedTokens({required this.tokens, required this.tokenLines});

  final List<String> tokens;
  final List<int> tokenLines;
}

List<Fingerprint> buildKGramHashes({
  required List<int> tokenIds,
  required int kGramSize,
}) {
  if (tokenIds.length < kGramSize) return [];

  const int offsetBasis = 1469598103934665603;
  const int prime = 1099511628211;

  final result = <Fingerprint>[];

  for (var start = 0; start <= tokenIds.length - kGramSize; start++) {
    var hash = offsetBasis;

    for (var i = 0; i < kGramSize; i++) {
      hash = (hash ^ tokenIds[start + i]).toUnsigned(64);
      hash = (hash * prime).toUnsigned(64);
    }

    result.add(Fingerprint(hash: hash, tokenPosition: start));
  }

  return result;
}

List<Fingerprint> selectFingerprints({
  required List<Fingerprint> hashes,
  required int windowSize,
}) {
  if (hashes.isEmpty) return [];

  final actualWindow = math.max(1, windowSize);

  if (hashes.length <= actualWindow) {
    return [_pickRightmostMinimum(hashes, 0, hashes.length - 1)];
  }

  final result = <Fingerprint>[];
  int? lastSelectedPosition;

  for (var start = 0; start <= hashes.length - actualWindow; start++) {
    final end = start + actualWindow - 1;
    final picked = _pickRightmostMinimum(hashes, start, end);

    if (lastSelectedPosition != picked.tokenPosition) {
      result.add(picked);
      lastSelectedPosition = picked.tokenPosition;
    }
  }

  return result;
}

Fingerprint _pickRightmostMinimum(
  List<Fingerprint> hashes,
  int start,
  int end,
) {
  var best = hashes[start];

  for (var i = start + 1; i <= end; i++) {
    final current = hashes[i];

    if (current.hash < best.hash) {
      best = current;
      continue;
    }

    if (current.hash == best.hash &&
        current.tokenPosition > best.tokenPosition) {
      best = current;
    }
  }

  return best;
}

List<String> _collectDartFiles(String rootPath) {
  final root = Directory(rootPath);
  if (!root.existsSync()) {
    return [];
  }

  final result = <String>[];

  for (final entity in root.listSync(recursive: true, followLinks: false)) {
    if (entity is! File) continue;

    final path = entity.path.replaceAll('\\', '/');

    if (!path.endsWith('.dart')) continue;
    if (path.contains('/.dart_tool/')) continue;
    if (path.contains('/build/')) continue;
    if (path.contains('/.fvm/')) continue;
    if (path.endsWith('.g.dart')) continue;
    if (path.endsWith('.freezed.dart')) continue;
    if (path.endsWith('.mocks.dart')) continue;
    if (path.endsWith('.gen.dart')) continue;
    if (path.endsWith('.config.dart')) continue;

    result.add(entity.path);
  }

  result.sort();
  return result;
}

List<int> _computeLineStarts(String source) {
  final starts = <int>[0];
  for (var i = 0; i < source.length; i++) {
    if (source.codeUnitAt(i) == 10) {
      starts.add(i + 1);
    }
  }
  return starts;
}

int _offsetToLine(List<int> lineStarts, int offset) {
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

int _tokenPosToLine(CodeBlock block, int tokenPos) {
  if (block.tokenLines.isEmpty) return block.startLine;
  final safePos = tokenPos.clamp(0, block.tokenLines.length - 1);
  return block.tokenLines[safePos];
}

bool _isNestedPairInSameFile(CodeBlock a, CodeBlock b) {
  if (a.filePath != b.filePath) {
    return false;
  }

  return _containsLineRange(a, b) || _containsLineRange(b, a);
}

bool _containsLineRange(CodeBlock outer, CodeBlock inner) {
  return outer.startLine <= inner.startLine && outer.endLine >= inner.endLine;
}
