import '../contract/internal/node_boundary_schema.dart';
import '../contract/node_spec.dart';
import '../contract/snapshot.dart';
import '../core/nodes.dart';

RectNodeSchemaFields rectNodeSchemaFieldsFromSnapshot(RectNodeSnapshot rect) {
  return NodeBoundarySchema.rectFieldsFromValidated((
    size: rect.size,
    fillColor: rect.fillColor,
    strokeColor: rect.strokeColor,
    strokeWidth: rect.strokeWidth,
  ));
}

RectNodeSchemaFields rectNodeSchemaFieldsFromSpec(RectNodeSpec rect) {
  return NodeBoundarySchema.rectFieldsFromValidated((
    size: rect.size,
    fillColor: rect.fillColor,
    strokeColor: rect.strokeColor,
    strokeWidth: rect.strokeWidth,
  ));
}

RectNodeSchemaFields rectNodeSchemaFieldsFromNode(RectNode rect) {
  return NodeBoundarySchema.rectFieldsFromValidated((
    size: rect.size,
    fillColor: rect.fillColor,
    strokeColor: rect.strokeColor,
    strokeWidth: rect.strokeWidth,
  ));
}
