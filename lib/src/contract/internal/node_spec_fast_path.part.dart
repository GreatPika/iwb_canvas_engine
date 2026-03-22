part of '../node_spec.dart';

@internal
ImageNodeSpec imageNodeSpecFromValidated({
  NodeSpecCommonSchemaFields? common,
  required ImageNodeSchemaFields fields,
}) {
  final resolvedCommon = NodeBoundarySchema.specCommonFromValidated(
    common ?? _defaultNodeSpecCommonSchemaFields(),
  );
  return _imageNodeSpecFromSchema(
    common: resolvedCommon,
    fields: NodeBoundarySchema.imageFieldsFromValidated(fields),
  );
}

@internal
TextNodeSpec textNodeSpecFromValidated({
  NodeSpecCommonSchemaFields? common,
  required TextNodeSpecSchemaFields fields,
}) {
  final resolvedCommon = NodeBoundarySchema.specCommonFromValidated(
    common ?? _defaultNodeSpecCommonSchemaFields(),
  );
  return _textNodeSpecFromSchema(
    common: resolvedCommon,
    fields: NodeBoundarySchema.textSpecFieldsFromValidated(fields),
  );
}

@internal
StrokeNodeSpec strokeNodeSpecFromValidated({
  NodeSpecCommonSchemaFields? common,
  required StrokeNodeSpecSchemaInput fields,
}) {
  final resolvedCommon = NodeBoundarySchema.specCommonFromValidated(
    common ?? _defaultNodeSpecCommonSchemaFields(),
  );
  return _strokeNodeSpecFromSchema(
    common: resolvedCommon,
    fields: NodeBoundarySchema.strokeSpecFieldsFromValidated(fields),
  );
}

@internal
LineNodeSpec lineNodeSpecFromValidated({
  NodeSpecCommonSchemaFields? common,
  required LineNodeSchemaFields fields,
}) {
  final resolvedCommon = NodeBoundarySchema.specCommonFromValidated(
    common ?? _defaultNodeSpecCommonSchemaFields(),
  );
  return _lineNodeSpecFromSchema(
    common: resolvedCommon,
    fields: NodeBoundarySchema.lineFieldsFromValidated(fields),
  );
}

@internal
RectNodeSpec rectNodeSpecFromValidated({
  NodeSpecCommonSchemaFields? common,
  required RectNodeSchemaFields fields,
}) {
  final resolvedCommon = NodeBoundarySchema.specCommonFromValidated(
    common ?? _defaultNodeSpecCommonSchemaFields(),
  );
  return _rectNodeSpecFromSchema(
    common: resolvedCommon,
    fields: NodeBoundarySchema.rectFieldsFromValidated(fields),
  );
}

@internal
PathNodeSpec pathNodeSpecFromValidated({
  NodeSpecCommonSchemaFields? common,
  required PathNodeSchemaFields fields,
}) {
  final resolvedCommon = NodeBoundarySchema.specCommonFromValidated(
    common ?? _defaultNodeSpecCommonSchemaFields(),
  );
  return _pathNodeSpecFromSchema(
    common: resolvedCommon,
    fields: NodeBoundarySchema.pathFieldsFromValidated(fields),
  );
}

NodeSpecCommonSchemaFields _defaultNodeSpecCommonSchemaFields() => (
  id: null,
  transform: Transform2D.identity,
  opacity: 1,
  hitPadding: 0,
  isVisible: true,
  isSelectable: true,
  isLocked: false,
  isDeletable: true,
  isTransformable: true,
);
