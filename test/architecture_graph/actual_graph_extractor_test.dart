import 'package:test/test.dart';

import '../../tool/architecture_graph/src/actual_graph.dart';
import '../../tool/architecture_graph/src/architecture_graph.dart';

void main() {
  const fixture = 'test/architecture_graph/fixtures/actual_graph_fixture.dart';
  const helper = 'test/architecture_graph/fixtures/actual_graph_helper.dart';

  test('extracts architecture-level declarations and directives', () {
    final graph = extractActualArchitectureGraphFromPaths(paths: [fixture]);

    expect(
      graph.exports.map((fact) => fact.uri),
      contains('test/architecture_graph/fixtures/exported_fixture.dart'),
    );
    expect(
      graph.imports.map((fact) => fact.uri),
      contains('test/architecture_graph/fixtures/exported_fixture.dart'),
    );
    expect(
      graph.declarations.map((fact) => fact.name),
      contains('FixtureOwner'),
    );
    expect(
      graph.declarations.map((fact) => fact.name),
      contains('FixturePort'),
    );
  });

  test('extracts implemented interfaces and composition fields', () {
    final graph = extractActualArchitectureGraphFromPaths(
      paths: [fixture],
      compositionTypes: const {'ExportedFixture'},
    );

    expect(
      graph.implementedInterfaces.map(
        (fact) => '${fact.declaration}:${fact.interface}',
      ),
      contains('FixtureOwner:FixturePort'),
    );
    expect(
      graph.compositionFields.map((fact) => '${fact.field}:${fact.type}'),
      contains('dependency:ExportedFixture'),
    );
  });

  test('extracts placeholders, exception throws, and simple delegations', () {
    final graph = extractActualArchitectureGraphFromPaths(
      paths: [fixture],
      compositionTypes: const {'ExportedFixture'},
      placeholderCoverage: const [
        PlaceholderCoverage(under: 'test/architecture_graph/fixtures/**'),
      ],
      sensitiveThrows: const [
        SensitiveThrowCoverage(
          owner: 'fixture.owner',
          under: 'test/architecture_graph/fixtures/**',
          exception: 'FixtureException',
        ),
      ],
    );

    expect(
      graph.placeholders.map((fact) => '${fact.member}:${fact.throwType}'),
      contains('FixtureOwner.missing:UnimplementedError'),
    );
    expect(
      graph.exceptionThrows.map((fact) => '${fact.owner}:${fact.exception}'),
      contains('FixtureOwner:FixtureException'),
    );
    expect(
      graph.delegations.map((fact) => '${fact.member}:${fact.targetType}'),
      contains('FixtureOwner.exposed:ExportedFixture'),
    );
  });

  test('ignores helper-level files outside declared extraction input', () {
    final graph = extractActualArchitectureGraphFromPaths(paths: [fixture]);

    expect(
      graph.declarations.map((fact) => fact.name),
      isNot(contains('IgnoredHelperFixture')),
    );
  });

  test('does not treat non-architecture fields as composition facts', () {
    final graph = extractActualArchitectureGraphFromPaths(paths: [fixture]);

    expect(graph.compositionFields, isEmpty);
  });

  test(
    'allows explicit helper input without inventing placeholder violations',
    () {
      final graph = extractActualArchitectureGraphFromPaths(paths: [helper]);

      expect(graph.placeholders, isEmpty);
      expect(graph.exceptionThrows, isEmpty);
    },
  );

  test(
    'does not extract placeholders outside declared placeholder coverage',
    () {
      final graph = extractActualArchitectureGraphFromPaths(paths: [fixture]);

      expect(graph.placeholders, isEmpty);
    },
  );

  test('normalizes directive URIs to repository-relative paths', () {
    expect(
      normalizeDirectiveUri(
        sourcePath: 'lib/iwb_canvas_engine.dart',
        uri: 'src/api/canvas_runtime.dart',
      ),
      'lib/src/api/canvas_runtime.dart',
    );
    expect(
      normalizeDirectiveUri(
        sourcePath: 'lib/src/api/canvas_runtime.dart',
        uri: '../runtime/runtime_root.dart',
      ),
      'lib/src/runtime/runtime_root.dart',
    );
    expect(
      normalizeDirectiveUri(
        sourcePath: 'lib/src/api/canvas_runtime.dart',
        uri: 'package:iwb_canvas_engine/src/api/canvas_document.dart',
      ),
      'lib/src/api/canvas_document.dart',
    );
  });

  test('assigns sensitive throw owner from coverage for top-level throws', () {
    final graph = extractActualArchitectureGraphFromPaths(
      paths: [fixture],
      sensitiveThrows: const [
        SensitiveThrowCoverage(
          owner: 'fixture.owner',
          under: 'test/architecture_graph/fixtures/**',
          exception: 'FixtureException',
        ),
      ],
    );

    expect(
      graph.exceptionThrows.map((fact) => '${fact.owner}:${fact.exception}'),
      contains('fixture.owner:FixtureException'),
    );
    expect(
      graph.exceptionThrows.map((fact) => '${fact.owner}:${fact.exception}'),
      contains('null:OtherFixtureException'),
    );
  });
}
