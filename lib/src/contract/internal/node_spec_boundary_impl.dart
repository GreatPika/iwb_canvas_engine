import '../node_spec.dart';
import 'node_spec_backing.dart';

abstract interface class NodeSpecBackingCarrier {
  NodeSpecBacking get nodeSpecBacking;
}

final Expando<NodeSpecBacking> _nodeSpecBackingCache = Expando<NodeSpecBacking>(
  'nodeSpecBacking',
);

NodeSpecBacking nodeSpecBackingOf(NodeSpec spec) {
  try {
    return (spec as NodeSpecBackingCarrier).nodeSpecBacking;
  } on TypeError {
    // Fall through to the public-field reconstruction path.
  }
  final cached = _nodeSpecBackingCache[spec];
  if (cached != null) {
    return cached;
  }
  final backing = _publicNodeSpecBackingOf(spec);
  _nodeSpecBackingCache[spec] = backing;
  return backing;
}

NodeSpecBacking _publicNodeSpecBackingOf(NodeSpec spec) {
  if (spec.runtimeType == ImageNodeSpec) {
    final image = spec as ImageNodeSpec;
    return ImageNodeSpecBacking(
      id: image.id,
      imageId: image.imageId,
      size: image.size,
      naturalSize: image.naturalSize,
      transform: image.transform,
      opacity: image.opacity,
      hitPadding: image.hitPadding,
      isVisible: image.isVisible,
      isSelectable: image.isSelectable,
      isLocked: image.isLocked,
      isDeletable: image.isDeletable,
      isTransformable: image.isTransformable,
    );
  }
  if (spec.runtimeType == TextNodeSpec) {
    final text = spec as TextNodeSpec;
    return TextNodeSpecBacking(
      id: text.id,
      text: text.text,
      fontSize: text.fontSize,
      color: text.color,
      align: text.align,
      textDirection: text.textDirection,
      isBold: text.isBold,
      isItalic: text.isItalic,
      isUnderline: text.isUnderline,
      fontFamily: text.fontFamily,
      maxWidth: text.maxWidth,
      lineHeight: text.lineHeight,
      transform: text.transform,
      opacity: text.opacity,
      hitPadding: text.hitPadding,
      isVisible: text.isVisible,
      isSelectable: text.isSelectable,
      isLocked: text.isLocked,
      isDeletable: text.isDeletable,
      isTransformable: text.isTransformable,
    );
  }
  if (spec.runtimeType == StrokeNodeSpec) {
    final stroke = spec as StrokeNodeSpec;
    return StrokeNodeSpecBacking(
      id: stroke.id,
      points: stroke.points,
      thickness: stroke.thickness,
      color: stroke.color,
      transform: stroke.transform,
      opacity: stroke.opacity,
      hitPadding: stroke.hitPadding,
      isVisible: stroke.isVisible,
      isSelectable: stroke.isSelectable,
      isLocked: stroke.isLocked,
      isDeletable: stroke.isDeletable,
      isTransformable: stroke.isTransformable,
    );
  }
  if (spec.runtimeType == LineNodeSpec) {
    final line = spec as LineNodeSpec;
    return LineNodeSpecBacking(
      id: line.id,
      start: line.start,
      end: line.end,
      thickness: line.thickness,
      color: line.color,
      transform: line.transform,
      opacity: line.opacity,
      hitPadding: line.hitPadding,
      isVisible: line.isVisible,
      isSelectable: line.isSelectable,
      isLocked: line.isLocked,
      isDeletable: line.isDeletable,
      isTransformable: line.isTransformable,
    );
  }
  if (spec.runtimeType == RectNodeSpec) {
    final rect = spec as RectNodeSpec;
    return RectNodeSpecBacking(
      id: rect.id,
      size: rect.size,
      fillColor: rect.fillColor,
      strokeColor: rect.strokeColor,
      strokeWidth: rect.strokeWidth,
      transform: rect.transform,
      opacity: rect.opacity,
      hitPadding: rect.hitPadding,
      isVisible: rect.isVisible,
      isSelectable: rect.isSelectable,
      isLocked: rect.isLocked,
      isDeletable: rect.isDeletable,
      isTransformable: rect.isTransformable,
    );
  }
  if (spec.runtimeType == PathNodeSpec) {
    final path = spec as PathNodeSpec;
    return PathNodeSpecBacking(
      id: path.id,
      svgPathData: path.svgPathData,
      fillColor: path.fillColor,
      strokeColor: path.strokeColor,
      strokeWidth: path.strokeWidth,
      fillRule: path.fillRule,
      transform: path.transform,
      opacity: path.opacity,
      hitPadding: path.hitPadding,
      isVisible: path.isVisible,
      isSelectable: path.isSelectable,
      isLocked: path.isLocked,
      isDeletable: path.isDeletable,
      isTransformable: path.isTransformable,
    );
  }
  throw StateError('Unsupported NodeSpec subtype: ${spec.runtimeType}');
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
