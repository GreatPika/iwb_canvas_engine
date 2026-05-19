import 'package:test/test.dart';

import '../support/public_api_surface.dart';

void main() {
  test('public signatures reference exported or approved SDK types', () async {
    final surface = await resolvePublicApiSurface();

    expect(collectUndefinedPublicTypeReferences(surface), isEmpty);
  });
}
