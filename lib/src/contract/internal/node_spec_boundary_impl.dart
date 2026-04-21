import '../node_spec.dart';
import 'boundary_impl_support.dart';
import 'node_spec_boundary_fallback.dart';
import 'node_spec_backing.dart';

abstract interface class NodeSpecBackingCarrier {
  NodeSpecBacking get nodeSpecBacking;
}

final Expando<NodeSpecBacking> _nodeSpecBackingCache = Expando<NodeSpecBacking>(
  'nodeSpecBacking',
);

final _nodeSpecBackingResolver =
    BoundaryBackingResolver<NodeSpec, NodeSpecBacking>(
      cache: _nodeSpecBackingCache,
      readCarrier: _nodeSpecBackingFromCarrier,
      rebuild: publicNodeSpecBackingOf,
    );

NodeSpecBacking nodeSpecBackingOf(NodeSpec spec) =>
    _nodeSpecBackingResolver.resolve(spec);

NodeSpecBacking? _nodeSpecBackingFromCarrier(NodeSpec spec) {
  return readBoundaryBackingCarrier(
    spec,
    (carrier) => (carrier as NodeSpecBackingCarrier).nodeSpecBacking,
  );
}

NodeSpec materializeNodeSpecForInternalUse(NodeSpecBacking backing) {
  return switch (backing) {
    ImageNodeSpecBacking image => _MaterializedImageNodeSpec(image),
    TextNodeSpecBacking text => _MaterializedTextNodeSpec(text),
    StrokeNodeSpecBacking stroke => _MaterializedStrokeNodeSpec(stroke),
    LineNodeSpecBacking line => _MaterializedLineNodeSpec(line),
    RectNodeSpecBacking rect => _MaterializedRectNodeSpec(rect),
    PathNodeSpecBacking path => _MaterializedPathNodeSpec(path),
  };
}

final class _MaterializedImageNodeSpec extends ImageNodeSpec
    implements NodeSpecBackingCarrier {
  _MaterializedImageNodeSpec(this.nodeSpecBacking)
    : super(
        id: nodeSpecBacking.id,
        imageId: nodeSpecBacking.imageId,
        size: nodeSpecBacking.size,
        naturalSize: nodeSpecBacking.naturalSize,
        transform: nodeSpecBacking.transform,
        opacity: nodeSpecBacking.opacity,
        hitPadding: nodeSpecBacking.hitPadding,
        isVisible: nodeSpecBacking.isVisible,
        isSelectable: nodeSpecBacking.isSelectable,
        isLocked: nodeSpecBacking.isLocked,
        isDeletable: nodeSpecBacking.isDeletable,
        isTransformable: nodeSpecBacking.isTransformable,
      );

  @override
  final ImageNodeSpecBacking nodeSpecBacking;
}

final class _MaterializedTextNodeSpec extends TextNodeSpec
    implements NodeSpecBackingCarrier {
  _MaterializedTextNodeSpec(this.nodeSpecBacking)
    : super(
        id: nodeSpecBacking.id,
        text: nodeSpecBacking.text,
        fontSize: nodeSpecBacking.fontSize,
        color: nodeSpecBacking.color,
        align: nodeSpecBacking.align,
        textDirection: nodeSpecBacking.textDirection,
        isBold: nodeSpecBacking.isBold,
        isItalic: nodeSpecBacking.isItalic,
        isUnderline: nodeSpecBacking.isUnderline,
        fontFamily: nodeSpecBacking.fontFamily,
        maxWidth: nodeSpecBacking.maxWidth,
        lineHeight: nodeSpecBacking.lineHeight,
        transform: nodeSpecBacking.transform,
        opacity: nodeSpecBacking.opacity,
        hitPadding: nodeSpecBacking.hitPadding,
        isVisible: nodeSpecBacking.isVisible,
        isSelectable: nodeSpecBacking.isSelectable,
        isLocked: nodeSpecBacking.isLocked,
        isDeletable: nodeSpecBacking.isDeletable,
        isTransformable: nodeSpecBacking.isTransformable,
      );

  @override
  final TextNodeSpecBacking nodeSpecBacking;
}

