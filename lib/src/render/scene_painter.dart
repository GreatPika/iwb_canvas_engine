import 'dart:collection';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

import '../core/nodes.dart';
import '../core/scene.dart';
import '../core/grid_safety_limits.dart';
import '../core/transform2d.dart';
import '../core/numeric_clamp.dart';
import '../input/scene_controller.dart';

/// LRU cache for built [Path] instances for [StrokeNode] geometry.
///
/// Why: avoid rebuilding long stroke polylines every frame.
/// Invariant: cached path is valid only while the stroke geometry is unchanged.
/// The cache validates freshness by [StrokeNode.pointsRevision].
/// Validate: `test/render/scene_stroke_path_cache_test.dart`.
class SceneStrokePathCache {
  SceneStrokePathCache({this.maxEntries = 512})
    : assert(maxEntries > 0, 'maxEntries must be > 0.');

  final int maxEntries;

  final LinkedHashMap<NodeId, _StrokePathEntry> _entries =
      LinkedHashMap<NodeId, _StrokePathEntry>();

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

  void clear() {
    _entries.clear();
  }

  Path getOrBuild(StrokeNode node) {
    final points = node.points;
    if (points.length < 2) {
      throw StateError(
        'SceneStrokePathCache.getOrBuild requires points.length >= 2. '
        'Dots must be handled separately.',
      );
    }

    final pointsRevision = node.pointsRevision;
    final cached = _entries.remove(node.id);
    if (cached != null && cached.pointsRevision == pointsRevision) {
      _entries[node.id] = cached;
      _debugHitCount += 1;
      return cached.path;
    }

    final path = _buildStrokePath(points);
    _entries[node.id] = _StrokePathEntry(
      path: path,
      pointsRevision: pointsRevision,
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

class _StrokePathEntry {
  const _StrokePathEntry({required this.path, required this.pointsRevision});

  final Path path;
  final int pointsRevision;
}

/// LRU cache for [TextPainter] layout results for [TextNode].
///
/// Why: avoid recomputing text layout on every paint when inputs are unchanged.
/// Invariant: cached layout is valid only while the key (text + style + layout
/// constraints) is unchanged.
/// Validate: `test/render/scene_text_layout_cache_test.dart`.
class SceneTextLayoutCache {
  SceneTextLayoutCache({this.maxEntries = 256})
    : assert(maxEntries > 0, 'maxEntries must be > 0.');

  final int maxEntries;

  final LinkedHashMap<_TextLayoutKey, TextPainter> _entries =
      LinkedHashMap<_TextLayoutKey, TextPainter>();

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

  void clear() {
    _entries.clear();
  }

  TextPainter getOrBuild({
    required TextNode node,
    required TextStyle textStyle,
    required double maxWidth,
    TextDirection textDirection = TextDirection.ltr,
  }) {
    final safeFontSize = clampPositiveFinite(node.fontSize, fallback: 24.0);
    final safeLineHeight =
        (node.lineHeight != null &&
            node.lineHeight!.isFinite &&
            node.lineHeight! > 0)
        ? node.lineHeight
        : null;
    final safeMaxWidth = clampNonNegativeFinite(maxWidth);
    final safeLetterSpacing = sanitizeFinite(
      textStyle.letterSpacing ?? 0.0,
      fallback: 0.0,
    );
    final safeWordSpacing = sanitizeFinite(
      textStyle.wordSpacing ?? 0.0,
      fallback: 0.0,
    );
    final key = _TextLayoutKey(
      text: node.text,
      fontSize: safeFontSize,
      fontFamily: node.fontFamily,
      isBold: node.isBold,
      isItalic: node.isItalic,
      isUnderline: node.isUnderline,
      align: node.align,
      lineHeight: safeLineHeight,
      letterSpacing: safeLetterSpacing,
      wordSpacing: safeWordSpacing,
      locale: textStyle.locale,
      maxWidth: safeMaxWidth,
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
      locale: textStyle.locale,
      maxLines: null,
    );
    textPainter.layout(maxWidth: safeMaxWidth);
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

class _TextLayoutKey {
  const _TextLayoutKey({
    required this.text,
    required this.fontSize,
    required this.fontFamily,
    required this.isBold,
    required this.isItalic,
    required this.isUnderline,
    required this.align,
    required this.lineHeight,
    required this.letterSpacing,
    required this.wordSpacing,
    required this.locale,
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
  final double letterSpacing;
  final double wordSpacing;
  final Locale? locale;
  final double maxWidth;
  final Color color;
  final TextDirection textDirection;

  @override
  bool operator ==(Object other) {
    return other is _TextLayoutKey &&
        other.text == text &&
        other.fontSize == fontSize &&
        other.fontFamily == fontFamily &&
        other.isBold == isBold &&
        other.isItalic == isItalic &&
        other.isUnderline == isUnderline &&
        other.align == align &&
        other.lineHeight == lineHeight &&
        other.letterSpacing == letterSpacing &&
        other.wordSpacing == wordSpacing &&
        other.locale == locale &&
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
    letterSpacing,
    wordSpacing,
    locale,
    maxWidth,
    color,
    textDirection,
  );
}

/// Resolves an [ImageNode.imageId] to a decoded [Image] instance.
///
/// This callback is invoked during painting, so it must be synchronous, fast,
/// and side-effect free.
///
/// Return `null` when the image is not available yet; the painter renders a
/// placeholder.
typedef ImageResolver = Image? Function(String imageId);

/// Strategy for snapping thin axis-aligned strokes to the physical pixel grid.
enum ThinLineSnapStrategy {
  /// Render geometry as-is without pixel-grid snapping.
  none,

  /// Snap thin horizontal/vertical line centers in view space.
  ///
  /// This targets crisper rendering on HiDPI displays for 1 logical px lines.
  autoAxisAlignedThin,
}

/// A [CustomPainter] that renders a [Scene] to a Flutter [Canvas].
///
/// The painter expects node geometry to be stored in local coordinates around
/// (0,0) and uses [SceneNode.transform] to map into scene/world coordinates.
/// It also applies [Scene.camera] offset to render into view coordinates.
class ScenePainter extends CustomPainter {
  static const double _cullPadding = 1.0;
  final Float64List _transformBuffer = Float64List(16);

  ScenePainter({
    required this.controller,
    required this.imageResolver,
    this.staticLayerCache,
    this.textLayoutCache,
    this.strokePathCache,
    this.selectionColor = const Color(0xFF1565C0),
    this.selectionStrokeWidth = 1,
    this.gridStrokeWidth = 1,
    this.devicePixelRatio = 1,
    this.thinLineSnapStrategy = ThinLineSnapStrategy.autoAxisAlignedThin,
    this.textDirection = TextDirection.ltr,
  }) : super(repaint: controller);

  final SceneController controller;
  final ImageResolver imageResolver;
  final SceneStaticLayerCache? staticLayerCache;
  final SceneTextLayoutCache? textLayoutCache;
  final SceneStrokePathCache? strokePathCache;
  final Color selectionColor;
  final double selectionStrokeWidth;
  final double gridStrokeWidth;
  final double devicePixelRatio;
  final ThinLineSnapStrategy thinLineSnapStrategy;
  final TextDirection textDirection;

  @override
  void paint(Canvas canvas, Size size) {
    final scene = controller.scene;
    final selectedNodeIds = controller.selectedNodeIds;
    final selectionRect = controller.selectionRect;
    final cameraOffset = sanitizeFiniteOffset(scene.camera.offset);
    final safeSelectionStrokeWidth = clampNonNegativeFinite(
      selectionStrokeWidth,
    );
    final safeGridStrokeWidth = clampNonNegativeFinite(gridStrokeWidth);

    if (staticLayerCache != null) {
      staticLayerCache!.draw(
        canvas,
        size,
        background: scene.background,
        cameraOffset: cameraOffset,
        gridStrokeWidth: safeGridStrokeWidth,
      );
    } else {
      _drawBackground(canvas, size, scene.background.color);
      _drawGrid(
        canvas,
        size,
        scene.background.grid,
        cameraOffset,
        safeGridStrokeWidth,
      );
    }
    final viewRect = Rect.fromLTWH(
      cameraOffset.dx,
      cameraOffset.dy,
      size.width,
      size.height,
    ).inflate(_cullPadding);
    final selectedNodes = _drawLayers(
      canvas,
      scene,
      cameraOffset,
      viewRect,
      selectedNodeIds,
    );
    _drawSelection(
      canvas,
      selectedNodes,
      cameraOffset,
      selectionRect,
      safeSelectionStrokeWidth,
    );
  }

  @override
  bool shouldRepaint(covariant ScenePainter oldDelegate) {
    final oldSelectionStrokeWidth = clampNonNegativeFinite(
      oldDelegate.selectionStrokeWidth,
    );
    final newSelectionStrokeWidth = clampNonNegativeFinite(
      selectionStrokeWidth,
    );
    final oldGridStrokeWidth = clampNonNegativeFinite(
      oldDelegate.gridStrokeWidth,
    );
    final newGridStrokeWidth = clampNonNegativeFinite(gridStrokeWidth);
    final oldDevicePixelRatio = clampPositiveFinite(
      oldDelegate.devicePixelRatio,
      fallback: 1,
    );
    final newDevicePixelRatio = clampPositiveFinite(
      devicePixelRatio,
      fallback: 1,
    );
    return oldDelegate.controller != controller ||
        oldDelegate.imageResolver != imageResolver ||
        oldDelegate.staticLayerCache != staticLayerCache ||
        oldDelegate.textLayoutCache != textLayoutCache ||
        oldDelegate.strokePathCache != strokePathCache ||
        oldDelegate.selectionColor != selectionColor ||
        oldSelectionStrokeWidth != newSelectionStrokeWidth ||
        oldGridStrokeWidth != newGridStrokeWidth ||
        oldDevicePixelRatio != newDevicePixelRatio ||
        oldDelegate.thinLineSnapStrategy != thinLineSnapStrategy ||
        oldDelegate.textDirection != textDirection;
  }

  List<SceneNode> _drawLayers(
    Canvas canvas,
    Scene scene,
    Offset cameraOffset,
    Rect viewRect,
    Set<NodeId> selectedNodeIds,
  ) {
    final selectedNodes = <SceneNode>[];
    for (final layer in scene.layers) {
      for (final node in layer.nodes) {
        if (!node.isVisible) continue;
        if (!viewRect.overlaps(node.boundsWorld)) continue;
        _drawNode(canvas, node, cameraOffset);
        if (selectedNodeIds.contains(node.id)) {
          selectedNodes.add(node);
        }
      }
    }
    return selectedNodes;
  }

  void _drawSelection(
    Canvas canvas,
    List<SceneNode> selectedNodes,
    Offset cameraOffset,
    Rect? selectionRect,
    double selectionStrokeWidth,
  ) {
    if (selectedNodes.isNotEmpty && selectionStrokeWidth > 0) {
      for (final node in selectedNodes) {
        _drawSelectionForNode(
          canvas,
          node,
          cameraOffset,
          selectionColor,
          selectionStrokeWidth,
        );
      }
    }

    if (selectionRect != null) {
      if (!_isFiniteRect(selectionRect)) return;
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
  }

  void _drawSelectionForNode(
    Canvas canvas,
    SceneNode node,
    Offset cameraOffset,
    Color color,
    double haloWidth,
  ) {
    if (node is ImageNode) {
      _drawBoxSelection(
        canvas,
        node.transform,
        cameraOffset,
        clampNonNegativeSizeFinite(node.size),
        color,
        haloWidth,
        baseStrokeWidth: 0,
        clearFill: true,
      );
    } else if (node is TextNode) {
      _drawBoxSelection(
        canvas,
        node.transform,
        cameraOffset,
        clampNonNegativeSizeFinite(node.size),
        color,
        haloWidth,
        baseStrokeWidth: 0,
        clearFill: true,
      );
    } else if (node is RectNode) {
      final safeStrokeWidth = clampNonNegativeFinite(node.strokeWidth);
      final hasStroke = node.strokeColor != null && safeStrokeWidth > 0;
      _drawBoxSelection(
        canvas,
        node.transform,
        cameraOffset,
        clampNonNegativeSizeFinite(node.size),
        color,
        haloWidth,
        baseStrokeWidth: hasStroke ? safeStrokeWidth : 0,
        clearFill: true,
      );
    } else if (node is LineNode) {
      if (!_isFiniteTransform2D(node.transform)) return;
      if (!_isFiniteOffset(node.start) || !_isFiniteOffset(node.end)) return;
      final baseThickness = clampNonNegativeFinite(node.thickness);
      final line = _resolveSnappedLine(
        node.transform,
        cameraOffset,
        baseThickness,
        node.start,
        node.end,
      );
      if (line != null) {
        canvas.drawLine(
          line.a,
          line.b,
          _haloPaint(
            baseThickness + haloWidth * 2,
            color,
            cap: StrokeCap.round,
          ),
        );
        canvas.drawLine(
          line.a,
          line.b,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = baseThickness
            ..strokeCap = StrokeCap.round
            ..color = _applyOpacity(node.color, node.opacity),
        );
      } else {
        canvas.save();
        canvas.transform(_toViewCanvasTransform(node.transform, cameraOffset));
        canvas.drawLine(
          node.start,
          node.end,
          _haloPaint(
            baseThickness + haloWidth * 2,
            color,
            cap: StrokeCap.round,
          ),
        );
        canvas.drawLine(
          node.start,
          node.end,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = baseThickness
            ..strokeCap = StrokeCap.round
            ..color = _applyOpacity(node.color, node.opacity),
        );
        canvas.restore();
      }
    } else if (node is StrokeNode) {
      if (node.points.isEmpty) return;
      if (!_isFiniteTransform2D(node.transform)) return;
      if (!_areFiniteOffsets(node.points)) return;
      final baseThickness = clampNonNegativeFinite(node.thickness);
      canvas.save();
      canvas.transform(_toViewCanvasTransform(node.transform, cameraOffset));
      if (node.points.length == 1) {
        _drawDotSelection(
          canvas,
          node.points.first,
          baseThickness / 2,
          color,
          _applyOpacity(node.color, node.opacity),
          haloWidth,
        );
      } else {
        final points = _resolveSnappedPolyline(
          node.transform,
          cameraOffset,
          baseThickness,
          node.points,
        );
        if (points != null) {
          final path = _buildStrokePath(points);
          canvas.restore();
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
              ..color = _applyOpacity(node.color, node.opacity),
          );
          return;
        }
        final path = strokePathCache != null
            ? strokePathCache!.getOrBuild(node)
            : _buildStrokePath(node.points);
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
            ..color = _applyOpacity(node.color, node.opacity),
        );
      }
      canvas.restore();
    } else if (node is PathNode) {
      final localPath = node.buildLocalPath(copy: false);
      if (localPath == null) return;
      if (!_isFiniteTransform2D(node.transform)) return;
      canvas.save();
      canvas.transform(_toViewCanvasTransform(node.transform, cameraOffset));
      final safeStrokeWidth = clampNonNegativeFinite(node.strokeWidth);
      final hasStroke = node.strokeColor != null && safeStrokeWidth > 0;
      final baseStrokeWidth = hasStroke ? safeStrokeWidth : 0.0;
      final metrics = localPath.computeMetrics().toList();
      if (metrics.isEmpty) {
        canvas.restore();
        return;
      }

      Path? closedContours;
      final openContours = <Path>[];
      final selectionFillType = _pathFillType(node.fillRule);
      for (final metric in metrics) {
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

      if (closedContours != null) {
        _drawPathHalo(
          canvas,
          closedContours,
          color,
          haloWidth,
          baseStrokeWidth: baseStrokeWidth,
          clearFill: true,
        );
      }

      for (final contour in openContours) {
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
              ..color = _applyOpacity(node.strokeColor ?? color, node.opacity),
          );
        }
      }
      canvas.restore();
    }
  }

  void _drawBoxSelection(
    Canvas canvas,
    Transform2D nodeTransform,
    Offset cameraOffset,
    Size size,
    Color color,
    double haloWidth, {
    required double baseStrokeWidth,
    required bool clearFill,
  }) {
    if (!_isFiniteTransform2D(nodeTransform)) return;
    canvas.save();
    canvas.transform(_toViewCanvasTransform(nodeTransform, cameraOffset));
    final rect = Rect.fromCenter(
      center: Offset.zero,
      width: clampNonNegativeFinite(size.width),
      height: clampNonNegativeFinite(size.height),
    );
    _drawRectHalo(
      canvas,
      rect,
      color,
      clampNonNegativeFinite(haloWidth),
      baseStrokeWidth: clampNonNegativeFinite(baseStrokeWidth),
      clearFill: clearFill,
    );
    canvas.restore();
  }

  Paint _haloPaint(
    double strokeWidth,
    Color color, {
    StrokeCap cap = StrokeCap.round,
    StrokeJoin join = StrokeJoin.round,
  }) {
    final safeStrokeWidth = clampNonNegativeFinite(strokeWidth);
    return Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = safeStrokeWidth
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
    final haloPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = haloColor;
    canvas.drawCircle(center, radius + haloWidth, haloPaint);
    final basePaint = Paint()
      ..style = PaintingStyle.fill
      ..color = baseColor;
    canvas.drawCircle(center, radius, basePaint);
  }

  void _drawRectHalo(
    Canvas canvas,
    Rect rect,
    Color color,
    double haloWidth, {
    required double baseStrokeWidth,
    required bool clearFill,
  }) {
    canvas.saveLayer(null, Paint());
    final safeHaloWidth = clampNonNegativeFinite(haloWidth);
    final safeBaseStrokeWidth = clampNonNegativeFinite(baseStrokeWidth);
    final haloPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = clampNonNegativeFinite(
        safeBaseStrokeWidth + safeHaloWidth * 2,
      )
      ..color = color;
    canvas.drawRect(rect, haloPaint);
    final clearPaint = Paint()..blendMode = BlendMode.clear;
    if (clearFill) {
      clearPaint.style = PaintingStyle.fill;
      canvas.drawRect(rect, clearPaint);
    }
    if (safeBaseStrokeWidth > 0) {
      clearPaint
        ..style = PaintingStyle.stroke
        ..strokeWidth = safeBaseStrokeWidth;
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
    final haloPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = clampNonNegativeFinite(
        safeBaseStrokeWidth + safeHaloWidth * 2,
      )
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas.drawPath(path, haloPaint);
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

  void _drawNode(Canvas canvas, SceneNode node, Offset cameraOffset) {
    if (node is ImageNode) {
      _drawImageNode(canvas, node, cameraOffset);
    } else if (node is TextNode) {
      _drawTextNode(canvas, node, cameraOffset);
    } else if (node is StrokeNode) {
      _drawStrokeNode(canvas, node, cameraOffset);
    } else if (node is LineNode) {
      _drawLineNode(canvas, node, cameraOffset);
    } else if (node is RectNode) {
      _drawRectNode(canvas, node, cameraOffset);
    } else if (node is PathNode) {
      _drawPathNode(canvas, node, cameraOffset);
    }
  }

  void _drawImageNode(Canvas canvas, ImageNode node, Offset cameraOffset) {
    if (!_isFiniteTransform2D(node.transform)) return;
    canvas.save();
    canvas.transform(_toViewCanvasTransform(node.transform, cameraOffset));

    final rect = Rect.fromCenter(
      center: Offset.zero,
      width: clampNonNegativeFinite(node.size.width),
      height: clampNonNegativeFinite(node.size.height),
    );

    final image = imageResolver(node.imageId);
    if (image != null) {
      final src = Rect.fromLTWH(
        0,
        0,
        image.width.toDouble(),
        image.height.toDouble(),
      );
      final paint = Paint()
        ..filterQuality = FilterQuality.medium
        ..color = Color.fromRGBO(255, 255, 255, _clamp01(node.opacity));
      canvas.drawImageRect(image, src, rect, paint);
    } else {
      _drawImagePlaceholder(canvas, rect, node.opacity);
    }

    canvas.restore();
  }

  void _drawImagePlaceholder(Canvas canvas, Rect rect, double opacity) {
    final color = _applyOpacity(const Color(0xFFB0BEC5), opacity);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = color;
    canvas.drawRect(rect, paint);
    canvas.drawLine(rect.topLeft, rect.bottomRight, paint);
    canvas.drawLine(rect.topRight, rect.bottomLeft, paint);
  }

  void _drawTextNode(Canvas canvas, TextNode node, Offset cameraOffset) {
    if (!_isFiniteTransform2D(node.transform)) return;
    canvas.save();
    canvas.transform(_toViewCanvasTransform(node.transform, cameraOffset));

    final fontSize = clampPositiveFinite(node.fontSize, fallback: 24.0);
    final safeLineHeight =
        (node.lineHeight != null &&
            node.lineHeight!.isFinite &&
            node.lineHeight! > 0)
        ? node.lineHeight
        : null;
    final textStyle = TextStyle(
      fontSize: fontSize,
      color: _applyOpacity(node.color, node.opacity),
      fontWeight: node.isBold ? FontWeight.bold : FontWeight.normal,
      fontStyle: node.isItalic ? FontStyle.italic : FontStyle.normal,
      decoration: node.isUnderline ? TextDecoration.underline : null,
      fontFamily: node.fontFamily,
      height: safeLineHeight == null ? null : safeLineHeight / fontSize,
    );

    final safeMaxWidth =
        (node.maxWidth != null && node.maxWidth!.isFinite && node.maxWidth! > 0)
        ? node.maxWidth!
        : clampNonNegativeFinite(node.size.width);
    final textPainter = textLayoutCache != null
        ? textLayoutCache!.getOrBuild(
            node: node,
            textStyle: textStyle,
            maxWidth: safeMaxWidth,
            textDirection: textDirection,
          )
        : (TextPainter(
            text: TextSpan(text: node.text, style: textStyle),
            textAlign: node.align,
            textDirection: textDirection,
            maxLines: null,
          )..layout(maxWidth: safeMaxWidth));

    final safeBoxSize = clampNonNegativeSizeFinite(node.size);
    final box = Rect.fromCenter(
      center: Offset.zero,
      width: safeBoxSize.width,
      height: safeBoxSize.height,
    );

    final dx = _textAlignOffset(
      node.align,
      box.width,
      textPainter.width,
      textDirection,
    );
    final dy = (box.height - textPainter.height) / 2;
    final offset = Offset(box.left + dx, box.top + dy);
    textPainter.paint(canvas, offset);

    canvas.restore();
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

  void _drawStrokeNode(Canvas canvas, StrokeNode node, Offset cameraOffset) {
    if (node.points.isEmpty) return;
    if (!_isFiniteTransform2D(node.transform)) return;
    if (!_areFiniteOffsets(node.points)) return;
    final baseThickness = clampNonNegativeFinite(node.thickness);
    canvas.save();
    canvas.transform(_toViewCanvasTransform(node.transform, cameraOffset));

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = baseThickness
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = _applyOpacity(node.color, node.opacity);

    if (node.points.length == 1) {
      canvas.drawCircle(
        node.points.first,
        baseThickness / 2,
        paint..style = PaintingStyle.fill,
      );
      canvas.restore();
      return;
    }

    final snappedPoints = _resolveSnappedPolyline(
      node.transform,
      cameraOffset,
      baseThickness,
      node.points,
    );
    if (snappedPoints != null) {
      canvas.restore();
      canvas.drawPath(_buildStrokePath(snappedPoints), paint);
      return;
    }

    final path = strokePathCache != null
        ? strokePathCache!.getOrBuild(node)
        : _buildStrokePath(node.points);
    canvas.drawPath(path, paint);
    canvas.restore();
  }

  void _drawLineNode(Canvas canvas, LineNode node, Offset cameraOffset) {
    if (!_isFiniteTransform2D(node.transform)) return;
    if (!_isFiniteOffset(node.start) || !_isFiniteOffset(node.end)) return;
    final baseThickness = clampNonNegativeFinite(node.thickness);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = baseThickness
      ..strokeCap = StrokeCap.round
      ..color = _applyOpacity(node.color, node.opacity);
    final line = _resolveSnappedLine(
      node.transform,
      cameraOffset,
      baseThickness,
      node.start,
      node.end,
    );
    if (line != null) {
      canvas.drawLine(line.a, line.b, paint);
      return;
    }
    canvas.save();
    canvas.transform(_toViewCanvasTransform(node.transform, cameraOffset));
    canvas.drawLine(node.start, node.end, paint);
    canvas.restore();
  }

  void _drawRectNode(Canvas canvas, RectNode node, Offset cameraOffset) {
    if (!_isFiniteTransform2D(node.transform)) return;
    final safeStrokeWidth = clampNonNegativeFinite(node.strokeWidth);
    canvas.save();
    canvas.transform(_toViewCanvasTransform(node.transform, cameraOffset));

    final rect = Rect.fromCenter(
      center: Offset.zero,
      width: clampNonNegativeFinite(node.size.width),
      height: clampNonNegativeFinite(node.size.height),
    );

    if (node.fillColor != null) {
      final paint = Paint()
        ..style = PaintingStyle.fill
        ..color = _applyOpacity(node.fillColor!, node.opacity);
      canvas.drawRect(rect, paint);
    }
    if (node.strokeColor != null && safeStrokeWidth > 0) {
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = safeStrokeWidth
        ..color = _applyOpacity(node.strokeColor!, node.opacity);
      canvas.drawRect(rect, paint);
    }

    canvas.restore();
  }

  void _drawPathNode(Canvas canvas, PathNode node, Offset cameraOffset) {
    if (node.svgPathData.trim().isEmpty) return;
    if (!_isFiniteTransform2D(node.transform)) return;
    final safeStrokeWidth = clampNonNegativeFinite(node.strokeWidth);

    final centered = node.buildLocalPath(copy: false);
    if (centered == null) return;

    canvas.save();
    canvas.transform(_toViewCanvasTransform(node.transform, cameraOffset));

    if (node.fillColor != null) {
      final paint = Paint()
        ..style = PaintingStyle.fill
        ..color = _applyOpacity(node.fillColor!, node.opacity);
      canvas.drawPath(centered, paint);
    }

    if (node.strokeColor != null && safeStrokeWidth > 0) {
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = safeStrokeWidth
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round
        ..color = _applyOpacity(node.strokeColor!, node.opacity);
      canvas.drawPath(centered, paint);
    }

    canvas.restore();
  }

  Rect _normalizeRect(Rect rect) {
    return Rect.fromLTRB(
      math.min(rect.left, rect.right),
      math.min(rect.top, rect.bottom),
      math.max(rect.left, rect.right),
      math.max(rect.top, rect.bottom),
    );
  }

  Float64List _toViewCanvasTransform(
    Transform2D nodeTransform,
    Offset cameraOffset,
  ) {
    _transformBuffer[0] = nodeTransform.a;
    _transformBuffer[1] = nodeTransform.b;
    _transformBuffer[2] = 0;
    _transformBuffer[3] = 0;
    _transformBuffer[4] = nodeTransform.c;
    _transformBuffer[5] = nodeTransform.d;
    _transformBuffer[6] = 0;
    _transformBuffer[7] = 0;
    _transformBuffer[8] = 0;
    _transformBuffer[9] = 0;
    _transformBuffer[10] = 1;
    _transformBuffer[11] = 0;
    _transformBuffer[12] = nodeTransform.tx - cameraOffset.dx;
    _transformBuffer[13] = nodeTransform.ty - cameraOffset.dy;
    _transformBuffer[14] = 0;
    _transformBuffer[15] = 1;
    return _transformBuffer;
  }

  Color _applyOpacity(Color color, double opacity) {
    final combined = (color.a * _clamp01(opacity)).clamp(0.0, 1.0);
    return color.withAlpha((combined * 255.0).round().clamp(0, 255));
  }

  double _clamp01(double value) {
    return clamp01Finite(value);
  }

  _LineEndpoints? _resolveSnappedLine(
    Transform2D nodeTransform,
    Offset cameraOffset,
    double strokeWidth,
    Offset localA,
    Offset localB,
  ) {
    if (!_canSnapThinStroke(nodeTransform, strokeWidth)) return null;
    final viewA = nodeTransform.applyToPoint(localA) - cameraOffset;
    final viewB = nodeTransform.applyToPoint(localB) - cameraOffset;
    if (!_isFiniteOffset(viewA) || !_isFiniteOffset(viewB)) return null;

    const axisTolerance = 1e-3;
    final isHorizontal = (viewA.dy - viewB.dy).abs() <= axisTolerance;
    final isVertical = (viewA.dx - viewB.dx).abs() <= axisTolerance;
    if (!isHorizontal && !isVertical) return null;

    if (isHorizontal) {
      final strokeWidthInView =
          strokeWidth * _effectiveViewScaleMagnitude(nodeTransform);
      final snappedY = _snapCenterCoordinate(
        (viewA.dy + viewB.dy) / 2,
        strokeWidthInView,
      );
      return _LineEndpoints(
        a: Offset(viewA.dx, snappedY),
        b: Offset(viewB.dx, snappedY),
      );
    }
    final strokeWidthInView =
        strokeWidth * _effectiveViewScaleMagnitude(nodeTransform);
    final snappedX = _snapCenterCoordinate(
      (viewA.dx + viewB.dx) / 2,
      strokeWidthInView,
    );
    return _LineEndpoints(
      a: Offset(snappedX, viewA.dy),
      b: Offset(snappedX, viewB.dy),
    );
  }

  List<Offset>? _resolveSnappedPolyline(
    Transform2D nodeTransform,
    Offset cameraOffset,
    double strokeWidth,
    List<Offset> localPoints,
  ) {
    if (!_canSnapThinStroke(nodeTransform, strokeWidth)) return null;
    if (localPoints.length < 2) return null;

    final viewPoints = <Offset>[];
    for (final point in localPoints) {
      final viewPoint = nodeTransform.applyToPoint(point) - cameraOffset;
      if (!_isFiniteOffset(viewPoint)) return null;
      viewPoints.add(viewPoint);
    }

    const axisTolerance = 1e-3;
    final first = viewPoints.first;
    final isHorizontal = viewPoints.every(
      (point) => (point.dy - first.dy).abs() <= axisTolerance,
    );
    final isVertical = viewPoints.every(
      (point) => (point.dx - first.dx).abs() <= axisTolerance,
    );
    if (!isHorizontal && !isVertical) return null;

    final strokeWidthInView =
        strokeWidth * _effectiveViewScaleMagnitude(nodeTransform);
    if (isHorizontal) {
      final meanY =
          viewPoints.map((p) => p.dy).reduce((a, b) => a + b) /
          viewPoints.length;
      final snappedY = _snapCenterCoordinate(meanY, strokeWidthInView);
      return viewPoints.map((point) => Offset(point.dx, snappedY)).toList();
    }
    final meanX =
        viewPoints.map((p) => p.dx).reduce((a, b) => a + b) / viewPoints.length;
    final snappedX = _snapCenterCoordinate(meanX, strokeWidthInView);
    return viewPoints.map((point) => Offset(snappedX, point.dy)).toList();
  }

  bool _canSnapThinStroke(Transform2D nodeTransform, double strokeWidth) {
    if (thinLineSnapStrategy != ThinLineSnapStrategy.autoAxisAlignedThin) {
      return false;
    }
    if (!_isFiniteTransform2D(nodeTransform)) return false;
    if (!_hasAxisAlignedUnitScale(nodeTransform)) return false;

    final viewScale = _effectiveViewScaleMagnitude(nodeTransform);
    if (!viewScale.isFinite || viewScale <= 0) return false;
    final strokeWidthInView = strokeWidth * viewScale;
    return strokeWidthInView > 0 && strokeWidthInView <= 1;
  }

  bool _hasAxisAlignedUnitScale(Transform2D transform) {
    const epsilon = 1e-6;
    if (transform.b.abs() > epsilon || transform.c.abs() > epsilon) {
      return false;
    }
    final scaleX = transform.a.abs();
    final scaleY = transform.d.abs();
    return (scaleX - 1).abs() <= epsilon && (scaleY - 1).abs() <= epsilon;
  }

  double _effectiveViewScaleMagnitude(Transform2D transform) {
    final safeScaleX = sanitizeFinite(transform.a.abs(), fallback: 1.0);
    final safeScaleY = sanitizeFinite(transform.d.abs(), fallback: 1.0);
    return math.max(safeScaleX, safeScaleY);
  }

  double _snapCenterCoordinate(double logical, double strokeWidth) {
    final safeDpr = clampPositiveFinite(devicePixelRatio, fallback: 1);
    final physical = logical * safeDpr;
    final physicalWidth = strokeWidth * safeDpr;
    final roundedWidth = physicalWidth.round();
    final targetFraction = roundedWidth.isOdd ? 0.5 : 0.0;
    final snappedPhysical =
        (physical - targetFraction).roundToDouble() + targetFraction;
    return snappedPhysical / safeDpr;
  }
}

class _LineEndpoints {
  const _LineEndpoints({required this.a, required this.b});

  final Offset a;
  final Offset b;
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

PathFillType _pathFillType(PathFillRule rule) {
  return rule == PathFillRule.evenOdd
      ? PathFillType.evenOdd
      : PathFillType.nonZero;
}

/// Cache for static grid rendering.
///
/// Why: avoid re-recording grid geometry when inputs are unchanged.
/// Invariant: static cache key must stay camera-independent; camera translation
/// is applied at draw time.
/// Validate: `test/render/scene_static_layer_cache_test.dart`.
class SceneStaticLayerCache {
  _StaticLayerKey? _key;
  Picture? _gridPicture;

  int _debugBuildCount = 0;
  int _debugDisposeCount = 0;

  @visibleForTesting
  int get debugBuildCount => _debugBuildCount;
  @visibleForTesting
  int get debugDisposeCount => _debugDisposeCount;
  @visibleForTesting
  int? get debugKeyHashCode => _key?.hashCode;

  void draw(
    Canvas canvas,
    Size size, {
    required Background background,
    required Offset cameraOffset,
    required double gridStrokeWidth,
  }) {
    _drawBackground(canvas, size, background.color);

    final safeCameraOffset = sanitizeFiniteOffset(cameraOffset);
    final safeGridStrokeWidth = clampNonNegativeFinite(gridStrokeWidth);
    final grid = background.grid;
    final effectiveGridEnabled = _isGridDrawable(
      grid,
      size: size,
      cameraOffset: Offset.zero,
    );
    final cell = grid.cellSize;
    final effectiveCellSize = effectiveGridEnabled ? cell : 0.0;
    final key = _StaticLayerKey(
      size: size,
      gridEnabled: effectiveGridEnabled,
      gridCellSize: effectiveCellSize,
      gridColor: grid.color,
      gridStrokeWidth: safeGridStrokeWidth,
    );

    if (_gridPicture == null || _key != key) {
      _disposeGridPictureIfNeeded();
      _key = key;
      _gridPicture = _recordGridPicture(size, grid, safeGridStrokeWidth);
      _debugBuildCount += 1;
    }

    if (!_key!.gridEnabled) return;
    final shift = _gridShiftForCameraOffset(
      safeCameraOffset,
      _key!.gridCellSize,
    );
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.translate(shift.dx, shift.dy);
    canvas.drawPicture(_gridPicture!);
    canvas.restore();
  }

  void dispose() {
    _disposeGridPictureIfNeeded();
    _key = null;
  }

  void _disposeGridPictureIfNeeded() {
    final picture = _gridPicture;
    if (picture == null) return;
    _gridPicture = null;
    picture.dispose();
    _debugDisposeCount += 1;
  }

  Picture _recordGridPicture(
    Size size,
    GridSettings grid,
    double gridStrokeWidth,
  ) {
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);
    _drawGrid(canvas, size, grid, Offset.zero, gridStrokeWidth);
    return recorder.endRecording();
  }
}

class _StaticLayerKey {
  const _StaticLayerKey({
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
    return other is _StaticLayerKey &&
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

void _drawBackground(Canvas canvas, Size size, Color color) {
  final paint = Paint()..color = color;
  canvas.drawRect(Offset.zero & size, paint);
}

void _drawGrid(
  Canvas canvas,
  Size size,
  GridSettings grid,
  Offset cameraOffset,
  double gridStrokeWidth,
) {
  if (!_isGridDrawable(grid, size: size, cameraOffset: cameraOffset)) return;
  final cell = grid.cellSize;

  final paint = Paint()
    ..color = grid.color
    ..strokeWidth = clampNonNegativeFinite(gridStrokeWidth);
  final startX = _gridStart(-cameraOffset.dx, cell);
  final startY = _gridStart(-cameraOffset.dy, cell);

  for (double x = startX; x <= size.width; x += cell) {
    canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
  }
  for (double y = startY; y <= size.height; y += cell) {
    canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
  }
}

bool _isGridDrawable(
  GridSettings grid, {
  required Size size,
  required Offset cameraOffset,
}) {
  if (!grid.isEnabled) return false;
  final cell = grid.cellSize;
  if (!cell.isFinite || cell < kMinGridCellSize) return false;

  final startX = _gridStart(-cameraOffset.dx, cell);
  final startY = _gridStart(-cameraOffset.dy, cell);
  final verticalLines = _gridLineCount(startX, size.width, cell);
  final horizontalLines = _gridLineCount(startY, size.height, cell);
  return verticalLines <= kMaxGridLinesPerAxis &&
      horizontalLines <= kMaxGridLinesPerAxis;
}

int _gridLineCount(double start, double extent, double cell) {
  if (!start.isFinite || !extent.isFinite || !cell.isFinite || cell <= 0) {
    return kMaxGridLinesPerAxis + 1;
  }
  if (start > extent) return 0;
  final count = ((extent - start) / cell).floor() + 1;
  return count < 0 ? 0 : count;
}

@visibleForTesting
int debugGridLineCount(double start, double extent, double cell) =>
    _gridLineCount(start, extent, cell);

double _gridStart(double offset, double cell) {
  final remainder = offset % cell;
  return remainder < 0 ? remainder + cell : remainder;
}

Offset _gridShiftForCameraOffset(Offset cameraOffset, double cellSize) {
  if (!cameraOffset.dx.isFinite || !cameraOffset.dy.isFinite) {
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

bool _isFiniteTransform2D(Transform2D transform) {
  return transform.a.isFinite &&
      transform.b.isFinite &&
      transform.c.isFinite &&
      transform.d.isFinite &&
      transform.tx.isFinite &&
      transform.ty.isFinite;
}

bool _isFiniteRect(Rect rect) {
  return rect.left.isFinite &&
      rect.top.isFinite &&
      rect.right.isFinite &&
      rect.bottom.isFinite;
}

bool _isFiniteOffset(Offset value) {
  return value.dx.isFinite && value.dy.isFinite;
}

bool _areFiniteOffsets(List<Offset> values) {
  for (final value in values) {
    if (!_isFiniteOffset(value)) return false;
  }
  return true;
}
