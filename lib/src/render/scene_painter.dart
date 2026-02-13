import 'dart:collection';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

import '../core/grid_safety_limits.dart';
import '../core/numeric_clamp.dart';
import '../core/text_layout.dart';
import '../core/transform2d.dart';
import '../public/scene_render_state.dart';
import '../public/snapshot.dart';
import 'render_geometry_cache.dart';

typedef ImageResolverV2 = Image? Function(String imageId);
typedef NodePreviewOffsetResolverV2 = Offset Function(NodeId nodeId);

int _requirePositiveCacheEntries(int maxEntries) {
  if (maxEntries <= 0) {
    throw ArgumentError.value(maxEntries, 'maxEntries', 'Must be > 0.');
  }
  return maxEntries;
}

class SceneStrokePathCacheV2 {
  SceneStrokePathCacheV2({int maxEntries = 512})
    : maxEntries = _requirePositiveCacheEntries(maxEntries);

  final int maxEntries;
  final LinkedHashMap<NodeId, _StrokePathEntryV2> _entries =
      LinkedHashMap<NodeId, _StrokePathEntryV2>();

  int _debugBuildCount = 0;
  int _debugHitCount = 0;
  int _debugEvictCount = 0;

  @visibleForTesting
  int get debugBuildCount => _debugBuildCount;
  @visibleForTesting
  int get debugHitCount => _debugHitCount;
  @visibleForTesting
  int get debugEvictCount => _debugEvictCount;
  @visibleForTesting
  int get debugSize => _entries.length;

  void clear() => _entries.clear();

  Path getOrBuild(StrokeNodeSnapshot node) {
    if (node.points.isEmpty) {
      return Path();
    }
    if (node.points.length == 1) {
      return Path()
        ..addOval(Rect.fromCircle(center: node.points.first, radius: 0));
    }

    final cached = _entries.remove(node.id);
    if (cached != null && cached.pointsRevision == node.pointsRevision) {
      _entries[node.id] = cached;
      _debugHitCount += 1;
      return cached.path;
    }

    final path = _buildStrokePath(node.points);
    _entries[node.id] = _StrokePathEntryV2(
      path: path,
      pointsRevision: node.pointsRevision,
    );
    _debugBuildCount += 1;
    _evictIfNeeded();
    return path;
  }

  void _evictIfNeeded() {
    while (_entries.length > maxEntries) {
      _entries.remove(_entries.keys.first);
      _debugEvictCount += 1;
    }
  }
}

class _StrokePathEntryV2 {
  const _StrokePathEntryV2({required this.path, required this.pointsRevision});

  final Path path;
  final int pointsRevision;
}

class SceneTextLayoutCacheV2 {
  SceneTextLayoutCacheV2({int maxEntries = 256})
    : maxEntries = _requirePositiveCacheEntries(maxEntries);

  final int maxEntries;
  final LinkedHashMap<_TextLayoutKeyV2, TextPainter> _entries =
      LinkedHashMap<_TextLayoutKeyV2, TextPainter>();

  int _debugBuildCount = 0;
  int _debugHitCount = 0;
  int _debugEvictCount = 0;

  @visibleForTesting
  int get debugBuildCount => _debugBuildCount;
  @visibleForTesting
  int get debugHitCount => _debugHitCount;
  @visibleForTesting
  int get debugEvictCount => _debugEvictCount;
  @visibleForTesting
  int get debugSize => _entries.length;

  void clear() => _entries.clear();

  TextPainter getOrBuild({
    required TextNodeSnapshot node,
    required TextStyle textStyle,
    required double? maxWidth,
    TextDirection textDirection = TextDirection.ltr,
  }) {
    final safeFontSize = normalizeTextLayoutFontSize(node.fontSize);
    final safeLineHeight = normalizeTextLayoutLineHeight(node.lineHeight);
    final key = _TextLayoutKeyV2(
      text: node.text,
      fontSize: safeFontSize,
      fontFamily: node.fontFamily,
      isBold: node.isBold,
      isItalic: node.isItalic,
      isUnderline: node.isUnderline,
      align: node.align,
      lineHeight: safeLineHeight,
      maxWidth: normalizeTextLayoutMaxWidth(maxWidth),
      color: textStyle.color ?? const Color(0xFF000000),
      textDirection: textDirection,
    );

    final cached = _entries.remove(key);
    if (cached != null) {
      _entries[key] = cached;
      _debugHitCount += 1;
      return cached;
    }

    final textPainter = TextPainter(
      text: TextSpan(text: node.text, style: textStyle),
      textAlign: node.align,
      textDirection: textDirection,
      maxLines: null,
    );
    if (key.maxWidth == null) {
      textPainter.layout();
    } else {
      textPainter.layout(maxWidth: key.maxWidth!);
    }
    _entries[key] = textPainter;
    _debugBuildCount += 1;
    _evictIfNeeded();
    return textPainter;
  }

