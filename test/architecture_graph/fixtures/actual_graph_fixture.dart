export 'exported_fixture.dart';

import 'exported_fixture.dart';

abstract interface class FixturePort {}

final class FixtureOwner implements FixturePort {
  final ExportedFixture dependency;

  FixtureOwner(this.dependency);

  ExportedFixture get exposed => dependency;
  FixturePort get missing => throw UnimplementedError();

  void fail() {
    throw FixtureException();
  }
}

final class FixtureException implements Exception {}

final class OtherFixtureException implements Exception {}

void topLevelFail() {
  throw FixtureException();
}

void topLevelOtherFail() {
  throw OtherFixtureException();
}

String topLevelDelegates(ExportedFixture dependency) => dependency.toString();

String topLevelCallsRoute(ExportedFixture dependency) {
  recordFixtureRoute();

  return dependency.toString();
}

Never topLevelThrowsThroughRoute() {
  throw recordFixtureRoute();
}

String topLevelMaterializesThroughRoute() => _materialize(() => 'ok');

T _materialize<T>(T Function() create) {
  try {
    return create();
  } on FixtureException catch (_, stackTrace) {
    Error.throwWithStackTrace(recordFixtureRoute(), stackTrace);
  }
}

FixtureException recordFixtureRoute() => FixtureException();

FixtureException recordUnverifiedFixtureRoute() => FixtureException();
