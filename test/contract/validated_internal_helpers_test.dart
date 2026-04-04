import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/src/contract/scene_contract_limits.dart';
import 'package:iwb_canvas_engine/src/contract/scene_model_invariants.dart';
import 'package:iwb_canvas_engine/src/contract/validated/finite_offset_value.dart';
import 'package:iwb_canvas_engine/src/contract/validated/font_family_value.dart';
import 'package:iwb_canvas_engine/src/contract/validated/image_id_value.dart';
import 'package:iwb_canvas_engine/src/contract/validated/instance_revision_value.dart';
import 'package:iwb_canvas_engine/src/contract/validated/layer_id_value.dart';
import 'package:iwb_canvas_engine/src/contract/validated/node_id_value.dart';
import 'package:iwb_canvas_engine/src/contract/validated/non_negative_finite_double_value.dart';
import 'package:iwb_canvas_engine/src/contract/validated/opacity_value.dart';
import 'package:iwb_canvas_engine/src/contract/validated/positive_finite_double_value.dart';
import 'package:iwb_canvas_engine/src/contract/validated/svg_path_data_value.dart';
import 'package:iwb_canvas_engine/src/contract/validated/text_content_value.dart';

void main() {
  test('contract boundary limits stay positive and ordered', () {
    expect(sceneContractLimitValues(), hasLength(11));
    expect(kMaxContentLayersPerScene, greaterThan(0));
    expect(kMaxNodesPerScene, greaterThan(0));
    expect(kMaxSvgPathDataLength, greaterThan(0));
    expect(kMaxLayerIdLength, greaterThan(0));
    expect(kMaxNodeIdLength, greaterThan(0));
    expect(kMaxImageIdLength, greaterThanOrEqualTo(kMaxNodeIdLength));
    expect(kMaxFontFamilyLength, greaterThan(0));
    expect(kMaxTextLength, greaterThan(kMaxFontFamilyLength));
    expect(kMaxStrokePointsPerNode, greaterThan(0));
    expect(kMaxPaletteItems, greaterThan(0));
    expect(kMaxRawSceneJsonLength, greaterThan(kMaxTextLength));
  });

  test('shared scene model invariant helpers enforce shared count limits', () {
    expect(
      sceneStrokePointCountViolationMessage(kMaxStrokePointsPerNode),
      isNull,
    );
    expect(
      sceneStrokePointCountViolationMessage(kMaxStrokePointsPerNode + 1),
      'must contain at most $kMaxStrokePointsPerNode points.',
    );
    expect(
      () =>
          validateStrokePointCount(kMaxStrokePointsPerNode + 1, name: 'points'),
      throwsA(
        isA<ArgumentError>().having(
          (error) => error.message,
          'message',
          'Must contain at most $kMaxStrokePointsPerNode points.',
        ),
      ),
    );

    expect(scenePaletteItemCountViolationMessage(kMaxPaletteItems), isNull);
    expect(
      scenePaletteItemCountViolationMessage(kMaxPaletteItems + 1),
      'must contain at most $kMaxPaletteItems items.',
    );
    expect(
      () => validatePaletteItemCount(kMaxPaletteItems + 1, name: 'palette'),
      throwsA(
        isA<ArgumentError>().having(
          (error) => error.message,
          'message',
          'Must contain at most $kMaxPaletteItems items.',
        ),
      ),
    );
  });

  test('validated value types implement equality and hashCode explicitly', () {
    final finiteOffsetA = FiniteOffsetValue.of(const Offset(1, 2));
    final finiteOffsetB = FiniteOffsetValue.fromJson(const <String, Object?>{
      'x': 1,
      'y': 2,
    }, path: 'offset');
    expect(finiteOffsetA == finiteOffsetB, isTrue);
    expect(finiteOffsetA.hashCode, finiteOffsetB.hashCode);

    final fontFamilyA = FontFamilyValue.parse('Sans');
    final fontFamilyB = FontFamilyValue.fromJson('Sans', path: 'fontFamily');
    expect(fontFamilyA == fontFamilyB, isTrue);
    expect(fontFamilyA.hashCode, fontFamilyB.hashCode);

    final imageIdA = ImageIdValue.parse('asset:sample');
    final imageIdB = ImageIdValue.fromJson('asset:sample', path: 'imageId');
    expect(imageIdA == imageIdB, isTrue);
    expect(imageIdA.hashCode, imageIdB.hashCode);

    final revisionA = InstanceRevisionValue.of(3);
    final revisionB = InstanceRevisionValue.fromJson(
      3,
      path: 'instanceRevision',
    );
    expect(revisionA == revisionB, isTrue);
    expect(revisionA.hashCode, revisionB.hashCode);

    final layerIdA = LayerIdValue.parse('layer-fast');
    final layerIdB = LayerIdValue.fromJson('layer-fast', path: 'layer.id');
    expect(layerIdA == layerIdB, isTrue);
    expect(layerIdA.hashCode, layerIdB.hashCode);
    expect(layerIdA.toString(), 'LayerIdValue(layer-fast)');

    final nodeIdA = NodeIdValue.parse('node-fast');
    final nodeIdB = NodeIdValue.fromJson('node-fast', path: 'node.id');
    expect(nodeIdA == nodeIdB, isTrue);
    expect(nodeIdA.hashCode, nodeIdB.hashCode);
    expect(nodeIdA.toString(), 'NodeIdValue(node-fast)');

    final nonNegativeA = NonNegativeFiniteDoubleValue.fromJson(
      1,
      path: 'value',
    );
    final nonNegativeB = NonNegativeFiniteDoubleValue.of(1);
    expect(nonNegativeA == nonNegativeB, isTrue);
    expect(nonNegativeA.hashCode, nonNegativeB.hashCode);

    final opacityA = OpacityValue.fromJson(0.5, path: 'opacity');
    final opacityB = OpacityValue.of(0.5);
    expect(opacityA == opacityB, isTrue);
    expect(opacityA.hashCode, opacityB.hashCode);

    final positiveA = PositiveFiniteDoubleValue.fromJson(2, path: 'value');
    final positiveB = PositiveFiniteDoubleValue.parse('2');
    expect(positiveA == positiveB, isTrue);
    expect(positiveA.hashCode, positiveB.hashCode);

    final svgA = SvgPathDataValue.parse('M0 0 L1 1');
    final svgB = SvgPathDataValue.fromJson('M0 0 L1 1', path: 'svgPathData');
    expect(svgA == svgB, isTrue);
    expect(svgA.hashCode, svgB.hashCode);

    final textA = TextContentValue.parse('hello');
    final textB = TextContentValue.fromJson('hello', path: 'text');
    expect(textA == textB, isTrue);
    expect(textA.hashCode, textB.hashCode);
  });
}
