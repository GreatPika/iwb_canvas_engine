import 'package:test/test.dart';

import '../../tool/architecture_graph/src/actual_graph.dart';
import '../../tool/architecture_graph/src/architecture_graph.dart';

const _fixture = 'test/architecture_graph/fixtures/actual_graph_fixture.dart';
const _helper = 'test/architecture_graph/fixtures/actual_graph_helper.dart';
const _unroutedMaterialize =
    'test/architecture_graph/fixtures/unrouted_materialize_fixture.dart';
const _coveredBehaviorOptions = ActualGraphExtractionOptions(
  compositionTypes: {'ExportedFixture'},
  delegationMembers: {'FixtureOwner.exposed'},
  delegationTargetTypes: {'ExportedFixture'},
  placeholderCoverage: [
    PlaceholderCoverage(under: 'test/architecture_graph/fixtures/**'),
  ],
  sensitiveThrows: [
    SensitiveThrowCoverage(
      owner: 'fixture.owner',
      under: 'test/architecture_graph/fixtures/**',
      exception: 'FixtureException',
    ),
  ],
);

void main() {
  group('surface facts', () {
    _registerDirectiveAndDeclarationTest();
    _registerCompositionSurfaceTest();
  });
  group('coverage filters', () {
    _registerCoveredBehaviorTest();
    _registerHelperInputTest();
    _registerCompositionFilterTest();
    _registerExplicitHelperInputTest();
    _registerPlaceholderCoverageTest();
  });
  group('routes and throws', () {
    _registerDirectiveUriNormalizationTest();
    _registerSensitiveThrowOwnerTest();
    _registerTopLevelDelegationTest();
    _registerUnnamedDelegationFilterTest();
    _registerNamedMemberCallTest();
    _registerSensitiveThrowRouteTest();
    _registerMaterializationRouteTest();
    _registerVerifiedMaterializationRouteTest();
    _registerUnroutedMaterializationTest();
  });
}

