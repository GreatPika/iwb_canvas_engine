import 'package:test/test.dart';

import '../support/public_api_surface.dart';

void main() {
  test('root public surface does not export retired legacy symbols', () async {
    final surface = await resolvePublicApiSurface();

    expect(surface.exportedNames.intersection(_legacySymbols), isEmpty);
  });
}

const _legacySymbols = {
  'SceneController',
  'SceneSnapshot',
  'NodeSpec',
  'NodePatch',
  'PatchField',
  'SceneWriteTxn',
  'SceneBuilder',
  'SceneCodec',
};
