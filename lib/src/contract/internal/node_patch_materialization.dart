import '../node_patch.dart';
import '../ids.dart';
import 'node_boundary_schema.dart';
import 'node_patch_backing.dart';

typedef _NodePatchBackingBuilder<TBacking extends NodePatchBacking, TFields> =
    TBacking Function({
      required NodeId id,
      required CommonNodePatchBacking? common,
      required TFields? fields,
    });

typedef _NodePatchMaterializer<
  TPatch extends NodePatch,
  TBacking extends NodePatchBacking
> = TPatch Function(TBacking backing);

CommonNodePatch materializeCommonNodePatch(CommonNodePatchBacking backing) {
  return CommonNodePatch.materialize(backing);
}

NodePatch materializeNodePatch(NodePatchBacking backing) {
  return switch (backing) {
    ImageNodePatchBacking image => materializeImageNodePatch(image),
    TextNodePatchBacking text => materializeTextNodePatch(text),
    StrokeNodePatchBacking stroke => materializeStrokeNodePatch(stroke),
    LineNodePatchBacking line => materializeLineNodePatch(line),
    RectNodePatchBacking rect => materializeRectNodePatch(rect),
    PathNodePatchBacking path => materializePathNodePatch(path),
  };
}

ImageNodePatch materializeImageNodePatch(ImageNodePatchBacking backing) {
  return ImageNodePatch.materialize(backing);
}

TextNodePatch materializeTextNodePatch(TextNodePatchBacking backing) {
  return TextNodePatch.materialize(backing);
}

StrokeNodePatch materializeStrokeNodePatch(StrokeNodePatchBacking backing) {
  return StrokeNodePatch.materialize(backing);
}

LineNodePatch materializeLineNodePatch(LineNodePatchBacking backing) {
  return LineNodePatch.materialize(backing);
}

RectNodePatch materializeRectNodePatch(RectNodePatchBacking backing) {
  return RectNodePatch.materialize(backing);
}

PathNodePatch materializePathNodePatch(PathNodePatchBacking backing) {
  return PathNodePatch.materialize(backing);
}

CommonNodePatch commonNodePatchFromValidated({
  NodePatchCommonSchemaFields? fields,
}) {
  return materializeCommonNodePatch(
    commonNodePatchBackingFromValidated(fields: fields),
  );
}

TPatch _nodePatchFromValidated<
  TPatch extends NodePatch,
  TBacking extends NodePatchBacking,
  TFields
>({
  required NodeId id,
  CommonNodePatchBacking? common,
  TFields? fields,
  required _NodePatchBackingBuilder<TBacking, TFields> buildBacking,
  required _NodePatchMaterializer<TPatch, TBacking> materialize,
}) {
  return materialize(buildBacking(id: id, common: common, fields: fields));
}

ImageNodePatch imageNodePatchFromValidated({
  required NodeId id,
  CommonNodePatch? common,
  ImageNodePatchSchemaFields? fields,
}) {
  return _nodePatchFromValidated(
    id: id,
    common: common?.internalBacking,
    fields: fields,
    buildBacking: imageNodePatchBackingFromValidated,
    materialize: materializeImageNodePatch,
  );
}

TextNodePatch textNodePatchFromValidated({
  required NodeId id,
  CommonNodePatch? common,
  TextNodePatchSchemaFields? fields,
}) {
  return _nodePatchFromValidated(
    id: id,
    common: common?.internalBacking,
    fields: fields,
    buildBacking: textNodePatchBackingFromValidated,
    materialize: materializeTextNodePatch,
  );
}

StrokeNodePatch strokeNodePatchFromValidated({
  required NodeId id,
  CommonNodePatch? common,
  StrokeNodePatchSchemaFields? fields,
}) {
  return _nodePatchFromValidated(
    id: id,
    common: common?.internalBacking,
    fields: fields,
    buildBacking: strokeNodePatchBackingFromValidated,
    materialize: materializeStrokeNodePatch,
  );
}

LineNodePatch lineNodePatchFromValidated({
  required NodeId id,
  CommonNodePatch? common,
  LineNodePatchSchemaFields? fields,
}) {
  return _nodePatchFromValidated(
    id: id,
    common: common?.internalBacking,
    fields: fields,
    buildBacking: lineNodePatchBackingFromValidated,
    materialize: materializeLineNodePatch,
  );
}

RectNodePatch rectNodePatchFromValidated({
  required NodeId id,
  CommonNodePatch? common,
  RectNodePatchSchemaFields? fields,
}) {
  return _nodePatchFromValidated(
    id: id,
    common: common?.internalBacking,
    fields: fields,
    buildBacking: rectNodePatchBackingFromValidated,
    materialize: materializeRectNodePatch,
  );
}

PathNodePatch pathNodePatchFromValidated({
  required NodeId id,
  CommonNodePatch? common,
  PathNodePatchSchemaFields? fields,
}) {
  return _nodePatchFromValidated(
    id: id,
    common: common?.internalBacking,
    fields: fields,
    buildBacking: pathNodePatchBackingFromValidated,
    materialize: materializePathNodePatch,
  );
}