void _registerDirectiveAndDeclarationTest() {
  test('extracts architecture-level declarations and directives', () {
    final graph = extractActualArchitectureGraphFromPaths(paths: [_fixture]);

    expect(
      graph.exports.map((fact) => fact.uri),
      contains('test/architecture_graph/fixtures/exported_fixture.dart'),
    );
    expect(
      graph.exports.map((fact) => fact.uri),
      contains(
        'test/architecture_graph/fixtures/conditional_exported_fixture.dart',
      ),
    );
    expect(
      graph.imports.map((fact) => fact.uri),
      contains('test/architecture_graph/fixtures/exported_fixture.dart'),
    );
    expect(
      graph.imports.map((fact) => fact.uri),
      contains(
        'test/architecture_graph/fixtures/conditional_imported_fixture.dart',
      ),
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
}

void _registerCompositionSurfaceTest() {
  test('extracts implemented interfaces and composition fields', () {
    final graph = extractActualArchitectureGraphFromPaths(
      paths: [_fixture],
      options: const ActualGraphExtractionOptions(
        compositionTypes: {'ExportedFixture'},
      ),
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
}

void _registerCoveredBehaviorTest() {
  test('extracts placeholders, exception throws, and simple delegations', () {
    final graph = extractActualArchitectureGraphFromPaths(
      paths: [_fixture],
      options: _coveredBehaviorOptions,
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
      graph.exceptionThrows.map((fact) => '${fact.member}:${fact.exception}'),
      contains('FixtureOwner.fail:FixtureException'),
    );
    expect(
      graph.delegations.map((fact) => '${fact.member}:${fact.targetType}'),
      contains('FixtureOwner.exposed:ExportedFixture'),
    );
  });
}

void _registerHelperInputTest() {
  test('ignores helper-level files outside declared extraction input', () {
    final graph = extractActualArchitectureGraphFromPaths(paths: [_fixture]);

    expect(
      graph.declarations.map((fact) => fact.name),
      isNot(contains('IgnoredHelperFixture')),
    );
  });
}

void _registerCompositionFilterTest() {
  test('does not treat non-architecture fields as composition facts', () {
    final graph = extractActualArchitectureGraphFromPaths(paths: [_fixture]);

    expect(graph.compositionFields, isEmpty);
  });
}

void _registerExplicitHelperInputTest() {
  test(
    'allows explicit helper input without inventing placeholder violations',
    () {
      final graph = extractActualArchitectureGraphFromPaths(paths: [_helper]);

      expect(graph.placeholders, isEmpty);
      expect(graph.exceptionThrows, isEmpty);
    },
  );
}

void _registerPlaceholderCoverageTest() {
  test(
    'does not extract placeholders outside declared placeholder coverage',
    () {
      final graph = extractActualArchitectureGraphFromPaths(paths: [_fixture]);

      expect(graph.placeholders, isEmpty);
    },
  );
}

void _registerDirectiveUriNormalizationTest() {
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
}

void _registerSensitiveThrowOwnerTest() {
  test('assigns sensitive throw owner from coverage for top-level throws', () {
    final graph = extractActualArchitectureGraphFromPaths(
      paths: [_fixture],
      options: const ActualGraphExtractionOptions(
        sensitiveThrows: [
          SensitiveThrowCoverage(
            owner: 'fixture.owner',
            under: 'test/architecture_graph/fixtures/**',
            exception: 'FixtureException',
          ),
        ],
      ),
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

void _registerTopLevelDelegationTest() {
  test('extracts simple delegations from top-level functions', () {
    final graph = extractActualArchitectureGraphFromPaths(
      paths: [_fixture],
      options: const ActualGraphExtractionOptions(
        delegationMembers: {'topLevelDelegates'},
        delegationTargetTypes: {'ExportedFixture'},
      ),
    );

    expect(
      graph.delegations.map((fact) => '${fact.member}:${fact.targetType}'),
      contains('topLevelDelegates:ExportedFixture'),
    );
  });
}

void _registerUnnamedDelegationFilterTest() {
  test('does not extract delegations that are not named graph facts', () {
    final graph = extractActualArchitectureGraphFromPaths(paths: [_fixture]);

    expect(graph.delegations, isEmpty);
  });
}

void _registerNamedMemberCallTest() {
  test('extracts only named member calls for graph routes', () {
    final graph = extractActualArchitectureGraphFromPaths(
      paths: [_fixture],
      options: const ActualGraphExtractionOptions(
        memberCallTargets: {'recordFixtureRoute'},
      ),
    );

    expect(
      graph.memberCalls.map((fact) => '${fact.member}:${fact.target}'),
      contains('topLevelCallsRoute:recordFixtureRoute'),
    );
    expect(
      graph.memberCalls.map((fact) => '${fact.member}:${fact.target}'),
      isNot(contains('topLevelDelegates:toString')),
    );
  });
}

void _registerSensitiveThrowRouteTest() {
  test('treats named sensitive throw routes as covered exception throws', () {
    final graph = extractActualArchitectureGraphFromPaths(
      paths: [_fixture],
      options: const ActualGraphExtractionOptions(
        memberCallTargets: {'recordFixtureRoute'},
        sensitiveThrows: [
          SensitiveThrowCoverage(
            owner: 'other.owner',
            under: 'test/architecture_graph/other/**',
            exception: 'OtherFixtureException',
          ),
          SensitiveThrowCoverage(
            owner: 'fixture.owner',
            under: 'test/architecture_graph/fixtures/**',
            exception: 'FixtureException',
          ),
        ],
      ),
    );

    expect(
      graph.exceptionThrows.map((fact) => '${fact.member}:${fact.exception}'),
      contains('topLevelThrowsThroughRoute:FixtureException'),
    );
    expect(
      graph.exceptionThrows.map((fact) => '${fact.owner}:${fact.exception}'),
      contains('fixture.owner:FixtureException'),
    );
  });
}

void _registerMaterializationRouteTest() {
  test('expands explicit materialization routes to the caller member', () {
    final graph = extractActualArchitectureGraphFromPaths(
      paths: [_fixture],
      options: const ActualGraphExtractionOptions(
        memberCallTargets: {'recordFixtureRoute'},
        sensitiveThrows: [
          SensitiveThrowCoverage(
            owner: 'fixture.owner',
            under: 'test/architecture_graph/fixtures/**',
            exception: 'FixtureException',
          ),
        ],
      ),
    );

    expect(
      graph.memberCalls.map((fact) => '${fact.member}:${fact.target}'),
      contains('topLevelMaterializesThroughRoute:recordFixtureRoute'),
    );
    expect(
      graph.exceptionThrows.map((fact) => '${fact.member}:${fact.exception}'),
      contains('topLevelMaterializesThroughRoute:FixtureException'),
    );
  });
}

void _registerVerifiedMaterializationRouteTest() {
  test('expands materialization routes only for verified route targets', () {
    final graph = extractActualArchitectureGraphFromPaths(
      paths: [_fixture],
      options: const ActualGraphExtractionOptions(
        memberCallTargets: {
          'recordFixtureRoute',
          'recordUnverifiedFixtureRoute',
        },
        sensitiveThrows: [
          SensitiveThrowCoverage(
            owner: 'fixture.owner',
            under: 'test/architecture_graph/fixtures/**',
            exception: 'FixtureException',
          ),
        ],
      ),
    );

    expect(
      graph.memberCalls.map((fact) => '${fact.member}:${fact.target}'),
      contains('topLevelMaterializesThroughRoute:recordFixtureRoute'),
    );
    expect(
      graph.memberCalls.map((fact) => '${fact.member}:${fact.target}'),
      isNot(
        contains(
          'topLevelMaterializesThroughRoute:recordUnverifiedFixtureRoute',
        ),
      ),
    );
    expect(
      graph.exceptionThrows
          .where(
            (fact) =>
                fact.member == 'topLevelMaterializesThroughRoute' &&
                fact.exception == 'FixtureException',
          )
          .length,
      1,
    );
  });
}

void _registerUnroutedMaterializationTest() {
  test(
    'does not expand materialization helpers without a routed throw body',
    () {
      final graph = extractActualArchitectureGraphFromPaths(
        paths: [_fixture, _unroutedMaterialize],
        options: const ActualGraphExtractionOptions(
          memberCallTargets: {'recordFixtureRoute'},
          sensitiveThrows: [
            SensitiveThrowCoverage(
              owner: 'fixture.owner',
              under: 'test/architecture_graph/fixtures/**',
              exception: 'FixtureException',
            ),
          ],
        ),
      );

      expect(
        graph.memberCalls.map((fact) => '${fact.member}:${fact.target}'),
        isNot(contains('topLevelUnroutedMaterializes:recordFixtureRoute')),
      );
      expect(
        graph.exceptionThrows.map((fact) => '${fact.member}:${fact.exception}'),
        isNot(contains('topLevelUnroutedMaterializes:FixtureException')),
      );
    },
  );
}
