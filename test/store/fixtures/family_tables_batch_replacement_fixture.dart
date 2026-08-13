import 'dart:ui' show Color, Offset, Size, TextDirection;

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/store/family_tables.dart';

import 'family_tables_telemetry.dart';

const _supportedElementCount = 200000;
const _largeUntouchedRectCount = _supportedElementCount - 12;

void main() {
  test('batch replacement opens only its changed family maps', () {
    final base = FamilyTables(_supportedBaseElements());
    final work = FamilyTablesTelemetry();
    final replaced = FamilyTables.observeTelemetry(
      work.record,
      () => base.editSparse((editor) {
        editor.recordUpdateBatch();
        for (final element in _replacements) {
          editor.replaceElement(element);
        }

        return editor.freeze();
      }),
    );

    expect(work.batchReplacementCount, 1);
    _expectBasePlusReplacementRows(replaced);
    _expectPerFamilyReplacementWork(work);
    _expectPerFamilyMapIdentity(base, replaced);
  });
}

// This one hand-authored row oracle keeps every family result and lookup
// precedence together; splitting it would hide cross-family parity drift.
// ignore: halstead-volume
void _expectBasePlusReplacementRows(FamilyTables tables) {
  expect(tables.imageRows.keys, {'image-0', 'image-1'});
  expect(tables.imageRows['image-0']!.size, const Size(11, 11));
  expect(tables.imageRows['image-1']!.size, const Size(2, 2));

  expect(tables.vectorRows.keys, {
    'image-0',
    'vector-0',
    'vector-1',
    'vector-2',
  });
  expect(tables.vectorRows['image-0']!.size, const Size(99, 99));
  expect(tables.vectorRows['vector-0']!.size, const Size(20, 20));
  expect(tables.vectorRows['vector-2']!.size, const Size(3, 3));

  expect(tables.pathRows.keys, {'path-0', 'path-1', 'path-2', 'path-3'});
  expect(tables.pathRows['path-0']!.svgPathData, 'M4 4');
  expect(tables.pathRows['path-3']!.svgPathData, 'M3 3');

  expect(tables.textRows.keys, {'text-0'});
  expect(tables.strokeRows.keys, {'stroke-0'});
  expect(tables.lineRows.keys, {'line-0'});
  expect(tables.rectRows, hasLength(_largeUntouchedRectCount));
  expect(tables.rectRows['rect-0']!.size, const Size(1, 1));
  expect(
    tables.rectRows['rect-${_largeUntouchedRectCount - 1}']!.size,
    const Size(1, 1),
  );

  expect(
    (tables.elementByCanvasId(CanvasElementId('image-0')) as CanvasImageElement)
        .size,
    const Size(11, 11),
  );
  expect(
    (tables.elementByCanvasId(CanvasElementId('vector-0'))
            as CanvasVectorElement)
        .size,
    const Size(20, 20),
  );
  expect(
    (tables.elementByCanvasId(CanvasElementId('path-0')) as CanvasPathElement)
        .svgPathData,
    'M4 4',
  );
}

void _expectPerFamilyReplacementWork(FamilyTablesTelemetry work) {
  _expectFamilyWork(
    work,
    const _ExpectedFamilyWork(
      kind: CanvasElementKind.image,
      baseEntryCopies: 2,
      retainsBaseIdentity: false,
      openAndFreezeCount: 1,
    ),
  );
  _expectFamilyWork(
    work,
    const _ExpectedFamilyWork(
      kind: CanvasElementKind.vector,
      baseEntryCopies: 3,
      retainsBaseIdentity: false,
      openAndFreezeCount: 1,
    ),
  );
  _expectFamilyWork(
    work,
    const _ExpectedFamilyWork(
      kind: CanvasElementKind.path,
      baseEntryCopies: 4,
      retainsBaseIdentity: false,
      openAndFreezeCount: 1,
    ),
  );
  _expectUntouchedFamilyWork(work, CanvasElementKind.rect);
  _expectUntouchedFamilyWork(work, CanvasElementKind.text);
  _expectUntouchedFamilyWork(work, CanvasElementKind.stroke);
  _expectUntouchedFamilyWork(work, CanvasElementKind.line);
}

