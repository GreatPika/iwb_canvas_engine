import 'dart:collection';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart' hide NodeId;
import 'package:iwb_canvas_engine/src/contract/scene_validation_diagnostics.dart'
    show SceneDataDiagnosticDescriptor;
import 'package:iwb_canvas_engine/src/contract/internal/snapshot_fast_path.dart';
import 'package:iwb_canvas_engine/src/contract/internal/unsafe_snapshot_materialization.dart';
import 'package:iwb_canvas_engine/src/contract/scene_contract_limits.dart'
    show sceneCoordMax, sceneSizeMax;
import 'package:iwb_canvas_engine/src/core/nodes.dart';
import 'package:iwb_canvas_engine/src/core/scene.dart';
import 'package:iwb_canvas_engine/src/core/text_layout.dart'
    show TextLayoutRequest;
import 'package:iwb_canvas_engine/src/core/scene_limits.dart'
    show
        kMaxContentLayersPerScene,
        kMaxImageIdLength,
        kMaxNodesPerScene,
        kMaxPaletteItems,
        kMaxStrokePointsPerNode,
        kMaxSvgPathDataLength,
        kMaxTextLength;
import 'package:iwb_canvas_engine/src/model/scene_builder.dart'
    as model_builder;
import 'package:iwb_canvas_engine/src/model/document.dart'
    show txnSceneFromSnapshot, txnSceneToSnapshot;
import 'package:iwb_canvas_engine/src/model/scene_from_import_draft.dart'
    show sceneFromValidatedImportDraft;
import 'package:iwb_canvas_engine/src/model/scene_import_draft.dart';
import 'package:iwb_canvas_engine/src/model/scene_from_snapshot.dart'
    show sceneImportFromSnapshot;
import 'package:iwb_canvas_engine/src/model/scene_node_boundary_mapping.dart'
    show
        sceneNodeFromSnapshotViaBoundarySchema,
        sceneNodeSnapshotFromViaBoundarySchema;
import 'package:iwb_canvas_engine/src/model/scene_policy.dart';
import 'package:iwb_canvas_engine/src/model/scene_snapshot_projection.dart';
import 'package:iwb_canvas_engine/src/model/scene_value_validation.dart'
    as value_validation;

import '../support/scene_builder_json_fixtures.dart';

Map<String, Object?> _minimalRectNodeJson({required String id}) {
  return minimalRectNodeJson(id: id);
}

Map<String, Object?> _minimalSceneJson() {
  return minimalSceneJson();
}

SceneSnapshot _duplicateLayerIdSnapshotFromInternalBypass() {
  return unsafeMaterializeSceneSnapshot(
    SceneSnapshotBacking(
      layers: <ContentLayerSnapshotBacking>[
        contentLayerSnapshotBackingFromValidated(
          id: 'layer-auto-dup',
          nodes: <NodeSnapshotBacking>[
            nodeSnapshotBackingOf(
              RectNodeSnapshot(id: 'r1', size: const Size(1, 1)),
            ),
          ],
        ),
        contentLayerSnapshotBackingFromValidated(
          id: 'layer-auto-dup',
          nodes: <NodeSnapshotBacking>[
            nodeSnapshotBackingOf(
              RectNodeSnapshot(id: 'r2', size: const Size(1, 1)),
            ),
          ],
        ),
      ],
    ),
  );
}

SceneSnapshot _duplicateBackgroundNodeSnapshotFromInternalBypass() {
  return unsafeMaterializeSceneSnapshot(
    SceneSnapshotBacking(
      backgroundLayer: backgroundLayerSnapshotBackingFromValidated(
        nodes: <NodeSnapshotBacking>[
          nodeSnapshotBackingOf(
            RectNodeSnapshot(id: 'dup-bg', size: const Size(1, 1)),
          ),
          nodeSnapshotBackingOf(
            RectNodeSnapshot(id: 'dup-bg', size: const Size(2, 2)),
          ),
        ],
      ),
      layers: <ContentLayerSnapshotBacking>[
        contentLayerSnapshotBackingFromValidated(id: 'layer-auto-3'),
      ],
    ),
  );
}

SceneSnapshot _outOfRangeTransformSnapshot() {
  return SceneSnapshot(
    layers: <ContentLayerSnapshot>[
      ContentLayerSnapshot(
        id: 'layer-auto-out-of-range',
        nodes: <NodeSnapshot>[
          RectNodeSnapshot(
            id: 'rect-out-of-range',
            size: const Size(1, 1),
            transform: const Transform2D(
              a: 1,
              b: 0,
              c: 0,
              d: 1,
              tx: 10000001,
              ty: 0,
            ),
          ),
        ],
      ),
    ],
  );
}

class _ThrowingMap extends MapBase<String, Object?> {
  @override
  Object? operator [](Object? key) => throw StateError('boom');

  @override
  void operator []=(String key, Object? value) =>
      throw UnsupportedError('noop');

  @override
  void clear() => throw UnsupportedError('noop');

  @override
  Iterable<String> get keys => const <String>[];

  @override
  Object? remove(Object? key) => throw UnsupportedError('noop');

  @override
  bool containsKey(Object? key) => throw StateError('boom');
}

class _FormatThrowingMap extends MapBase<String, Object?> {
  @override
  Object? operator [](Object? key) => throw const FormatException('bad map');

  @override
  void operator []=(String key, Object? value) =>
      throw UnsupportedError('noop');

  @override
  void clear() => throw UnsupportedError('noop');

  @override
  Iterable<String> get keys => const <String>['schemaVersion'];

  @override
  Object? remove(Object? key) => throw UnsupportedError('noop');

  @override
  bool containsKey(Object? key) => throw const FormatException('bad map');
}