  void _evictIfNeeded() {
    while (_entries.length > maxEntries) {
      _entries.remove(_entries.keys.first);
      _debugEvictCount += 1;
    }
  }
}

class _TextLayoutKeyV2 {
  const _TextLayoutKeyV2({
    required this.text,
    required this.fontSize,
    required this.fontFamily,
    required this.isBold,
    required this.isItalic,
    required this.isUnderline,
    required this.align,
    required this.lineHeight,
    required this.maxWidth,
    required this.color,
    required this.textDirection,
  });

  final String text;
  final double fontSize;
  final String? fontFamily;
  final bool isBold;
  final bool isItalic;
  final bool isUnderline;
  final TextAlign align;
  final double? lineHeight;
  final double? maxWidth;
  final Color color;
  final TextDirection textDirection;

  @override
  bool operator ==(Object other) {
    return other is _TextLayoutKeyV2 &&
        other.text == text &&
        other.fontSize == fontSize &&
        other.fontFamily == fontFamily &&
        other.isBold == isBold &&
        other.isItalic == isItalic &&
        other.isUnderline == isUnderline &&
        other.align == align &&
        other.lineHeight == lineHeight &&
        other.maxWidth == maxWidth &&
        other.color == color &&
        other.textDirection == textDirection;
  }

  @override
  int get hashCode => Object.hash(
    text,
    fontSize,
    fontFamily,
    isBold,
    isItalic,
    isUnderline,
    align,
    lineHeight,
    maxWidth,
    color,
    textDirection,
  );
}

class ScenePathMetricsCacheV2 {
  ScenePathMetricsCacheV2({int maxEntries = 512})
    : maxEntries = _requirePositiveCacheEntries(maxEntries);

  final int maxEntries;
  final LinkedHashMap<NodeId, _PathMetricsEntryV2> _entries =
      LinkedHashMap<NodeId, _PathMetricsEntryV2>();

  int _debugBuildCount = 0;
  int _debugHitCount = 0;
  int _debugEvictCount = 0;

  @visibleForTesting
  int get debugBuildCount => _debugBuildCount;
  @visibleForTesting
  int get debugHitCount => _debugHitCount;
  @visibleForTesting
  int get debugEvictCount => _debugEvictCount;
  @visibleForTesting
  int get debugSize => _entries.length;

  void clear() => _entries.clear();

  PathSelectionContoursV2 getOrBuild({
    required PathNodeSnapshot node,
    required Path localPath,
  }) {
    final cached = _entries.remove(node.id);
    if (cached != null &&
        cached.svgPathData == node.svgPathData &&
        cached.fillRule == node.fillRule) {
      _entries[node.id] = cached;
      _debugHitCount += 1;
      return cached.contours;
    }

    final fillType = _fillTypeFromSnapshot(node.fillRule);
    Path? closedContours;
    final openContours = <Path>[];
    for (final metric in localPath.computeMetrics()) {
      final contour = metric.extractPath(
        0,
        metric.length,
        startWithMoveTo: true,
      );
      contour.fillType = fillType;
      if (metric.isClosed) {
        contour.close();
        closedContours ??= Path()..fillType = fillType;
        closedContours.addPath(contour, Offset.zero);
      } else {
        openContours.add(contour);
      }
    }

    final contours = PathSelectionContoursV2(
      closedContours: closedContours,
      openContours: openContours,
    );
    _entries[node.id] = _PathMetricsEntryV2(
      svgPathData: node.svgPathData,
      fillRule: node.fillRule,
      contours: contours,
    );
    _debugBuildCount += 1;
    _evictIfNeeded();
    return contours;
  }

  void _evictIfNeeded() {
    while (_entries.length > maxEntries) {
      _entries.remove(_entries.keys.first);
      _debugEvictCount += 1;
    }
  }
}

class _PathMetricsEntryV2 {
  const _PathMetricsEntryV2({
    required this.svgPathData,
    required this.fillRule,
    required this.contours,
  });

  final String svgPathData;
  final V2PathFillRule fillRule;
  final PathSelectionContoursV2 contours;
}

class PathSelectionContoursV2 {
  const PathSelectionContoursV2({
    required this.closedContours,
    required this.openContours,
  });

  final Path? closedContours;
  final List<Path> openContours;
}

class SceneStaticLayerCacheV2 {
  _StaticLayerKeyV2? _key;
  Picture? _gridPicture;

  int _debugBuildCount = 0;
  int _debugDisposeCount = 0;

  @visibleForTesting
  int get debugBuildCount => _debugBuildCount;
  @visibleForTesting
  int get debugDisposeCount => _debugDisposeCount;
  @visibleForTesting
  int? get debugKeyHashCode => _key?.hashCode;

  void clear() {
    _disposeGridPictureIfNeeded();
    _key = null;
  }

  void dispose() => clear();

