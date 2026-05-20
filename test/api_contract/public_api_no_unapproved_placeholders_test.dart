import 'dart:io';

import 'package:test/test.dart';

import '../../tool/guardrails/src/public_api_placeholder_allowlist.dart';
import '../../tool/guardrails/src/repository_paths.dart';

void main() {
  _testAllowlistedPlaceholders();
  _testAllowlistMetadata();
  _testPlaceholderDetector();
  _testExportCombinators();
}

void _testAllowlistedPlaceholders() {
  test('exported public placeholders are explicitly allowlisted', () {
    final discovered = _discoverPublicApiPlaceholders();
    final allowlisted = {
      for (final placeholder in publicApiPlaceholderAllowlist)
        placeholder.declarationId,
    };

    expect(discovered.difference(allowlisted), isEmpty);
    expect(allowlisted.difference(discovered), isEmpty);
  });
}

void _testAllowlistMetadata() {
  test(
    'allowlist entries carry owner phase, reason, and removal condition',
    () {
      for (final placeholder in publicApiPlaceholderAllowlist) {
        expect(placeholder.ownerPhase, matches(RegExp(r'^P\d+$')));
        expect(placeholder.reason.trim(), isNotEmpty);
        expect(placeholder.removalCondition.trim(), isNotEmpty);
      }
    },
  );
}

void _testPlaceholderDetector() {
  test('detector covers block bodies and ignores private helpers', () {
    expect(
      _unimplementedPlaceholdersInSource('''
final class PublicApi {
  Object get expressionGetter => throw UnimplementedError();
  void blockMethod() {
    throw UnimplementedError();
  }
  void _privateMethod() {
    throw UnimplementedError();
  }
}

final class PublicConstructors {
  factory PublicConstructors() => throw UnimplementedError();
  PublicConstructors.named() {
    throw UnimplementedError();
  }
}

final class _PrivateHelper {
  void run() {
    throw UnimplementedError();
  }
}

void topLevelPublic() {
  throw UnimplementedError();
}

void _topLevelPrivate() {
  throw UnimplementedError();
}
'''),
      {
        'PublicApi.expressionGetter',
        'PublicApi.blockMethod',
        'PublicConstructors.new',
        'PublicConstructors.named',
        'topLevelPublic',
      },
    );
  });
}

void _testExportCombinators() {
  test('detector covers root exports with combinators', () {
    final paths = _exportedPublicApiPathsFromBarrel('''
export 'src/api/visible.dart';
export 'src/api/shown.dart' show PublicType;
export 'src/api/hidden.dart' hide PrivateType;
''').map((file) => file.path).toList();

    expect(paths, [
      endsWith('lib/src/api/visible.dart'),
      endsWith('lib/src/api/shown.dart'),
      endsWith('lib/src/api/hidden.dart'),
    ]);
  });
}

Set<String> _discoverPublicApiPlaceholders() {
  final placeholders = <String>{};
  for (final file in _exportedPublicApiFiles()) {
    placeholders.addAll(_unimplementedPlaceholders(file));
  }
  placeholders.addAll(_surfacePlaceholders());

  return placeholders;
}

List<File> _exportedPublicApiFiles() {
  final barrel = File(
    '$repositoryRoot/lib/iwb_canvas_engine.dart',
  ).readAsStringSync();

  return _exportedPublicApiPathsFromBarrel(barrel);
}

List<File> _exportedPublicApiPathsFromBarrel(String barrel) {
  return [
    for (final match in RegExp(
      r"export\s+'([^']+)'\s*(?:show\s+[^;]+|hide\s+[^;]+)?;",
    ).allMatches(barrel))
      File('$repositoryRoot/lib/${match.group(1)}'),
  ];
}

Set<String> _unimplementedPlaceholders(File file) {
  return _unimplementedPlaceholdersInSource(file.readAsStringSync());
}

Set<String> _unimplementedPlaceholdersInSource(String source) {
  final placeholders = <String>{};
  _addCallablePlaceholders(source, placeholders);
  _addConstructorPlaceholders(source, placeholders);

  return placeholders;
}

void _addCallablePlaceholders(String source, Set<String> placeholders) {
  for (final match in _callableSignatures().allMatches(source)) {
    final name = match.group(1) ?? match.group(2);
    if (name == null || name.startsWith('_')) {
      continue;
    }
    final className = _enclosingClassName(source, match.start);
    if (className != null && className.startsWith('_')) {
      continue;
    }
    if (className == name) {
      continue;
    }
    placeholders.add(className == null ? name : '$className.$name');
  }
}

void _addConstructorPlaceholders(String source, Set<String> placeholders) {
  for (final match in _constructorSignatures().allMatches(source)) {
    final className = match.group(1);
    final constructorName = match.group(2);
    final enclosingClassName = _enclosingClassName(source, match.start);
    if (!_isPublicConstructorPlaceholder(
      className,
      constructorName,
      enclosingClassName,
    )) {
      continue;
    }
    placeholders.add('$className.${constructorName ?? 'new'}');
  }
}

bool _isPublicConstructorPlaceholder(
  String? className,
  String? constructorName,
  String? enclosingClassName,
) {
  return className != null &&
      enclosingClassName != null &&
      className == enclosingClassName &&
      !className.startsWith('_') &&
      !(constructorName?.startsWith('_') ?? false);
}

RegExp _callableSignatures() {
  return RegExp(
    r'(?:[A-Za-z0-9_<>,? ]+)\s+get\s+([a-zA-Z0-9_]+)\s*(?:=>\s*throw UnimplementedError\(\)|\{\s*throw UnimplementedError\(\);\s*\})|'
    r'(?:[A-Za-z0-9_<>,? ]+|void)\s+([a-zA-Z0-9_]+)\([^;{}]*\)\s*(?:=>\s*throw UnimplementedError\(\)|\{\s*throw UnimplementedError\(\);\s*\})',
    multiLine: true,
  );
}

RegExp _constructorSignatures() {
  return RegExp(
    r'(?:factory\s+)?([A-Za-z0-9_]+)(?:\.([A-Za-z0-9_]+))?\([^;{}]*\)\s*(?:=>\s*throw UnimplementedError\(\)|\{\s*throw UnimplementedError\(\);\s*\})',
    multiLine: true,
  );
}

Set<String> _surfacePlaceholders() {
  final source = File(
    '$repositoryRoot/lib/src/api/canvas_surface.dart',
  ).readAsStringSync();

  return {
    if (source.contains(
      'Widget build(BuildContext context) => const SizedBox.shrink();',
    ))
      'CanvasSurface.build',
  };
}

String? _enclosingClassName(String source, int offset) {
  final declarations = RegExp(
    r'(?:abstract\s+interface\s+class|base\s+class|final\s+class|sealed\s+class|class)\s+([A-Za-z0-9_]+)[^{]*\{',
  ).allMatches(source.substring(0, offset));
  if (declarations.isEmpty) {
    return null;
  }

  final declaration = declarations.last;
  final className = declaration.group(1);
  if (className == null) {
    return null;
  }

  final bodyStart = declaration.end - 1;
  final body = source.substring(bodyStart, offset);

  return _hasOpenBody(body) ? className : null;
}

bool _hasOpenBody(String body) {
  var depth = 0;
  for (final unit in body.codeUnits) {
    if (unit == _openBrace) {
      depth++;
    } else if (unit == _closeBrace) {
      depth--;
    }
  }

  return depth > 0;
}

const int _openBrace = 0x7B;
const int _closeBrace = 0x7D;
