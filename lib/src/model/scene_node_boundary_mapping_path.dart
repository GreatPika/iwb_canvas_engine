import '../contract/internal/node_boundary_schema.dart';
import '../contract/node_spec.dart';
import '../contract/snapshot.dart';
import '../core/nodes.dart';

PathNodeSchemaFields pathNodeSchemaFieldsFromSnapshot(PathNodeSnapshot path) {
  return NodeBoundarySchema.pathFieldsFromValidated((
    svgPathData: path.svgPathData,
    fillColor: path.fillColor,
    strokeColor: path.strokeColor,
    strokeWidth: path.strokeWidth,
    fillRule: path.fillRule,
  ));
}

PathNodeSchemaFields pathNodeSchemaFieldsFromSpec(PathNodeSpec path) {
  return NodeBoundarySchema.pathFieldsFromValidated((
    svgPathData: path.svgPathData,
    fillColor: path.fillColor,
    strokeColor: path.strokeColor,
    strokeWidth: path.strokeWidth,
    fillRule: path.fillRule,
  ));
}

PathNodeSchemaFields pathNodeSchemaFieldsFromNode(PathNode path) {
  return NodeBoundarySchema.pathFieldsFromValidated((
    svgPathData: path.svgPathData,
    fillColor: path.fillColor,
    strokeColor: path.strokeColor,
    strokeWidth: path.strokeWidth,
    fillRule: path.fillRule,
  ));
}