void _expectUntouchedFamilyWork(
  FamilyTablesTelemetry work,
  CanvasElementKind kind,
) {
  _expectFamilyWork(
    work,
    _ExpectedFamilyWork(
      kind: kind,
      baseEntryCopies: 0,
      retainsBaseIdentity: true,
      openAndFreezeCount: 0,
    ),
  );
}

void _expectFamilyWork(
  FamilyTablesTelemetry work,
  _ExpectedFamilyWork expected,
) {
  expect(work.transactionOpenCount(expected.kind), expected.openAndFreezeCount);
  expect(
    work.transactionBaseEntryCopyCount(expected.kind),
    expected.baseEntryCopies,
  );
  expect(
    work.transactionFreezeCount(expected.kind),
    expected.openAndFreezeCount,
  );
  expect(
    work.transactionFinalMapRetainsBaseIdentity(expected.kind),
    expected.retainsBaseIdentity,
  );
}

final class _ExpectedFamilyWork {
  const _ExpectedFamilyWork({
    required this.kind,
    required this.baseEntryCopies,
    required this.retainsBaseIdentity,
    required this.openAndFreezeCount,
  });

  final CanvasElementKind kind;
  final int baseEntryCopies;
  final bool retainsBaseIdentity;
  final int openAndFreezeCount;
}

void _expectPerFamilyMapIdentity(FamilyTables base, FamilyTables replaced) {
  expect(identical(replaced.imageRows, base.imageRows), isFalse);
  expect(identical(replaced.vectorRows, base.vectorRows), isFalse);
  expect(identical(replaced.pathRows, base.pathRows), isFalse);
  expect(identical(replaced.textRows, base.textRows), isTrue);
  expect(identical(replaced.strokeRows, base.strokeRows), isTrue);
  expect(identical(replaced.lineRows, base.lineRows), isTrue);
  expect(identical(replaced.rectRows, base.rectRows), isTrue);
}

Iterable<CanvasElement> _supportedBaseElements() sync* {
  yield _image('image-0', size: 1);
  yield _image('image-1', size: 2);
  yield _vector('vector-0', size: 1);
  yield _vector('vector-1', size: 2);
  yield _vector('vector-2', size: 3);
  yield _path('path-0', svgPathData: 'M0 0');
  yield _path('path-1', svgPathData: 'M1 1');
  yield _path('path-2', svgPathData: 'M2 2');
  yield _path('path-3', svgPathData: 'M3 3');
  yield _text('text-0');
  yield _stroke('stroke-0');
  yield _line('line-0');
  for (var index = 0; index < _largeUntouchedRectCount; index += 1) {
    yield _rect('rect-$index');
  }
}

final _replacements = [
  _image('image-0', size: 10),
  _image('image-0', size: 11),
  // The direct owner preserves its established image-before-vector lookup
  // precedence even if an internal batch carries the same id across families.
  _vector('image-0', size: 99),
  _vector('vector-0', size: 20),
  _path('path-0', svgPathData: 'M4 4'),
];

CanvasImageElement _image(String id, {required double size}) {
  return CanvasImageElement(
    id: CanvasElementId(id),
    resourceId: CanvasResourceId('$id-resource'),
    size: Size(size, size),
  );
}

CanvasVectorElement _vector(String id, {required double size}) {
  return CanvasVectorElement(
    id: CanvasElementId(id),
    resourceId: CanvasResourceId('$id-resource'),
    size: Size(size, size),
  );
}

CanvasPathElement _path(String id, {required String svgPathData}) {
  return CanvasPathElement(id: CanvasElementId(id), svgPathData: svgPathData);
}

CanvasTextElement _text(String id) {
  return CanvasTextElement(
    id: CanvasElementId(id),
    text: id,
    color: const Color(0xFF000000),
    textDirection: TextDirection.ltr,
  );
}

CanvasStrokeElement _stroke(String id) {
  return CanvasStrokeElement(
    id: CanvasElementId(id),
    points: const [Offset.zero],
    thickness: 1,
    color: const Color(0xFF000000),
  );
}

CanvasLineElement _line(String id) {
  return CanvasLineElement(
    id: CanvasElementId(id),
    start: Offset.zero,
    end: const Offset(1, 1),
    thickness: 1,
    color: const Color(0xFF000000),
  );
}

CanvasRectElement _rect(String id) {
  return CanvasRectElement(id: CanvasElementId(id), size: const Size(1, 1));
}