  void draw(
    Canvas canvas,
    Size size, {
    required BackgroundSnapshot background,
    required Offset cameraOffset,
    required double gridStrokeWidth,
  }) {
    _drawBackground(canvas, size, background.color);

    final safeOffset = sanitizeFiniteOffset(cameraOffset);
    final safeGridStrokeWidth = clampNonNegativeFinite(gridStrokeWidth);
    final grid = background.grid;
    final enabled = _isGridDrawable(
      grid,
      size: size,
      cameraOffset: Offset.zero,
    );
    if (!enabled) {
      _disposeGridPictureIfNeeded();
      _key = null;
      return;
    }

    final key = _StaticLayerKeyV2(
      size: size,
      gridEnabled: true,
      gridCellSize: grid.cellSize,
      gridColor: grid.color,
      gridStrokeWidth: safeGridStrokeWidth,
    );

    if (_gridPicture == null || _key != key) {
      _disposeGridPictureIfNeeded();
      _key = key;
      _gridPicture = _recordGridPicture(size, grid, safeGridStrokeWidth);
      _debugBuildCount += 1;
    }

    final picture = _gridPicture;
    if (picture == null) {
      return;
    }
    final shift = _gridShiftForCameraOffset(safeOffset, key.gridCellSize);
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.translate(shift.dx, shift.dy);
    canvas.drawPicture(picture);
    canvas.restore();
  }

  Picture _recordGridPicture(
    Size size,
    GridSnapshot grid,
    double gridStrokeWidth,
  ) {
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);
    _drawGrid(canvas, size, grid, Offset.zero, gridStrokeWidth);
    return recorder.endRecording();
  }

  void _disposeGridPictureIfNeeded() {
    final picture = _gridPicture;
    if (picture == null) {
      return;
    }
    _gridPicture = null;
    picture.dispose();
    _debugDisposeCount += 1;
  }
}

class _StaticLayerKeyV2 {
  const _StaticLayerKeyV2({
    required this.size,
    required this.gridEnabled,
    required this.gridCellSize,
    required this.gridColor,
    required this.gridStrokeWidth,
  });

  final Size size;
  final bool gridEnabled;
  final double gridCellSize;
  final Color gridColor;
  final double gridStrokeWidth;

  @override
  bool operator ==(Object other) {
    return other is _StaticLayerKeyV2 &&
        other.size == size &&
        other.gridEnabled == gridEnabled &&
        other.gridCellSize == gridCellSize &&
        other.gridColor == gridColor &&
        other.gridStrokeWidth == gridStrokeWidth;
  }

  @override
  int get hashCode =>
      Object.hash(size, gridEnabled, gridCellSize, gridColor, gridStrokeWidth);
}

class ScenePainterV2 extends CustomPainter {
  static const double _cullPadding = 1.0;

  ScenePainterV2({
    required this.controller,
    required this.imageResolver,
    this.nodePreviewOffsetResolver,
    this.staticLayerCache,
    this.textLayoutCache,
    this.strokePathCache,
    this.pathMetricsCache,
    this.selectionRect,
    this.selectionColor = const Color(0xFF1565C0),
    this.selectionStrokeWidth = 1,
    this.gridStrokeWidth = 1,
    this.textDirection = TextDirection.ltr,
  }) : super(repaint: controller);

  final SceneRenderState controller;
  final ImageResolverV2 imageResolver;
  final NodePreviewOffsetResolverV2? nodePreviewOffsetResolver;
  final SceneStaticLayerCacheV2? staticLayerCache;
  final SceneTextLayoutCacheV2? textLayoutCache;
  final SceneStrokePathCacheV2? strokePathCache;
  final ScenePathMetricsCacheV2? pathMetricsCache;
  final Rect? selectionRect;
  final Color selectionColor;
  final double selectionStrokeWidth;
  final double gridStrokeWidth;
  final TextDirection textDirection;
  final RenderGeometryCache _geometryCache = RenderGeometryCache();

  final Float64List _transformBuffer = Float64List(16);

  @override
  void paint(Canvas canvas, Size size) {
    final snapshot = controller.snapshot;
    final selectedIds = controller.selectedNodeIds;
    final cameraOffset = sanitizeFiniteOffset(snapshot.camera.offset);

    if (staticLayerCache != null) {
      staticLayerCache!.draw(
        canvas,
        size,
        background: snapshot.background,
        cameraOffset: cameraOffset,
        gridStrokeWidth: gridStrokeWidth,
      );
    } else {
      _drawBackground(canvas, size, snapshot.background.color);
      _drawGrid(
        canvas,
        size,
        snapshot.background.grid,
        cameraOffset,
        gridStrokeWidth,
      );
    }

    final viewRect = Rect.fromLTWH(
      cameraOffset.dx,
      cameraOffset.dy,
      size.width,
      size.height,
    ).inflate(_cullPadding);

    final selectedNodes = <NodeSnapshot>[];
    for (final layer in snapshot.layers) {
      for (final node in layer.nodes) {
        if (!node.isVisible) {
          continue;
        }
        final previewDelta = _nodePreviewOffset(node.id);
        final bounds = _nodeBoundsWorld(node, previewDelta: previewDelta);
        if (!_isFiniteRect(bounds) || !viewRect.overlaps(bounds)) {
          continue;
        }
        _drawNode(canvas, node, cameraOffset, previewDelta: previewDelta);
        if (selectedIds.contains(node.id)) {
          selectedNodes.add(node);
        }
      }
    }

    _drawSelection(
      canvas,
      selectedNodes,
      cameraOffset,
      selectionRect,
      clampNonNegativeFinite(selectionStrokeWidth),
    );
  }

