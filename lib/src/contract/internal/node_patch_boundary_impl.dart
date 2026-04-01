import '../node_patch.dart';
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

CommonNodePatchBacking commonNodePatchBackingOf(CommonNodePatch patch) {
  try {
    return (patch as CommonNodePatchBackingCarrier).commonNodePatchBacking;
  } on TypeError {
    // Fall through to the public-field reconstruction path.
  }
  final cached = _commonNodePatchBackingCache[patch];
  if (cached != null) {
    return cached;
  }
  if (patch.runtimeType != CommonNodePatch) {
    throw StateError(
      'Unsupported CommonNodePatch subtype: ${patch.runtimeType}',
    );
  }
  final backing = CommonNodePatchBacking(
    transform: patch.transform,
    opacity: patch.opacity,
    hitPadding: patch.hitPadding,
    isVisible: patch.isVisible,
    isSelectable: patch.isSelectable,
    isLocked: patch.isLocked,
    isDeletable: patch.isDeletable,
    isTransformable: patch.isTransformable,
  );
  _commonNodePatchBackingCache[patch] = backing;
  return backing;
}

NodePatchBacking nodePatchBackingOf(NodePatch patch) {
  try {
    return (patch as NodePatchBackingCarrier).nodePatchBacking;
  } on TypeError {
    // Fall through to the public-field reconstruction path.
  }
  final cached = _nodePatchBackingCache[patch];
  if (cached != null) {
    return cached;
  }
  final common = commonNodePatchBackingOf(patch.common);
  final backing = _publicNodePatchBackingOf(patch, common);
  _nodePatchBackingCache[patch] = backing;
  return backing;
}

NodePatchBacking _publicNodePatchBackingOf(
  NodePatch patch,
  CommonNodePatchBacking common,
) {
  if (patch.runtimeType == ImageNodePatch) {
    final image = patch as ImageNodePatch;
    return ImageNodePatchBacking(
      id: image.id,
      common: common,
      imageId: image.imageId,
      size: image.size,
      naturalSize: image.naturalSize,
    );
  }
  if (patch.runtimeType == TextNodePatch) {
    final text = patch as TextNodePatch;
    return TextNodePatchBacking(
      id: text.id,
      common: common,
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
    );
  }
  if (patch.runtimeType == StrokeNodePatch) {
    final stroke = patch as StrokeNodePatch;
    return StrokeNodePatchBacking(
      id: stroke.id,
      common: common,
      points: stroke.points,
      thickness: stroke.thickness,
      color: stroke.color,
    );
  }
  if (patch.runtimeType == LineNodePatch) {
    final line = patch as LineNodePatch;
    return LineNodePatchBacking(
      id: line.id,
      common: common,
      start: line.start,
      end: line.end,
      thickness: line.thickness,
      color: line.color,
    );
  }
  if (patch.runtimeType == RectNodePatch) {
    final rect = patch as RectNodePatch;
    return RectNodePatchBacking(
      id: rect.id,
      common: common,
      size: rect.size,
      fillColor: rect.fillColor,
      strokeColor: rect.strokeColor,
      strokeWidth: rect.strokeWidth,
    );
  }
  if (patch.runtimeType == PathNodePatch) {
    final path = patch as PathNodePatch;
    return PathNodePatchBacking(
      id: path.id,
      common: common,
      svgPathData: path.svgPathData,
      fillColor: path.fillColor,
      strokeColor: path.strokeColor,
      strokeWidth: path.strokeWidth,
      fillRule: path.fillRule,
    );
  }
  throw StateError('Unsupported NodePatch subtype: ${patch.runtimeType}');
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