void main() {
  test('sceneBuildFromJsonMap wraps unexpected parser errors', () {
    expect(
      () => model_builder.sceneBuildFromJsonMap(_ThrowingMap()),
      throwsA(
        predicate(
          (e) =>
              e is SceneDataException &&
              e.code == SceneDataErrorCode.invalidJson &&
              e.source is Map<String, Object?> &&
              (e.source as Map<String, Object?>)['type'] == 'StateError',
        ),
      ),
    );
  });

  test(
    'sceneBuildFromDynamicJsonMap maps parsed-map normalization failures to invalidJsonPayload',
    () {
      final malformed = <Object?, Object?>{
        'schemaVersion': schemaVersionWrite,
        1: 'non-string-key',
      };

      expect(
        () => model_builder.sceneBuildFromDynamicJsonMap(
          malformed.cast<String, Object?>(),
        ),
        throwsA(
          predicate(
            (e) =>
                e is SceneDataException &&
                e.code == SceneDataErrorCode.invalidJson &&
                e.path == null &&
                e.details['template'] == 'invalidJsonPayload',
          ),
        ),
      );
    },
  );

  test(
    'sceneBuildFromDynamicJsonMap maps FormatException failures to invalidJsonPayload',
    () {
      expect(
        () => model_builder.sceneBuildFromDynamicJsonMap(_FormatThrowingMap()),
        throwsA(
          predicate(
            (e) =>
                e is SceneDataException &&
                e.code == SceneDataErrorCode.invalidJson &&
                e.details['template'] == 'invalidJsonPayload',
          ),
        ),
      );
    },
  );

  test(
    'sceneValidateCore canonicalizes background and preserves all node types',
    () {
      final scene = Scene(
        backgroundLayer: BackgroundLayer(),
        layers: <ContentLayer>[
          ContentLayer(
            id: 'layer-auto-5',
            nodes: <SceneNode>[
              ImageNode(
                id: 'img',
                imageId: 'image://1',
                size: const Size(8, 9),
                naturalSize: const Size(16, 18),
              ),
              TextNode(
                id: 'txt',
                text: 'hello',
                fontSize: 18,
                color: const Color(0xFF112233),
                maxWidth: 120,
                lineHeight: 1.3,
              ),
              StrokeNode(
                id: 'str',
                points: const <Offset>[Offset(0, 0), Offset(3, 4)],
                thickness: 2,
                color: Color(0xFF445566),
              ),
              LineNode(
                id: 'ln',
                start: const Offset(0, 0),
                end: const Offset(10, 2),
                thickness: 3,
                color: const Color(0xFF778899),
              ),
              RectNode(id: 'rect', size: const Size(5, 6), strokeWidth: 1),
              PathNode(
                id: 'path-non-zero',
                svgPathData: 'M0 0 L5 0 L5 5 Z',
                strokeWidth: 1,
                fillRule: PathFillRule.nonZero,
              ),
              PathNode(
                id: 'path-even-odd',
                svgPathData: 'M0 0 L5 0 L5 5 Z',
                strokeWidth: 1,
                fillRule: PathFillRule.evenOdd,
              ),
            ],
          ),
        ],
      );

      final canonical = model_builder.sceneValidateCore(scene);

      expect(canonical.backgroundLayer, isNotNull);
      final nodes = canonical.layers.first.nodes;
      expect(nodes[0], isA<ImageNode>());
      expect(nodes[1], isA<TextNode>());
      expect(nodes[2], isA<StrokeNode>());
      expect(nodes[3], isA<LineNode>());
      expect(nodes[4], isA<RectNode>());
      expect(nodes[5], isA<PathNode>());
      expect(nodes[6], isA<PathNode>());
      expect((nodes[5] as PathNode).fillRule, PathFillRule.nonZero);
      expect((nodes[6] as PathNode).fillRule, PathFillRule.evenOdd);
    },
  );

  test('sceneCanonicalizeAndValidateScene canonicalizes runtime scene', () {
    final scene = Scene(
      layers: <ContentLayer>[
        ContentLayer(
          id: 'layer-auto-delegate',
          nodes: <SceneNode>[
            RectNode(id: 'rect-runtime', size: const Size(4, 5)),
          ],
        ),
      ],
    );

    final canonical = model_builder.sceneCanonicalizeAndValidateScene(scene);

    expect(canonical.backgroundLayer, isNotNull);
    expect(canonical.layers.single.nodes.single.id, 'rect-runtime');
  });

  test(
    'sceneCanonicalizeAndValidateSnapshot preserves canonical snapshot structure',
    () {
      final snapshot = SceneSnapshot(
        backgroundLayer: BackgroundLayerSnapshot(
          nodes: <NodeSnapshot>[
            RectNodeSnapshot(id: 'bg-runtime-snapshot', size: const Size(1, 1)),
          ],
        ),
        layers: <ContentLayerSnapshot>[
          ContentLayerSnapshot(
            id: 'layer-auto-runtime-snapshot',
            nodes: <NodeSnapshot>[
              RectNodeSnapshot(id: 'rect-runtime-snapshot', size: Size(4, 5)),
            ],
          ),
        ],
      );

      final canonical = model_builder.sceneCanonicalizeAndValidateSnapshot(
        snapshot,
      );

      expect(canonical.backgroundLayer.nodes.single.id, 'bg-runtime-snapshot');
      expect(canonical.layers.single.nodes.single.id, 'rect-runtime-snapshot');
    },
  );

  test(
    'sceneValidateCore materializes missing background layer without changing content ownership',
    () {
      final scene = Scene(
        layers: <ContentLayer>[
          ContentLayer(
            id: 'layer-auto-runtime-no-background',
            nodes: <SceneNode>[
              RectNode(
                id: 'rect-runtime-no-background',
                size: const Size(4, 5),
              ),
            ],
          ),
        ],
      );

      final canonical = model_builder.sceneValidateCore(scene);

      expect(canonical.backgroundLayer, isNotNull);
      final backgroundLayer = canonical.backgroundLayer;
      if (backgroundLayer == null) {
        fail('Expected sceneValidateCore to materialize background layer.');
      }
      expect(backgroundLayer.nodes, isEmpty);
      expect(canonical.layers.single.id, 'layer-auto-runtime-no-background');
      expect(
        canonical.layers.single.nodes.single.id,
        'rect-runtime-no-background',
      );
    },
  );

  test(
    'txnSceneFromSnapshot allocates missing instance revisions across background and content traversal',
    () {
      var nextRevision = 40;
      final snapshot = SceneSnapshot(
        backgroundLayer: BackgroundLayerSnapshot(
          nodes: <NodeSnapshot>[
            RectNodeSnapshot(
              id: 'bg-import',
              size: const Size(1, 1),
              instanceRevision: 0,
            ),
          ],
        ),
        layers: <ContentLayerSnapshot>[
          ContentLayerSnapshot(
            id: 'layer-auto-import',
            nodes: <NodeSnapshot>[
              RectNodeSnapshot(
                id: 'content-import-1',
                size: const Size(2, 2),
                instanceRevision: 0,
              ),
              RectNodeSnapshot(
                id: 'content-import-2',
                size: const Size(3, 3),
                instanceRevision: 7,
              ),
            ],
          ),
        ],
      );

      final scene = txnSceneFromSnapshot(
        snapshot,
        nextInstanceRevision: () => nextRevision++,
      );

      final backgroundLayer = scene.backgroundLayer;
      if (backgroundLayer == null) {
        fail('Expected imported scene to materialize background layer.');
      }
      expect(backgroundLayer.nodes.single.instanceRevision, 40);
      expect(scene.layers.single.nodes.first.instanceRevision, 41);
      expect(scene.layers.single.nodes.last.instanceRevision, 7);
      expect(nextRevision, 42);
    },
  );

  test(
    'txnSceneToSnapshot canonicalizes absent runtime background layer and preserves scene shell',
    () {
      final scene = Scene(
        layers: <ContentLayer>[
          ContentLayer(
            id: 'layer-auto-export',
            nodes: <SceneNode>[
              RectNode(id: 'rect-export', size: const Size(4, 5)),
            ],
          ),
        ],
        camera: Camera(offset: const Offset(9, 11)),
        background: Background(
          color: const Color(0xFFABCDEF),
          grid: GridSettings(
            isEnabled: true,
            cellSize: 24,
            color: const Color(0xFF010203),
          ),
        ),
        palette: ScenePalette(
          penColors: <Color>[const Color(0xFF111111)],
          backgroundColors: <Color>[const Color(0xFF222222)],
          gridSizes: <double>[24, 48],
        ),
      );

      final snapshot = txnSceneToSnapshot(scene);

      expect(snapshot.backgroundLayer.nodes, isEmpty);
      expect(snapshot.layers.single.id, 'layer-auto-export');
      expect(snapshot.layers.single.nodes.single.id, 'rect-export');
      expect(snapshot.camera.offset, const Offset(9, 11));
      expect(snapshot.background.color, const Color(0xFFABCDEF));
      expect(snapshot.background.grid.isEnabled, isTrue);
      expect(snapshot.background.grid.cellSize, 24);
      expect(snapshot.background.grid.color, const Color(0xFF010203));
      expect(snapshot.palette.penColors, <Color>[const Color(0xFF111111)]);
      expect(snapshot.palette.backgroundColors, <Color>[
        const Color(0xFF222222),
      ]);
      expect(snapshot.palette.gridSizes, <double>[24, 48]);
    },
  );

  test(
    'ScenePolicy runtime and encode entrypoints preserve runtime diagnostics',
    () {
      Scene duplicateScene() {
        return Scene(
          backgroundLayer: BackgroundLayer(
            nodes: <SceneNode>[
              RectNode(id: 'dup-runtime', size: const Size(1, 1)),
            ],
          ),
          layers: <ContentLayer>[
            ContentLayer(
              id: 'layer-auto-runtime-dup',
              nodes: <SceneNode>[
                RectNode(id: 'dup-runtime', size: const Size(2, 2)),
              ],
            ),
          ],
        );
      }

      final validators = <Scene Function(Scene)>[
        (scene) => ScenePolicy.validateRuntimeScene(
          scene,
          snapshotFromScene: txnSceneToSnapshot,
          sceneFromValidatedImportDraft: sceneFromValidatedImportDraft,
        ),
        (scene) => ScenePolicy.validateEncodeScene(
          scene,
          snapshotFromScene: txnSceneToSnapshot,
          sceneFromValidatedImportDraft: sceneFromValidatedImportDraft,
        ),
      ];

      for (final validate in validators) {
        expect(
          () => validate(duplicateScene()),
          throwsA(
            predicate(
              (e) =>
                  e is SceneDataException &&
                  e.code == SceneDataErrorCode.duplicateNodeId &&
                  e.path == 'layers[0].nodes[0].id' &&
                  e.message == 'Must be unique across scene layers.',
            ),
          ),
        );
      }
    },
  );

  test(
    'ScenePolicy import snapshot and runtime validation reuse the draft import spine',
    () {
      final rawSnapshot = SceneSnapshot(
        layers: <ContentLayerSnapshot>[
          ContentLayerSnapshot(
            id: 'layer-auto-policy',
            nodes: <NodeSnapshot>[
              RectNodeSnapshot(id: 'rect-policy', size: const Size(5, 6)),
            ],
          ),
        ],
      );

      final canonicalSnapshot = ScenePolicy.validateImportSnapshot(rawSnapshot);
      expect(canonicalSnapshot.backgroundLayer.nodes, isEmpty);
      expect(canonicalSnapshot.layers.single.nodes.single.id, 'rect-policy');

      final runtimeScene = ScenePolicy.validateRuntimeScene(
        Scene(
          layers: <ContentLayer>[
            ContentLayer(
              id: 'layer-auto-policy',
              nodes: <SceneNode>[
                RectNode(id: 'rect-policy', size: const Size(5, 6)),
              ],
            ),
          ],
        ),
        snapshotFromScene: txnSceneToSnapshot,
        sceneFromValidatedImportDraft: sceneFromValidatedImportDraft,
      );
      expect(runtimeScene.layers.single.nodes.single.id, 'rect-policy');
    },
  );

  test(
    'ScenePolicy.validateImportSnapshot reports unsupported typed scene subtypes as SceneDataException',
    () {
      expect(
        () => ScenePolicy.validateImportSnapshot(_UnsupportedSceneSnapshot()),
        throwsA(
          predicate(
            (e) =>
                e is SceneDataException &&
                e.code == SceneDataErrorCode.invalidValue &&
                e.path == null &&
                e.details['template'] == 'unsupportedBoundarySubtype' &&
                e.details['boundaryType'] == 'SceneSnapshot' &&
                e.details['runtimeType'] == '_UnsupportedSceneSnapshot',
          ),
        ),
      );
    },
  );

  test('sceneImportFromSnapshot imports through the draft adapter wrapper', () {
    final imported = sceneImportFromSnapshot(
      SceneSnapshot(
        layers: <ContentLayerSnapshot>[
          ContentLayerSnapshot(
            id: 'layer-auto-wrapper',
            nodes: <NodeSnapshot>[
              RectNodeSnapshot(id: 'rect-wrapper', size: const Size(7, 8)),
            ],
          ),
        ],
      ),
      nextInstanceRevision: () => 41,
    );

    final rect = imported.layers.single.nodes.single as RectNode;
    expect(rect.id, 'rect-wrapper');
    expect(rect.instanceRevision, 41);
  });

  test(
    'sceneImportFromSnapshot rejects out-of-range transform values from typed snapshots',
    () {
      expect(
        () => sceneImportFromSnapshot(_outOfRangeTransformSnapshot()),
        throwsA(
          predicate(
            (e) =>
                e is SceneDataException &&
                e.code == SceneDataErrorCode.outOfRange &&
                e.path == 'layers[0].nodes[0].transform.tx',
          ),
        ),
      );
    },
  );

  test(
    'ScenePolicy.validateImportDraft preserves malformed raw-backing diagnostics for node values',
    () {
      final rawDraft = SceneImportDraft.fromBacking(
        sceneSnapshotBackingFromValidated(
          layers: <ContentLayerSnapshotBacking>[
            contentLayerSnapshotBackingFromValidated(
              id: 'layer-auto-raw-draft-invalid',
              nodes: <NodeSnapshotBacking>[
                const RectNodeSnapshotBacking(
                  id: 'rect-invalid',
                  size: Size(-1, 1),
                ),
              ],
            ),
          ],
        ),
      );

      expect(
        () => ScenePolicy.validateImportDraft(rawDraft),
        throwsA(
          predicate(
            (e) =>
                e is SceneDataException &&
                e.code == SceneDataErrorCode.invalidValue &&
                e.path == 'layers[0].nodes[0].size.w',
          ),
        ),
      );
    },
  );

  test(
    'validated scene snapshot projection rejects malformed backing graphs',
    () {
      final malformedBacking = SceneSnapshotBacking(
        backgroundLayer: backgroundLayerSnapshotBackingFromValidated(
          nodes: <NodeSnapshotBacking>[
            nodeSnapshotBackingOf(
              RectNodeSnapshot(id: 'dup-projection', size: const Size(1, 1)),
            ),
          ],
        ),
        layers: <ContentLayerSnapshotBacking>[
          contentLayerSnapshotBackingFromValidated(
            id: 'layer-auto-projection',
            nodes: <NodeSnapshotBacking>[
              nodeSnapshotBackingOf(
                RectNodeSnapshot(id: 'dup-projection', size: const Size(2, 2)),
              ),
            ],
          ),
        ],
      );

      expect(
        () => projectValidatedSceneSnapshot(malformedBacking),
        throwsA(
          predicate(
            (e) =>
                e is SceneDataException &&
                e.code == SceneDataErrorCode.duplicateNodeId &&
                e.path == 'layers[0].nodes[0].id',
          ),
        ),
      );
    },
  );

  test(
    'scene node boundary mapping materializes runtime nodes to snapshots',
    () {
      final snapshot = sceneNodeSnapshotFromViaBoundarySchema(
        RectNode(id: 'rect-boundary', size: const Size(3, 4)),
      );

      expect(snapshot, isA<RectNodeSnapshot>());
      expect(snapshot.id, 'rect-boundary');
    },
  );

  test('sceneBuildFromSnapshot rejects out-of-range transform values', () {
    expect(
      () =>
          model_builder.sceneBuildFromSnapshot(_outOfRangeTransformSnapshot()),
      throwsA(
        predicate(
          (e) =>
              e is SceneDataException &&
              e.code == SceneDataErrorCode.outOfRange &&
              e.path == 'layers[0].nodes[0].transform.tx',
        ),
      ),
    );
  });

  test('sceneBuildFromSnapshot rejects singular transform values', () {
    final snapshot = sceneSnapshotFromValidated(
      layers: <ContentLayerSnapshot>[
        contentLayerSnapshotFromValidated(
          id: 'layer-auto-1',
          nodes: <NodeSnapshot>[
            rectNodeSnapshotFromValidated(
              common: nodeSnapshotCommonFieldsFromValidated(
                id: 'r1',
                transform: const Transform2D(
                  a: 1,
                  b: 2,
                  c: 2,
                  d: 4,
                  tx: 0,
                  ty: 0,
                ),
              ),
              fields: (
                size: const Size(1, 1),
                fillColor: null,
                strokeColor: null,
                strokeWidth: 0,
              ),
            ),
          ],
        ),
      ],
    );

    expect(
      () => model_builder.sceneBuildFromSnapshot(snapshot),
      throwsA(
        predicate(
          (e) =>
              e is SceneDataException &&
              e.code == SceneDataErrorCode.invalidValue &&
              e.path == 'layers[0].nodes[0].transform' &&
              e.message ==
                  'Field layers[0].nodes[0].transform must be invertible (non-singular).',
        ),
      ),
    );
  });

  test('sceneBuildFromSnapshot rejects duplicate content layer ids', () {
    final snapshot = _duplicateLayerIdSnapshotFromInternalBypass();

    expect(
      () => model_builder.sceneBuildFromSnapshot(snapshot),
      throwsA(
        predicate(
          (e) =>
              e is SceneDataException &&
              e.code == SceneDataErrorCode.duplicateLayerId &&
              e.path == 'layers[1].id' &&
              e.details['template'] == 'duplicateLayerId' &&
              e.message ==
                  'Field layers[1].id must be unique across content layers.',
        ),
      ),
    );
  });

  test('sceneBuildFromSnapshot derives text bounds from layout inputs', () {
    final textSnapshot = TextNodeSnapshot(
      id: 't-derived',
      text: 'Derived text size',
      fontSize: 24,
      color: Color(0xFF000000),
      align: TextAlign.left,
      textDirection: TextDirection.ltr,
      isBold: false,
      isItalic: false,
      isUnderline: false,
    );
    final snapshot = SceneSnapshot(
      layers: <ContentLayerSnapshot>[
        ContentLayerSnapshot(
          id: 'layer-auto-text',
          nodes: <NodeSnapshot>[textSnapshot],
        ),
      ],
    );

    final expectedSize = TextLayoutRequest(
      text: textSnapshot.text,
      color: textSnapshot.color,
      fontSize: textSnapshot.fontSize,
      isBold: textSnapshot.isBold,
      isItalic: textSnapshot.isItalic,
      isUnderline: textSnapshot.isUnderline,
      textAlign: textSnapshot.align,
      fontFamily: textSnapshot.fontFamily,
      lineHeight: textSnapshot.lineHeight,
      maxWidth: textSnapshot.maxWidth,
    ).measure();

    final scene = model_builder.sceneBuildFromSnapshot(snapshot);
    final textNode = scene.layers.first.nodes.single as TextNode;

    expect(textNode.localBounds.width, closeTo(expectedSize.width, 0.001));
    expect(textNode.localBounds.height, closeTo(expectedSize.height, 0.001));
  });

  test(
    'snapshot validation and boundary mapping cover exact snapshot node families',
    () {
      final snapshots = <NodeSnapshot>[
        ImageNodeSnapshot(
          id: 'img-coverage',
          imageId: 'asset:coverage',
          size: const Size(40, 30),
          naturalSize: const Size(80, 60),
        ),
        TextNodeSnapshot(
          id: 'text-coverage',
          text: 'coverage',
          fontSize: 18,
          color: const Color(0xFF112233),
          align: TextAlign.center,
          textDirection: TextDirection.rtl,
          fontFamily: 'Mono',
          maxWidth: 140,
          lineHeight: 1.3,
        ),
        StrokeNodeSnapshot(
          id: 'stroke-coverage',
          points: const <Offset>[Offset(0, 0), Offset(10, 10)],
          thickness: 3,
          color: const Color(0xFF445566),
        ),
        LineNodeSnapshot(
          id: 'line-coverage',
          start: const Offset(1, 2),
          end: const Offset(9, 12),
          thickness: 2,
          color: const Color(0xFF778899),
        ),
        PathNodeSnapshot(
          id: 'path-coverage',
          svgPathData: 'M0 0 L20 0 L20 10 Z',
          fillColor: const Color(0xFF4CAF50),
          strokeColor: const Color(0xFF1B5E20),
          strokeWidth: 1,
          fillRule: PathFillRule.evenOdd,
        ),
      ];
      final snapshot = SceneSnapshot(
        layers: <ContentLayerSnapshot>[
          ContentLayerSnapshot(id: 'layer-auto-coverage', nodes: snapshots),
        ],
      );

      expect(
        () => value_validation.sceneValidateSnapshotValues(
          snapshot,
          onError:
              ({
                required Object? value,
                required String field,
                String? message,
                SceneDataDiagnosticDescriptor? diagnostic,
              }) {
                if (diagnostic != null) {
                  throw diagnostic.toException(path: field, source: value);
                }
                fail('Unexpected validation error at $field: $message');
              },
          requirePositiveGridCellSize: true,
          requireEnabledMinGridCellSize: true,
        ),
        returnsNormally,
      );

      final runtimeNodes = <SceneNode>[
        for (var index = 0; index < snapshots.length; index += 1)
          sceneNodeFromSnapshotViaBoundarySchema(
            snapshots[index],
            instanceRevision: index + 1,
          ),
      ];

      expect(runtimeNodes[0], isA<ImageNode>());
      expect(runtimeNodes[1], isA<TextNode>());
      expect(runtimeNodes[2], isA<StrokeNode>());
      expect(runtimeNodes[3], isA<LineNode>());
      expect(runtimeNodes[4], isA<PathNode>());

      final textNode = runtimeNodes[1] as TextNode;
      expect(textNode.localBounds.width, greaterThan(0));
      expect(textNode.localBounds.height, greaterThan(0));
    },
  );

  test(
    'sceneBuildFromJsonMap keeps legacy node-* and layer-* ids readable',
    () {
      final json = _minimalSceneJson();
      json['backgroundLayer'] = <String, Object?>{
        'nodes': <Object?>[
          <String, Object?>{..._minimalRectNodeJson(id: 'node-1')},
        ],
      };
      json['layers'] = <Object?>[
        <String, Object?>{
          'id': 'layer-1',
          'nodes': <Object?>[
            <String, Object?>{..._minimalRectNodeJson(id: 'node-2')},
          ],
        },
      ];

      final scene = model_builder.sceneBuildFromJsonMap(json);

      expect(scene.backgroundLayer, isNotNull);
      final backgroundLayer = scene.backgroundLayer;
      if (backgroundLayer == null) {
        fail('Expected legacy payload import to materialize background layer.');
      }
      expect(backgroundLayer.nodes.single.id, 'node-1');
      expect(scene.layers.single.id, 'layer-1');
      expect(scene.layers.single.nodes.single.id, 'node-2');
    },
  );

  test('sceneBuildFromJsonMap reports missing required fields', () {
    final missingCases =
        <({String label, String expectedPath, Map<String, Object?> json})>[
          (
            label: 'schemaVersion',
            expectedPath: 'schemaVersion',
            json: (() {
              final json = _minimalSceneJson();
              json.remove('schemaVersion');
              return json;
            })(),
          ),
          (
            label: 'camera',
            expectedPath: 'camera',
            json: (() {
              final json = _minimalSceneJson();
              json.remove('camera');
              return json;
            })(),
          ),
          (
            label: 'camera.offsetX',
            expectedPath: 'camera.offsetX',
            json: (() {
              final json = _minimalSceneJson();
              final camera = json['camera'] as Map<String, Object?>;
              camera.remove('offsetX');
              return json;
            })(),
          ),
          (
            label: 'layers',
            expectedPath: 'layers',
            json: (() {
              final json = _minimalSceneJson();
              json.remove('layers');
              return json;
            })(),
          ),
          (
            label: 'node.id',
            expectedPath: 'layers[0].nodes[0].id',
            json: (() {
              final json = _minimalSceneJson();
              final layer =
                  (json['layers'] as List<Object?>).first
                      as Map<String, Object?>;
              final node =
                  (layer['nodes'] as List<Object?>).first
                      as Map<String, Object?>;
              node.remove('id');
              return json;
            })(),
          ),
          (
            label: 'node.hitPadding',
            expectedPath: 'layers[0].nodes[0].hitPadding',
            json: (() {
              final json = _minimalSceneJson();
              final layer =
                  (json['layers'] as List<Object?>).first
                      as Map<String, Object?>;
              final node =
                  (layer['nodes'] as List<Object?>).first
                      as Map<String, Object?>;
              node.remove('hitPadding');
              return json;
            })(),
          ),
        ];

    for (final testCase in missingCases) {
      expect(
        () => model_builder.sceneBuildFromJsonMap(testCase.json),
        throwsA(
          predicate(
            (e) =>
                e is SceneDataException &&
                e.code == SceneDataErrorCode.missingField &&
                e.path == testCase.expectedPath,
          ),
        ),
        reason: testCase.label,
      );
    }
  });

  test('sceneBuildFromJsonMap rejects non-object background layer nodes', () {
    final json = _minimalSceneJson();
    json['backgroundLayer'] = <String, Object?>{
      'nodes': <Object?>[123],
    };

    expect(
      () => model_builder.sceneBuildFromJsonMap(json),
      throwsA(
        predicate(
          (e) =>
              e is SceneDataException &&
              e.code == SceneDataErrorCode.invalidFieldType &&
              e.path == 'backgroundLayer.nodes[0]' &&
              e.message == 'Node must be an object.',
        ),
      ),
    );
  });

  test('sceneBuildFromJsonMap rejects missing content layer id', () {
    final json = _minimalSceneJson();
    final layer =
        (json['layers'] as List<Object?>).first as Map<String, Object?>;
    layer.remove('id');

    expect(
      () => model_builder.sceneBuildFromJsonMap(json),
      throwsA(
        predicate(
          (e) =>
              e is SceneDataException &&
              e.code == SceneDataErrorCode.missingField &&
              e.path == 'layers[0].id' &&
              e.message == 'Missing required field layers[0].id.',
        ),
      ),
    );
  });

  test('sceneBuildFromJsonMap rejects non-string content layer id', () {
    final json = _minimalSceneJson();
    final layer =
        (json['layers'] as List<Object?>).first as Map<String, Object?>;
    layer['id'] = 123;

    expect(
      () => model_builder.sceneBuildFromJsonMap(json),
      throwsA(
        predicate(
          (e) =>
              e is SceneDataException &&
              e.code == SceneDataErrorCode.invalidFieldType &&
              e.path == 'layers[0].id' &&
              e.message == 'Field layers[0].id must be a string.',
        ),
      ),
    );
  });

  test('sceneBuildFromJsonMap reports missing required bool fields', () {
    final json = _minimalSceneJson();
    final layer =
        (json['layers'] as List<Object?>).first as Map<String, Object?>;
    final node =
        (layer['nodes'] as List<Object?>).first as Map<String, Object?>;
    node.remove('isVisible');

    expect(
      () => model_builder.sceneBuildFromJsonMap(json),
      throwsA(
        predicate(
          (e) =>
              e is SceneDataException &&
              e.code == SceneDataErrorCode.missingField &&
              e.path == 'layers[0].nodes[0].isVisible' &&
              e.message ==
                  'Missing required field layers[0].nodes[0].isVisible.',
        ),
      ),
    );
  });

  test('sceneBuildFromJsonMap distinguishes missingField and invalidFieldType '
      'messages for schemaVersion', () {
    final missingJson = _minimalSceneJson()..remove('schemaVersion');
    expect(
      () => model_builder.sceneBuildFromJsonMap(missingJson),
      throwsA(
        predicate(
          (e) =>
              e is SceneDataException &&
              e.code == SceneDataErrorCode.missingField &&
              e.path == 'schemaVersion' &&
              e.message == 'Missing required field schemaVersion.',
        ),
      ),
    );

    final wrongTypeJson = _minimalSceneJson();
    wrongTypeJson['schemaVersion'] = '1';
    expect(
      () => model_builder.sceneBuildFromJsonMap(wrongTypeJson),
      throwsA(
        predicate(
          (e) =>
              e is SceneDataException &&
              e.code == SceneDataErrorCode.invalidFieldType &&
              e.path == 'schemaVersion' &&
              e.message == 'Field schemaVersion must be an int.',
        ),
      ),
    );
  });

  test('sceneBuildFromJsonMap rejects unsafe integer values', () {
    final json = _minimalSceneJson();
    json['schemaVersion'] = 9007199254740992.0;

    expect(
      () => model_builder.sceneBuildFromJsonMap(json),
      throwsA(
        predicate(
          (e) =>
              e is SceneDataException &&
              e.code == SceneDataErrorCode.invalidValue &&
              e.path == 'schemaVersion' &&
              e.details['template'] == 'fieldMustBeSafeInteger' &&
              e.details['limit'] == 9007199254740991 &&
              e.message ==
                  'Field schemaVersion must be a safe integer within +/-9007199254740991.',
        ),
      ),
    );

    final intLiteralJson = _minimalSceneJson();
    intLiteralJson['schemaVersion'] = 9007199254740992;

    expect(
      () => model_builder.sceneBuildFromJsonMap(intLiteralJson),
      throwsA(
        predicate(
          (e) =>
              e is SceneDataException &&
              e.code == SceneDataErrorCode.invalidValue &&
              e.path == 'schemaVersion' &&
              e.details['template'] == 'fieldMustBeSafeInteger' &&
              e.details['limit'] == 9007199254740991 &&
              e.message ==
                  'Field schemaVersion must be a safe integer within +/-9007199254740991.',
        ),
      ),
    );
  });

  test('sceneBuildFromJsonMap rejects non-string palette color entries', () {
    final json = _minimalSceneJson();
    final palette = json['palette'] as Map<String, Object?>;
    palette['penColors'] = <Object?>[123];

    expect(
      () => model_builder.sceneBuildFromJsonMap(json),
      throwsA(
        predicate(
          (e) =>
              e is SceneDataException &&
              e.code == SceneDataErrorCode.invalidFieldType &&
              e.path == 'palette.penColors[0]' &&
              e.message == 'Items of penColors must be strings.',
        ),
      ),
    );
  });

  test('sceneBuildFromJsonMap rejects invalid color literals with details', () {
    final json = _minimalSceneJson();
    (json['background'] as Map<String, Object?>)['color'] = '#GGGGGG';

    expect(
      () => model_builder.sceneBuildFromJsonMap(json),
      throwsA(
        predicate(
          (e) =>
              e is SceneDataException &&
              e.code == SceneDataErrorCode.invalidValue &&
              e.path == 'background.color' &&
              e.details['template'] == 'invalidColorLiteral' &&
              e.details['value'] == '#GGGGGG' &&
              e.message == 'Invalid color: #GGGGGG.',
        ),
      ),
    );
  });

  test('sceneBuildFromJsonMap rejects map keys that are not strings', () {
    final json = _minimalSceneJson();
    json['camera'] = <Object?, Object?>{'offsetX': 0, 'offsetY': 0, 1: 0};

    expect(
      () => model_builder.sceneBuildFromJsonMap(json),
      throwsA(
        predicate(
          (e) =>
              e is SceneDataException &&
              e.code == SceneDataErrorCode.invalidFieldType &&
              e.message == 'JSON object keys must be strings.',
        ),
      ),
    );
  });

  test('sceneBuildFromJsonMap rejects too many content layers', () {
    final json = _minimalSceneJson();
    json['layers'] = <Object?>[
      for (var i = 0; i < kMaxContentLayersPerScene + 1; i++)
        <String, Object?>{'id': 'layer-$i', 'nodes': <Object?>[]},
    ];

    expect(
      () => model_builder.sceneBuildFromJsonMap(json),
      throwsA(
        predicate(
          (e) =>
              e is SceneDataException &&
              e.code == SceneDataErrorCode.invalidValue &&
              e.path == 'layers',
        ),
      ),
    );
  });

  test(
    'sceneBuildFromJsonMap reports content layer overflow before extra layer shape errors',
    () {
      final json = _minimalSceneJson();
      json['layers'] = <Object?>[
        for (var i = 0; i < kMaxContentLayersPerScene; i++)
          <String, Object?>{'id': 'layer-$i', 'nodes': <Object?>[]},
        null,
      ];

      expect(
        () => model_builder.sceneBuildFromJsonMap(json),
        throwsA(
          predicate(
            (e) =>
                e is SceneDataException &&
                e.code == SceneDataErrorCode.invalidValue &&
                e.path == 'layers',
          ),
        ),
      );
    },
  );

  test('sceneBuildFromJsonMap rejects too many nodes in scene', () {
    final json = _minimalSceneJson();
    json['layers'] = <Object?>[
      <String, Object?>{
        'id': 'layer-0',
        'nodes': <Object?>[
          for (var i = 0; i < kMaxNodesPerScene + 1; i++)
            _minimalRectNodeJson(id: 'n$i'),
        ],
      },
    ];

    expect(
      () => model_builder.sceneBuildFromJsonMap(json),
      throwsA(
        predicate(
          (e) =>
              e is SceneDataException &&
              e.code == SceneDataErrorCode.invalidValue &&
              e.path == 'layers[0].nodes',
        ),
      ),
    );
  });

  test(
    'sceneBuildFromJsonMap reports node overflow before extra node shape errors',
    () {
      final json = _minimalSceneJson();
      json['layers'] = <Object?>[
        <String, Object?>{
          'id': 'layer-0',
          'nodes': <Object?>[
            for (var i = 0; i < kMaxNodesPerScene; i++)
              _minimalRectNodeJson(id: 'n$i'),
            <String, Object?>{
              'id': 'overflow-node',
              'transform': <String, Object?>{
                'a': 1,
                'b': 0,
                'c': 0,
                'd': 1,
                'tx': 0,
                'ty': 0,
              },
            },
          ],
        },
      ];

      expect(
        () => model_builder.sceneBuildFromJsonMap(json),
        throwsA(
          predicate(
            (e) =>
                e is SceneDataException &&
                e.code == SceneDataErrorCode.invalidValue &&
                e.path == 'layers[0].nodes',
          ),
        ),
      );
    },
  );

  test(
    'sceneBuildFromJsonMap rejects aggregated node overflow across background and content layers',
    () {
      final json = _minimalSceneJson();
      final contentNode = _minimalRectNodeJson(id: 'fg');
      json['backgroundLayer'] = <String, Object?>{
        'nodes': <Object?>[
          for (var i = 0; i < kMaxNodesPerScene; i++)
            _minimalRectNodeJson(id: 'bg-$i'),
        ],
      };
      json['layers'] = <Object?>[
        <String, Object?>{
          'id': 'layer-0',
          'nodes': <Object?>[contentNode],
        },
      ];

      expect(
        () => model_builder.sceneBuildFromJsonMap(json),
        throwsA(
          predicate(
            (e) =>
                e is SceneDataException &&
                e.code == SceneDataErrorCode.invalidValue &&
                e.path == 'layers[0].nodes',
          ),
        ),
      );
    },
  );

  test('sceneBuildFromJsonMap rejects too many stroke points', () {
    // INV:INV-SER-SHARED-STROKE-POINT-LIMIT
    final json = _minimalSceneJson();
    json['layers'] = <Object?>[
      <String, Object?>{
        'id': 'layer-0',
        'nodes': <Object?>[
          <String, Object?>{
            ..._minimalRectNodeJson(id: 's1'),
            'type': 'stroke',
            'localPoints': <Object?>[
              for (var i = 0; i < kMaxStrokePointsPerNode + 1; i++)
                <String, Object?>{'x': i.toDouble(), 'y': 0.0},
            ],
            'thickness': 1,
            'color': '#FF000000',
          },
        ],
      },
    ];

    expect(
      () => model_builder.sceneBuildFromJsonMap(json),
      throwsA(
        predicate(
          (e) =>
              e is SceneDataException &&
              e.code == SceneDataErrorCode.invalidValue &&
              e.path == 'layers[0].nodes[0].localPoints' &&
              e.details['template'] == 'maxPoints' &&
              e.details['maxPoints'] == kMaxStrokePointsPerNode &&
              e.message ==
                  'Field layers[0].nodes[0].localPoints must contain at most '
                      '$kMaxStrokePointsPerNode points.',
        ),
      ),
    );
  });

  test('sceneBuildFromJsonMap rejects oversized svgPathData', () {
    final json = _minimalSceneJson();
    json['layers'] = <Object?>[
      <String, Object?>{
        'id': 'layer-0',
        'nodes': <Object?>[
          <String, Object?>{
            ..._minimalRectNodeJson(id: 'p1'),
            'type': 'path',
            'svgPathData':
                "M0 0 ${List<String>.filled(kMaxSvgPathDataLength + 1, 'L1 1').join(' ')}",
            'fillRule': 'nonZero',
            'strokeWidth': 1,
          },
        ],
      },
    ];

    expect(
      () => model_builder.sceneBuildFromJsonMap(json),
      throwsA(
        predicate(
          (e) =>
              e is SceneDataException &&
              e.code == SceneDataErrorCode.invalidValue &&
              e.path == 'layers[0].nodes[0].svgPathData',
        ),
      ),
    );
  });

  test('sceneBuildFromJsonMap rejects oversized text payload', () {
    final json = _minimalSceneJson();
    json['layers'] = <Object?>[
      <String, Object?>{
        'id': 'layer-0',
        'nodes': <Object?>[
          <String, Object?>{
            ...(_minimalRectNodeJson(id: 't1')
              ..remove('size')
              ..remove('strokeWidth')),
            'type': 'text',
            'text': List<String>.filled(kMaxTextLength + 1, 'a').join(),
            'fontSize': 14,
            'color': '#FF000000',
            'align': 'left',
            'textDirection': 'ltr',
            'isBold': false,
            'isItalic': false,
            'isUnderline': false,
          },
        ],
      },
    ];

    expect(
      () => model_builder.sceneBuildFromJsonMap(json),
      throwsA(
        predicate(
          (e) =>
              e is SceneDataException &&
              e.code == SceneDataErrorCode.invalidValue &&
              e.path == 'layers[0].nodes[0].text',
        ),
      ),
    );
  });

  test('sceneBuildFromJsonMap rejects oversized derived text bounds', () {
    final json = _minimalSceneJson();
    json['layers'] = <Object?>[
      <String, Object?>{
        'id': 'layer-0',
        'nodes': <Object?>[
          <String, Object?>{
            ...(_minimalRectNodeJson(id: 't-derived-overflow')
              ..remove('size')
              ..remove('strokeWidth')),
            'type': 'text',
            'text': List<String>.filled(30000, 'W').join(),
            'fontSize': 1000,
            'color': '#FF000000',
            'align': 'left',
            'textDirection': 'ltr',
            'isBold': false,
            'isItalic': false,
            'isUnderline': false,
            'maxWidth': null,
          },
        ],
      },
    ];

    expect(
      () => model_builder.sceneBuildFromJsonMap(json),
      throwsA(
        predicate(
          (e) =>
              e is SceneDataException &&
              e.code == SceneDataErrorCode.outOfRange &&
              e.path == 'layers[0].nodes[0].derivedBounds.w',
        ),
      ),
    );
  });

  test('sceneBuildFromJsonMap rejects oversized palette penColors', () {
    // INV:INV-SER-SHARED-PALETTE-ITEM-LIMIT
    final json = _minimalSceneJson();
    (json['palette'] as Map<String, Object?>)['penColors'] = <Object?>[
      for (var i = 0; i < kMaxPaletteItems + 1; i++) '#FF000000',
    ];

    expect(
      () => model_builder.sceneBuildFromJsonMap(json),
      throwsA(
        predicate(
          (e) =>
              e is SceneDataException &&
              e.code == SceneDataErrorCode.invalidValue &&
              e.path == 'palette.penColors' &&
              e.details['template'] == 'maxItems' &&
              e.details['maxItems'] == kMaxPaletteItems &&
              e.message ==
                  'Field palette.penColors must contain at most '
                      '$kMaxPaletteItems items.',
        ),
      ),
    );
  });

  test('sceneBuildFromJsonMap rejects oversized palette gridSizes', () {
    final json = _minimalSceneJson();
    (json['palette'] as Map<String, Object?>)['gridSizes'] = <Object?>[
      for (var i = 0; i < kMaxPaletteItems + 1; i++) i + 1,
    ];

    expect(
      () => model_builder.sceneBuildFromJsonMap(json),
      throwsA(
        predicate(
          (e) =>
              e is SceneDataException &&
              e.code == SceneDataErrorCode.invalidValue &&
              e.path == 'palette.gridSizes' &&
              e.details['template'] == 'maxItems' &&
              e.details['maxItems'] == kMaxPaletteItems &&
              e.message ==
                  'Field palette.gridSizes must contain at most '
                      '$kMaxPaletteItems items.',
        ),
      ),
    );
  });

  test('sceneBuildFromJsonMap rejects non-finite scene metadata values', () {
    final cameraJson = _minimalSceneJson();
    (cameraJson['camera'] as Map<String, Object?>)['offsetX'] = double.infinity;

    expect(
      () => model_builder.sceneBuildFromJsonMap(cameraJson),
      throwsA(
        predicate(
          (e) =>
              e is SceneDataException &&
              e.code == SceneDataErrorCode.invalidValue &&
              e.path == 'camera.offsetX' &&
              e.message == 'Field offsetX must be finite.',
        ),
      ),
    );

    final gridJson = _minimalSceneJson();
    ((gridJson['background'] as Map<String, Object?>)['grid']
            as Map<String, Object?>)['cellSize'] =
        double.infinity;

    expect(
      () => model_builder.sceneBuildFromJsonMap(gridJson),
      throwsA(
        predicate(
          (e) =>
              e is SceneDataException &&
              e.code == SceneDataErrorCode.invalidValue &&
              e.path == 'background.grid.cellSize' &&
              e.message == 'Field cellSize must be finite.',
        ),
      ),
    );
  });

  test('sceneBuildFromJsonMap rejects out-of-range scene metadata values', () {
    final cameraJson = _minimalSceneJson();
    (cameraJson['camera'] as Map<String, Object?>)['offsetX'] =
        sceneCoordMax + 1;

    expect(
      () => model_builder.sceneBuildFromJsonMap(cameraJson),
      throwsA(
        predicate(
          (e) =>
              e is SceneDataException &&
              e.code == SceneDataErrorCode.outOfRange &&
              e.path == 'camera.offsetX',
        ),
      ),
    );

    final gridJson = _minimalSceneJson();
    ((gridJson['background'] as Map<String, Object?>)['grid']
            as Map<String, Object?>)['cellSize'] =
        sceneSizeMax + 1;

    expect(
      () => model_builder.sceneBuildFromJsonMap(gridJson),
      throwsA(
        predicate(
          (e) =>
              e is SceneDataException &&
              e.code == SceneDataErrorCode.outOfRange &&
              e.path == 'background.grid.cellSize',
        ),
      ),
    );
  });

  test(
    'typed text/stroke/palette boundaries enforce shared model invariants',
    () {
      // INV:INV-SER-TEXT-DIRECTION-EXPLICIT
      expect(
        () => StrokeNodeSnapshot(
          id: 'stroke-too-many',
          points: <Offset>[
            for (var i = 0; i < kMaxStrokePointsPerNode + 1; i++)
              Offset(i.toDouble(), 0),
          ],
          thickness: 1,
          color: const Color(0xFF000000),
        ),
        throwsArgumentError,
      );

      expect(
        () => ScenePaletteSnapshot(
          penColors: <Color>[
            for (var i = 0; i < kMaxPaletteItems + 1; i++)
              const Color(0xFF000000),
          ],
        ),
        throwsArgumentError,
      );

      final text = TextNodeSnapshot(
        id: 'text-rtl',
        text: 'rtl',
        fontSize: 16,
        color: const Color(0xFF000000),
        textDirection: TextDirection.rtl,
      );
      expect(text.textDirection, TextDirection.rtl);
    },
  );

  test('sceneBuildFromJsonMap rejects missing textDirection', () {
    final json = _minimalSceneJson();
    json['layers'] = <Object?>[
      <String, Object?>{
        'id': 'layer-0',
        'nodes': <Object?>[
          <String, Object?>{
            ...(_minimalRectNodeJson(id: 't-legacy')
              ..remove('size')
              ..remove('strokeWidth')),
            'type': 'text',
            'text': 'Legacy text',
            'fontSize': 14,
            'color': '#FF000000',
            'align': 'start',
            'isBold': false,
            'isItalic': false,
            'isUnderline': false,
          },
        ],
      },
    ];

    expect(
      () => model_builder.sceneBuildFromJsonMap(json),
      throwsA(
        predicate(
          (e) =>
              e is SceneDataException &&
              e.code == SceneDataErrorCode.missingField &&
              e.path == 'layers[0].nodes[0].textDirection' &&
              e.message ==
                  'Missing required field layers[0].nodes[0].textDirection.',
        ),
      ),
    );
  });

  test('sceneBuildFromJsonMap rejects unknown textDirection', () {
    final json = _minimalSceneJson();
    json['layers'] = <Object?>[
      <String, Object?>{
        'id': 'layer-0',
        'nodes': <Object?>[
          <String, Object?>{
            ...(_minimalRectNodeJson(id: 't-invalid-direction')
              ..remove('size')
              ..remove('strokeWidth')),
            'type': 'text',
            'text': 'Invalid direction',
            'fontSize': 14,
            'color': '#FF000000',
            'align': 'start',
            'textDirection': 'sideways',
            'isBold': false,
            'isItalic': false,
            'isUnderline': false,
          },
        ],
      },
    ];

    expect(
      () => model_builder.sceneBuildFromJsonMap(json),
      throwsA(
        predicate(
          (e) =>
              e is SceneDataException &&
              e.code == SceneDataErrorCode.invalidValue &&
              e.path == 'layers[0].nodes[0].textDirection' &&
              e.details['template'] == 'unknownEnumValue' &&
              e.details['value'] == 'sideways' &&
              e.message == 'Unknown text direction: sideways.',
        ),
      ),
    );
  });

  test(
    'sceneCanonicalizeAndValidateSnapshot rejects oversized stroke points and palette gridSizes',
    () {
      expect(
        () => sceneSnapshotFromValidated(
          layers: <ContentLayerSnapshot>[
            ContentLayerSnapshot(
              id: 'layer-auto-overflow-stroke',
              nodes: <NodeSnapshot>[
                strokeNodeSnapshotFromValidated(
                  common: nodeSnapshotCommonFieldsFromValidated(
                    id: 'stroke-overflow-policy',
                    instanceRevision: 1,
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
                    points: <Offset>[
                      for (var i = 0; i < kMaxStrokePointsPerNode + 1; i++)
                        Offset(i.toDouble(), 0),
                    ],
                    thickness: 1,
                    color: const Color(0xFF000000),
                  ),
                ),
              ],
            ),
          ],
        ),
        throwsA(
          isA<ArgumentError>().having((error) => error.name, 'name', 'points'),
        ),
      );

      final oversizedPalette = unsafeMaterializeSceneSnapshot(
        SceneSnapshotBacking(
          layers: <ContentLayerSnapshotBacking>[
            contentLayerSnapshotBackingFromValidated(
              id: 'layer-auto-overflow-palette',
            ),
          ],
          palette: ScenePaletteSnapshotBacking(
            gridSizes: <double>[
              for (var i = 0; i < kMaxPaletteItems + 1; i++) i + 1,
            ],
          ),
        ),
      );

      expect(
        () => model_builder.sceneCanonicalizeAndValidateSnapshot(
          oversizedPalette,
        ),
        throwsA(
          predicate(
            (e) =>
                e is SceneDataException &&
                e.code == SceneDataErrorCode.invalidValue &&
                e.path == 'palette.gridSizes' &&
                e.details['template'] == 'maxItems' &&
                e.details['maxItems'] == kMaxPaletteItems &&
                e.message ==
                    'Field palette.gridSizes must contain at most '
                        '$kMaxPaletteItems items.',
          ),
        ),
      );
    },
  );

  test(
    'sceneCanonicalizeAndValidateSnapshot and ScenePolicy.validateImportSnapshot keep canonical out-of-range paths',
    () {
      final scenarios =
          <({String description, SceneSnapshot snapshot, String path})>[
            (
              description: 'line start.x',
              snapshot: SceneSnapshot(
                layers: <ContentLayerSnapshot>[
                  ContentLayerSnapshot(
                    id: 'layer-auto-line-start',
                    nodes: <NodeSnapshot>[
                      LineNodeSnapshot(
                        id: 'line-start',
                        start: Offset(sceneCoordMax + 1, 0),
                        end: const Offset(1, 1),
                        thickness: 1,
                        color: const Color(0xFF000000),
                      ),
                    ],
                  ),
                ],
              ),
              path: 'layers[0].nodes[0].start.x',
            ),
            (
              description: 'line end.y',
              snapshot: SceneSnapshot(
                layers: <ContentLayerSnapshot>[
                  ContentLayerSnapshot(
                    id: 'layer-auto-line-end',
                    nodes: <NodeSnapshot>[
                      LineNodeSnapshot(
                        id: 'line-end',
                        start: const Offset(0, 0),
                        end: Offset(1, sceneCoordMax + 1),
                        thickness: 1,
                        color: const Color(0xFF000000),
                      ),
                    ],
                  ),
                ],
              ),
              path: 'layers[0].nodes[0].end.y',
            ),
            (
              description: 'stroke points[1].x',
              snapshot: SceneSnapshot(
                layers: <ContentLayerSnapshot>[
                  ContentLayerSnapshot(
                    id: 'layer-auto-stroke-x',
                    nodes: <NodeSnapshot>[
                      StrokeNodeSnapshot(
                        id: 'stroke-x',
                        points: <Offset>[
                          const Offset(0, 0),
                          Offset(sceneCoordMax + 1, 1),
                        ],
                        thickness: 1,
                        color: const Color(0xFF000000),
                      ),
                    ],
                  ),
                ],
              ),
              path: 'layers[0].nodes[0].points[1].x',
            ),
            (
              description: 'stroke points[1].y',
              snapshot: SceneSnapshot(
                layers: <ContentLayerSnapshot>[
                  ContentLayerSnapshot(
                    id: 'layer-auto-stroke-y',
                    nodes: <NodeSnapshot>[
                      StrokeNodeSnapshot(
                        id: 'stroke-y',
                        points: <Offset>[
                          const Offset(0, 0),
                          Offset(1, sceneCoordMax + 1),
                        ],
                        thickness: 1,
                        color: const Color(0xFF000000),
                      ),
                    ],
                  ),
                ],
              ),
              path: 'layers[0].nodes[0].points[1].y',
            ),
          ];

      for (final scenario in scenarios) {
        for (final validate
            in <({String label, SceneSnapshot Function(SceneSnapshot) run})>[
              (
                label: 'sceneCanonicalizeAndValidateSnapshot',
                run: model_builder.sceneCanonicalizeAndValidateSnapshot,
              ),
              (
                label: 'ScenePolicy.validateImportSnapshot',
                run: ScenePolicy.validateImportSnapshot,
              ),
            ]) {
          expect(
            () => validate.run(scenario.snapshot),
            throwsA(
              predicate(
                (e) =>
                    e is SceneDataException &&
                    e.code == SceneDataErrorCode.outOfRange &&
                    e.path == scenario.path &&
                    e.details['template'] == 'outOfRange' &&
                    e.details['min'] == -sceneCoordMax &&
                    e.details['max'] == sceneCoordMax,
              ),
            ),
            reason: '${scenario.description} via ${validate.label}',
          );
        }
      }
    },
  );

  test(
    'sceneCanonicalizeAndValidateSnapshot validates optional text layout fields and non-uniform path transforms',
    () {
      final snapshot = sceneSnapshotFromValidated(
        layers: <ContentLayerSnapshot>[
          contentLayerSnapshotFromValidated(
            id: 'layer-auto-policy-ranges',
            nodes: <NodeSnapshot>[
              TextNodeSnapshot(
                id: 'text-policy-ranges',
                text: 'Sized text',
                transform: const Transform2D(
                  a: 1,
                  b: 0,
                  c: 0,
                  d: 1.5,
                  tx: 0,
                  ty: 0,
                ),
                fontSize: 16,
                color: const Color(0xFF000000),
                textDirection: TextDirection.ltr,
                maxWidth: 120,
                lineHeight: 1.25,
              ),
              PathNodeSnapshot(
                id: 'path-policy-ranges',
                transform: const Transform2D(
                  a: 1.2,
                  b: 0,
                  c: 0,
                  d: 0.8,
                  tx: 0,
                  ty: 0,
                ),
                svgPathData: 'M0 0 L5 0 L5 5 Z',
                strokeWidth: 2,
                fillRule: PathFillRule.evenOdd,
              ),
            ],
          ),
        ],
      );

      final validated = model_builder.sceneCanonicalizeAndValidateSnapshot(
        snapshot,
      );

      expect(validated.layers.single.nodes, hasLength(2));
    },
  );

  test('public snapshot boundary rejects oversized image ids', () {
    expect(
      () => ImageNodeSnapshot(
        id: 'img-boundary',
        imageId: 'x' * (kMaxImageIdLength + 1),
        size: const Size(1, 1),
      ),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('sceneValidateSnapshotValues skips duplicate node-id policy', () {
    SceneDataException asSceneDataException({
      required Object? value,
      required String field,
      required String message,
    }) {
      return SceneDataException(
        code: SceneDataErrorCode.invalidValue,
        path: field,
        message: 'Field $field $message',
        source: value,
      );
    }

    expect(
      () => value_validation.sceneValidateSnapshotValues(
        unsafeMaterializeSceneSnapshot(
          SceneSnapshotBacking(
            layers: <ContentLayerSnapshotBacking>[
              contentLayerSnapshotBackingFromValidated(
                id: 'layer-auto-2',
                nodes: <NodeSnapshotBacking>[
                  nodeSnapshotBackingOf(
                    RectNodeSnapshot(id: 'dup', size: const Size(1, 1)),
                  ),
                  nodeSnapshotBackingOf(
                    RectNodeSnapshot(id: 'dup', size: const Size(1, 1)),
                  ),
                ],
              ),
            ],
          ),
        ),
        onError:
            ({
              required Object? value,
              required String field,
              String? message,
              SceneDataDiagnosticDescriptor? diagnostic,
            }) {
              if (diagnostic != null) {
                throw diagnostic.toException(path: field, source: value);
              }
              throw asSceneDataException(
                value: value,
                field: field,
                message: message ?? 'is invalid.',
              );
            },
        requirePositiveGridCellSize: true,
        requireEnabledMinGridCellSize: true,
      ),
      returnsNormally,
    );
  });

  test('sceneValidateSnapshotValues skips duplicate content-layer policy', () {
    SceneDataException asSceneDataException({
      required Object? value,
      required String field,
      required String message,
    }) {
      return SceneDataException(
        code: SceneDataErrorCode.invalidValue,
        path: field,
        message: 'Field $field $message',
        source: value,
      );
    }

    expect(
      () => value_validation.sceneValidateSnapshotValues(
        unsafeMaterializeSceneSnapshot(
          SceneSnapshotBacking(
            layers: <ContentLayerSnapshotBacking>[
              contentLayerSnapshotBackingFromValidated(id: 'layer-auto-dup-a'),
              contentLayerSnapshotBackingFromValidated(id: 'layer-auto-dup-a'),
            ],
          ),
        ),
        onError:
            ({
              required Object? value,
              required String field,
              String? message,
              SceneDataDiagnosticDescriptor? diagnostic,
            }) {
              if (diagnostic != null) {
                throw diagnostic.toException(path: field, source: value);
              }
              throw asSceneDataException(
                value: value,
                field: field,
                message: message ?? 'is invalid.',
              );
            },
        requirePositiveGridCellSize: true,
        requireEnabledMinGridCellSize: true,
      ),
      returnsNormally,
    );
  });

  test('sceneBuildFromSnapshot rejects duplicate ids in background layer', () {
    final snapshot = _duplicateBackgroundNodeSnapshotFromInternalBypass();

    expect(
      () => model_builder.sceneBuildFromSnapshot(snapshot),
      throwsA(
        predicate(
          (e) =>
              e is SceneDataException &&
              e.code == SceneDataErrorCode.duplicateNodeId &&
              e.path == 'backgroundLayer.nodes[1].id' &&
              e.message == 'Must be unique across scene layers.',
        ),
      ),
    );
  });

  test(
    'SceneImportDraft keeps ordinary construction validated and raw bypass explicit',
    () {
      final validatedDraft = SceneImportDraft(
        camera: const CameraSnapshotBacking(offset: Offset(12, -34)),
      );

      expect(validatedDraft.camera.offset, const Offset(12, -34));

      expect(
        () => SceneImportDraft(
          camera: const CameraSnapshotBacking(offset: Offset(double.nan, 0)),
        ),
        throwsA(
          isA<ArgumentError>().having(
            (error) => error.name,
            'name',
            'camera.offset.dx',
          ),
        ),
      );

      final rawDraft = SceneImportDraft.fromBacking(
        SceneSnapshotBacking(
          camera: const CameraSnapshotBacking(
            offset: Offset(double.nan, sceneCoordMax + 1),
          ),
        ),
      );

      expect(rawDraft.camera.offset.dx.isNaN, isTrue);
      expect(rawDraft.camera.offset.dy, sceneCoordMax + 1);
    },
  );

  test(
    'sceneValidateSnapshotValues skips background duplicate-node policy',
    () {
      SceneDataException asSceneDataException({
        required Object? value,
        required String field,
        required String message,
      }) {
        return SceneDataException(
          code: SceneDataErrorCode.invalidValue,
          path: field,
          message: 'Field $field $message',
          source: value,
        );
      }

      expect(
        () => value_validation.sceneValidateSnapshotValues(
          unsafeMaterializeSceneSnapshot(
            SceneSnapshotBacking(
              backgroundLayer: backgroundLayerSnapshotBackingFromValidated(
                nodes: <NodeSnapshotBacking>[
                  nodeSnapshotBackingOf(
                    RectNodeSnapshot(id: 'dup-bg', size: const Size(1, 1)),
                  ),
                  nodeSnapshotBackingOf(
                    RectNodeSnapshot(id: 'dup-bg', size: const Size(1, 1)),
                  ),
                ],
              ),
              layers: <ContentLayerSnapshotBacking>[
                contentLayerSnapshotBackingFromValidated(id: 'layer-auto-4'),
              ],
            ),
          ),
          onError:
              ({
                required Object? value,
                required String field,
                String? message,
                SceneDataDiagnosticDescriptor? diagnostic,
              }) {
                if (diagnostic != null) {
                  throw diagnostic.toException(path: field, source: value);
                }
                throw asSceneDataException(
                  value: value,
                  field: field,
                  message: message ?? 'is invalid.',
                );
              },
          requirePositiveGridCellSize: true,
          requireEnabledMinGridCellSize: true,
        ),
        returnsNormally,
      );
    },
  );

  test('sceneValidateCore reports background duplicate node ids', () {
    expect(
      () => model_builder.sceneValidateCore(
        Scene(
          backgroundLayer: BackgroundLayer(
            nodes: <SceneNode>[
              RectNode(id: 'dup-bg', size: const Size(1, 1)),
              RectNode(id: 'dup-bg', size: const Size(1, 1)),
            ],
          ),
          layers: <ContentLayer>[ContentLayer(id: 'layer-auto-6')],
        ),
      ),
      throwsA(
        predicate(
          (e) =>
              e is SceneDataException &&
              e.code == SceneDataErrorCode.duplicateNodeId &&
              e.path == 'backgroundLayer.nodes[1].id' &&
              e.message == 'Must be unique across scene layers.',
        ),
      ),
    );
  });

  test('sceneValidateCore reports duplicate content layer ids', () {
    expect(
      () => model_builder.sceneValidateCore(
        Scene(
          layers: <ContentLayer>[
            ContentLayer(id: 'layer-auto-dup-b'),
            ContentLayer(id: 'layer-auto-dup-b'),
          ],
        ),
      ),
      throwsA(
        predicate(
          (e) =>
              e is SceneDataException &&
              e.code == SceneDataErrorCode.duplicateLayerId &&
              e.path == 'layers[1].id' &&
              e.details['template'] == 'duplicateLayerId' &&
              e.message ==
                  'Field layers[1].id must be unique across content layers.',
        ),
      ),
    );
  });

  test('sceneValidatePositiveInt reports non-positive values', () {
    SceneDataException asSceneDataException({
      required Object? value,
      required String field,
      required String message,
    }) {
      return SceneDataException(
        code: SceneDataErrorCode.invalidValue,
        path: field,
        message: 'Field $field $message',
        source: value,
      );
    }

    expect(
      () => value_validation.sceneValidatePositiveInt(
        0,
        field: 'instanceRevision',
        onError:
            ({
              required Object? value,
              required String field,
              String? message,
              SceneDataDiagnosticDescriptor? diagnostic,
            }) {
              if (diagnostic != null) {
                throw diagnostic.toException(path: field, source: value);
              }
              throw asSceneDataException(
                value: value,
                field: field,
                message: message ?? 'is invalid.',
              );
            },
      ),
      throwsA(
        predicate(
          (e) =>
              e is SceneDataException &&
              e.path == 'instanceRevision' &&
              e.message == 'Field instanceRevision must be > 0.',
        ),
      ),
    );
  });
}

final class _UnsupportedSceneSnapshot extends SceneSnapshot {
  _UnsupportedSceneSnapshot();
}
