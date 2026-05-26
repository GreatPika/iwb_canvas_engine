import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
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
  void blockMethod({required int count}) {
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

  test('surface detector covers structurally empty CanvasSurface state', () {
    const source = '''
final class CanvasSurface extends StatefulWidget {}

final class _CanvasSurfaceState extends State<CanvasSurface> {
  @override
  Widget build(BuildContext context) {
    return const SizedBox
        .shrink();
  }
}
''';

    final discovered = _surfacePlaceholdersInSource(source);
    final allowlisted = {
      for (final placeholder in publicApiPlaceholderAllowlist)
        placeholder.declarationId,
    };

    expect(discovered, {'CanvasSurface.build'});
    expect(discovered.difference(allowlisted), isEmpty);
  });
}

void _testExportCombinators() {
  test('detector covers root exports with combinators', () {
    final exportedFiles = _exportedPublicApiFilesFromBarrel('''
export 'src/api/visible.dart';
export 'src/api/shown.dart' show PublicType;
export 'src/api/hidden.dart' hide PublicType;
''');

    expect(exportedFiles.map((file) => file.file.path), [
      endsWith('lib/src/api/visible.dart'),
      endsWith('lib/src/api/shown.dart'),
      endsWith('lib/src/api/hidden.dart'),
    ]);
    expect(exportedFiles[0].includesTopLevelName('PublicType'), isTrue);
    expect(exportedFiles[1].includesTopLevelName('PublicType'), isTrue);
    expect(exportedFiles[1].includesTopLevelName('publicHelper'), isFalse);
    expect(exportedFiles[2].includesTopLevelName('PublicType'), isFalse);
    expect(exportedFiles[2].includesTopLevelName('publicHelper'), isTrue);
  });

  test('detector ignores placeholders hidden by root export combinators', () {
    const source = '''
final class ExportedType {
  void method() => throw UnimplementedError();
}

void publicHelper({required int count}) => throw UnimplementedError();
''';

    expect(
      _unimplementedPlaceholdersInSource(
        source,
        isExportedTopLevelName: (name) => name == 'ExportedType',
      ),
      {'ExportedType.method'},
    );
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

List<_ExportedPublicApiFile> _exportedPublicApiFiles() {
  final barrel = File(
    '$repositoryRoot/lib/iwb_canvas_engine.dart',
  ).readAsStringSync();

  return _exportedPublicApiFilesFromBarrel(barrel);
}

List<_ExportedPublicApiFile> _exportedPublicApiFilesFromBarrel(String barrel) {
  final unit = parseString(
    content: barrel,
    path: '$repositoryRoot/lib/iwb_canvas_engine.dart',
  ).unit;

  return [
    for (final directive in unit.directives)
      if (directive is ExportDirective)
        if (directive.uri.stringValue case final path?)
          _ExportedPublicApiFile(
            file: File('$repositoryRoot/lib/$path'),
            combinators: directive.combinators,
          ),
  ];
}

Set<String> _unimplementedPlaceholders(_ExportedPublicApiFile file) {
  return _unimplementedPlaceholdersInSource(
    file.file.readAsStringSync(),
    isExportedTopLevelName: file.includesTopLevelName,
  );
}

Set<String> _unimplementedPlaceholdersInSource(
  String source, {
  bool Function(String name) isExportedTopLevelName = _isPublicTopLevelName,
}) {
  final unit = parseString(content: source).unit;

  return _PublicPlaceholderCollector().collect(
    unit,
    isExportedTopLevelName: isExportedTopLevelName,
  );
}

Set<String> _surfacePlaceholders() {
  final source = File(
    '$repositoryRoot/lib/src/api/canvas_surface.dart',
  ).readAsStringSync();

  return _surfacePlaceholdersInSource(source);
}

Set<String> _surfacePlaceholdersInSource(String source) {
  final unit = parseString(content: source).unit;

  return {if (_hasCanvasSurfaceEmptyStateBuild(unit)) 'CanvasSurface.build'};
}

bool _hasCanvasSurfaceEmptyStateBuild(CompilationUnit unit) {
  for (final declaration in unit.declarations) {
    if (declaration is! ClassDeclaration ||
        declaration.namePart.typeName.lexeme != '_CanvasSurfaceState' ||
        !_extendsCanvasSurfaceState(declaration)) {
      continue;
    }
    for (final member in declaration.body.members) {
      if (member is MethodDeclaration &&
          member.name.lexeme == 'build' &&
          _returnsConstSizedBoxShrink(member.body)) {
        return true;
      }
    }
  }

  return false;
}

bool _extendsCanvasSurfaceState(ClassDeclaration declaration) {
  final superclass = declaration.extendsClause?.superclass;
  final typeArguments = superclass?.typeArguments?.arguments;

  return superclass?.name.lexeme == 'State' &&
      typeArguments != null &&
      typeArguments.length == 1 &&
      typeArguments.single.toSource() == 'CanvasSurface';
}

bool _returnsConstSizedBoxShrink(FunctionBody body) {
  return switch (body) {
    ExpressionFunctionBody(:final expression) => _isConstSizedBoxShrink(
      expression,
    ),
    BlockFunctionBody(:final block) => switch (block.statements) {
      [ReturnStatement(:final expression?)] => _isConstSizedBoxShrink(
        expression,
      ),
      _ => false,
    },
    _ => false,
  };
}

bool _isConstSizedBoxShrink(Expression expression) {
  if (expression is! InstanceCreationExpression ||
      !expression.isConst ||
      expression.argumentList.arguments.isNotEmpty) {
    return false;
  }

  final constructorName = expression.constructorName;
  final type = constructorName.type;
  final typeName = type.importPrefix?.name.lexeme ?? type.name.lexeme;
  final namedConstructor = constructorName.name?.name ?? type.name.lexeme;

  return typeName == 'SizedBox' && namedConstructor == 'shrink';
}

final class _PublicPlaceholderCollector {
  Set<String> collect(
    CompilationUnit unit, {
    required bool Function(String name) isExportedTopLevelName,
  }) {
    final placeholders = <String>{};
    for (final declaration in unit.declarations) {
      switch (declaration) {
        case FunctionDeclaration():
          _addTopLevelPlaceholder(
            declaration,
            placeholders,
            isExportedTopLevelName: isExportedTopLevelName,
          );
        case ClassDeclaration():
          _addClassPlaceholders(
            declaration,
            placeholders,
            isExportedTopLevelName: isExportedTopLevelName,
          );
      }
    }

    return placeholders;
  }

  void _addTopLevelPlaceholder(
    FunctionDeclaration declaration,
    Set<String> placeholders, {
    required bool Function(String name) isExportedTopLevelName,
  }) {
    final name = declaration.name.lexeme;
    if (!isExportedTopLevelName(name) ||
        !_isUnimplementedBody(declaration.functionExpression.body)) {
      return;
    }
    placeholders.add(name);
  }

  void _addClassPlaceholders(
    ClassDeclaration declaration,
    Set<String> placeholders, {
    required bool Function(String name) isExportedTopLevelName,
  }) {
    final className = declaration.namePart.typeName.lexeme;
    if (!isExportedTopLevelName(className)) {
      return;
    }
    for (final member in declaration.body.members) {
      switch (member) {
        case MethodDeclaration():
          _addMethodPlaceholder(className, member, placeholders);
        case ConstructorDeclaration():
          _addConstructorPlaceholder(className, member, placeholders);
        default:
          break;
      }
    }
  }

  void _addMethodPlaceholder(
    String className,
    MethodDeclaration declaration,
    Set<String> placeholders,
  ) {
    final name = declaration.name.lexeme;
    if (_isPrivateName(name) || !_isUnimplementedBody(declaration.body)) {
      return;
    }
    placeholders.add('$className.$name');
  }

  void _addConstructorPlaceholder(
    String className,
    ConstructorDeclaration declaration,
    Set<String> placeholders,
  ) {
    final constructorName = declaration.name?.lexeme;
    if (_isPrivateName(constructorName) ||
        !_isUnimplementedBody(declaration.body)) {
      return;
    }
    placeholders.add('$className.${constructorName ?? 'new'}');
  }
}

bool _isUnimplementedBody(FunctionBody body) {
  return switch (body) {
    ExpressionFunctionBody(:final expression) => _isUnimplementedThrow(
      expression,
    ),
    BlockFunctionBody(:final block) => switch (block.statements) {
      [ExpressionStatement(:final expression)] => _isUnimplementedThrow(
        expression,
      ),
      _ => false,
    },
    _ => false,
  };
}

bool _isUnimplementedThrow(Expression expression) {
  return expression is ThrowExpression &&
      _isUnimplementedError(expression.expression);
}

bool _isUnimplementedError(Expression expression) {
  return switch (expression) {
    InstanceCreationExpression() =>
      expression.constructorName.type.toSource() == 'UnimplementedError',
    MethodInvocation(:final target, :final methodName) =>
      target == null && methodName.name == 'UnimplementedError',
    _ => false,
  };
}

bool _isPrivateName(String? name) => name?.startsWith('_') ?? false;

bool _isPublicTopLevelName(String name) => !_isPrivateName(name);

final class _ExportedPublicApiFile {
  _ExportedPublicApiFile({
    required this.file,
    required NodeList<Combinator> combinators,
  }) : shownNames = _shownNames(combinators),
       hiddenNames = _hiddenNames(combinators);

  final File file;
  final Set<String>? shownNames;
  final Set<String> hiddenNames;

  bool includesTopLevelName(String name) {
    if (_isPrivateName(name)) {
      return false;
    }
    if (shownNames case final shownNames? when !shownNames.contains(name)) {
      return false;
    }

    return !hiddenNames.contains(name);
  }
}

Set<String>? _shownNames(NodeList<Combinator> combinators) {
  Set<String>? shownNames;
  for (final combinator in combinators) {
    if (combinator is! ShowCombinator) {
      continue;
    }
    final names = combinator.shownNames.map((name) => name.name).toSet();
    shownNames = shownNames == null ? names : shownNames.intersection(names);
  }

  return shownNames;
}

Set<String> _hiddenNames(NodeList<Combinator> combinators) {
  return {
    for (final combinator in combinators)
      if (combinator is HideCombinator)
        for (final name in combinator.hiddenNames) name.name,
  };
}