  void _drawSelection(
    Canvas canvas,
    List<NodeSnapshot> selectedNodes,
    Offset cameraOffset,
    Rect? selectionRect,
    double selectionStrokeWidth,
  ) {
    if (selectedNodes.isNotEmpty && selectionStrokeWidth > 0) {
      for (final node in selectedNodes) {
        final previewDelta = _nodePreviewOffset(node.id);
        _drawSelectionForNode(
          canvas,
          node,
          cameraOffset,
          selectionColor,
          selectionStrokeWidth,
          previewDelta: previewDelta,
        );
      }
    }

    if (selectionRect == null) {
      return;
    }
    if (!_isFiniteRect(selectionRect)) {
      return;
    }
    final normalized = _normalizeRect(selectionRect);
    final viewRect = normalized.shift(-cameraOffset);
    final fillPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = _applyOpacity(selectionColor, 0.15);
    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = selectionStrokeWidth
      ..color = selectionColor;
    canvas.drawRect(viewRect, fillPaint);
    canvas.drawRect(viewRect, strokePaint);
  }

  void _drawSelectionForNode(
    Canvas canvas,
    NodeSnapshot node,
    Offset cameraOffset,
    Color color,
    double haloWidth, {
    required Offset previewDelta,
  }) {
    if (previewDelta != Offset.zero) {
      canvas.save();
      canvas.translate(previewDelta.dx, previewDelta.dy);
    }
    switch (node) {
      case ImageNodeSnapshot image:
        _drawWorldBoundsSelection(
          canvas,
          image,
          cameraOffset,
          color,
          haloWidth,
        );
      case TextNodeSnapshot text:
        _drawWorldBoundsSelection(canvas, text, cameraOffset, color, haloWidth);
      case RectNodeSnapshot rect:
        _drawWorldBoundsSelection(canvas, rect, cameraOffset, color, haloWidth);
      case LineNodeSnapshot line:
        if (!line.transform.isFinite ||
            !_isFiniteOffset(line.start) ||
            !_isFiniteOffset(line.end)) {
          return;
        }
        final baseThickness = clampNonNegativeFinite(line.thickness);
        canvas.save();
        canvas.transform(_toViewTransform(line.transform, cameraOffset));
        canvas.drawLine(
          line.start,
          line.end,
          _haloPaint(
            baseThickness + haloWidth * 2,
            color,
            cap: StrokeCap.round,
          ),
        );
        canvas.drawLine(
          line.start,
          line.end,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = baseThickness
            ..strokeCap = StrokeCap.round
            ..color = _applyOpacity(line.color, line.opacity),
        );
        canvas.restore();
      case StrokeNodeSnapshot stroke:
        if (stroke.points.isEmpty ||
            !stroke.transform.isFinite ||
            !_areFiniteOffsets(stroke.points)) {
          return;
        }
        final baseThickness = clampNonNegativeFinite(stroke.thickness);
        canvas.save();
        canvas.transform(_toViewTransform(stroke.transform, cameraOffset));
        if (stroke.points.length == 1) {
          _drawDotSelection(
            canvas,
            stroke.points.first,
            baseThickness / 2,
            color,
            _applyOpacity(stroke.color, stroke.opacity),
            haloWidth,
          );
        } else {
          final path = strokePathCache != null
              ? strokePathCache!.getOrBuild(stroke)
              : _buildStrokePath(stroke.points);
          canvas.drawPath(
            path,
            _haloPaint(
              baseThickness + haloWidth * 2,
              color,
              cap: StrokeCap.round,
              join: StrokeJoin.round,
            ),
          );
          canvas.drawPath(
            path,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = baseThickness
              ..strokeCap = StrokeCap.round
              ..strokeJoin = StrokeJoin.round
              ..color = _applyOpacity(stroke.color, stroke.opacity),
          );
        }
        canvas.restore();
      case PathNodeSnapshot pathNode:
        if (!pathNode.transform.isFinite) {
          return;
        }
        final localPath = _geometryCache.get(pathNode).localPath;
        if (localPath == null) {
          return;
        }
        canvas.save();
        canvas.transform(_toViewTransform(pathNode.transform, cameraOffset));
        final safeStrokeWidth = clampNonNegativeFinite(pathNode.strokeWidth);
        final hasStroke = pathNode.strokeColor != null && safeStrokeWidth > 0;
        final baseStrokeWidth = hasStroke ? safeStrokeWidth : 0.0;
        final contours = pathMetricsCache != null
            ? pathMetricsCache!.getOrBuild(node: pathNode, localPath: localPath)
            : _buildPathSelectionContours(
                pathNode: pathNode,
                localPath: localPath,
              );
        if (contours.closedContours != null) {
          _drawPathHalo(
            canvas,
            contours.closedContours!,
            color,
            haloWidth,
            baseStrokeWidth: baseStrokeWidth,
            clearFill: true,
          );
        }
        for (final contour in contours.openContours) {
          canvas.drawPath(
            contour,
            _haloPaint(
              baseStrokeWidth + haloWidth * 2,
              color,
              cap: StrokeCap.round,
              join: StrokeJoin.round,
            ),
          );
          if (baseStrokeWidth > 0) {
            canvas.drawPath(
              contour,
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = baseStrokeWidth
                ..strokeJoin = StrokeJoin.round
                ..strokeCap = StrokeCap.round
                ..color = _applyOpacity(
                  pathNode.strokeColor ?? color,
                  pathNode.opacity,
                ),
            );
          }
        }
        canvas.restore();
    }
    if (previewDelta != Offset.zero) {
      canvas.restore();
    }
  }

