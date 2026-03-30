import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart' hide NodeId;
import 'package:iwb_canvas_engine/src/contract/internal/node_patch_fast_path.dart';
import 'package:iwb_canvas_engine/src/contract/internal/node_spec_fast_path.dart';
import 'package:iwb_canvas_engine/src/contract/internal/snapshot_fast_path.dart';

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

  test(
    'snapshot fast-path compatibility owners preserve defaults and explicit internal owners',
    () {
      final backgroundLayer = backgroundLayerSnapshotFromValidated(
        nodes: <NodeSnapshot>[
          RectNodeSnapshot(id: 'bg-rect', size: Size(2, 3)),
        ],
      );
      final palette = scenePaletteSnapshotFromValidated(
        penColors: <Color>[const Color(0xFF123456)],
        backgroundColors: <Color>[const Color(0xFFEEEEEE)],
        gridSizes: <double>[24],
      );
      final scene = sceneSnapshotFromValidated(
        backgroundLayer: backgroundLayer,
        camera: cameraSnapshotFromValidated(offset: const Offset(4, 5)),
        background: backgroundSnapshotFromValidated(
          color: const Color(0xFFFAFAFA),
          grid: gridSnapshotFromValidated(
            isEnabled: true,
            cellSize: 24,
            color: const Color(0xFF010203),
          ),
        ),
        palette: palette,
      );
      final image = imageNodeSnapshotFromValidated(
        common: nodeSnapshotCommonFieldsFromValidated(id: 'img-defaults'),
        fields: (
          imageId: 'asset:defaults',
          size: const Size(10, 20),
          naturalSize: null,
        ),
      );

      expect(
        scene.internalBacking.backgroundLayer,
        same(backgroundLayer.internalBacking),
      );
      expect(scene.backgroundLayer.nodes.single.id, 'bg-rect');
      expect(scene.camera.offset, const Offset(4, 5));
      expect(scene.background.color, const Color(0xFFFAFAFA));
      expect(scene.background.grid.isEnabled, isTrue);
      expect(scene.palette.penColors, const <Color>[Color(0xFF123456)]);
      expect(image.naturalSize, isNull);
      expect(image.instanceRevision, 0);
      expect(image.transform, Transform2D.identity);
      expect(image.isVisible, isTrue);
      expect(image.isSelectable, isTrue);
      expect(image.isLocked, isFalse);
      expect(image.isDeletable, isTrue);
      expect(image.isTransformable, isTrue);
    },
  );

  test(
    'validated snapshot fast-path node helpers preserve shared common defaults across families',
    () {
      final nodes = <NodeSnapshot>[
        imageNodeSnapshotFromValidated(
          common: nodeSnapshotCommonFieldsFromValidated(
            id: 'img-shared-defaults',
          ),
          fields: (
            imageId: 'asset:shared-defaults',
            size: const Size(10, 20),
            naturalSize: null,
          ),
        ),
        textNodeSnapshotFromValidated(
          common: nodeSnapshotCommonFieldsFromValidated(
            id: 'text-shared-defaults',
          ),
          fields: (
            text: 'hello',
            size: const Size(30, 40),
            fontSize: 24,
            color: const Color(0xFF000000),
            align: TextAlign.left,
            isBold: false,
            isItalic: false,
            isUnderline: false,
            fontFamily: null,
            maxWidth: null,
            lineHeight: null,
          ),
        ),
        strokeNodeSnapshotFromValidated(
          common: nodeSnapshotCommonFieldsFromValidated(
            id: 'stroke-shared-defaults',
          ),
          fields: (
            points: const <Offset>[Offset(0, 0), Offset(1, 1)],
            pointsRevision: 0,
            thickness: 2,
            color: const Color(0xFF111111),
          ),
        ),
        lineNodeSnapshotFromValidated(
          common: nodeSnapshotCommonFieldsFromValidated(
            id: 'line-shared-defaults',
          ),
          fields: (
            start: const Offset(0, 0),
            end: const Offset(2, 2),
            thickness: 3,
            color: const Color(0xFF222222),
          ),
        ),
        rectNodeSnapshotFromValidated(
          common: nodeSnapshotCommonFieldsFromValidated(
            id: 'rect-shared-defaults',
          ),
          fields: (
            size: const Size(8, 9),
            fillColor: null,
            strokeColor: null,
            strokeWidth: 0,
          ),
        ),
        pathNodeSnapshotFromValidated(
          common: nodeSnapshotCommonFieldsFromValidated(
            id: 'path-shared-defaults',
          ),
          fields: (
            svgPathData: 'M0 0 L10 10',
            fillColor: null,
            strokeColor: null,
            strokeWidth: 0,
            fillRule: PathFillRule.nonZero,
          ),
        ),
      ];

      for (final node in nodes) {
        expect(node.instanceRevision, 0);
        expect(node.transform, Transform2D.identity);
        expect(node.opacity, 1);
        expect(node.hitPadding, 0);
        expect(node.isVisible, isTrue);
        expect(node.isSelectable, isTrue);
        expect(node.isLocked, isFalse);
        expect(node.isDeletable, isTrue);
        expect(node.isTransformable, isTrue);
      }
    },
  );

  test('validated image patch fast-path builds default common patch', () {
    final image = imageNodePatchFromValidated(id: 'img-default-common');

    expect(image.common.transform.isAbsent, isTrue);
    expect(image.common.opacity.isAbsent, isTrue);
    expect(image.common.hitPadding.isAbsent, isTrue);
    expect(image.common.isVisible.isAbsent, isTrue);
  });

  test('validated spec fast-path helpers build default common schema', () {
    final image = imageNodeSpecFromValidated(
      fields: (
        imageId: 'asset:default',
        size: const Size(10, 20),
        naturalSize: null,
      ),
    );
    final text = textNodeSpecFromValidated(
      fields: (
        text: 'default',
        fontSize: 18,
        color: const Color(0xFF000000),
        align: TextAlign.left,
        isBold: false,
        isItalic: false,
        isUnderline: false,
        fontFamily: null,
        maxWidth: null,
        lineHeight: null,
      ),
    );
    final stroke = strokeNodeSpecFromValidated(
      fields: (
        points: const <Offset>[Offset(0, 0), Offset(1, 1)],
        thickness: 2,
        color: const Color(0xFF111111),
      ),
    );
    final line = lineNodeSpecFromValidated(
      fields: (
        start: const Offset(0, 0),
        end: const Offset(5, 5),
        thickness: 3,
        color: const Color(0xFF222222),
      ),
    );
    final rect = rectNodeSpecFromValidated(
      fields: (
        size: const Size(8, 9),
        fillColor: null,
        strokeColor: null,
        strokeWidth: 1.5,
      ),
    );
    final path = pathNodeSpecFromValidated(
      fields: (
        svgPathData: 'M0 0 L10 10',
        fillColor: null,
        strokeColor: null,
        strokeWidth: 2,
        fillRule: PathFillRule.evenOdd,
      ),
    );

    for (final spec in <NodeSpec>[image, text, stroke, line, rect, path]) {
      expect(spec.id, isNull);
      expect(spec.transform, Transform2D.identity);
      expect(spec.opacity, 1);
      expect(spec.hitPadding, 0);
      expect(spec.isVisible, isTrue);
      expect(spec.isSelectable, isTrue);
      expect(spec.isLocked, isFalse);
      expect(spec.isDeletable, isTrue);
      expect(spec.isTransformable, isTrue);
    }
  });

  test('validated patch fast-path helpers build default field payloads', () {
    final text = textNodePatchFromValidated(id: 'text-default-fields');
    final stroke = strokeNodePatchFromValidated(id: 'stroke-default-fields');
    final line = lineNodePatchFromValidated(id: 'line-default-fields');
    final rect = rectNodePatchFromValidated(id: 'rect-default-fields');
    final path = pathNodePatchFromValidated(id: 'path-default-fields');

    expect(text.text.isAbsent, isTrue);
    expect(text.fontSize.isAbsent, isTrue);
    expect(text.color.isAbsent, isTrue);
    expect(text.align.isAbsent, isTrue);
    expect(text.isBold.isAbsent, isTrue);
    expect(text.isItalic.isAbsent, isTrue);
    expect(text.isUnderline.isAbsent, isTrue);
    expect(text.fontFamily.isAbsent, isTrue);
    expect(text.maxWidth.isAbsent, isTrue);
    expect(text.lineHeight.isAbsent, isTrue);

    expect(stroke.points.isAbsent, isTrue);
    expect(stroke.thickness.isAbsent, isTrue);
    expect(stroke.color.isAbsent, isTrue);

    expect(line.start.isAbsent, isTrue);
    expect(line.end.isAbsent, isTrue);
    expect(line.thickness.isAbsent, isTrue);
    expect(line.color.isAbsent, isTrue);

    expect(rect.size.isAbsent, isTrue);
    expect(rect.fillColor.isAbsent, isTrue);
    expect(rect.strokeColor.isAbsent, isTrue);
    expect(rect.strokeWidth.isAbsent, isTrue);

    expect(path.svgPathData.isAbsent, isTrue);
    expect(path.fillColor.isAbsent, isTrue);
    expect(path.strokeColor.isAbsent, isTrue);
    expect(path.strokeWidth.isAbsent, isTrue);
    expect(path.fillRule.isAbsent, isTrue);
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
        common: nodeSnapshotCommonFieldsFromValidated(
          id: 'stroke-snapshot-owned',
        ),
        fields: (
          points: snapshotPoints,
          pointsRevision: 0,
          thickness: 3,
          color: const Color(0xFF222222),
        ),
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
