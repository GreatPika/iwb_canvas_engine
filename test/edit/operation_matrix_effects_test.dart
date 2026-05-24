import 'dart:io';

import 'package:test/test.dart';

import '../support/flutter_in_package_test_harness.dart';

void main() {
  test('edit document and resource rows install through the store', () {
    return expectLater(
      runFlutterInPackageTest(
        'test/edit/fixtures/operation_matrix_effects_fixture.dart',
      ),
      completes,
    );
  });

  test('edit operation matrix fixture covers every edit-owned row', () {
    expect(
      _operationMatrixRowsCoveredByFixture(),
      _editOwnedRowsFromOperationMatrix(),
    );
  });

  test('updateElement taxonomy rows are implemented by CommitCompiler', () {
    expect(_missingCompilerTaxonomyFields(), isEmpty);
  });
}

Set<String> _operationMatrixRowsCoveredByFixture() {
  final source = File(
    'test/edit/fixtures/operation_matrix_effects_fixture.dart',
  ).readAsStringSync();
  final rowPattern = RegExp(r"_EditOperationMatrixCase\(\s*'([^']+)'");

  return {for (final match in rowPattern.allMatches(source)) ?match.group(1)};
}

Set<String> _editOwnedRowsFromOperationMatrix() {
  final rows = _markdownTableFirstColumn('docs/contracts/operation_matrix.md');

  return rows.where(_isEditOwnedOperationRow).toSet();
}

bool _isEditOwnedOperationRow(String row) {
  return _editOwnedOperationMatrixRows.contains(row);
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
  final bodyStart = source.indexOf('{', declaration.start);
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

  throw StateError('Unclosed compiler taxonomy function: $functionName');
}

Set<String> _markdownTableFirstColumn(String path) {
  return _markdownTableFirstColumnFromSource(File(path).readAsStringSync());
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

const _editOwnedOperationMatrixRows = {
  'addElement content',
  'addBackgroundElement',
  'CanvasEdit.updateElement',
  'CanvasEdit.removeElement',
  'ensureLayer no-op',
  'ensureLayer changed',
  'CanvasEdit.clearContent',
  'CanvasEdit.setCameraOffset',
  'setBackgroundColor',
  'setGrid',
  'setPalette',
  'upsertResource new/changed',
  'removeUnusedResource removed',
  'no-op edit',
};