  PathSelectionContoursV2 _buildPathSelectionContours({
    required PathNodeSnapshot pathNode,
    required Path localPath,
  }) {
    final selectionFillType = _fillTypeFromSnapshot(pathNode.fillRule);
    Path? closedContours;
    final openContours = <Path>[];
    for (final metric in localPath.computeMetrics()) {
      final contour = metric.extractPath(
        0,
        metric.length,
        startWithMoveTo: true,
      );
      contour.fillType = selectionFillType;
      if (metric.isClosed) {
        contour.close();
        closedContours ??= Path()..fillType = selectionFillType;
        closedContours.addPath(contour, Offset.zero);
      } else {
        openContours.add(contour);
      }
    }
    return PathSelectionContoursV2(
      closedContours: closedContours,
      openContours: openContours,
    );
  }

  void _drawWorldBoundsSelection(
    Canvas canvas,
    NodeSnapshot node,
    Offset cameraOffset,
    Color color,
    double haloWidth,
  ) {
    final worldBounds = _nodeBoundsWorld(node, previewDelta: Offset.zero);
    if (!_isFiniteRect(worldBounds)) {
      return;
    }
    final viewRect = worldBounds.shift(-cameraOffset);
    _drawRectHalo(canvas, viewRect, color, haloWidth, clearFill: true);
  }

  Paint _haloPaint(
    double strokeWidth,
    Color color, {
    StrokeCap cap = StrokeCap.round,
    StrokeJoin join = StrokeJoin.round,
  }) {
    return Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = clampNonNegativeFinite(strokeWidth)
      ..strokeCap = cap
      ..strokeJoin = join
      ..color = color;
  }

