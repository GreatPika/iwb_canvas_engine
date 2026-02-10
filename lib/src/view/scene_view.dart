import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import '../controller/scene_controller.dart';
import '../render/scene_painter.dart';

ui.Image? _defaultImageResolver(String _) => null;

class SceneViewV2 extends StatefulWidget {
  const SceneViewV2({
    required this.controller,
    this.imageResolver,
    this.staticLayerCache,
    this.textLayoutCache,
    this.strokePathCache,
    this.pathMetricsCache,
    this.selectionColor = const Color(0xFF1565C0),
    this.selectionStrokeWidth = 1,
    this.gridStrokeWidth = 1,
    super.key,
  });

  final SceneControllerV2 controller;
  final ImageResolverV2? imageResolver;
  final SceneStaticLayerCacheV2? staticLayerCache;
  final SceneTextLayoutCacheV2? textLayoutCache;
  final SceneStrokePathCacheV2? strokePathCache;
  final ScenePathMetricsCacheV2? pathMetricsCache;
  final Color selectionColor;
  final double selectionStrokeWidth;
  final double gridStrokeWidth;

  @override
  State<SceneViewV2> createState() => _SceneViewV2State();
}

class _SceneViewV2State extends State<SceneViewV2> {
  late SceneStaticLayerCacheV2 _staticLayerCache;
  late bool _ownsStaticLayerCache;
  late SceneTextLayoutCacheV2 _textLayoutCache;
  late bool _ownsTextLayoutCache;
  late SceneStrokePathCacheV2 _strokePathCache;
  late bool _ownsStrokePathCache;
  late ScenePathMetricsCacheV2 _pathMetricsCache;
  late bool _ownsPathMetricsCache;

  int _lastEpoch = 0;

  @visibleForTesting
  SceneStaticLayerCacheV2 get debugStaticLayerCache => _staticLayerCache;
  @visibleForTesting
  SceneTextLayoutCacheV2 get debugTextLayoutCache => _textLayoutCache;
  @visibleForTesting
  SceneStrokePathCacheV2 get debugStrokePathCache => _strokePathCache;
  @visibleForTesting
  ScenePathMetricsCacheV2 get debugPathMetricsCache => _pathMetricsCache;

  @override
  void initState() {
    super.initState();
    _initStaticLayerCache();
    _initTextLayoutCache();
    _initStrokePathCache();
    _initPathMetricsCache();
    _lastEpoch = widget.controller.controllerEpoch;
    widget.controller.addListener(_handleControllerChanged);
  }

  @override
  void didUpdateWidget(SceneViewV2 oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_handleControllerChanged);
      widget.controller.addListener(_handleControllerChanged);
      _lastEpoch = widget.controller.controllerEpoch;
      _clearAllCaches();
    }
    if (oldWidget.staticLayerCache != widget.staticLayerCache) {
      _syncStaticLayerCache();
    }
    if (oldWidget.textLayoutCache != widget.textLayoutCache) {
      _syncTextLayoutCache();
    }
    if (oldWidget.strokePathCache != widget.strokePathCache) {
      _syncStrokePathCache();
    }
    if (oldWidget.pathMetricsCache != widget.pathMetricsCache) {
      _syncPathMetricsCache();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleControllerChanged);
    if (_ownsStaticLayerCache) {
      _staticLayerCache.dispose();
    }
    if (_ownsTextLayoutCache) {
      _textLayoutCache.clear();
    }
    if (_ownsStrokePathCache) {
      _strokePathCache.clear();
    }
    if (_ownsPathMetricsCache) {
      _pathMetricsCache.clear();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textDirection = Directionality.maybeOf(context) ?? TextDirection.ltr;
    return CustomPaint(
      painter: ScenePainterV2(
        controller: widget.controller,
        imageResolver: widget.imageResolver ?? _defaultImageResolver,
        staticLayerCache: _staticLayerCache,
        textLayoutCache: _textLayoutCache,
        strokePathCache: _strokePathCache,
        pathMetricsCache: _pathMetricsCache,
        selectionColor: widget.selectionColor,
        selectionStrokeWidth: widget.selectionStrokeWidth,
        gridStrokeWidth: widget.gridStrokeWidth,
        textDirection: textDirection,
      ),
      child: const SizedBox.expand(),
    );
  }

  void _handleControllerChanged() {
    final epoch = widget.controller.controllerEpoch;
    if (epoch == _lastEpoch) return;
    _lastEpoch = epoch;
    _clearAllCaches();
  }

  void _clearAllCaches() {
    _staticLayerCache.clear();
    _textLayoutCache.clear();
    _strokePathCache.clear();
    _pathMetricsCache.clear();
  }

  void _initStaticLayerCache() {
    final external = widget.staticLayerCache;
    if (external != null) {
      _staticLayerCache = external;
      _ownsStaticLayerCache = false;
      return;
    }
    _staticLayerCache = SceneStaticLayerCacheV2();
    _ownsStaticLayerCache = true;
  }

  void _syncStaticLayerCache() {
    if (_ownsStaticLayerCache) {
      _staticLayerCache.dispose();
    }
    _initStaticLayerCache();
  }

  void _initTextLayoutCache() {
    final external = widget.textLayoutCache;
    if (external != null) {
      _textLayoutCache = external;
      _ownsTextLayoutCache = false;
      return;
    }
    _textLayoutCache = SceneTextLayoutCacheV2();
    _ownsTextLayoutCache = true;
  }

  void _syncTextLayoutCache() {
    if (_ownsTextLayoutCache) {
      _textLayoutCache.clear();
    }
    _initTextLayoutCache();
  }

  void _initStrokePathCache() {
    final external = widget.strokePathCache;
    if (external != null) {
      _strokePathCache = external;
      _ownsStrokePathCache = false;
      return;
    }
    _strokePathCache = SceneStrokePathCacheV2();
    _ownsStrokePathCache = true;
  }

  void _syncStrokePathCache() {
    if (_ownsStrokePathCache) {
      _strokePathCache.clear();
    }
    _initStrokePathCache();
  }

  void _initPathMetricsCache() {
    final external = widget.pathMetricsCache;
    if (external != null) {
      _pathMetricsCache = external;
      _ownsPathMetricsCache = false;
      return;
    }
    _pathMetricsCache = ScenePathMetricsCacheV2();
    _ownsPathMetricsCache = true;
  }

  void _syncPathMetricsCache() {
    if (_ownsPathMetricsCache) {
      _pathMetricsCache.clear();
    }
    _initPathMetricsCache();
  }
}
