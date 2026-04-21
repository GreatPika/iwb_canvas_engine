import '../node_patch.dart';
import 'boundary_impl_support.dart';
import 'node_patch_boundary_fallback.dart';
import 'node_patch_backing.dart';

abstract interface class CommonNodePatchBackingCarrier {
  CommonNodePatchBacking get commonNodePatchBacking;
}

abstract interface class NodePatchBackingCarrier {
  NodePatchBacking get nodePatchBacking;
}

final Expando<CommonNodePatchBacking> _commonNodePatchBackingCache =
    Expando<CommonNodePatchBacking>('commonNodePatchBacking');
final Expando<NodePatchBacking> _nodePatchBackingCache =
    Expando<NodePatchBacking>('nodePatchBacking');

final _commonNodePatchBackingResolver =
    BoundaryBackingResolver<CommonNodePatch, CommonNodePatchBacking>(
      cache: _commonNodePatchBackingCache,
      readCarrier: _commonNodePatchBackingFromCarrier,
      rebuild: _rebuildCommonNodePatchBacking,
    );

final _nodePatchBackingResolver =
    BoundaryBackingResolver<NodePatch, NodePatchBacking>(
      cache: _nodePatchBackingCache,
      readCarrier: _nodePatchBackingFromCarrier,
      rebuild: _rebuildNodePatchBacking,
    );

CommonNodePatchBacking commonNodePatchBackingOf(CommonNodePatch patch) =>
    _commonNodePatchBackingResolver.resolve(patch);

NodePatchBacking nodePatchBackingOf(NodePatch patch) =>
    _nodePatchBackingResolver.resolve(patch);

CommonNodePatchBacking? _commonNodePatchBackingFromCarrier(
  CommonNodePatch patch,
) {
  return readBoundaryBackingCarrier(
    patch,
    (carrier) =>
        (carrier as CommonNodePatchBackingCarrier).commonNodePatchBacking,
  );
}

NodePatchBacking? _nodePatchBackingFromCarrier(NodePatch patch) {
  return readBoundaryBackingCarrier(
    patch,
    (carrier) => (carrier as NodePatchBackingCarrier).nodePatchBacking,
  );
}

NodePatchBacking _rebuildNodePatchBacking(NodePatch patch) {
  return publicNodePatchBackingOf(
    patch,
    commonNodePatchBackingOf(patch.common),
  );
}

CommonNodePatchBacking _rebuildCommonNodePatchBacking(CommonNodePatch patch) {
  requireExactBoundaryRuntimeType(
    value: patch,
    exactType: CommonNodePatch,
    typeName: 'CommonNodePatch',
  );
  return CommonNodePatchBacking(
    transform: patch.transform,
    opacity: patch.opacity,
    hitPadding: patch.hitPadding,
    isVisible: patch.isVisible,
    isSelectable: patch.isSelectable,
    isLocked: patch.isLocked,
    isDeletable: patch.isDeletable,
    isTransformable: patch.isTransformable,
  );
}

CommonNodePatch materializeCommonNodePatchForInternalUse(
  CommonNodePatchBacking backing,
) {
  return _MaterializedCommonNodePatch(backing);
}

NodePatch materializeNodePatchForInternalUse(NodePatchBacking backing) {
  return switch (backing) {
    ImageNodePatchBacking image => _MaterializedImageNodePatch(image),
    TextNodePatchBacking text => _MaterializedTextNodePatch(text),
    StrokeNodePatchBacking stroke => _MaterializedStrokeNodePatch(stroke),
    LineNodePatchBacking line => _MaterializedLineNodePatch(line),
    RectNodePatchBacking rect => _MaterializedRectNodePatch(rect),
    PathNodePatchBacking path => _MaterializedPathNodePatch(path),
  };
}

final class _MaterializedCommonNodePatch extends CommonNodePatch
    implements CommonNodePatchBackingCarrier {
  _MaterializedCommonNodePatch(this.commonNodePatchBacking)
    : super(
        transform: commonNodePatchBacking.transform,
        opacity: commonNodePatchBacking.opacity,
        hitPadding: commonNodePatchBacking.hitPadding,
        isVisible: commonNodePatchBacking.isVisible,
        isSelectable: commonNodePatchBacking.isSelectable,
        isLocked: commonNodePatchBacking.isLocked,
        isDeletable: commonNodePatchBacking.isDeletable,
        isTransformable: commonNodePatchBacking.isTransformable,
      );

  @override
  final CommonNodePatchBacking commonNodePatchBacking;
}

