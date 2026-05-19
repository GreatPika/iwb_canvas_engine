import 'package:test/test.dart';

import '../support/public_api_registry.dart';
import '../support/public_api_surface.dart';

void main() {
  test(
    'root public barrel exports every registry name and no extras',
    () async {
      final registryNames = readPublicApiRegistry();
      final surface = await resolvePublicApiSurface();

      expect(surface.exportedNames.difference(registryNames), isEmpty);
      expect(registryNames.difference(surface.exportedNames), isEmpty);
    },
  );
}
