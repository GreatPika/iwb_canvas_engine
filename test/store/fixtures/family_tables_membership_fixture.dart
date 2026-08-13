import 'dart:ui' show Color, Offset, Size, TextAlign, TextDirection;

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/contracts/internal/schema_v1_import_events.dart';
import 'package:iwb_canvas_engine/src/store/family_tables.dart';

import 'family_tables_telemetry.dart';

void main() {
  _testEmptyAndSingleFamilySnapshots();
  _testAllFamilyAndMutationSnapshots();
  _testSchemaV1ImportSnapshot();
  _testSupportedSizeSnapshot();
}

void _testEmptyAndSingleFamilySnapshots() {
  test(
    'empty and single-family membership matches map keys without unions',
    () {
      final empty = _observeMembershipOperation(
        () => const FamilyTables.empty(),
      );
      _expectMembershipSnapshot(empty, const {});
      expect(empty.contains(CanvasElementId('absent')), isFalse);
      final single = _observeMembershipOperation(
        () => FamilyTables([_rect('single')]),
      );
      _expectMembershipSnapshot(single, const {
        CanvasElementKind.rect: {'single'},
      });
    },
  );
}

// The one ordered witness keeps each immutable mutation and its exact
// seven-family membership oracle visible without hidden fixture state.
// ignore: halstead-volume
void _testAllFamilyAndMutationSnapshots() {
  test(
    'construction and mutation membership matches authoritative map keys',
    () {
      final all = _observeMembershipOperation(
        () => FamilyTables(_allFamilyElements()),
      );
      _expectMembershipSnapshot(all, _allFamilyIds);

      final added = _observeMembershipOperation(
        () => all.addElement(_rect('added')),
      );
      _expectMembershipSnapshot(added, {
        ..._allFamilyIds,
        CanvasElementKind.rect: {'rect', 'added'},
      });

      final removed = _observeMembershipOperation(
        () => added.removeElement(CanvasElementId('path')),
      );
      _expectMembershipSnapshot(removed, {
        ..._allFamilyIds,
        CanvasElementKind.path: const {},
        CanvasElementKind.rect: {'rect', 'added'},
      });

      final replaced = _observeMembershipOperation(
        () => removed.editSparse((editor) {
          editor.recordUpdateBatch();
          editor.replaceElement(_rect('rect', size: 2));

          return editor.freeze();
        }),
      );
      _expectMembershipSnapshot(replaced, {
        ..._allFamilyIds,
        CanvasElementKind.path: const {},
        CanvasElementKind.rect: {'rect', 'added'},
      });

      final cleared = _observeMembershipOperation(replaced.clearElements);
      _expectMembershipSnapshot(cleared, const {});
      expect(replaced.contains(CanvasElementId('added')), isTrue);
    },
  );
}

void _testSchemaV1ImportSnapshot() {
  test('Schema V1 import membership matches authoritative map keys', () {
    final imported = _observeMembershipOperation(() {
      final builder = FamilyTablesSchemaV1ImportBuilder();
      for (final event in _allFamilyImportEvents()) {
        builder.add(event);
      }

      return builder.consume();
    });
    _expectMembershipSnapshot(imported, _allFamilyIds);
    expect(imported.contains(CanvasElementId('image')), isTrue);
  });
}

// The supported-size witness keeps its exact seven-family map checks and
// direct query budget together, so the document-scale failure is legible.
// ignore: halstead-volume
void _testSupportedSizeSnapshot() {
  test('supported-size membership stays direct and exact', () {
    const supportedElementCount = 200000;
    final tables = _observeMembershipOperation(
      () => FamilyTables(_supportedSizeElements(supportedElementCount)),
    );

    expect(tables.imageRows.keys, {'image'});
    expect(tables.vectorRows.keys, {'vector'});
    expect(tables.pathRows.keys, {'path'});
    expect(tables.textRows.keys, {'text'});
    expect(tables.strokeRows.keys, {'stroke'});
    expect(tables.lineRows.keys, {'line'});
    expect(tables.rectRows, hasLength(supportedElementCount - 6));
    for (var index = 0; index < supportedElementCount - 7; index += 1) {
      expect(tables.rectRows, contains('supported-rect-$index'));
    }
    expect(tables.rectRows, contains('rect'));

    _expectDirectMembership(tables, CanvasElementId('rect'), expectedProbes: 7);
    _expectDirectMembership(
      tables,
      CanvasElementId('supported-rect-${supportedElementCount - 8}'),
      expectedProbes: 7,
    );
    _expectDirectMembership(
      tables,
      CanvasElementId('supported-absent'),
      expectedContains: false,
      expectedProbes: 7,
    );
  });
}

