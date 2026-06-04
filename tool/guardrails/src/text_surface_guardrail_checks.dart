import 'guardrail_violation.dart';
import 'repository_paths.dart';

const textSingleMeasuredLayoutSourceGuardrailId =
    'text.single_measured_layout_source';
const textNoOverlayTextPainterMeasurementGuardrailId =
    'text.no_overlay_textpainter_measurement';
const surfaceEditableTextSurfaceOnlyGuardrailId =
    'surface.editable_text_surface_only';
const _measuredLayoutSourcePath =
    'lib/src/frame/frame_text_layout_measurer.dart';
final _textPainterConstructorPattern = RegExp(
  r'\bTextPainter\s*(?:\.new)?\s*\(',
);

Future<List<GuardrailViolation>> checkTextSingleMeasuredLayoutSource() {
  return Future.value(
    checkTextSingleMeasuredLayoutSourceSources(_textMeasurementSources()),
  );
}

Future<List<GuardrailViolation>> checkNoOverlayTextPainterMeasurement() {
  return Future.value(
    checkNoOverlayTextPainterMeasurementSources(_overlaySources()),
  );
}

Future<List<GuardrailViolation>> checkEditableTextSurfaceOnly() {
  return Future.value(
    checkEditableTextSurfaceOnlySources(_productionAndExampleSources()),
  );
}

List<GuardrailViolation> checkTextSingleMeasuredLayoutSourceSources(
  Map<String, String> sources,
) {
  final violations = <GuardrailViolation>[];
  final measurer = sources[_measuredLayoutSourcePath];
  if (measurer == null ||
      !measurer.contains('implements MeasuredTextLayoutPort') ||
      !_containsTextPainterConstructor(measurer) ||
      !measurer.contains('_measuredLayoutFor')) {
    violations.add(
      const GuardrailViolation(
        guardrailId: textSingleMeasuredLayoutSourceGuardrailId,
        path: _measuredLayoutSourcePath,
        message:
            'frame text layout measurer must remain the measured layout source',
      ),
    );
  }

  for (final entry in sources.entries) {
    if (_containsUnauthorizedTextPainter(entry.key, entry.value)) {
      violations.add(
        GuardrailViolation(
          guardrailId: textSingleMeasuredLayoutSourceGuardrailId,
          path: entry.key,
          message:
              'only frame_text_layout_measurer may construct TextPainter for text measurement',
        ),
      );
    }
    if (_isTextGeometryConsumerSource(entry.key) &&
        _containsFormulaTextBounds(entry.value)) {
      violations.add(
        GuardrailViolation(
          guardrailId: textSingleMeasuredLayoutSourceGuardrailId,
          path: entry.key,
          message:
              'text geometry must consume measured text layout, not formula bounds',
        ),
      );
    }
  }

  return violations;
}

List<GuardrailViolation> checkNoOverlayTextPainterMeasurementSources(
  Map<String, String> sources,
) {
  return [
    for (final entry in sources.entries)
      if (_containsTextPainterConstructor(entry.value))
        GuardrailViolation(
          guardrailId: textNoOverlayTextPainterMeasurementGuardrailId,
          path: entry.key,
          message:
              'surface/example overlays must not duplicate TextPainter measurement',
        ),
  ];
}

List<GuardrailViolation> checkEditableTextSurfaceOnlySources(
  Map<String, String> sources,
) {
  return [
    for (final entry in sources.entries)
      if (_isForbiddenEditableTextOwner(entry.key) &&
          entry.value.contains('EditableText'))
        GuardrailViolation(
          guardrailId: surfaceEditableTextSurfaceOnlyGuardrailId,
          path: entry.key,
          message:
              'EditableText production use is allowed only under surface or example owners',
        ),
  ];
}

bool _containsFormulaTextBounds(String source) {
  return _hasTextGeometryMarker(source) && _hasFormulaToken(source);
}

bool _hasTextGeometryMarker(String source) {
  return _containsAny(source, const [
    'CanvasElementKind.text',
    'CanvasTextEditGeometry',
    '_textBounds',
    '_textPaintBounds',
    '_textHitBounds',
    '_textSelectionBounds',
    '_textEditBounds',
    '_geometryFor',
    'editBoundsWorld',
    'editBoundsLocal',
  ]);
}

bool _hasFormulaToken(String source) {
  return _containsTextPainterConstructor(source) ||
      source.contains('Rect.fromLTWH') &&
          _containsAny(source, const [
            '.length',
            'fontSize',
            'maxWidth',
            'lineHeight',
            'liveText',
          ]);
}

bool _isForbiddenEditableTextOwner(String path) {
  return path.startsWith('lib/src/') && !path.startsWith('lib/src/surface/');
}

bool _containsUnauthorizedTextPainter(String path, String source) {
  return path != _measuredLayoutSourcePath &&
      _containsTextPainterConstructor(source);
}

bool _containsTextPainterConstructor(String source) {
  return _textPainterConstructorPattern.hasMatch(source);
}

bool _isTextGeometryConsumerSource(String path) {
  return path.startsWith('lib/src/geometry/') ||
      path.startsWith('lib/src/runtime/');
}

bool _containsAny(String source, Iterable<String> needles) {
  return needles.any(source.contains);
}

Map<String, String> _textMeasurementSources() {
  return {
    for (final file in [
      ...dartFilesUnder('lib/src/frame'),
      ...dartFilesUnder('lib/src/geometry'),
      ...dartFilesUnder('lib/src/runtime'),
    ])
      relativePath(file): file.readAsStringSync(),
  };
}

Map<String, String> _overlaySources() {
  return {
    for (final directory in const ['lib/src/surface', 'example/lib'])
      for (final file in dartFilesUnder(directory))
        relativePath(file): file.readAsStringSync(),
  };
}

Map<String, String> _productionAndExampleSources() {
  return {
    for (final directory in const ['lib/src', 'example/lib'])
      for (final file in dartFilesUnder(directory))
        relativePath(file): file.readAsStringSync(),
  };
}
