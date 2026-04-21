import '../node_patch.dart';
import '../ids.dart';
import 'node_boundary_schema.dart';
import 'node_patch_boundary_impl.dart';
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
  return materializeCommonNodePatchForInternalUse(backing);
}

NodePatch materializeNodePatch(NodePatchBacking backing) {
  return materializeNodePatchForInternalUse(backing);
}

ImageNodePatch materializeImageNodePatch(ImageNodePatchBacking backing) {
  return materializeNodePatchForInternalUse(backing) as ImageNodePatch;
}

TextNodePatch materializeTextNodePatch(TextNodePatchBacking backing) {
  return materializeNodePatchForInternalUse(backing) as TextNodePatch;
}

StrokeNodePatch materializeStrokeNodePatch(StrokeNodePatchBacking backing) {
  return materializeNodePatchForInternalUse(backing) as StrokeNodePatch;
}

LineNodePatch materializeLineNodePatch(LineNodePatchBacking backing) {
  return materializeNodePatchForInternalUse(backing) as LineNodePatch;
}

RectNodePatch materializeRectNodePatch(RectNodePatchBacking backing) {
  return materializeNodePatchForInternalUse(backing) as RectNodePatch;
}

PathNodePatch materializePathNodePatch(PathNodePatchBacking backing) {
  return materializeNodePatchForInternalUse(backing) as PathNodePatch;
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
    common: common == null ? null : commonNodePatchBackingOf(common),
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
    common: common == null ? null : commonNodePatchBackingOf(common),
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
    common: common == null ? null : commonNodePatchBackingOf(common),
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
    common: common == null ? null : commonNodePatchBackingOf(common),
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
    common: common == null ? null : commonNodePatchBackingOf(common),
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
    common: common == null ? null : commonNodePatchBackingOf(common),
    fields: fields,
    buildBacking: pathNodePatchBackingFromValidated,
    materialize: materializePathNodePatch,
  );
}