void _expectMembershipSnapshot(
  FamilyTables tables,
  Map<CanvasElementKind, Set<String>> expectedIdsByFamily,
) {
  _expectFamilyMapKeys(tables, expectedIdsByFamily);
  for (final entry in expectedIdsByFamily.entries) {
    for (final id in entry.value) {
      _expectDirectMembership(
        tables,
        CanvasElementId(id),
        expectedProbes: _probeCountByFamily[entry.key]!,
      );
    }
  }
  _expectDirectMembership(
    tables,
    CanvasElementId('absent'),
    expectedContains: false,
    expectedProbes: 7,
  );
}

void _expectFamilyMapKeys(
  FamilyTables tables,
  Map<CanvasElementKind, Set<String>> expectedIdsByFamily,
) {
  expect(
    tables.imageRows.keys,
    _expectedIds(expectedIdsByFamily, CanvasElementKind.image),
  );
  expect(
    tables.vectorRows.keys,
    _expectedIds(expectedIdsByFamily, CanvasElementKind.vector),
  );
  expect(
    tables.pathRows.keys,
    _expectedIds(expectedIdsByFamily, CanvasElementKind.path),
  );
  expect(
    tables.textRows.keys,
    _expectedIds(expectedIdsByFamily, CanvasElementKind.text),
  );
  expect(
    tables.strokeRows.keys,
    _expectedIds(expectedIdsByFamily, CanvasElementKind.stroke),
  );
  expect(
    tables.lineRows.keys,
    _expectedIds(expectedIdsByFamily, CanvasElementKind.line),
  );
  expect(
    tables.rectRows.keys,
    _expectedIds(expectedIdsByFamily, CanvasElementKind.rect),
  );
}

Set<String> _expectedIds(
  Map<CanvasElementKind, Set<String>> expectedIdsByFamily,
  CanvasElementKind family,
) {
  return expectedIdsByFamily[family] ?? const {};
}

void _expectDirectMembership(
  FamilyTables tables,
  CanvasElementId id, {
  required int expectedProbes,
  bool expectedContains = true,
}) {
  final work = FamilyTablesTelemetry();
  final contains = FamilyTables.observeTelemetry(
    work.record,
    () => tables.contains(id),
  );

  expect(contains, expectedContains);
  expect(work.mapProbeCount, expectedProbes);
  _expectNoForbiddenMembershipWork(work);
}

T _observeMembershipOperation<T>(T Function() operation) {
  final work = FamilyTablesTelemetry();
  final result = FamilyTables.observeTelemetry(work.record, operation);

  _expectNoForbiddenMembershipWork(work);
  return result;
}

void _expectNoForbiddenMembershipWork(FamilyTablesTelemetry work) {
  expect(work.membershipUnionAllocationCount, 0);
  expect(work.retainedMembershipCopyAllocationCount, 0);
  expect(work.membershipKeyCopyCount, 0);
}

List<CanvasElement> _allFamilyElements() {
  return [
    CanvasImageElement(
      id: CanvasElementId('image'),
      resourceId: CanvasResourceId('image-resource'),
      size: const Size(1, 1),
    ),
    CanvasVectorElement(
      id: CanvasElementId('vector'),
      resourceId: CanvasResourceId('vector-resource'),
      size: const Size(1, 1),
    ),
    CanvasPathElement(id: CanvasElementId('path'), svgPathData: 'M0 0'),
    CanvasTextElement(
      id: CanvasElementId('text'),
      text: 'text',
      color: const Color(0xFF000000),
      textDirection: TextDirection.ltr,
    ),
    CanvasStrokeElement(
      id: CanvasElementId('stroke'),
      points: const [Offset.zero],
      thickness: 1,
      color: const Color(0xFF000000),
    ),
    CanvasLineElement(
      id: CanvasElementId('line'),
      start: Offset.zero,
      end: const Offset(1, 1),
      thickness: 1,
      color: const Color(0xFF000000),
    ),
    CanvasRectElement(id: CanvasElementId('rect'), size: const Size(1, 1)),
  ];
}

