import '../contract/internal/node_boundary_schema.dart';
import '../contract/node_spec.dart';
import '../contract/snapshot.dart';
import '../core/nodes.dart';

LineNodeSchemaFields lineNodeSchemaFieldsFromSnapshot(LineNodeSnapshot line) {
  return NodeBoundarySchema.lineFieldsFromValidated((
    start: line.start,
    end: line.end,
    thickness: line.thickness,
    color: line.color,
  ));
}

LineNodeSchemaFields lineNodeSchemaFieldsFromSpec(LineNodeSpec line) {
  return NodeBoundarySchema.lineFieldsFromValidated((
    start: line.start,
    end: line.end,
    thickness: line.thickness,
    color: line.color,
  ));
}

LineNodeSchemaFields lineNodeSchemaFieldsFromNode(LineNode line) {
  return NodeBoundarySchema.lineFieldsFromValidated((
    start: line.start,
    end: line.end,
    thickness: line.thickness,
    color: line.color,
  ));
}