  void _drawDotSelection(
    Canvas canvas,
    Offset center,
    double radius,
    Color haloColor,
    Color baseColor,
    double haloWidth,
  ) {
    canvas.drawCircle(
      center,
      radius + haloWidth,
      Paint()
        ..style = PaintingStyle.fill
        ..color = haloColor,
    );
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.fill
        ..color = baseColor,
    );
  }

  void _drawRectHalo(
    Canvas canvas,
    Rect rect,
    Color color,
    double haloWidth, {
    required bool clearFill,
  }) {
    canvas.saveLayer(null, Paint());
    final safeHaloWidth = clampNonNegativeFinite(haloWidth);
    canvas.drawRect(
      rect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = clampNonNegativeFinite(safeHaloWidth * 2)
        ..color = color,
    );
    final clearPaint = Paint()..blendMode = BlendMode.clear;
    if (clearFill) {
      clearPaint.style = PaintingStyle.fill;
      canvas.drawRect(rect, clearPaint);
    }
    canvas.restore();
  }

  void _drawPathHalo(
    Canvas canvas,
    Path path,
    Color color,
    double haloWidth, {
    required double baseStrokeWidth,
    required bool clearFill,
  }) {
    canvas.saveLayer(null, Paint());
    final safeHaloWidth = clampNonNegativeFinite(haloWidth);
    final safeBaseStrokeWidth = clampNonNegativeFinite(baseStrokeWidth);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = clampNonNegativeFinite(
          safeBaseStrokeWidth + safeHaloWidth * 2,
        )
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round
        ..color = color,
    );
    final clearPaint = Paint()..blendMode = BlendMode.clear;
    if (clearFill) {
      clearPaint.style = PaintingStyle.fill;
      canvas.drawPath(path, clearPaint);
    }
    if (safeBaseStrokeWidth > 0) {
      clearPaint
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round
        ..strokeWidth = safeBaseStrokeWidth;
      canvas.drawPath(path, clearPaint);
    }
    canvas.restore();
  }

  void _drawNode(
    Canvas canvas,
    NodeSnapshot node,
    Offset cameraOffset, {
    required Offset previewDelta,
  }) {
    if (previewDelta != Offset.zero) {
      canvas.save();
      canvas.translate(previewDelta.dx, previewDelta.dy);
    }
    switch (node) {
      case RectNodeSnapshot rectNode:
        _drawRectNode(canvas, rectNode, cameraOffset);
      case LineNodeSnapshot lineNode:
        _drawLineNode(canvas, lineNode, cameraOffset);
      case StrokeNodeSnapshot strokeNode:
        _drawStrokeNode(canvas, strokeNode, cameraOffset);
      case TextNodeSnapshot textNode:
        _drawTextNode(canvas, textNode, cameraOffset);
      case ImageNodeSnapshot imageNode:
        _drawImageNode(canvas, imageNode, cameraOffset);
      case PathNodeSnapshot pathNode:
        _drawPathNode(canvas, pathNode, cameraOffset);
    }
    if (previewDelta != Offset.zero) {
      canvas.restore();
    }
  }

  void _drawRectNode(
    Canvas canvas,
    RectNodeSnapshot node,
    Offset cameraOffset,
  ) {
    if (!node.transform.isFinite) {
      return;
    }
    final rect = _centerRect(node.size);
    canvas.save();
    canvas.transform(_toViewTransform(node.transform, cameraOffset));
    if (node.fillColor != null) {
      canvas.drawRect(
        rect,
        Paint()
          ..style = PaintingStyle.fill
          ..color = _applyOpacity(node.fillColor!, node.opacity),
      );
    }
    final strokeWidth = clampNonNegativeFinite(node.strokeWidth);
    if (node.strokeColor != null && strokeWidth > 0) {
      canvas.drawRect(
        rect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..color = _applyOpacity(node.strokeColor!, node.opacity),
      );
    }
    canvas.restore();
  }

  void _drawLineNode(
    Canvas canvas,
    LineNodeSnapshot node,
    Offset cameraOffset,
  ) {
    if (!node.transform.isFinite ||
        !_isFiniteOffset(node.start) ||
        !_isFiniteOffset(node.end)) {
      return;
    }
    canvas.save();
    canvas.transform(_toViewTransform(node.transform, cameraOffset));
    canvas.drawLine(
      node.start,
      node.end,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = clampNonNegativeFinite(node.thickness)
        ..strokeCap = StrokeCap.round
        ..color = _applyOpacity(node.color, node.opacity),
    );
    canvas.restore();
  }

  void _drawStrokeNode(
    Canvas canvas,
    StrokeNodeSnapshot node,
    Offset cameraOffset,
  ) {
    if (node.points.isEmpty ||
        !node.transform.isFinite ||
        !_areFiniteOffsets(node.points)) {
      return;
    }

    final thickness = clampNonNegativeFinite(node.thickness);
    canvas.save();
    canvas.transform(_toViewTransform(node.transform, cameraOffset));

    if (node.points.length == 1) {
      canvas.drawCircle(
        node.points.first,
        thickness / 2,
        Paint()
          ..style = PaintingStyle.fill
          ..color = _applyOpacity(node.color, node.opacity),
      );
      canvas.restore();
      return;
    }

    final path = strokePathCache != null
        ? strokePathCache!.getOrBuild(node)
        : _buildStrokePath(node.points);

    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = thickness
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = _applyOpacity(node.color, node.opacity),
    );
    canvas.restore();
  }

  void _drawTextNode(
    Canvas canvas,
    TextNodeSnapshot node,
    Offset cameraOffset,
  ) {
    if (!node.transform.isFinite) {
      return;
    }
    final safeSize = clampNonNegativeSizeFinite(node.size);
    final style = buildTextStyleForTextLayout(
      color: _applyOpacity(node.color, node.opacity),
      fontSize: node.fontSize,
      fontFamily: node.fontFamily,
      isBold: node.isBold,
      isItalic: node.isItalic,
      isUnderline: node.isUnderline,
      lineHeight: node.lineHeight,
    );
    final maxWidth = normalizeTextLayoutMaxWidth(node.maxWidth);

    final textPainter = textLayoutCache != null
        ? textLayoutCache!.getOrBuild(
            node: node,
            textStyle: style,
            maxWidth: maxWidth,
            textDirection: textDirection,
          )
        : _buildTextPainter(node, style, maxWidth);

    final alignOffset = _textAlignOffset(
      node.align,
      safeSize.width,
      textPainter.width,
      textDirection,
    );

    canvas.save();
    canvas.transform(_toViewTransform(node.transform, cameraOffset));
    textPainter.paint(
      canvas,
      Offset(-safeSize.width / 2 + alignOffset, -safeSize.height / 2),
    );
    canvas.restore();
  }

  TextPainter _buildTextPainter(
    TextNodeSnapshot node,
    TextStyle style,
    double? maxWidth,
  ) {
    final painter = TextPainter(
      text: TextSpan(text: node.text, style: style),
      textAlign: node.align,
      textDirection: textDirection,
      maxLines: null,
    );
    final safeMaxWidth = normalizeTextLayoutMaxWidth(maxWidth);
    if (safeMaxWidth == null) {
      painter.layout();
    } else {
      painter.layout(maxWidth: safeMaxWidth);
    }
    return painter;
  }

  void _drawImageNode(
    Canvas canvas,
    ImageNodeSnapshot node,
    Offset cameraOffset,
  ) {
    if (!node.transform.isFinite) {
      return;
    }
    final image = imageResolver(node.imageId);
    final rect = _centerRect(node.size);
    canvas.save();
    canvas.transform(_toViewTransform(node.transform, cameraOffset));
    if (image == null) {
      canvas.drawRect(
        rect,
        Paint()
          ..style = PaintingStyle.stroke
          ..color = const Color(0xFF9E9E9E),
      );
      canvas.restore();
      return;
    }

    paintImage(
      canvas: canvas,
      rect: rect,
      image: image,
      fit: BoxFit.fill,
      filterQuality: FilterQuality.medium,
      opacity: _alpha01(node.opacity),
    );
    canvas.restore();
  }

  void _drawPathNode(
    Canvas canvas,
    PathNodeSnapshot node,
    Offset cameraOffset,
  ) {
    if (!node.transform.isFinite) {
      return;
    }

    final localPath = _geometryCache.get(node).localPath;
    if (localPath == null) {
      return;
    }

    if (pathMetricsCache != null) {
      pathMetricsCache!.getOrBuild(node: node, localPath: localPath);
    }

    canvas.save();
    canvas.transform(_toViewTransform(node.transform, cameraOffset));

    if (node.fillColor != null) {
      canvas.drawPath(
        localPath,
        Paint()
          ..style = PaintingStyle.fill
          ..color = _applyOpacity(node.fillColor!, node.opacity),
      );
    }

    final strokeWidth = clampNonNegativeFinite(node.strokeWidth);
    if (node.strokeColor != null && strokeWidth > 0) {
      canvas.drawPath(
        localPath,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..color = _applyOpacity(node.strokeColor!, node.opacity),
      );
    }
    canvas.restore();
  }

  Rect _nodeBoundsWorld(NodeSnapshot node, {required Offset previewDelta}) {
    final bounds = _geometryCache.get(node).worldBounds;
    if (previewDelta == Offset.zero) return bounds;
    return bounds.shift(previewDelta);
  }

  Offset _nodePreviewOffset(NodeId nodeId) {
    return nodePreviewOffsetResolver?.call(nodeId) ?? Offset.zero;
  }

  Float64List _toViewTransform(Transform2D transform, Offset cameraOffset) {
    _transformBuffer[0] = transform.a;
    _transformBuffer[1] = transform.b;
    _transformBuffer[2] = 0;
    _transformBuffer[3] = 0;
    _transformBuffer[4] = transform.c;
    _transformBuffer[5] = transform.d;
    _transformBuffer[6] = 0;
    _transformBuffer[7] = 0;
    _transformBuffer[8] = 0;
    _transformBuffer[9] = 0;
    _transformBuffer[10] = 1;
    _transformBuffer[11] = 0;
    _transformBuffer[12] = transform.tx - cameraOffset.dx;
    _transformBuffer[13] = transform.ty - cameraOffset.dy;
    _transformBuffer[14] = 0;
    _transformBuffer[15] = 1;
    return _transformBuffer;
  }

  @override
  bool shouldRepaint(covariant ScenePainterV2 oldDelegate) {
    return oldDelegate.controller != controller ||
        oldDelegate.imageResolver != imageResolver ||
        oldDelegate.nodePreviewOffsetResolver != nodePreviewOffsetResolver ||
        oldDelegate.staticLayerCache != staticLayerCache ||
        oldDelegate.textLayoutCache != textLayoutCache ||
        oldDelegate.strokePathCache != strokePathCache ||
        oldDelegate.pathMetricsCache != pathMetricsCache ||
        oldDelegate.selectionRect != selectionRect ||
        oldDelegate.selectionColor != selectionColor ||
        oldDelegate.selectionStrokeWidth != selectionStrokeWidth ||
        oldDelegate.gridStrokeWidth != gridStrokeWidth ||
        oldDelegate.textDirection != textDirection;
  }
}

