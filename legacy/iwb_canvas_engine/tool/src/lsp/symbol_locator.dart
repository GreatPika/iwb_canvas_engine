import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';

final class LocatedSymbol {
  const LocatedSymbol({
    required this.repoRelativePath,
    required this.displayName,
    required this.line,
    required this.character,
    required this.kind,
  });

  final String repoRelativePath;
  final String displayName;
  final int line;
  final int character;
  final String kind;
}

LocatedSymbol locateSymbol({
  required Directory root,
  required String repoRelativePath,
  required String query,
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
  final unit = parsed.unit;
  final lineInfo = parsed.lineInfo;

  final classMethodMatch = RegExp(
    r'^([A-Za-z_]\w*)\.([A-Za-z_]\w*)$',
  ).firstMatch(query);
  if (classMethodMatch != null) {
    final className = classMethodMatch.group(1);
    final memberName = classMethodMatch.group(2);
    if (className == null || memberName == null) {
      throw SymbolLocateFailure(
        'Symbol query "$query" could not be parsed in $repoRelativePath.',
      );
    }
    for (final declaration in unit.declarations.whereType<ClassDeclaration>()) {
      if (declaration.name.lexeme != className) {
        continue;
      }
      for (final member in declaration.members) {
        if (member is MethodDeclaration && member.name.lexeme == memberName) {
          final location = lineInfo.getLocation(member.name.offset);
          return LocatedSymbol(
            repoRelativePath: repoRelativePath,
            displayName: '$className.$memberName',
            line: location.lineNumber - 1,
            character: location.columnNumber - 1,
            kind: member.isGetter
                ? 'getter'
                : member.isSetter
                ? 'setter'
                : 'method',
          );
        }
      }
      throw SymbolLocateFailure(
        'Class "$className" does not declare member "$memberName" in '
        '$repoRelativePath.',
      );
    }
    throw SymbolLocateFailure(
      'Class "$className" not found in $repoRelativePath.',
    );
  }

  for (final declaration in unit.declarations) {
    switch (declaration) {
      case ClassDeclaration(:final name):
        if (name.lexeme != query) {
          continue;
        }
        final location = lineInfo.getLocation(name.offset);
        return LocatedSymbol(
          repoRelativePath: repoRelativePath,
          displayName: query,
          line: location.lineNumber - 1,
          character: location.columnNumber - 1,
          kind: 'class',
        );
      case FunctionDeclaration(:final name):
        if (name.lexeme != query) {
          continue;
        }
        final location = lineInfo.getLocation(name.offset);
        final kind = declaration.isGetter
            ? 'getter'
            : declaration.isSetter
            ? 'setter'
            : 'function';
        return LocatedSymbol(
          repoRelativePath: repoRelativePath,
          displayName: query,
          line: location.lineNumber - 1,
          character: location.columnNumber - 1,
          kind: kind,
        );
      default:
        continue;
    }
  }

  throw SymbolLocateFailure('Symbol "$query" not found in $repoRelativePath.');
}

final class SymbolLocateFailure implements Exception {
  const SymbolLocateFailure(this.message);

  final String message;

  @override
  String toString() => message;
}
