import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart' hide NodeId;
import 'package:iwb_canvas_engine/src/contract/internal/node_patch_fast_path.dart';
import 'package:iwb_canvas_engine/src/contract/internal/node_spec_fast_path.dart';
import 'package:iwb_canvas_engine/src/contract/internal/snapshot_fast_path.dart';
import 'package:iwb_canvas_engine/src/contract/owned_collections.dart';
import 'package:iwb_canvas_engine/src/interactive/interaction_eligibility_policy.dart';
import 'package:iwb_canvas_engine/src/model/scene_node_boundary_mapping.dart';
import 'package:iwb_canvas_engine/src/render/render_geometry_builder.dart';
import 'package:iwb_canvas_engine/src/serialization/scene_codec.dart';

// INV:INV-ENG-CONTRACT-ARCHITECTURE-BOUNDARY
// INV:INV-ENG-BOUNDARY-HERMETIC-CONCRETE-TYPES

void main() {
  test(
    'validated spec fast-path barrel exposes backing and materialization',
    () {
      final backing = imageNodeSpecBackingFromValidated(
        common: (
          id: 'img-backing',
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
          imageId: 'asset:backing',
          size: const Size(11, 12),
          naturalSize: const Size(21, 22),
        ),
      );

      final spec = materializeNodeSpec(backing) as ImageNodeSpec;

      expect(nodeSpecBackingOf(spec), same(backing));
      expect(spec.imageId, 'asset:backing');
      expect(spec.size, const Size(11, 12));
      expect(spec.naturalSize, const Size(21, 22));
    },
  );

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
        textDirection: TextDirection.ltr,
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

  test(
    'validated patch fast-path barrel exposes backing and materialization',
    () {
      final backing = imageNodePatchBackingFromValidated(
        id: 'img-patch-backing',
        common: commonNodePatchBackingFromValidated(
          fields: (
            transform: const PatchField<Transform2D>.absent(),
            opacity: PatchField<double>.value(0.25),
            hitPadding: const PatchField<double>.absent(),
            isVisible: const PatchField<bool>.absent(),
            isSelectable: const PatchField<bool>.absent(),
            isLocked: const PatchField<bool>.absent(),
            isDeletable: const PatchField<bool>.absent(),
            isTransformable: const PatchField<bool>.absent(),
          ),
        ),
        fields: (
          imageId: PatchField<String>.value('asset:patch-backing'),
          size: PatchField<Size>.value(const Size(9, 10)),
          naturalSize: const PatchField<Size?>.absent(),
        ),
      );

      final patch = materializeNodePatch(backing) as ImageNodePatch;

      expect(nodePatchBackingOf(patch), same(backing));
      expect(patch.common.opacity.value, 0.25);
      expect(patch.imageId.value, 'asset:patch-backing');
      expect(patch.size.value, const Size(9, 10));
    },
  );

  test('validated patch materializer covers every patch family branch', () {
    final textPatch =
        materializeNodePatch(
              textNodePatchBackingFromValidated(
                id: 'text-patch-materialized',
                common: commonNodePatchBackingFromValidated(
                  fields: (
                    transform: const PatchField<Transform2D>.absent(),
                    opacity: PatchField<double>.value(0.1),
                    hitPadding: const PatchField<double>.absent(),
                    isVisible: const PatchField<bool>.absent(),
                    isSelectable: const PatchField<bool>.absent(),
                    isLocked: const PatchField<bool>.absent(),
                    isDeletable: const PatchField<bool>.absent(),
                    isTransformable: const PatchField<bool>.absent(),
                  ),
                ),
                fields: (
                  text: PatchField<String>.value('materialized'),
                  fontSize: const PatchField<double>.absent(),
                  color: const PatchField<Color>.absent(),
                  align: const PatchField<TextAlign>.absent(),
                  textDirection: const PatchField<TextDirection>.absent(),
                  isBold: const PatchField<bool>.absent(),
                  isItalic: const PatchField<bool>.absent(),
                  isUnderline: const PatchField<bool>.absent(),
                  fontFamily: const PatchField<String?>.absent(),
                  maxWidth: const PatchField<double?>.absent(),
                  lineHeight: const PatchField<double?>.absent(),
                ),
              ),
            )
            as TextNodePatch;
    final strokePatch =
        materializeNodePatch(
              strokeNodePatchBackingFromValidated(
                id: 'stroke-patch-materialized',
                fields: (
                  points: PatchField<List<Offset>>.value(const <Offset>[
                    Offset(1, 1),
                    Offset(2, 2),
                  ]),
                  thickness: const PatchField<double>.absent(),
                  color: const PatchField<Color>.absent(),
                ),
              ),
            )
            as StrokeNodePatch;
    final linePatch =
        materializeNodePatch(
              lineNodePatchBackingFromValidated(
                id: 'line-patch-materialized',
                fields: (
                  start: PatchField<Offset>.value(const Offset(3, 3)),
                  end: const PatchField<Offset>.absent(),
                  thickness: const PatchField<double>.absent(),
                  color: const PatchField<Color>.absent(),
                ),
              ),
            )
            as LineNodePatch;
    final rectPatch =
        materializeNodePatch(
              rectNodePatchBackingFromValidated(
                id: 'rect-patch-materialized',
                fields: (
                  size: PatchField<Size>.value(const Size(4, 5)),
                  fillColor: const PatchField<Color?>.absent(),
                  strokeColor: const PatchField<Color?>.absent(),
                  strokeWidth: const PatchField<double>.absent(),
                ),
              ),
            )
            as RectNodePatch;
    final pathPatch =
        materializeNodePatch(
              pathNodePatchBackingFromValidated(
                id: 'path-patch-materialized',
                fields: (
                  svgPathData: PatchField<String>.value('M0 0 L3 3'),
                  fillColor: const PatchField<Color?>.absent(),
                  strokeColor: const PatchField<Color?>.absent(),
                  strokeWidth: const PatchField<double>.absent(),
                  fillRule: const PatchField<PathFillRule>.absent(),
                ),
              ),
            )
            as PathNodePatch;

    expect(textPatch.text.value, 'materialized');
    expect(strokePatch.points.value, const <Offset>[
      Offset(1, 1),
      Offset(2, 2),
    ]);
    expect(linePatch.start.value, const Offset(3, 3));
    expect(rectPatch.size.value, const Size(4, 5));
    expect(pathPatch.svgPathData.value, 'M0 0 L3 3');
  });

  test('validated fast-path materializers cover every node family branch', () {
    final textSpec =
        materializeNodeSpec(
              textNodeSpecBackingFromValidated(
                common: (
                  id: 'text-backing',
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
                  text: 'text',
                  fontSize: 16,
                  color: const Color(0xFF000000),
                  align: TextAlign.center,
                  textDirection: TextDirection.ltr,
                  isBold: false,
                  isItalic: false,
                  isUnderline: false,
                  fontFamily: null,
                  maxWidth: null,
                  lineHeight: null,
                ),
              ),
            )
            as TextNodeSpec;
    final strokeSpec =
        materializeNodeSpec(
              strokeNodeSpecBackingFromValidated(
                common: (
                  id: 'stroke-backing',
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
                  points: const <Offset>[Offset(0, 0), Offset(2, 2)],
                  thickness: 2,
                  color: const Color(0xFF111111),
                ),
              ),
            )
            as StrokeNodeSpec;
    final lineSpec =
        materializeNodeSpec(
              lineNodeSpecBackingFromValidated(
                common: (
                  id: 'line-backing',
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
                  start: const Offset(1, 1),
                  end: const Offset(3, 3),
                  thickness: 3,
                  color: const Color(0xFF222222),
                ),
              ),
            )
            as LineNodeSpec;
    final rectSpec =
        materializeNodeSpec(
              rectNodeSpecBackingFromValidated(
                common: (
                  id: 'rect-backing',
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
                  size: const Size(12, 13),
                  fillColor: null,
                  strokeColor: const Color(0xFF333333),
                  strokeWidth: 4,
                ),
              ),
            )
            as RectNodeSpec;
    final pathSpec =
        materializeNodeSpec(
              pathNodeSpecBackingFromValidated(
                common: (
                  id: 'path-backing',
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
                  svgPathData: 'M0 0 L1 1',
                  fillColor: null,
                  strokeColor: const Color(0xFF444444),
                  strokeWidth: 5,
                  fillRule: PathFillRule.nonZero,
                ),
              ),
            )
            as PathNodeSpec;

    final common = CommonNodePatch(opacity: PatchField<double>.value(0.6));
    final textPatch = textNodePatchFromValidated(
      id: 'text-patch-backing',
      common: common,
      fields: (
        text: PatchField<String>.value('patched'),
        fontSize: const PatchField<double>.absent(),
        color: const PatchField<Color>.absent(),
        align: const PatchField<TextAlign>.absent(),
        textDirection: const PatchField<TextDirection>.absent(),
        isBold: const PatchField<bool>.absent(),
        isItalic: const PatchField<bool>.absent(),
        isUnderline: const PatchField<bool>.absent(),
        fontFamily: const PatchField<String?>.absent(),
        maxWidth: const PatchField<double?>.absent(),
        lineHeight: const PatchField<double?>.absent(),
      ),
    );
    final strokePatch = strokeNodePatchFromValidated(
      id: 'stroke-patch-backing',
      common: common,
      fields: (
        points: PatchField<List<Offset>>.value(const <Offset>[
          Offset(3, 4),
          Offset(5, 6),
        ]),
        thickness: const PatchField<double>.absent(),
        color: const PatchField<Color>.absent(),
      ),
    );
    final linePatch = lineNodePatchFromValidated(
      id: 'line-patch-backing',
      common: common,
      fields: (
        start: PatchField<Offset>.value(const Offset(7, 8)),
        end: const PatchField<Offset>.absent(),
        thickness: const PatchField<double>.absent(),
        color: const PatchField<Color>.absent(),
      ),
    );
    final rectPatch = rectNodePatchFromValidated(
      id: 'rect-patch-backing',
      common: common,
      fields: (
        size: PatchField<Size>.value(const Size(14, 15)),
        fillColor: const PatchField<Color?>.absent(),
        strokeColor: const PatchField<Color?>.absent(),
        strokeWidth: const PatchField<double>.absent(),
      ),
    );
    final pathPatch = pathNodePatchFromValidated(
      id: 'path-patch-backing',
      common: common,
      fields: (
        svgPathData: PatchField<String>.value('M1 1 L2 2'),
        fillColor: const PatchField<Color?>.absent(),
        strokeColor: const PatchField<Color?>.absent(),
        strokeWidth: const PatchField<double>.absent(),
        fillRule: const PatchField<PathFillRule>.absent(),
      ),
    );

    expect(textSpec.align, TextAlign.center);
    expect(strokeSpec.points, const <Offset>[Offset(0, 0), Offset(2, 2)]);
    expect(lineSpec.end, const Offset(3, 3));
    expect(rectSpec.strokeColor, const Color(0xFF333333));
    expect(pathSpec.strokeWidth, 5);

    expect(textPatch.common.opacity.value, 0.6);
    expect(textPatch.text.value, 'patched');
    expect(strokePatch.common.opacity.value, 0.6);
    expect(strokePatch.points.value, const <Offset>[
      Offset(3, 4),
      Offset(5, 6),
    ]);
    expect(linePatch.start.value, const Offset(7, 8));
    expect(rectPatch.size.value, const Size(14, 15));
    expect(pathPatch.svgPathData.value, 'M1 1 L2 2');
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
        textDirection: const PatchField<TextDirection>.absent(),
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
        sceneSnapshotBackingOf(scene).backgroundLayer,
        same(backgroundLayerSnapshotBackingOf(backgroundLayer)),
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
    'validated snapshot producers enforce structure while raw materialization keeps the internal bypass',
    () {
      final malformedBacking = sceneSnapshotBackingFromValidated(
        backgroundLayer: backgroundLayerSnapshotBackingFromValidated(
          nodes: <NodeSnapshotBacking>[
            nodeSnapshotBackingOf(
              RectNodeSnapshot(id: 'dup-struct', size: const Size(1, 1)),
            ),
          ],
        ),
        layers: <ContentLayerSnapshotBacking>[
          contentLayerSnapshotBackingFromValidated(
            id: 'layer-struct',
            nodes: <NodeSnapshotBacking>[
              nodeSnapshotBackingOf(
                RectNodeSnapshot(id: 'dup-struct', size: const Size(2, 2)),
              ),
            ],
          ),
        ],
      );

      expect(
        () => sceneSnapshotFromValidated(
          backgroundLayer: materializeBackgroundLayerSnapshot(
            malformedBacking.backgroundLayer,
          ),
          layers: materializeContentLayerSnapshotList(malformedBacking.layers),
        ),
        throwsA(
          predicate(
            (error) =>
                error is SceneDataException &&
                error.code == SceneDataErrorCode.duplicateNodeId &&
                error.path == 'layers[0].nodes[0].id' &&
                error.details['template'] == 'duplicateNodeId',
          ),
        ),
      );

      expect(
        () => sceneSnapshotFromValidatedBacking(malformedBacking),
        throwsA(
          predicate(
            (error) =>
                error is SceneDataException &&
                error.code == SceneDataErrorCode.duplicateNodeId &&
                error.path == 'layers[0].nodes[0].id' &&
                error.details['template'] == 'duplicateNodeId',
          ),
        ),
      );

      final malformed = materializeSceneSnapshot(malformedBacking);
      expect(sceneSnapshotBackingOf(malformed), same(malformedBacking));
      expect(malformed.backgroundLayer.nodes.single.id, 'dup-struct');
      expect(malformed.layers.single.nodes.single.id, 'dup-struct');
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
        ),
        strokeNodeSnapshotFromValidated(
          common: nodeSnapshotCommonFieldsFromValidated(
            id: 'stroke-shared-defaults',
          ),
          fields: (
            points: const <Offset>[Offset(0, 0), Offset(1, 1)],
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
        textDirection: TextDirection.ltr,
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

  test(
    'validated snapshot/spec/patch fast-path boundaries cover fallback and materialized getters',
    () {
      final imageSpec = ImageNodeSpec(
        id: 'img-spec-public',
        imageId: 'asset:img',
        size: const Size(10, 11),
        naturalSize: const Size(20, 21),
        transform: Transform2D.translation(const Offset(1, 2)),
        opacity: 0.8,
        hitPadding: 3,
        isVisible: false,
        isSelectable: false,
        isLocked: true,
        isDeletable: false,
        isTransformable: false,
      );
      final textSpecBacking = textNodeSpecBackingFromValidated(
        common: (
          id: 'text-spec-materialized',
          transform: Transform2D.translation(const Offset(3, 4)),
          opacity: 0.7,
          hitPadding: 5,
          isVisible: false,
          isSelectable: false,
          isLocked: true,
          isDeletable: false,
          isTransformable: false,
        ),
        fields: (
          text: 'hello',
          fontSize: 19,
          color: const Color(0xFF101010),
          align: TextAlign.end,
          textDirection: TextDirection.rtl,
          isBold: true,
          isItalic: true,
          isUnderline: true,
          fontFamily: 'Mono',
          maxWidth: 120,
          lineHeight: 1.5,
        ),
      );
      final strokeSpecBacking = strokeNodeSpecBackingFromValidated(
        common: (
          id: 'stroke-spec-materialized',
          transform: Transform2D.translation(const Offset(6, 7)),
          opacity: 0.6,
          hitPadding: 2,
          isVisible: false,
          isSelectable: false,
          isLocked: true,
          isDeletable: false,
          isTransformable: false,
        ),
        fields: (
          points: const <Offset>[Offset(0, 0), Offset(4, 5)],
          thickness: 2.5,
          color: const Color(0xFF202020),
        ),
      );
      final lineSpecBacking = lineNodeSpecBackingFromValidated(
        common: (
          id: 'line-spec-materialized',
          transform: Transform2D.translation(const Offset(8, 9)),
          opacity: 0.5,
          hitPadding: 4,
          isVisible: false,
          isSelectable: false,
          isLocked: true,
          isDeletable: false,
          isTransformable: false,
        ),
        fields: (
          start: const Offset(1, 1),
          end: const Offset(5, 6),
          thickness: 3.5,
          color: const Color(0xFF303030),
        ),
      );
      final rectSpecBacking = rectNodeSpecBackingFromValidated(
        common: (
          id: 'rect-spec-materialized',
          transform: Transform2D.translation(const Offset(10, 11)),
          opacity: 0.4,
          hitPadding: 6,
          isVisible: false,
          isSelectable: false,
          isLocked: true,
          isDeletable: false,
          isTransformable: false,
        ),
        fields: (
          size: const Size(12, 13),
          fillColor: const Color(0xFF404040),
          strokeColor: const Color(0xFF505050),
          strokeWidth: 1.25,
        ),
      );
      final pathSpecBacking = pathNodeSpecBackingFromValidated(
        common: (
          id: 'path-spec-materialized',
          transform: Transform2D.translation(const Offset(12, 13)),
          opacity: 0.3,
          hitPadding: 7,
          isVisible: false,
          isSelectable: false,
          isLocked: true,
          isDeletable: false,
          isTransformable: false,
        ),
        fields: (
          svgPathData: 'M0 0 L2 2',
          fillColor: const Color(0xFF606060),
          strokeColor: const Color(0xFF707070),
          strokeWidth: 2.25,
          fillRule: PathFillRule.evenOdd,
        ),
      );

      expect(nodeSpecBackingOf(imageSpec).id, 'img-spec-public');

      final textSpec = materializeTextNodeSpec(textSpecBacking);
      final strokeSpec = materializeStrokeNodeSpec(strokeSpecBacking);
      final lineSpec = materializeLineNodeSpec(lineSpecBacking);
      final rectSpec = materializeRectNodeSpec(rectSpecBacking);
      final pathSpec = materializePathNodeSpec(pathSpecBacking);

      expect(nodeSpecBackingOf(textSpec), same(textSpecBacking));
      expect(textSpec.textDirection, TextDirection.rtl);
      expect(textSpec.fontFamily, 'Mono');
      expect(textSpec.maxWidth, 120);
      expect(textSpec.lineHeight, 1.5);
      expect(strokeSpec.points, const <Offset>[Offset(0, 0), Offset(4, 5)]);
      expect(strokeSpec.thickness, 2.5);
      expect(lineSpec.start, const Offset(1, 1));
      expect(lineSpec.end, const Offset(5, 6));
      expect(rectSpec.fillColor, const Color(0xFF404040));
      expect(rectSpec.strokeColor, const Color(0xFF505050));
      expect(pathSpec.svgPathData, 'M0 0 L2 2');
      expect(pathSpec.fillRule, PathFillRule.evenOdd);

      final publicCommon = CommonNodePatch(
        opacity: PatchField<double>.value(0.25),
        isLocked: PatchField<bool>.value(true),
      );
      final imagePatch = ImageNodePatch(
        id: 'img-patch-public',
        common: publicCommon,
        imageId: PatchField<String>.value('asset:patch'),
      );
      expect(commonNodePatchBackingOf(publicCommon).opacity.value, 0.25);
      expect(nodePatchBackingOf(imagePatch).id, 'img-patch-public');

      final textPatchBacking = textNodePatchBackingFromValidated(
        id: 'text-patch-materialized',
        common: commonNodePatchBackingFromValidated(
          fields: (
            transform: PatchField<Transform2D>.value(
              Transform2D.translation(const Offset(2, 3)),
            ),
            opacity: PatchField<double>.value(0.4),
            hitPadding: PatchField<double>.value(2),
            isVisible: PatchField<bool>.value(false),
            isSelectable: PatchField<bool>.value(false),
            isLocked: PatchField<bool>.value(true),
            isDeletable: PatchField<bool>.value(false),
            isTransformable: PatchField<bool>.value(false),
          ),
        ),
        fields: (
          text: PatchField<String>.value('patched'),
          fontSize: PatchField<double>.value(21),
          color: PatchField<Color>.value(const Color(0xFF111111)),
          align: PatchField<TextAlign>.value(TextAlign.center),
          textDirection: PatchField<TextDirection>.value(TextDirection.rtl),
          isBold: PatchField<bool>.value(true),
          isItalic: PatchField<bool>.value(true),
          isUnderline: PatchField<bool>.value(true),
          fontFamily: PatchField<String?>.value('Serif'),
          maxWidth: PatchField<double?>.value(140),
          lineHeight: PatchField<double?>.value(1.8),
        ),
      );
      final strokePatchBacking = strokeNodePatchBackingFromValidated(
        id: 'stroke-patch-materialized',
        common: commonNodePatchBackingFromValidated(),
        fields: (
          points: PatchField<List<Offset>>.value(const <Offset>[
            Offset(1, 2),
            Offset(3, 4),
          ]),
          thickness: PatchField<double>.value(4),
          color: PatchField<Color>.value(const Color(0xFF222222)),
        ),
      );
      final linePatchBacking = lineNodePatchBackingFromValidated(
        id: 'line-patch-materialized',
        common: commonNodePatchBackingFromValidated(),
        fields: (
          start: PatchField<Offset>.value(const Offset(5, 6)),
          end: PatchField<Offset>.value(const Offset(7, 8)),
          thickness: PatchField<double>.value(3),
          color: PatchField<Color>.value(const Color(0xFF333333)),
        ),
      );
      final rectPatchBacking = rectNodePatchBackingFromValidated(
        id: 'rect-patch-materialized',
        common: commonNodePatchBackingFromValidated(),
        fields: (
          size: PatchField<Size>.value(const Size(9, 10)),
          fillColor: PatchField<Color?>.value(const Color(0xFF444444)),
          strokeColor: PatchField<Color?>.value(const Color(0xFF555555)),
          strokeWidth: PatchField<double>.value(2),
        ),
      );
      final pathPatchBacking = pathNodePatchBackingFromValidated(
        id: 'path-patch-materialized',
        common: commonNodePatchBackingFromValidated(),
        fields: (
          svgPathData: PatchField<String>.value('M1 1 L3 3'),
          fillColor: PatchField<Color?>.value(const Color(0xFF666666)),
          strokeColor: PatchField<Color?>.value(const Color(0xFF777777)),
          strokeWidth: PatchField<double>.value(5),
          fillRule: PatchField<PathFillRule>.value(PathFillRule.nonZero),
        ),
      );

      final textPatch = materializeTextNodePatch(textPatchBacking);
      final strokePatch = materializeStrokeNodePatch(strokePatchBacking);
      final linePatch = materializeLineNodePatch(linePatchBacking);
      final rectPatch = materializeRectNodePatch(rectPatchBacking);
      final pathPatch = materializePathNodePatch(pathPatchBacking);

      expect(nodePatchBackingOf(textPatch), same(textPatchBacking));
      expect(textPatch.common.opacity.value, 0.4);
      expect(textPatch.text.value, 'patched');
      expect(textPatch.textDirection.value, TextDirection.rtl);
      expect(textPatch.fontFamily.value, 'Serif');
      expect(strokePatch.points.value, const <Offset>[
        Offset(1, 2),
        Offset(3, 4),
      ]);
      expect(linePatch.end.value, const Offset(7, 8));
      expect(rectPatch.strokeColor.value, const Color(0xFF555555));
      expect(pathPatch.fillRule.value, PathFillRule.nonZero);

      final publicScene = SceneSnapshot(
        layers: <ContentLayerSnapshot>[
          ContentLayerSnapshot(
            id: 'layer-public',
            nodes: <NodeSnapshot>[
              ImageNodeSnapshot(
                id: 'image-public',
                imageId: 'asset:scene',
                size: const Size(16, 17),
              ),
            ],
          ),
        ],
        palette: ScenePaletteSnapshot(
          penColors: const <Color>[Color(0xFF010101)],
          backgroundColors: const <Color>[Color(0xFF020202)],
          gridSizes: const <double>[12],
        ),
      );
      expect(
        sceneSnapshotBackingOf(publicScene).layers.single.id,
        'layer-public',
      );

      final materializedScene = materializeSceneSnapshot(
        sceneSnapshotBackingFromValidated(
          layers: <ContentLayerSnapshotBacking>[
            contentLayerSnapshotBackingFromValidated(
              id: 'layer-materialized',
              nodes: <NodeSnapshotBacking>[
                imageNodeSnapshotBackingFromValidated(
                  common: nodeSnapshotCommonFieldsFromValidated(
                    id: 'image-materialized',
                    instanceRevision: 11,
                    transform: Transform2D.translation(const Offset(1, 1)),
                    opacity: 0.9,
                    hitPadding: 1,
                    isVisible: false,
                    isSelectable: false,
                    isLocked: true,
                    isDeletable: false,
                    isTransformable: false,
                  ),
                  fields: (
                    imageId: 'asset:scene-img',
                    size: const Size(30, 31),
                    naturalSize: const Size(32, 33),
                  ),
                ),
                textNodeSnapshotBackingFromValidated(
                  common: nodeSnapshotCommonFieldsFromValidated(
                    id: 'text-materialized',
                    instanceRevision: 12,
                  ),
                  fields: (
                    text: 'scene text',
                    fontSize: 18,
                    color: const Color(0xFF030303),
                    align: TextAlign.start,
                    textDirection: TextDirection.rtl,
                    isBold: true,
                    isItalic: true,
                    isUnderline: true,
                    fontFamily: 'Mono',
                    maxWidth: 140,
                    lineHeight: 1.6,
                  ),
                ),
                strokeNodeSnapshotBackingFromValidated(
                  common: nodeSnapshotCommonFieldsFromValidated(
                    id: 'stroke-materialized',
                    instanceRevision: 13,
                  ),
                  fields: (
                    points: OwnedList<Offset>.of(const <Offset>[
                      Offset(2, 2),
                      Offset(4, 4),
                    ]),
                    thickness: 3,
                    color: const Color(0xFF040404),
                  ),
                ),
                lineNodeSnapshotBackingFromValidated(
                  common: nodeSnapshotCommonFieldsFromValidated(
                    id: 'line-materialized',
                    instanceRevision: 14,
                  ),
                  fields: (
                    start: const Offset(5, 5),
                    end: const Offset(6, 6),
                    thickness: 2,
                    color: const Color(0xFF050505),
                  ),
                ),
                rectNodeSnapshotBackingFromValidated(
                  common: nodeSnapshotCommonFieldsFromValidated(
                    id: 'rect-materialized',
                    instanceRevision: 15,
                  ),
                  fields: (
                    size: const Size(36, 37),
                    fillColor: const Color(0xFF060606),
                    strokeColor: const Color(0xFF070707),
                    strokeWidth: 4,
                  ),
                ),
                pathNodeSnapshotBackingFromValidated(
                  common: nodeSnapshotCommonFieldsFromValidated(
                    id: 'path-materialized',
                    instanceRevision: 16,
                  ),
                  fields: (
                    svgPathData: 'M0 0 L4 4',
                    fillColor: const Color(0xFF080808),
                    strokeColor: const Color(0xFF090909),
                    strokeWidth: 2,
                    fillRule: PathFillRule.evenOdd,
                  ),
                ),
              ],
            ),
          ],
          backgroundLayer: backgroundLayerSnapshotBackingFromValidated(
            nodes: <NodeSnapshotBacking>[
              rectNodeSnapshotBackingFromValidated(
                common: nodeSnapshotCommonFieldsFromValidated(
                  id: 'bg-rect',
                  instanceRevision: 17,
                ),
                fields: (
                  size: const Size(40, 41),
                  fillColor: const Color(0xFF111111),
                  strokeColor: null,
                  strokeWidth: 0,
                ),
              ),
            ],
          ),
          camera: cameraSnapshotBackingFromValidated(
            offset: const Offset(20, 21),
          ),
          background: backgroundSnapshotBackingFromValidated(
            color: const Color(0xFF121212),
            grid: gridSnapshotBackingFromValidated(
              isEnabled: true,
              cellSize: 24,
              color: const Color(0xFF131313),
            ),
          ),
          palette: scenePaletteSnapshotBackingFromValidated(
            penColors: const <Color>[Color(0xFF141414)],
            backgroundColors: const <Color>[Color(0xFF151515)],
            gridSizes: const <double>[16, 32],
          ),
        ),
      );

      expect(
        sceneSnapshotBackingOf(materializedScene).layers.single.id,
        'layer-materialized',
      );
      expect(
        backgroundLayerSnapshotBackingOf(
          materializedScene.backgroundLayer,
        ).nodes,
        hasLength(1),
      );
      expect(
        contentLayerSnapshotBackingOf(materializedScene.layers.single).nodes,
        hasLength(6),
      );
      expect(
        scenePaletteSnapshotBackingOf(materializedScene.palette).gridSizes,
        const <double>[16, 32],
      );

      final nodes = materializedScene.layers.single.nodes;
      expect((nodes[0] as ImageNodeSnapshot).naturalSize, const Size(32, 33));
      expect((nodes[1] as TextNodeSnapshot).textDirection, TextDirection.rtl);
      expect((nodes[2] as StrokeNodeSnapshot).points, const <Offset>[
        Offset(2, 2),
        Offset(4, 4),
      ]);
      expect((nodes[3] as LineNodeSnapshot).end, const Offset(6, 6));
      expect((nodes[4] as RectNodeSnapshot).strokeWidth, 4);
      expect((nodes[5] as PathNodeSnapshot).fillRule, PathFillRule.evenOdd);
      expect(nodeSnapshotBackingOf(nodes[0]).id, 'image-materialized');
      expect(nodeSnapshotBackingOf(nodes[1]).id, 'text-materialized');
      expect(nodeSnapshotBackingOf(nodes[2]).id, 'stroke-materialized');
      expect(nodeSnapshotBackingOf(nodes[3]).id, 'line-materialized');
      expect(nodeSnapshotBackingOf(nodes[4]).id, 'rect-materialized');
      expect(nodeSnapshotBackingOf(nodes[5]).id, 'path-materialized');
      expect(materializedScene.camera.offset, const Offset(20, 21));
      expect(materializedScene.background.grid.cellSize, 24);
      expect(materializedScene.backgroundLayer.nodes.single.id, 'bg-rect');

      final publicStrokeSnapshot = StrokeNodeSnapshot(
        id: 'stroke-fallback-public',
        instanceRevision: 18,
        points: const <Offset>[Offset(8, 8), Offset(9, 9)],
        thickness: 6,
        color: const Color(0xFF161616),
      );
      final publicStrokeBacking = nodeSnapshotBackingOf(publicStrokeSnapshot);
      expect(
        nodeSnapshotBackingOf(publicStrokeSnapshot),
        same(publicStrokeBacking),
      );
      expect(publicStrokeBacking.id, 'stroke-fallback-public');
      expect(
        (publicStrokeBacking as StrokeNodeSnapshotBacking).points,
        const <Offset>[Offset(8, 8), Offset(9, 9)],
      );

      final publicLineSnapshot = LineNodeSnapshot(
        id: 'line-fallback-public',
        instanceRevision: 19,
        start: const Offset(10, 11),
        end: const Offset(12, 13),
        thickness: 7,
        color: const Color(0xFF171717),
      );
      final publicLineBacking = nodeSnapshotBackingOf(publicLineSnapshot);
      expect(
        nodeSnapshotBackingOf(publicLineSnapshot),
        same(publicLineBacking),
      );
      expect(publicLineBacking.id, 'line-fallback-public');
    },
  );

  test(
    'public fallback reconstruction covers every spec and patch family plus snapshot list materializers',
    () {
      final fallbackSpecs = <NodeSpec>[
        TextNodeSpec(
          id: 'text-fallback',
          text: 'fallback',
          color: const Color(0xFF111111),
          textDirection: TextDirection.ltr,
        ),
        StrokeNodeSpec(
          id: 'stroke-fallback',
          points: const <Offset>[Offset.zero, Offset(1, 1)],
          thickness: 2,
          color: const Color(0xFF222222),
        ),
        LineNodeSpec(
          id: 'line-fallback',
          start: const Offset(1, 2),
          end: const Offset(3, 4),
          thickness: 3,
          color: const Color(0xFF333333),
        ),
        RectNodeSpec(
          id: 'rect-fallback',
          size: const Size(5, 6),
          fillColor: const Color(0xFF444444),
        ),
        PathNodeSpec(
          id: 'path-fallback',
          svgPathData: 'M0 0 L1 0 L1 1 Z',
          fillColor: const Color(0xFF555555),
        ),
      ];
      for (final spec in fallbackSpecs) {
        final backing = nodeSpecBackingOf(spec);
        expect(nodeSpecBackingOf(spec), same(backing));
        expect(materializeNodeSpec(backing).id, spec.id);
      }

      final commonPatch = CommonNodePatch(
        opacity: const PatchField<double>.value(0.5),
      );
      expect(
        materializeCommonNodePatch(
          commonNodePatchBackingOf(commonPatch),
        ).opacity.value,
        0.5,
      );

      final fallbackPatches = <NodePatch>[
        TextNodePatch(
          id: 'text-patch-fallback',
          text: const PatchField<String>.value('patched'),
        ),
        StrokeNodePatch(
          id: 'stroke-patch-fallback',
          points: PatchField<List<Offset>>.value(const <Offset>[
            Offset.zero,
            Offset(2, 2),
          ]),
        ),
        LineNodePatch(
          id: 'line-patch-fallback',
          start: const PatchField<Offset>.value(Offset(1, 1)),
          end: const PatchField<Offset>.value(Offset(2, 2)),
        ),
        RectNodePatch(
          id: 'rect-patch-fallback',
          size: const PatchField<Size>.value(Size(7, 8)),
        ),
        PathNodePatch(
          id: 'path-patch-fallback',
          svgPathData: const PatchField<String>.value('M0 0 Z'),
        ),
      ];
      for (final patch in fallbackPatches) {
        final backing = nodePatchBackingOf(patch);
        expect(nodePatchBackingOf(patch), same(backing));
        expect(materializeNodePatch(backing).id, patch.id);
      }

      final contentBackings = <ContentLayerSnapshotBacking>[
        ContentLayerSnapshotBacking(
          id: 'layer-a',
          nodes: <NodeSnapshotBacking>[
            imageNodeSnapshotBackingFromValidated(
              common: nodeSnapshotCommonFieldsFromValidated(
                id: 'img-a',
                instanceRevision: 1,
              ),
              fields: (
                imageId: 'asset:a',
                size: const Size(1, 2),
                naturalSize: const Size(1, 2),
              ),
            ),
          ],
        ),
      ];
      final nodeBackings = <NodeSnapshotBacking>[
        rectNodeSnapshotBackingFromValidated(
          common: nodeSnapshotCommonFieldsFromValidated(
            id: 'rect-a',
            instanceRevision: 2,
          ),
          fields: (
            size: const Size(3, 4),
            fillColor: const Color(0xFF666666),
            strokeColor: null,
            strokeWidth: 0,
          ),
        ),
      ];

      expect(
        materializeContentLayerSnapshotList(contentBackings).single.id,
        'layer-a',
      );
      expect(materializeNodeSnapshotList(nodeBackings).single.id, 'rect-a');
    },
  );

  test('unsupported boundary subtypes fail fast across seam helpers', () {
    // INV:INV-ENG-BOUNDARY-HERMETIC-CONCRETE-TYPES
    final fakeSnapshot = _UnsupportedNodeSnapshot();
    final fakeSpec = _UnsupportedNodeSpec();
    final fakePatch = _UnsupportedNodePatch();

    expect(
      () => nodeSnapshotBackingOf(fakeSnapshot),
      throwsA(isA<StateError>()),
    );
    expect(() => nodeSpecBackingOf(fakeSpec), throwsA(isA<StateError>()));
    expect(() => nodePatchBackingOf(fakePatch), throwsA(isA<StateError>()));
    expect(
      () => sceneNodeFromSnapshotViaBoundarySchema(
        fakeSnapshot,
        instanceRevision: 1,
      ),
      throwsA(isA<StateError>()),
    );
    expect(
      () => sceneNodeFromSpecViaBoundarySchema(
        fakeSpec,
        fallbackId: 'fallback',
        instanceRevision: 1,
      ),
      throwsA(isA<StateError>()),
    );
    expect(
      () => buildRenderGeometryEntry(fakeSnapshot),
      throwsA(isA<StateError>()),
    );
    expect(
      () => buildRenderGeometryValidityKey(fakeSnapshot),
      throwsA(isA<StateError>()),
    );
    expect(
      () => centerWorldForNodeSnapshots(<NodeSnapshot>[fakeSnapshot]),
      throwsA(isA<StateError>()),
    );
    expect(
      () => debugEncodeCanonicalSnapshotForTest(
        SceneSnapshot(
          layers: <ContentLayerSnapshot>[
            ContentLayerSnapshot(
              id: 'layer-unsupported',
              nodes: <NodeSnapshot>[fakeSnapshot],
            ),
          ],
        ),
      ),
      throwsA(isA<StateError>()),
    );
  });

  test('fallback backing helpers reject public subclasses of known types', () {
    // INV:INV-ENG-BOUNDARY-HERMETIC-CONCRETE-TYPES
    expect(
      () => nodeSpecBackingOf(_SubclassedImageNodeSpec()),
      throwsA(isA<StateError>()),
    );
    expect(
      () => nodePatchBackingOf(_SubclassedImageNodePatch()),
      throwsA(isA<StateError>()),
    );
    expect(
      () => commonNodePatchBackingOf(_SubclassedCommonNodePatch()),
      throwsA(isA<StateError>()),
    );
    expect(
      () => nodeSnapshotBackingOf(_SubclassedImageNodeSnapshot()),
      throwsA(isA<StateError>()),
    );
    expect(
      () => sceneSnapshotBackingOf(_SubclassedSceneSnapshot()),
      throwsA(isA<StateError>()),
    );
    expect(
      () => backgroundLayerSnapshotBackingOf(
        _SubclassedBackgroundLayerSnapshot(),
      ),
      throwsA(isA<StateError>()),
    );
    expect(
      () => contentLayerSnapshotBackingOf(_SubclassedContentLayerSnapshot()),
      throwsA(isA<StateError>()),
    );
    expect(
      () => scenePaletteSnapshotBackingOf(_SubclassedScenePaletteSnapshot()),
      throwsA(isA<StateError>()),
    );
  });
}

final class _UnsupportedNodeSpec extends NodeSpec {
  const _UnsupportedNodeSpec()
    : super(
        id: 'unsupported-spec',
        transform: Transform2D.identity,
        opacity: 1,
        hitPadding: 0,
        isVisible: true,
        isSelectable: true,
        isLocked: false,
        isDeletable: true,
        isTransformable: true,
      );
}

final class _UnsupportedNodePatch extends NodePatch {
  _UnsupportedNodePatch()
    : super(id: 'unsupported-patch', common: CommonNodePatch());
}

final class _UnsupportedNodeSnapshot extends NodeSnapshot {
  const _UnsupportedNodeSnapshot()
    : super(
        id: 'unsupported-snapshot',
        instanceRevision: 1,
        transform: Transform2D.identity,
        opacity: 1,
        hitPadding: 0,
        isVisible: true,
        isSelectable: true,
        isLocked: false,
        isDeletable: true,
        isTransformable: true,
      );
}

final class _SubclassedImageNodeSpec extends ImageNodeSpec {
  _SubclassedImageNodeSpec()
    : super(imageId: 'asset:subclassed', size: const Size(1, 1));
}

final class _SubclassedCommonNodePatch extends CommonNodePatch {
  _SubclassedCommonNodePatch();
}

final class _SubclassedImageNodePatch extends ImageNodePatch {
  _SubclassedImageNodePatch() : super(id: 'subclassed-patch');
}

final class _SubclassedImageNodeSnapshot extends ImageNodeSnapshot {
  _SubclassedImageNodeSnapshot()
    : super(
        id: 'subclassed-snapshot',
        imageId: 'asset:subclassed',
        size: const Size(1, 1),
      );
}

final class _SubclassedSceneSnapshot extends SceneSnapshot {
  _SubclassedSceneSnapshot();
}

final class _SubclassedBackgroundLayerSnapshot extends BackgroundLayerSnapshot {
  _SubclassedBackgroundLayerSnapshot();
}

final class _SubclassedContentLayerSnapshot extends ContentLayerSnapshot {
  _SubclassedContentLayerSnapshot() : super(id: 'subclassed-layer');
}

final class _SubclassedScenePaletteSnapshot extends ScenePaletteSnapshot {
  _SubclassedScenePaletteSnapshot();
}