void _drawBackground(Canvas canvas, Size size, Color color) {
  canvas.drawRect(Offset.zero & size, Paint()..color = color);
}

void _drawGrid(
  Canvas canvas,
  Size size,
  GridSnapshot grid,
  Offset cameraOffset,
  double gridStrokeWidth,
) {
  if (!_isGridDrawable(grid, size: size, cameraOffset: cameraOffset)) {
    return;
  }

  final cell = grid.cellSize;
  final paint = Paint()
    ..color = grid.color
    ..strokeWidth = clampNonNegativeFinite(gridStrokeWidth);

  final startX = _gridStart(-cameraOffset.dx, cell);
  final startY = _gridStart(-cameraOffset.dy, cell);

  final strideX = _gridStrideForLineCount(
    _gridLineCount(startX, size.width, cell),
  );
  final strideY = _gridStrideForLineCount(
    _gridLineCount(startY, size.height, cell),
  );

  for (var x = startX, index = 0; x <= size.width; x += cell, index++) {
    if (index % strideX != 0) {
      continue;
    }
    canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
  }

  for (var y = startY, index = 0; y <= size.height; y += cell, index++) {
    if (index % strideY != 0) {
      continue;
    }
    canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
  }
}

bool _isGridDrawable(
  GridSnapshot grid, {
  required Size size,
  required Offset cameraOffset,
}) {
  if (!grid.isEnabled) {
    return false;
  }
  if (!size.width.isFinite || !size.height.isFinite) {
    return false;
  }
  if (size.width <= 0 || size.height <= 0) {
    return false;
  }
  if (!_isFiniteOffset(cameraOffset)) {
    return false;
  }
  if (!grid.cellSize.isFinite || grid.cellSize < kMinGridCellSize) {
    return false;
  }
  return true;
}

