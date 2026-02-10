import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/basic.dart';

// INV:INV-V2-NO-EXTERNAL-MUTATION

void main() {
  test('PatchField supports absent/value/nullValue states', () {
    const absent = PatchField<String>.absent();
    const value = PatchField<String>.value('node');
    const nullValue = PatchField<String?>.nullValue();

    expect(absent.state, PatchFieldState.absent);
    expect(absent.isAbsent, isTrue);
    expect(absent.hasValue, isFalse);
    expect(absent.isNullValue, isFalse);
    expect(absent.valueOrNull, isNull);
    expect(() => absent.value, throwsStateError);

    expect(value.state, PatchFieldState.value);
    expect(value.isAbsent, isFalse);
    expect(value.hasValue, isTrue);
    expect(value.isNullValue, isFalse);
    expect(value.value, 'node');
    expect(value.valueOrNull, 'node');

    expect(nullValue.state, PatchFieldState.nullValue);
    expect(nullValue.isAbsent, isFalse);
    expect(nullValue.hasValue, isFalse);
    expect(nullValue.isNullValue, isTrue);
    expect(nullValue.valueOrNull, isNull);
    expect(() => nullValue.value, throwsStateError);
  });

  test('CommonNodePatch defaults to absent for all fields', () {
    const patch = CommonNodePatch();

    expect(patch.transform.isAbsent, isTrue);
    expect(patch.opacity.isAbsent, isTrue);
    expect(patch.hitPadding.isAbsent, isTrue);
    expect(patch.isVisible.isAbsent, isTrue);
    expect(patch.isSelectable.isAbsent, isTrue);
    expect(patch.isLocked.isAbsent, isTrue);
    expect(patch.isDeletable.isAbsent, isTrue);
    expect(patch.isTransformable.isAbsent, isTrue);
  });

  test('NodePatch variants expose typed tri-state payloads', () {
    const common = CommonNodePatch(
      transform: PatchField<Transform2D>.value(Transform2D.identity),
      opacity: PatchField<double>.value(0.8),
      hitPadding: PatchField<double>.value(2),
      isVisible: PatchField<bool>.value(true),
      isSelectable: PatchField<bool>.value(false),
      isLocked: PatchField<bool>.value(true),
      isDeletable: PatchField<bool>.value(false),
      isTransformable: PatchField<bool>.value(true),
    );

    const image = ImageNodePatch(
      id: 'img-1',
      common: common,
      imageId: PatchField<String>.value('image://1'),
      size: PatchField<Size>.value(Size(10, 20)),
      naturalSize: PatchField<Size?>.nullValue(),
    );

    const text = TextNodePatch(
      id: 'text-1',
      text: PatchField<String>.value('hello'),
      size: PatchField<Size>.value(Size(100, 50)),
      fontSize: PatchField<double>.value(16),
      color: PatchField<Color>.value(Color(0xFF00FF00)),
      align: PatchField<TextAlign>.value(TextAlign.right),
      isBold: PatchField<bool>.value(true),
      isItalic: PatchField<bool>.value(true),
      isUnderline: PatchField<bool>.value(false),
      fontFamily: PatchField<String?>.value('Mono'),
      maxWidth: PatchField<double?>.value(240),
      lineHeight: PatchField<double?>.nullValue(),
    );

    const stroke = StrokeNodePatch(
      id: 'stroke-1',
      points: PatchField<List<Offset>>.value(<Offset>[
        Offset(1, 2),
        Offset(3, 4),
      ]),
      thickness: PatchField<double>.value(3),
      color: PatchField<Color>.value(Color(0xFFABCDEF)),
    );

    const line = LineNodePatch(
      id: 'line-1',
      start: PatchField<Offset>.value(Offset(0, 0)),
      end: PatchField<Offset>.value(Offset(5, 5)),
      thickness: PatchField<double>.value(2),
      color: PatchField<Color>.value(Color(0xFF123456)),
    );

    const rect = RectNodePatch(
      id: 'rect-1',
      size: PatchField<Size>.value(Size(7, 9)),
      fillColor: PatchField<Color?>.nullValue(),
      strokeColor: PatchField<Color?>.value(Color(0xFF111111)),
      strokeWidth: PatchField<double>.value(1.5),
    );

    const path = PathNodePatch(
      id: 'path-1',
      svgPathData: PatchField<String>.value('M0 0 L10 10'),
      fillColor: PatchField<Color?>.value(Color(0xFF222222)),
      strokeColor: PatchField<Color?>.nullValue(),
      strokeWidth: PatchField<double>.value(2),
      fillRule: PatchField<V2PathFillRule>.value(V2PathFillRule.evenOdd),
    );

    expect(image.common.opacity.value, 0.8);
    expect(image.imageId.value, 'image://1');
    expect(image.naturalSize.isNullValue, isTrue);

    expect(text.align.value, TextAlign.right);
    expect(text.fontFamily.value, 'Mono');
    expect(text.lineHeight.isNullValue, isTrue);

    expect(stroke.points.value.length, 2);
    expect(stroke.thickness.value, 3);

    expect(line.start.value, const Offset(0, 0));
    expect(line.end.value, const Offset(5, 5));

    expect(rect.fillColor.isNullValue, isTrue);
    expect(rect.strokeColor.value, const Color(0xFF111111));

    expect(path.fillRule.value, V2PathFillRule.evenOdd);
    expect(path.strokeColor.isNullValue, isTrue);
  });

  test('Patch constructors are callable at runtime (non-const path)', () {
    final dynamicValue = PatchField<String>.value('runtime');
    final dynamicNull = PatchField<String?>.nullValue();

    final imagePatch = ImageNodePatch(
      id: 'image-runtime',
      imageId: dynamicValue,
    );
    final textPatch = TextNodePatch(
      id: 'text-runtime',
      fontFamily: dynamicNull,
    );
    final strokePatch = StrokeNodePatch(
      id: 'stroke-runtime',
      thickness: PatchField<double>.value(2),
    );
    final linePatch = LineNodePatch(
      id: 'line-runtime',
      start: PatchField<Offset>.value(const Offset(1, 1)),
    );
    final rectPatch = RectNodePatch(
      id: 'rect-runtime',
      strokeWidth: PatchField<double>.value(3),
    );
    final pathPatch = PathNodePatch(
      id: 'path-runtime',
      fillRule: PatchField<V2PathFillRule>.value(V2PathFillRule.nonZero),
    );

    expect(imagePatch.imageId.value, 'runtime');
    expect(textPatch.fontFamily.isNullValue, isTrue);
    expect(strokePatch.thickness.value, 2);
    expect(linePatch.start.value, const Offset(1, 1));
    expect(rectPatch.strokeWidth.value, 3);
    expect(pathPatch.fillRule.value, V2PathFillRule.nonZero);
  });
}
