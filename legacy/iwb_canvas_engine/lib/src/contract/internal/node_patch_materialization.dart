import '../ids.dart';
import '../node_patch.dart';
import 'node_boundary_schema.dart';
import 'node_patch_backing.dart';
import 'node_patch_boundary_impl.dart';

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

ImageNodePatch _materializeImageNodePatchFromValidated(
  ImageNodePatchBacking backing,
) {
  return materializeNodePatchForInternalUse(backing) as ImageNodePatch;
}

TextNodePatch _materializeTextNodePatchFromValidated(
  TextNodePatchBacking backing,
) {
  return materializeNodePatchForInternalUse(backing) as TextNodePatch;
}

StrokeNodePatch _materializeStrokeNodePatchFromValidated(
  StrokeNodePatchBacking backing,
) {
  return materializeNodePatchForInternalUse(backing) as StrokeNodePatch;
}

LineNodePatch _materializeLineNodePatchFromValidated(
  LineNodePatchBacking backing,
) {
  return materializeNodePatchForInternalUse(backing) as LineNodePatch;
}

RectNodePatch _materializeRectNodePatchFromValidated(
  RectNodePatchBacking backing,
) {
  return materializeNodePatchForInternalUse(backing) as RectNodePatch;
}

PathNodePatch _materializePathNodePatchFromValidated(
  PathNodePatchBacking backing,
) {
  return materializeNodePatchForInternalUse(backing) as PathNodePatch;
}

CommonNodePatch commonNodePatchFromValidated({
  NodePatchCommonSchemaFields? fields,
}) {
  return materializeCommonNodePatchForInternalUse(
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
    materialize: _materializeImageNodePatchFromValidated,
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
    materialize: _materializeTextNodePatchFromValidated,
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
    materialize: _materializeStrokeNodePatchFromValidated,
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
    materialize: _materializeLineNodePatchFromValidated,
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
    materialize: _materializeRectNodePatchFromValidated,
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
    materialize: _materializePathNodePatchFromValidated,
  );
}
