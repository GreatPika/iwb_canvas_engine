import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart' hide NodeId;
import 'package:iwb_canvas_engine/src/contract/node_patch.dart';
import 'package:iwb_canvas_engine/src/contract/node_spec.dart';
import 'package:iwb_canvas_engine/src/contract/snapshot.dart';

void main() {
  test('validated spec fast-path helpers build typed boundary objects', () {
    final image = imageNodeSpecFromValidated(
      common: (
        id: 'img-1',
        transform: Transform2D.identity,
        opacity: 1,
        hitPadding: 0,
        isVisible: true,
        isSelectable: true,
        isLocked: false,
        isDeletable: true,
        isTransformable: true,
      ),
      fields: (
        imageId: 'asset:1',
        size: const Size(10, 20),
        naturalSize: const Size(30, 40),
      ),
    );
    final text = textNodeSpecFromValidated(
      common: (
        id: 'text-1',
        transform: Transform2D.identity,
        opacity: 1,
        hitPadding: 0,
        isVisible: true,
        isSelectable: true,
        isLocked: false,
        isDeletable: true,
        isTransformable: true,
      ),
      fields: (
        text: 'hello',
        fontSize: 18,
        color: const Color(0xFF000000),
        align: TextAlign.left,
        isBold: false,
        isItalic: false,
        isUnderline: false,
        fontFamily: 'Mono',
        maxWidth: 120,
        lineHeight: 1.4,
      ),
    );
    final stroke = strokeNodeSpecFromValidated(
      common: (
        id: 'stroke-1',
        transform: Transform2D.identity,
        opacity: 1,
        hitPadding: 0,
        isVisible: true,
        isSelectable: true,
        isLocked: false,
        isDeletable: true,
        isTransformable: true,
      ),
      fields: (
        points: const <Offset>[Offset(0, 0), Offset(1, 1)],
        thickness: 2,
        color: const Color(0xFF111111),
      ),
    );
    final line = lineNodeSpecFromValidated(
      common: (
        id: 'line-1',
        transform: Transform2D.identity,
        opacity: 1,
        hitPadding: 0,
        isVisible: true,
        isSelectable: true,
        isLocked: false,
        isDeletable: true,
        isTransformable: true,
      ),
      fields: (
        start: const Offset(0, 0),
        end: const Offset(5, 5),
        thickness: 3,
        color: const Color(0xFF222222),
      ),
    );
    final rect = rectNodeSpecFromValidated(
      common: (
        id: 'rect-1',
        transform: Transform2D.identity,
        opacity: 1,
        hitPadding: 0,
        isVisible: true,
        isSelectable: true,
        isLocked: false,
        isDeletable: true,
        isTransformable: true,
      ),
      fields: (
        size: const Size(8, 9),
        fillColor: null,
        strokeColor: null,
        strokeWidth: 1.5,
      ),
    );
    final path = pathNodeSpecFromValidated(
      common: (
        id: 'path-1',
        transform: Transform2D.identity,
        opacity: 1,
        hitPadding: 0,
        isVisible: true,
        isSelectable: true,
        isLocked: false,
        isDeletable: true,
        isTransformable: true,
      ),
      fields: (
        svgPathData: 'M0 0 L10 10',
        fillColor: null,
        strokeColor: null,
        strokeWidth: 2,
        fillRule: PathFillRule.evenOdd,
      ),
    );

    expect(image.imageId, 'asset:1');
    expect(text.fontFamily, 'Mono');
    expect(stroke.points, const <Offset>[Offset(0, 0), Offset(1, 1)]);
    expect(line.end, const Offset(5, 5));
    expect(rect.strokeWidth, 1.5);
    expect(path.fillRule, PathFillRule.evenOdd);
  });

  test('validated patch fast-path helpers build typed boundary objects', () {
    final common = commonNodePatchFromValidated(
      fields: (
        transform: PatchField<Transform2D>.value(Transform2D.identity),
        opacity: PatchField<double>.value(0.5),
        hitPadding: PatchField<double>.value(2),
        isVisible: PatchField<bool>.value(false),
        isSelectable: const PatchField<bool>.absent(),
        isLocked: const PatchField<bool>.absent(),
        isDeletable: const PatchField<bool>.absent(),
        isTransformable: const PatchField<bool>.absent(),
      ),
    );
    final image = imageNodePatchFromValidated(
      id: 'img-1',
      common: common,
      fields: (
        imageId: PatchField<String>.value('asset:2'),
        size: PatchField<Size>.value(const Size(4, 5)),
        naturalSize: PatchField<Size?>.value(null),
      ),
    );
    final text = textNodePatchFromValidated(
      id: 'text-1',
      fields: (
        text: PatchField<String>.value('updated'),
        fontSize: const PatchField<double>.absent(),
        color: const PatchField<Color>.absent(),
        align: const PatchField<TextAlign>.absent(),
        isBold: const PatchField<bool>.absent(),
        isItalic: const PatchField<bool>.absent(),
        isUnderline: const PatchField<bool>.absent(),
        fontFamily: PatchField<String?>.value('Mono'),
        maxWidth: const PatchField<double?>.absent(),
        lineHeight: const PatchField<double?>.absent(),
      ),
    );
    final stroke = strokeNodePatchFromValidated(
      id: 'stroke-1',
      fields: (
        points: PatchField<List<Offset>>.value(const <Offset>[
          Offset(1, 2),
          Offset(3, 4),
        ]),
        thickness: const PatchField<double>.absent(),
        color: const PatchField<Color>.absent(),
      ),
    );
    final line = lineNodePatchFromValidated(
      id: 'line-1',
      fields: (
        start: PatchField<Offset>.value(const Offset(2, 0)),
        end: const PatchField<Offset>.absent(),
        thickness: const PatchField<double>.absent(),
        color: const PatchField<Color>.absent(),
      ),
    );
    final rect = rectNodePatchFromValidated(
      id: 'rect-1',
      fields: (
        size: const PatchField<Size>.absent(),
        fillColor: const PatchField<Color?>.absent(),
        strokeColor: const PatchField<Color?>.absent(),
        strokeWidth: PatchField<double>.value(2),
      ),
    );
    final path = pathNodePatchFromValidated(
      id: 'path-1',
      fields: (
        svgPathData: const PatchField<String>.absent(),
        fillColor: const PatchField<Color?>.absent(),
        strokeColor: const PatchField<Color?>.absent(),
        strokeWidth: const PatchField<double>.absent(),
        fillRule: PatchField<PathFillRule>.value(PathFillRule.evenOdd),
      ),
    );

    expect(image.common.opacity.value, 0.5);
    expect(image.naturalSize.valueOrNull, isNull);
    expect(text.text.value, 'updated');
    expect(stroke.points.value, const <Offset>[Offset(1, 2), Offset(3, 4)]);
    expect(line.start.value, const Offset(2, 0));
    expect(rect.strokeWidth.value, 2);
    expect(path.fillRule.value, PathFillRule.evenOdd);
  });

  test('validated image patch fast-path builds default common patch', () {
    final image = imageNodePatchFromValidated(id: 'img-default-common');

    expect(image.common.transform.isAbsent, isTrue);
    expect(image.common.opacity.isAbsent, isTrue);
    expect(image.common.hitPadding.isAbsent, isTrue);
    expect(image.common.isVisible.isAbsent, isTrue);
  });

  test(
    'validated spec and snapshot fast-paths snapshot stroke point ownership',
    () {
      final specPoints = <Offset>[const Offset(1, 2), const Offset(3, 4)];
      final snapshotPoints = <Offset>[const Offset(5, 6), const Offset(7, 8)];

      final spec = strokeNodeSpecFromValidated(
        common: (
          id: 'stroke-spec-owned',
          transform: Transform2D.identity,
          opacity: 1,
          hitPadding: 0,
          isVisible: true,
          isSelectable: true,
          isLocked: false,
          isDeletable: true,
          isTransformable: true,
        ),
        fields: (
          points: specPoints,
          thickness: 2,
          color: const Color(0xFF111111),
        ),
      );
      final snapshot = strokeNodeSnapshotFromValidated(
        id: 'stroke-snapshot-owned',
        points: snapshotPoints,
        thickness: 3,
        color: const Color(0xFF222222),
      );

      specPoints[1] = const Offset(30, 40);
      snapshotPoints[1] = const Offset(70, 80);

      expect(spec.points, const <Offset>[Offset(1, 2), Offset(3, 4)]);
      expect(snapshot.points, const <Offset>[Offset(5, 6), Offset(7, 8)]);
      expect(() => spec.points.add(const Offset(9, 9)), throwsUnsupportedError);
      expect(
        () => snapshot.points.add(const Offset(10, 10)),
        throwsUnsupportedError,
      );
    },
  );

  test(
    'validated patch fast-path snapshots stroke point payload ownership',
    () {
      final points = <Offset>[const Offset(1, 2), const Offset(3, 4)];

      final patch = strokeNodePatchFromValidated(
        id: 'stroke-owned',
        fields: (
          points: PatchField<List<Offset>>.value(points),
          thickness: const PatchField<double>.absent(),
          color: const PatchField<Color>.absent(),
        ),
      );

      points[1] = const Offset(30, 40);

      expect(patch.points.value, const <Offset>[Offset(1, 2), Offset(3, 4)]);
      expect(
        () => patch.points.value.add(const Offset(5, 6)),
        throwsUnsupportedError,
      );
    },
  );
}
