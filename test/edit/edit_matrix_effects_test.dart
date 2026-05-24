import 'dart:io';

import 'package:test/test.dart';

import '../support/flutter_in_package_test_harness.dart';

void main() {
  test('edit document and resource rows install through the store', () {
    return expectLater(
      runFlutterInPackageTest(
        'test/edit/fixtures/edit_matrix_effects_fixture.dart',
      ),
      completes,
    );
  });

  test('edit operation matrix fixture covers every edit-owned row', () {
    expect(
      _operationMatrixRowsCoveredByFixture(),
      _editOwnedRowsFromOperationMatrix(),
    );
    expect(_implementedEditMethodsMissingFromOperationMatrix(), isEmpty);
  });

  test('updateElement taxonomy rows are implemented by CommitCompiler', () {
    expect(_missingCompilerTaxonomyFields(), isEmpty);
  });
}

Set<String> _operationMatrixRowsCoveredByFixture() {
  final source = File(
    'test/edit/fixtures/edit_matrix_effects_fixture.dart',
  ).readAsStringSync();
  final rowPattern = RegExp(r"_EditOperationMatrixCase\(\s*'([^']+)'");

  return {for (final match in rowPattern.allMatches(source)) ?match.group(1)};
}

Set<String> _editOwnedRowsFromOperationMatrix() {
  final rows = _operationMatrixOperationRows();
  final editMethods = _implementedEditMutationNames();

  return {
    for (final row in rows)
      if (_isEditOwnedOperationRow(row, editMethods)) row,
  };
}

Set<String> _implementedEditMethodsMissingFromOperationMatrix() {
  final rows = _operationMatrixOperationRows();

  return {
    for (final method in _implementedEditMutationNames())
      if (!_operationRowsContainEditMethod(rows, method)) method,
  };
}

bool _isEditOwnedOperationRow(String row, Set<String> editMethods) {
  if (row == 'no-op edit') {
    return true;
  }

  final method = _editMethodNameFromOperationRow(row);

  return method != null && editMethods.contains(method);
}

bool _operationRowsContainEditMethod(Set<String> rows, String method) {
  return rows.any((row) => _editMethodNameFromOperationRow(row) == method);
}

String? _editMethodNameFromOperationRow(String row) {
  const qualifiedPrefix = 'CanvasEdit.';
  final operation = row.startsWith(qualifiedPrefix)
      ? row.substring(qualifiedPrefix.length)
      : row;
  final method = operation.split(' ').first;
  if (!RegExp(r'^[a-z][A-Za-z0-9]+$').hasMatch(method)) {
    return null;
  }

  return method;
}

Set<String> _operationMatrixOperationRows() {
  final source = File('docs/contracts/operation_matrix.md').readAsStringSync();
  final tableStart = source.indexOf('| Operation | State touched |');
  final tableEnd = source.indexOf('\nNotes:', tableStart);

  return _markdownTableFirstColumnFromSource(
    source.substring(tableStart, tableEnd),
  );
}

Set<String> _implementedEditMutationNames() {
  final apiSource = File('lib/src/api/canvas_runtime.dart').readAsStringSync();
  final editInterface = _declarationBody(apiSource, 'CanvasEdit');
  final mutationPattern = RegExp(
    r'(?:bool|void|CanvasElementId|CanvasClearResult)\s+([A-Za-z0-9_]+)\s*\(',
  );
  final unsupported = _unsupportedEditMethods();

  return {
    for (final method in _firstCaptureGroups(mutationPattern, editInterface))
      if (!unsupported.contains(method)) method,
  };
}

Set<String> _unsupportedEditMethods() {
  final source = File('lib/src/edit/edit_session.dart').readAsStringSync();
  final unsupportedPattern = RegExp(
    r'CanvasEdit\.([A-Za-z0-9_]+) is owned by ',
  );

  return _firstCaptureGroups(unsupportedPattern, source);
}

Set<String> _firstCaptureGroups(RegExp pattern, String source) {
  final values = <String>{};
  for (final match in pattern.allMatches(source)) {
    final value = match.group(1);
    if (value != null) {
      values.add(value);
    }
  }

  return values;
}

List<String> _missingCompilerTaxonomyFields() {
  final compilerSource = File(
    'lib/src/edit/commit_compiler.dart',
  ).readAsStringSync();

  return [
    for (final token in _updateElementTaxonomyTokens())
      if (!_compilerFunctionForToken(
        compilerSource,
        token,
      ).contains(_fieldComparisonForToken(token)))
        token,
  ];
}

Set<String> _updateElementTaxonomyTokens() {
  final source = File('docs/contracts/edit_kernel.md').readAsStringSync();
  final taxonomyStart = source.indexOf('Field taxonomy:');
  final taxonomyEnd = source.indexOf(
    '`CommitCompiler` may implement',
    taxonomyStart,
  );
  final taxonomy = source.substring(taxonomyStart, taxonomyEnd);
  final rows = _markdownTableFirstColumnFromSource(taxonomy);
  final tokenPattern = RegExp(r'`([^`]+)`');

  return {
    for (final row in rows)
      for (final match in tokenPattern.allMatches(row)) ?match.group(1),
  };
}

String _compilerFunctionForToken(String source, String token) {
  return _functionBody(source, _taxonomyFunctionName(token));
}

String _taxonomyFunctionName(String token) {
  return switch (token.substring(0, token.indexOf('.'))) {
    'CanvasElementUpdate' => '_elementUpdateDelta',
    'CanvasImageElementUpdate' => '_imageUpdateDelta',
    'CanvasPathElementUpdate' => '_pathUpdateDelta',
    'CanvasTextElementUpdate' => '_textUpdateDelta',
    'CanvasStrokeElementUpdate' => '_strokeUpdateDelta',
    'CanvasLineElementUpdate' => '_lineUpdateDelta',
    'CanvasRectElementUpdate' => '_rectUpdateDelta',
    final owner => throw StateError('Unknown update taxonomy owner: $owner'),
  };
}

String _fieldComparisonForToken(String token) {
  final field = token.substring(token.indexOf('.') + 1);
  if (field == 'points') {
    return '_sameList(before.points, after.points)';
  }

  return 'before.$field != after.$field';
}

String _functionBody(String source, String functionName) {
  final declaration = RegExp(
    'StoreRevisionDelta\\s+$functionName\\s*\\(',
  ).firstMatch(source);
  if (declaration == null) {
    throw StateError('Missing compiler taxonomy function: $functionName');
  }

  return _balancedBody(source, source.indexOf('{', declaration.start));
}

String _balancedBody(String source, int bodyStart) {
  var depth = 0;
  for (var index = bodyStart; index < source.length; index += 1) {
    final character = source[index];
    if (character == '{') {
      depth += 1;
    } else if (character == '}') {
      depth -= 1;
      if (depth == 0) {
        return source.substring(bodyStart, index + 1);
      }
    }
  }

  throw StateError('Unclosed declaration body.');
}

Set<String> _markdownTableFirstColumnFromSource(String source) {
  return {
    for (final line in source.split('\n'))
      if (line.startsWith('| ') &&
          !line.startsWith('|---') &&
          !line.startsWith('| Operation ') &&
          !line.startsWith('| Field token '))
        line.split('|')[1].trim(),
  };
}

String _declarationBody(String source, String declarationName) {
  final declaration = RegExp(
    'abstract interface class $declarationName\\s*{',
  ).firstMatch(source);
  if (declaration == null) {
    throw StateError('Missing declaration: $declarationName');
  }

  return _balancedBody(source, source.indexOf('{', declaration.start));
}
