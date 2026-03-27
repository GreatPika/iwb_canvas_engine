import '../contract/internal/node_boundary_schema.dart';
import '../contract/node_spec.dart';
import '../contract/snapshot.dart';
import '../core/nodes.dart';

ImageNodeSchemaFields imageNodeSchemaFieldsFromSnapshot(
  ImageNodeSnapshot image,
) {
  return NodeBoundarySchema.imageFieldsFromValidated((
    imageId: image.imageId,
    size: image.size,
    naturalSize: image.naturalSize,
  ));
}

ImageNodeSchemaFields imageNodeSchemaFieldsFromSpec(ImageNodeSpec image) {
  return NodeBoundarySchema.imageFieldsFromValidated((
    imageId: image.imageId,
    size: image.size,
    naturalSize: image.naturalSize,
  ));
}

ImageNodeSchemaFields imageNodeSchemaFieldsFromNode(ImageNode image) {
  return NodeBoundarySchema.imageFieldsFromValidated((
    imageId: image.imageId,
    size: image.size,
    naturalSize: image.naturalSize,
  ));
}
