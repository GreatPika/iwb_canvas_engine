import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:test/test.dart';

import '../support/flutter_in_package_test_harness.dart';

// The structural check uses analyzer resolution so aliases and helper wrappers
// cannot hide reads from the retired SpatialQueryResult candidate seam.
// ignore_for_file: number-of-external-imports

void main() {
  test('frame spatial paint admission distinguishes rejection from empty', () {
    return expectLater(
      runFlutterInPackageTest(
        'test/frame/fixtures/frame_spatial_paint_admission_fixture.dart',
      ),
      completes,
    );
  });

  test(
    'frame and spatial test support do not read base spatial candidates',
    () async {
      expect(await _baseSpatialCandidateAccessViolations(), isEmpty);
    },
  );
}

Future<List<String>> _baseSpatialCandidateAccessViolations() async {
  final root = Directory.current.path;
  final collection = AnalysisContextCollection(
    includedPaths: [
      '$root/lib/src/frame',
      '$root/test/frame',
      '$root/test/spatial',
    ],
  );
  final violations = <String>[];

  try {
    for (final file in _candidateConsumerFiles(root)) {
      final context = collection.contextFor(file.absolute.path);
      final result = await context.currentSession.getResolvedUnit(
        file.absolute.path,
      );
      if (result is! ResolvedUnitResult) {
        violations.add('Could not resolve ${file.path}.');
        continue;
      }

      final visitor = _BaseSpatialCandidateAccessVisitor(file.path);
      result.unit.accept(visitor);
      violations.addAll(visitor.violations);
    }
  } finally {
    await collection.dispose();
  }

  return violations;
}

Iterable<File> _candidateConsumerFiles(String root) sync* {
  for (final relativeDirectory in const [
    'lib/src/frame',
    'test/frame/fixtures',
    'test/spatial/fixtures',
  ]) {
    final directory = Directory('$root/$relativeDirectory');
    if (!directory.existsSync()) {
      continue;
    }
    yield* directory
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'));
  }
}

final class _BaseSpatialCandidateAccessVisitor
    extends RecursiveAstVisitor<void> {
  _BaseSpatialCandidateAccessVisitor(this.path);

  final String path;
  final List<String> violations = [];

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    if (node.name == 'candidates' || node.name == 'hasCandidates') {
      final element = node.element;
      if (_isSpatialQueryResultMember(element)) {
        violations.add('$path reads SpatialQueryResult.${node.name}');
      }
    }
    super.visitSimpleIdentifier(node);
  }

  bool _isSpatialQueryResultMember(Element? element) {
    final enclosingName = element?.enclosingElement?.displayName;
    final libraryUri = element?.library?.uri.toString();

    return enclosingName == 'SpatialQueryResult' &&
        libraryUri?.endsWith('/spatial_query_result.dart') == true;
  }
}