Iterable<CanvasElement> _supportedSizeElements(int count) sync* {
  yield* _allFamilyElements();
  for (var index = 0; index < count - 7; index += 1) {
    yield _rect('supported-rect-$index');
  }
}

CanvasRectElement _rect(String id, {double size = 1}) {
  return CanvasRectElement(id: CanvasElementId(id), size: Size(size, size));
}

// One literal keeps every schema event variant aligned with the independent
// seven-family oracle; splitting it would hide a missing import family.
// ignore: halstead-volume, source-lines-of-code
Iterable<SchemaV1ElementImportEvent> _allFamilyImportEvents() {
  final common = <CanvasElementKind, SchemaV1ElementCommonImport>{
    for (final kind in CanvasElementKind.values)
      kind: SchemaV1ElementCommonImport(
        id: CanvasElementId(kind.name),
        kind: kind,
        revision: 0,
        transform: CanvasTransform.identity,
        opacity: 1,
        hitPadding: 0,
        isVisible: true,
        isSelectable: true,
        isLocked: false,
        isDeletable: true,
        isTransformable: true,
        metadata: const CanvasMetadata.empty(),
      ),
  };

  return [
    SchemaV1ImageElementImportEvent(
      common: common[CanvasElementKind.image]!,
      resourceId: CanvasResourceId('image-resource'),
      size: const Size(1, 1),
      naturalSize: null,
    ),
    SchemaV1VectorElementImportEvent(
      common: common[CanvasElementKind.vector]!,
      resourceId: CanvasResourceId('vector-resource'),
      size: const Size(1, 1),
      naturalSize: null,
    ),
    SchemaV1PathElementImportEvent(
      common: common[CanvasElementKind.path]!,
      svgPathData: 'M0 0',
      fillColor: null,
      strokeColor: null,
      strokeWidth: 0,
      fillRule: CanvasPathFillRule.nonZero,
    ),
    SchemaV1TextElementImportEvent(
      common: common[CanvasElementKind.text]!,
      text: 'text',
      fontSize: 24,
      color: const Color(0xFF000000),
      align: TextAlign.left,
      textDirection: TextDirection.ltr,
      isBold: false,
      isItalic: false,
      isUnderline: false,
      fontFamily: null,
      maxWidth: null,
      lineHeight: null,
    ),
    SchemaV1StrokeElementImportEvent(
      common: common[CanvasElementKind.stroke]!,
      points: const [Offset.zero],
      thickness: 1,
      color: const Color(0xFF000000),
    ),
    SchemaV1LineElementImportEvent(
      common: common[CanvasElementKind.line]!,
      start: Offset.zero,
      end: const Offset(1, 1),
      thickness: 1,
      color: const Color(0xFF000000),
    ),
    SchemaV1RectElementImportEvent(
      common: common[CanvasElementKind.rect]!,
      size: const Size(1, 1),
      fillColor: null,
      strokeColor: null,
      strokeWidth: 0,
    ),
  ];
}

const _allFamilyIds = {
  CanvasElementKind.image: {'image'},
  CanvasElementKind.vector: {'vector'},
  CanvasElementKind.path: {'path'},
  CanvasElementKind.text: {'text'},
  CanvasElementKind.stroke: {'stroke'},
  CanvasElementKind.line: {'line'},
  CanvasElementKind.rect: {'rect'},
};

const _probeCountByFamily = {
  CanvasElementKind.image: 1,
  CanvasElementKind.vector: 2,
  CanvasElementKind.path: 3,
  CanvasElementKind.text: 4,
  CanvasElementKind.stroke: 5,
  CanvasElementKind.line: 6,
  CanvasElementKind.rect: 7,
};