final class _MaterializedStrokeNodeSpec extends StrokeNodeSpec
    implements NodeSpecBackingCarrier {
  _MaterializedStrokeNodeSpec(this.nodeSpecBacking)
    : super(
        id: nodeSpecBacking.id,
        points: nodeSpecBacking.points,
        thickness: nodeSpecBacking.thickness,
        color: nodeSpecBacking.color,
        transform: nodeSpecBacking.transform,
        opacity: nodeSpecBacking.opacity,
        hitPadding: nodeSpecBacking.hitPadding,
        isVisible: nodeSpecBacking.isVisible,
        isSelectable: nodeSpecBacking.isSelectable,
        isLocked: nodeSpecBacking.isLocked,
        isDeletable: nodeSpecBacking.isDeletable,
        isTransformable: nodeSpecBacking.isTransformable,
      );

  @override
  final StrokeNodeSpecBacking nodeSpecBacking;
}

final class _MaterializedLineNodeSpec extends LineNodeSpec
    implements NodeSpecBackingCarrier {
  _MaterializedLineNodeSpec(this.nodeSpecBacking)
    : super(
        id: nodeSpecBacking.id,
        start: nodeSpecBacking.start,
        end: nodeSpecBacking.end,
        thickness: nodeSpecBacking.thickness,
        color: nodeSpecBacking.color,
        transform: nodeSpecBacking.transform,
        opacity: nodeSpecBacking.opacity,
        hitPadding: nodeSpecBacking.hitPadding,
        isVisible: nodeSpecBacking.isVisible,
        isSelectable: nodeSpecBacking.isSelectable,
        isLocked: nodeSpecBacking.isLocked,
        isDeletable: nodeSpecBacking.isDeletable,
        isTransformable: nodeSpecBacking.isTransformable,
      );

  @override
  final LineNodeSpecBacking nodeSpecBacking;
}

final class _MaterializedRectNodeSpec extends RectNodeSpec
    implements NodeSpecBackingCarrier {
  _MaterializedRectNodeSpec(this.nodeSpecBacking)
    : super(
        id: nodeSpecBacking.id,
        size: nodeSpecBacking.size,
        fillColor: nodeSpecBacking.fillColor,
        strokeColor: nodeSpecBacking.strokeColor,
        strokeWidth: nodeSpecBacking.strokeWidth,
        transform: nodeSpecBacking.transform,
        opacity: nodeSpecBacking.opacity,
        hitPadding: nodeSpecBacking.hitPadding,
        isVisible: nodeSpecBacking.isVisible,
        isSelectable: nodeSpecBacking.isSelectable,
        isLocked: nodeSpecBacking.isLocked,
        isDeletable: nodeSpecBacking.isDeletable,
        isTransformable: nodeSpecBacking.isTransformable,
      );

  @override
  final RectNodeSpecBacking nodeSpecBacking;
}

final class _MaterializedPathNodeSpec extends PathNodeSpec
    implements NodeSpecBackingCarrier {
  _MaterializedPathNodeSpec(this.nodeSpecBacking)
    : super(
        id: nodeSpecBacking.id,
        svgPathData: nodeSpecBacking.svgPathData,
        fillColor: nodeSpecBacking.fillColor,
        strokeColor: nodeSpecBacking.strokeColor,
        strokeWidth: nodeSpecBacking.strokeWidth,
        fillRule: nodeSpecBacking.fillRule,
        transform: nodeSpecBacking.transform,
        opacity: nodeSpecBacking.opacity,
        hitPadding: nodeSpecBacking.hitPadding,
        isVisible: nodeSpecBacking.isVisible,
        isSelectable: nodeSpecBacking.isSelectable,
        isLocked: nodeSpecBacking.isLocked,
        isDeletable: nodeSpecBacking.isDeletable,
        isTransformable: nodeSpecBacking.isTransformable,
      );

  @override
  final PathNodeSpecBacking nodeSpecBacking;
}
