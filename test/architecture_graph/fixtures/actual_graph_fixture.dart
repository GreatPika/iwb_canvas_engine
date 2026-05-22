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
