import '../contract/internal/node_boundary_schema.dart';
import '../contract/node_spec.dart';
import '../contract/snapshot.dart';
import '../core/nodes.dart';

StrokeNodeSnapshotSchemaFields strokeNodeSchemaFieldsFromSnapshot(
  StrokeNodeSnapshot stroke,
) {
  return NodeBoundarySchema.strokeSnapshotFieldsFromValidated((
    points: stroke.points,
    pointsRevision: stroke.pointsRevision,
    thickness: stroke.thickness,
    color: stroke.color,
  ));
}

StrokeNodeSpecSchemaFields strokeNodeSchemaFieldsFromSpec(
  StrokeNodeSpec stroke,
) {
  return NodeBoundarySchema.strokeSpecFieldsFromValidated((
    points: stroke.points,
    thickness: stroke.thickness,
    color: stroke.color,
  ));
}

StrokeNodeSnapshotSchemaFields strokeNodeSchemaFieldsFromNode(
  StrokeNode stroke,
) {
  return NodeBoundarySchema.strokeSnapshotFieldsFromValidated((
    points: stroke.points,
    pointsRevision: stroke.pointsRevision,
    thickness: stroke.thickness,
    color: stroke.color,
  ));
}
