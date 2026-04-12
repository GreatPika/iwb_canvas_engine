import 'dart:developer' as developer;
import 'dart:ui';

import '../contract/path_fill_rule.dart';
import '../contract/runtime_node_value_validation.dart';
import 'geometry.dart';
import 'local_bounds_policy.dart';
import 'scene_node.dart';

/// SVG-path based vector node.
class PathNode extends SceneNode {
  /// When enabled, `buildLocalPath()` records failure reasons and emits
  /// diagnostics logs even in release builds.
  ///
  /// By default, failures are silent in release builds and are only recorded
  /// when assertions are enabled (debug/profile).
  // ignore: avoid-global-state, intentional process-wide diagnostics toggle
  static bool enableBuildLocalPathDiagnostics = false;

  PathNode({
    required super.id,
    required String svgPathData,
    this.fillColor,
    this.strokeColor,
    double strokeWidth = 1,
    PathFillRule fillRule = PathFillRule.nonZero,
    super.instanceRevision,
    super.hitPadding,
    super.transform,
    super.opacity,
    super.isVisible,
    super.isSelectable,
    super.isLocked,
    super.isDeletable,
    super.isTransformable,
  }) : _strokeWidth = validateNonNegativeFiniteDoubleValue(
         strokeWidth,
         name: 'strokeWidth',
       ),
       _svgPathData = validateSvgPathDataValue(
         svgPathData,
         name: 'svgPathData',
       ),
       _fillRule = fillRule,
       super(type: NodeType.path);

  Color? fillColor;
  Color? strokeColor;
  double get strokeWidth => _strokeWidth;
  late double _strokeWidth;
  set strokeWidth(double value) {
    _strokeWidth = validateNonNegativeFiniteDoubleValue(
      value,
      name: 'strokeWidth',
    );
  }

  String _svgPathData;
  PathFillRule _fillRule;

  late final _PathNodeLocalPathCacheOwner _localPathCache =
      _PathNodeLocalPathCacheOwner();

  /// Debug-only failure reason for the last `buildLocalPath()` attempt.
  ///
  /// This value is populated when assertions are enabled, or when
  /// [enableBuildLocalPathDiagnostics] is true.
  String? get debugLastBuildLocalPathFailureReason =>
      _localPathCache.debugLastBuildLocalPathFailureReason;

  /// Debug-only exception captured from the last `buildLocalPath()` attempt.
  ///
  /// This value is populated when assertions are enabled, or when
  /// [enableBuildLocalPathDiagnostics] is true.
  Object? get debugLastBuildLocalPathException =>
      _localPathCache.debugLastBuildLocalPathException;

  /// Debug-only stack trace captured from the last `buildLocalPath()` attempt.
  ///
  /// This value is populated when assertions are enabled, or when
  /// [enableBuildLocalPathDiagnostics] is true.
  StackTrace? get debugLastBuildLocalPathStackTrace =>
      _localPathCache.debugLastBuildLocalPathStackTrace;

  String get svgPathData => _svgPathData;
  set svgPathData(String value) {
    final validated = validateSvgPathDataValue(value, name: 'svgPathData');
    if (_svgPathData == validated) return;
    _svgPathData = validated;
    _localPathCache.invalidate();
  }

  PathFillRule get fillRule => _fillRule;
  set fillRule(PathFillRule value) {
    if (_fillRule == value) return;
    _fillRule = value;
    _localPathCache.invalidate();
  }

  /// Builds a local path centered around (0,0), or returns null if invalid.
  ///
  /// The returned path is in the node's local coordinate space. The caller is
  /// responsible for applying [transform].
  ///
  /// This method returns a defensive copy of the cached geometry so external
  /// callers cannot accidentally mutate internal cache state.
  Path? buildLocalPath() => _localPathCache.buildLocalPath(
    _PathNodeCacheRequest(
      svgPathData: svgPathData,
      fillRule: fillRule,
      diagnosticsEnabled: enableBuildLocalPathDiagnostics,
      assertionsEnabled: _assertionsEnabled,
    ),
  );

  @override
  Rect get localBounds => _localPathCache.resolveLocalBounds(
    request: _PathNodeCacheRequest(
      svgPathData: svgPathData,
      fillRule: fillRule,
      diagnosticsEnabled: enableBuildLocalPathDiagnostics,
      assertionsEnabled: _assertionsEnabled,
    ),
    strokeColor: strokeColor,
    strokeWidth: strokeWidth,
  );

  static final bool _assertionsEnabled = (() {
    var enabled = false;
    assert(() {
      enabled = true;
      return true;
    }());
    return enabled;
  })();
}

final class _PathNodeLocalPathCacheOwner {
  Path? _cachedLocalPath;
  Rect? _cachedLocalPathBounds;
  String? _cachedSvgPathData;
  PathFillRule? _cachedFillRule;
  bool _cacheResolved = false;

  String? _debugLastBuildLocalPathFailureReason;
  Object? _debugLastBuildLocalPathException;
  StackTrace? _debugLastBuildLocalPathStackTrace;