int _gridLineCount(double start, double extent, double cell) {
  if (!start.isFinite || !extent.isFinite || !cell.isFinite || cell <= 0) {
    return 0;
  }
  return ((extent - start) / cell).ceil().clamp(0, 1 << 30) + 1;
}

int _gridStrideForLineCount(int lineCount) {
  if (lineCount <= kMaxGridLinesPerAxis) {
    return 1;
  }
  return (lineCount / kMaxGridLinesPerAxis).ceil().clamp(1, 1 << 30);
}

double _gridStart(double offset, double cell) {
  if (!offset.isFinite || !cell.isFinite || cell <= 0) {
    return 0;
  }
  final rem = offset % cell;
  return rem > 0 ? rem - cell : rem;
}

Offset _gridShiftForCameraOffset(Offset cameraOffset, double cellSize) {
  if (!_isFiniteOffset(cameraOffset)) {
    return Offset.zero;
  }
  if (!cellSize.isFinite || cellSize <= 0) {
    return Offset.zero;
  }
  return Offset(
    _gridStart(-cameraOffset.dx, cellSize),
    _gridStart(-cameraOffset.dy, cellSize),
  );
}

Rect _centerRect(Size size) {
  final safe = clampNonNegativeSizeFinite(size);
  return Rect.fromCenter(
    center: Offset.zero,
    width: safe.width,
    height: safe.height,
  );
}

Rect _normalizeRect(Rect rect) {
  final left = rect.left < rect.right ? rect.left : rect.right;
  final right = rect.left < rect.right ? rect.right : rect.left;
  final top = rect.top < rect.bottom ? rect.top : rect.bottom;
  final bottom = rect.top < rect.bottom ? rect.bottom : rect.top;
  return Rect.fromLTRB(left, top, right, bottom);
}

Path _buildStrokePath(List<Offset> points) {
  final path = Path()..fillType = PathFillType.nonZero;
  final first = points.first;
  path.moveTo(first.dx, first.dy);
  for (var i = 1; i < points.length; i++) {
    final p = points[i];
    path.lineTo(p.dx, p.dy);
  }
  return path;
}

PathFillType _fillTypeFromSnapshot(V2PathFillRule rule) {
  return rule == V2PathFillRule.evenOdd
      ? PathFillType.evenOdd
      : PathFillType.nonZero;
}

Color _applyOpacity(Color color, double opacity) {
  final alpha = (_alpha01(opacity) * 255.0).round().clamp(0, 255);
  return color.withAlpha(alpha);
}

double _alpha01(double opacity) {
  return clampNonNegativeFinite(opacity).clamp(0.0, 1.0);
}

double _textAlignOffset(
  TextAlign align,
  double boxWidth,
  double textWidth,
  TextDirection textDirection,
) {
  switch (align) {
    case TextAlign.right:
      return boxWidth - textWidth;
    case TextAlign.end:
      return textDirection == TextDirection.rtl ? 0 : boxWidth - textWidth;
    case TextAlign.center:
      return (boxWidth - textWidth) / 2;
    case TextAlign.left:
      return 0;
    case TextAlign.start:
    case TextAlign.justify:
      return textDirection == TextDirection.rtl ? boxWidth - textWidth : 0;
  }
}

bool _isFiniteRect(Rect rect) {
  return rect.left.isFinite &&
      rect.top.isFinite &&
      rect.right.isFinite &&
      rect.bottom.isFinite;
}

bool _isFiniteOffset(Offset offset) {
  return offset.dx.isFinite && offset.dy.isFinite;
}

bool _areFiniteOffsets(List<Offset> offsets) {
  for (final offset in offsets) {
    if (!_isFiniteOffset(offset)) {
      return false;
    }
  }
  return true;
}
