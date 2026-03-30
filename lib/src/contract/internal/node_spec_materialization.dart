import '../node_spec.dart';
import 'node_boundary_schema.dart';
import 'node_spec_backing.dart';

typedef _NodeSpecBackingBuilder<TBacking extends NodeSpecBacking, TFields> =
    TBacking Function({
      required NodeSpecCommonSchemaFields? common,
      required TFields fields,
    });

typedef _NodeSpecMaterializer<
  TSpec extends NodeSpec,
  TBacking extends NodeSpecBacking
> = TSpec Function(TBacking backing);

NodeSpec materializeNodeSpec(NodeSpecBacking backing) {
  return switch (backing) {
    ImageNodeSpecBacking image => materializeImageNodeSpec(image),
    TextNodeSpecBacking text => materializeTextNodeSpec(text),
    StrokeNodeSpecBacking stroke => materializeStrokeNodeSpec(stroke),
    LineNodeSpecBacking line => materializeLineNodeSpec(line),
    RectNodeSpecBacking rect => materializeRectNodeSpec(rect),
    PathNodeSpecBacking path => materializePathNodeSpec(path),
  };
}

ImageNodeSpec materializeImageNodeSpec(ImageNodeSpecBacking backing) {
  return ImageNodeSpec.materialize(backing);
}

TextNodeSpec materializeTextNodeSpec(TextNodeSpecBacking backing) {
  return TextNodeSpec.materialize(backing);
}

StrokeNodeSpec materializeStrokeNodeSpec(StrokeNodeSpecBacking backing) {
  return StrokeNodeSpec.materialize(backing);
}

LineNodeSpec materializeLineNodeSpec(LineNodeSpecBacking backing) {
  return LineNodeSpec.materialize(backing);
}

RectNodeSpec materializeRectNodeSpec(RectNodeSpecBacking backing) {
  return RectNodeSpec.materialize(backing);
}

PathNodeSpec materializePathNodeSpec(PathNodeSpecBacking backing) {
  return PathNodeSpec.materialize(backing);
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
    materialize: materializeImageNodeSpec,
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
    materialize: materializeTextNodeSpec,
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
    materialize: materializeStrokeNodeSpec,
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
    materialize: materializeLineNodeSpec,
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
    materialize: materializeRectNodeSpec,
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
    materialize: materializePathNodeSpec,
  );
}
