import 'package:test/test.dart';

import '../support/public_api_surface.dart';

void main() {
  test('public signatures reference exported or approved SDK types', () async {
    final surface = await resolvePublicApiSurface();

    expect(collectUndefinedPublicTypeReferences(surface), isEmpty);
  });

  test('public declarations cannot inherit private surface types', () async {
    final surface = await resolvePublicApiSurface(
      libraryPath:
          '$repoRoot/test/api_contract/fixtures/private_supertypes.dart',
    );

    expect(
      collectUndefinedPublicTypeReferences(surface),
      containsAll({'_HiddenBase', '_HiddenInterface', '_HiddenMixin'}),
    );
  });
}
