import '../node_spec.dart';
import 'node_boundary_schema.dart';
import 'node_spec_backing.dart';
import 'node_spec_boundary_impl.dart';

typedef _NodeSpecBackingBuilder<TBacking extends NodeSpecBacking, TFields> =
    TBacking Function({
      required NodeSpecCommonSchemaFields? common,
      required TFields fields,
    });

typedef _NodeSpecMaterializer<
  TSpec extends NodeSpec,
  TBacking extends NodeSpecBacking
> = TSpec Function(TBacking backing);

ImageNodeSpec _materializeImageNodeSpecFromValidated(
  ImageNodeSpecBacking backing,
) {
  return materializeNodeSpecForInternalUse(backing) as ImageNodeSpec;
}

TextNodeSpec _materializeTextNodeSpecFromValidated(
  TextNodeSpecBacking backing,
) {
  return materializeNodeSpecForInternalUse(backing) as TextNodeSpec;
}

StrokeNodeSpec _materializeStrokeNodeSpecFromValidated(
  StrokeNodeSpecBacking backing,
) {
  return materializeNodeSpecForInternalUse(backing) as StrokeNodeSpec;
}

LineNodeSpec _materializeLineNodeSpecFromValidated(
  LineNodeSpecBacking backing,
) {
  return materializeNodeSpecForInternalUse(backing) as LineNodeSpec;
}

RectNodeSpec _materializeRectNodeSpecFromValidated(
  RectNodeSpecBacking backing,
) {
  return materializeNodeSpecForInternalUse(backing) as RectNodeSpec;
}

PathNodeSpec _materializePathNodeSpecFromValidated(
  PathNodeSpecBacking backing,
) {
  return materializeNodeSpecForInternalUse(backing) as PathNodeSpec;
}

TSpec _nodeSpecFromValidated<
  TSpec extends NodeSpec,
  TBacking extends NodeSpecBacking,
  TFields
>({
  NodeSpecCommonSchemaFields? common,
  required TFields fields,
  required _NodeSpecBackingBuilder<TBacking, TFields> buildBacking,
  required _NodeSpecMaterializer<TSpec, TBacking> materialize,
}) {
  return materialize(buildBacking(common: common, fields: fields));
}

ImageNodeSpec imageNodeSpecFromValidated({
  NodeSpecCommonSchemaFields? common,
  required ImageNodeSchemaFields fields,
}) {
  return _nodeSpecFromValidated(
    common: common,
    fields: fields,
    buildBacking: imageNodeSpecBackingFromValidated,
    materialize: _materializeImageNodeSpecFromValidated,
  );
}

TextNodeSpec textNodeSpecFromValidated({
  NodeSpecCommonSchemaFields? common,
  required TextNodeSpecSchemaFields fields,
}) {
  return _nodeSpecFromValidated(
    common: common,
    fields: fields,
    buildBacking: textNodeSpecBackingFromValidated,
    materialize: _materializeTextNodeSpecFromValidated,
  );
}

StrokeNodeSpec strokeNodeSpecFromValidated({
  NodeSpecCommonSchemaFields? common,
  required StrokeNodeSpecSchemaInput fields,
}) {
  return _nodeSpecFromValidated(
    common: common,
    fields: fields,
    buildBacking: strokeNodeSpecBackingFromValidated,
    materialize: _materializeStrokeNodeSpecFromValidated,
  );
}

LineNodeSpec lineNodeSpecFromValidated({
  NodeSpecCommonSchemaFields? common,
  required LineNodeSchemaFields fields,
}) {
  return _nodeSpecFromValidated(
    common: common,
    fields: fields,
    buildBacking: lineNodeSpecBackingFromValidated,
    materialize: _materializeLineNodeSpecFromValidated,
  );
}

RectNodeSpec rectNodeSpecFromValidated({
  NodeSpecCommonSchemaFields? common,
  required RectNodeSchemaFields fields,
}) {
  return _nodeSpecFromValidated(
    common: common,
    fields: fields,
    buildBacking: rectNodeSpecBackingFromValidated,
    materialize: _materializeRectNodeSpecFromValidated,
  );
}

PathNodeSpec pathNodeSpecFromValidated({
  NodeSpecCommonSchemaFields? common,
  required PathNodeSchemaFields fields,
}) {
  return _nodeSpecFromValidated(
    common: common,
    fields: fields,
    buildBacking: pathNodeSpecBackingFromValidated,
    materialize: _materializePathNodeSpecFromValidated,
  );
}