  String? get debugLastBuildLocalPathFailureReason =>
      _debugLastBuildLocalPathFailureReason;
  Object? get debugLastBuildLocalPathException =>
      _debugLastBuildLocalPathException;
  StackTrace? get debugLastBuildLocalPathStackTrace =>
      _debugLastBuildLocalPathStackTrace;

  Path? buildLocalPath(_PathNodeCacheRequest request) {
    final cached = _resolve(request);
    if (cached == null) return null;
    return Path.from(cached);
  }

  Rect resolveLocalBounds({
    required _PathNodeCacheRequest request,
    required Color? strokeColor,
    required double strokeWidth,
  }) {
    _resolve(request);
    final bounds = _cachedLocalPathBounds;
    if (bounds == null) return Rect.zero;
    return strokeAwareLocalBounds(
      baseBounds: bounds,
      strokeColor: strokeColor,
      strokeWidth: strokeWidth,
    );
  }

  void invalidate() {
    _cacheResolved = false;
    _cachedLocalPath = null;
    _cachedLocalPathBounds = null;
    _cachedSvgPathData = null;
    _cachedFillRule = null;
  }

  Path? _resolve(_PathNodeCacheRequest request) {
    if (_hasMatchingResolvedCache(request)) return _cachedLocalPath;
    if (request.hasEmptySvgPathData) {
      _rememberFailure(request, reason: 'empty-svg-path-data');
      return null;
    }
    return _resolveParsedPath(request);
  }

  Path? _resolveParsedPath(_PathNodeCacheRequest request) {
    try {
      final path = parseSvgPathDataOrThrow(request.svgPathData);
      if (!hasDrawablePathMetric(path)) {
        _rememberFailure(request, reason: 'svg-path-has-no-nonzero-length');
        return null;
      }
      return _rememberSuccess(request, path);
    } catch (e, st) {
      _rememberFailure(
        request,
        reason: 'exception-while-building-local-path',
        exception: e,
        stackTrace: st,
      );
      return null;
    }
  }

  bool _hasMatchingResolvedCache(_PathNodeCacheRequest request) {
    return _cacheResolved &&
        _cachedSvgPathData == request.svgPathData &&
        _cachedFillRule == request.fillRule;
  }

  Path _rememberSuccess(_PathNodeCacheRequest request, Path path) {
    final geometry = centerPathGeometry(path, fillType: request.fillType);
    _cacheResolved = true;
    _cachedSvgPathData = request.svgPathData;
    _cachedFillRule = request.fillRule;
    _cachedLocalPath = geometry.localPath;
    _cachedLocalPathBounds = geometry.localBounds;
    _clearRecordedFailure(request);
    return geometry.localPath;
  }

  void _rememberFailure(
    _PathNodeCacheRequest request, {
    required String reason,
    Object? exception,
    StackTrace? stackTrace,
  }) {
    _cacheResolved = true;
    _cachedSvgPathData = request.svgPathData;
    _cachedFillRule = request.fillRule;
    _cachedLocalPath = null;
    _cachedLocalPathBounds = null;
    _recordBuildLocalPathFailure(
      request,
      reason: reason,
      exception: exception,
      stackTrace: stackTrace,
    );
  }

  void _recordBuildLocalPathFailure(
    _PathNodeCacheRequest request, {
    required String reason,
    Object? exception,
    StackTrace? stackTrace,
  }) {
    if (request.diagnosticsEnabled) {
      _debugLastBuildLocalPathFailureReason = reason;
      _debugLastBuildLocalPathException = exception;
      _debugLastBuildLocalPathStackTrace = stackTrace;
      developer.log(
        reason,
        name: 'iwb_canvas_engine.PathNode.buildLocalPath',
        error: exception,
        stackTrace: stackTrace,
      );
      return;
    }
    if (!request.assertionsEnabled) return;
    _debugLastBuildLocalPathFailureReason = reason;
    _debugLastBuildLocalPathException = exception;
    _debugLastBuildLocalPathStackTrace = stackTrace;
  }

  void _clearRecordedFailure(_PathNodeCacheRequest request) {
    if (!request.diagnosticsEnabled && !request.assertionsEnabled) return;
    _debugLastBuildLocalPathFailureReason = null;
    _debugLastBuildLocalPathException = null;
    _debugLastBuildLocalPathStackTrace = null;
  }
}

final class _PathNodeCacheRequest {
  const _PathNodeCacheRequest({
    required this.svgPathData,
    required this.fillRule,
    required this.diagnosticsEnabled,
    required this.assertionsEnabled,
  });

  final String svgPathData;
  final PathFillRule fillRule;
  final bool diagnosticsEnabled;
  final bool assertionsEnabled;

  bool get hasEmptySvgPathData => svgPathData.trim().isEmpty;
  PathFillType get fillType => fillRule == PathFillRule.evenOdd
      ? PathFillType.evenOdd
      : PathFillType.nonZero;
}