final class _MaterializedImageNodePatch extends ImageNodePatch
    implements NodePatchBackingCarrier {
  _MaterializedImageNodePatch(this.nodePatchBacking)
    : super(
        id: nodePatchBacking.id,
        common: materializeCommonNodePatchForInternalUse(
          nodePatchBacking.common,
        ),
        imageId: nodePatchBacking.imageId,
        size: nodePatchBacking.size,
        naturalSize: nodePatchBacking.naturalSize,
      );

  @override
  final ImageNodePatchBacking nodePatchBacking;
}

final class _MaterializedTextNodePatch extends TextNodePatch
    implements NodePatchBackingCarrier {
  _MaterializedTextNodePatch(this.nodePatchBacking)
    : super(
        id: nodePatchBacking.id,
        common: materializeCommonNodePatchForInternalUse(
          nodePatchBacking.common,
        ),
        text: nodePatchBacking.text,
        fontSize: nodePatchBacking.fontSize,
        color: nodePatchBacking.color,
        align: nodePatchBacking.align,
        textDirection: nodePatchBacking.textDirection,
        isBold: nodePatchBacking.isBold,
        isItalic: nodePatchBacking.isItalic,
        isUnderline: nodePatchBacking.isUnderline,
        fontFamily: nodePatchBacking.fontFamily,
        maxWidth: nodePatchBacking.maxWidth,
        lineHeight: nodePatchBacking.lineHeight,
      );

  @override
  final TextNodePatchBacking nodePatchBacking;
}

final class _MaterializedStrokeNodePatch extends StrokeNodePatch
    implements NodePatchBackingCarrier {
  _MaterializedStrokeNodePatch(this.nodePatchBacking)
    : super(
        id: nodePatchBacking.id,
        common: materializeCommonNodePatchForInternalUse(
          nodePatchBacking.common,
        ),
        points: nodePatchBacking.points,
        thickness: nodePatchBacking.thickness,
        color: nodePatchBacking.color,
      );

  @override
  final StrokeNodePatchBacking nodePatchBacking;
}

final class _MaterializedLineNodePatch extends LineNodePatch
    implements NodePatchBackingCarrier {
  _MaterializedLineNodePatch(this.nodePatchBacking)
    : super(
        id: nodePatchBacking.id,
        common: materializeCommonNodePatchForInternalUse(
          nodePatchBacking.common,
        ),
        start: nodePatchBacking.start,
        end: nodePatchBacking.end,
        thickness: nodePatchBacking.thickness,
        color: nodePatchBacking.color,
      );

  @override
  final LineNodePatchBacking nodePatchBacking;
}

final class _MaterializedRectNodePatch extends RectNodePatch
    implements NodePatchBackingCarrier {
  _MaterializedRectNodePatch(this.nodePatchBacking)
    : super(
        id: nodePatchBacking.id,
        common: materializeCommonNodePatchForInternalUse(
          nodePatchBacking.common,
        ),
        size: nodePatchBacking.size,
        fillColor: nodePatchBacking.fillColor,
        strokeColor: nodePatchBacking.strokeColor,
        strokeWidth: nodePatchBacking.strokeWidth,
      );

  @override
  final RectNodePatchBacking nodePatchBacking;
}

final class _MaterializedPathNodePatch extends PathNodePatch
    implements NodePatchBackingCarrier {
  _MaterializedPathNodePatch(this.nodePatchBacking)
    : super(
        id: nodePatchBacking.id,
        common: materializeCommonNodePatchForInternalUse(
          nodePatchBacking.common,
        ),
        svgPathData: nodePatchBacking.svgPathData,
        fillColor: nodePatchBacking.fillColor,
        strokeColor: nodePatchBacking.strokeColor,
        strokeWidth: nodePatchBacking.strokeWidth,
        fillRule: nodePatchBacking.fillRule,
      );

  @override
  final PathNodePatchBacking nodePatchBacking;
}
