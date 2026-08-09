import 'package:vector_graphics_codec/vector_graphics_codec.dart';

import '../../support/vector_preparation_fixture.dart';

void main() {
  final response = const VectorGraphicsCodec().decode(
    assertionOnlyMalformedVectorBytes(),
    null,
  );
  if (!response.complete) {
    throw StateError('Malformed assertion-only fixture did not complete.');
  }
}
