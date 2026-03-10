import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/core/scene_limits.dart'
    show
        kMaxFontFamilyLength,
        kMaxImageIdLength,
        kMaxLayerIdLength,
        kMaxNodeIdLength,
        kMaxSvgPathDataLength,
        kMaxTextLength;

T _requireValue<T>(T? value, String description) {
  if (value == null) {
    fail(description);
  }
  return value;
}

Map<String, Object?> _singleNodeJson(Map<String, Object?> sceneJson) {
  final layers = sceneJson['layers'] as List<Object?>;
  final layer = layers.single as Map<String, Object?>;
  final nodes = layer['nodes'] as List<Object?>;
  return nodes.single as Map<String, Object?>;
}

void main() {
  group('validated boundary values', () {
    test('public id helpers preserve string typedef behavior', () {
      expect(parseNodeId('node-custom'), 'node-custom');
      expect(parseLayerId('layer-custom'), 'layer-custom');
      expect(generateNodeId(3), 'node-3');
      expect(generateLayerId(4), 'layer-4');
      expect(isGeneratedNodeId('node-3'), isTrue);
      expect(isGeneratedLayerId('layer-4'), isTrue);
      expect(isGeneratedNodeId('custom'), isFalse);
      expect(isGeneratedLayerId('custom'), isFalse);
      expect(tryParseGeneratedNodeIdSeed('node-3'), 3);
      expect(tryParseGeneratedLayerIdSeed('layer-4'), 4);
      expect(tryParseGeneratedNodeIdSeed('node-'), isNull);
      expect(tryParseGeneratedNodeIdSeed('node--1'), isNull);
      expect(tryParseGeneratedNodeIdSeed('node-01'), isNull);
      expect(tryParseGeneratedNodeIdSeed('layer-1'), isNull);
      expect(tryParseGeneratedLayerIdSeed('layer-foo'), isNull);
      expect(tryParseGeneratedLayerIdSeed('layer-0007'), isNull);
      expect(
        tryParseGeneratedNodeIdSeed('node-${'1' * kMaxNodeIdLength}'),
        isNull,
      );
      expect(
        tryParseGeneratedLayerIdSeed('layer-${'1' * kMaxLayerIdLength}'),
        isNull,
      );
      expect(tryParseGeneratedNodeIdSeed('node-${'9' * 30}'), isNull);
      expect(tryParseGeneratedLayerIdSeed('layer-${'9' * 30}'), isNull);
    });

    test('id values parse, generate and recognize legacy seeds', () {
      expect(NodeIdValue.parse('node-custom').value, 'node-custom');
      expect(LayerIdValue.parse('layer-custom').value, 'layer-custom');
      expect(NodeIdValue.generate(12).value, 'node-12');
      expect(LayerIdValue.generate(7).value, 'layer-7');
      expect(NodeIdValue.isGeneratedLegacyFormat('node-12'), isTrue);
      expect(LayerIdValue.isGeneratedLegacyFormat('layer-7'), isTrue);
      expect(NodeIdValue.tryParseGeneratedSeed('node-12'), 12);
      expect(LayerIdValue.tryParseGeneratedSeed('layer-7'), 7);
    });

    test('id values reject blank and oversized input', () {
      expect(() => NodeIdValue.parse('   '), throwsA(isA<ArgumentError>()));
      expect(
        () => LayerIdValue.parse('x' * (kMaxLayerIdLength + 1)),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => NodeIdValue.parse('x' * (kMaxNodeIdLength + 1)),
        throwsA(isA<ArgumentError>()),
      );
      expect(() => NodeIdValue.generate(-1), throwsA(isA<ArgumentError>()));
    });

    test('image id value preserves current string boundary policy', () {
      expect(ImageIdValue.of('').value, '');
      expect(ImageIdValue.parse('image://1').value, 'image://1');
      expect(
        ImageIdValue.fromJson('asset:sample', path: 'node.imageId').value,
        'asset:sample',
      );
      expect(
        ImageIdValue.of('asset:sample').toString(),
        'ImageIdValue(length: 12)',
      );
      expect(
        () => ImageIdValue.of('x' * (kMaxImageIdLength + 1)),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => ImageIdValue.fromJson(
          'x' * (kMaxImageIdLength + 1),
          path: 'node.imageId',
        ),
        throwsA(isA<SceneDataException>()),
      );
    });

    test('numeric and offset values validate finite/range semantics', () {
      expect(PositiveFiniteDoubleValue.of(1).value, 1);
      expect(PositiveFiniteDoubleValue.parse('1.5').value, 1.5);
      expect(NonNegativeFiniteDoubleValue.of(0).value, 0);
      expect(NonNegativeFiniteDoubleValue.parse('0').value, 0);
      expect(OpacityValue.of(0.25).value, 0.25);
      expect(OpacityValue.parse('0.5').value, 0.5);
      expect(
        FiniteOffsetValue.of(const Offset(3, 4)).value,
        const Offset(3, 4),
      );
      expect(
        FiniteOffsetValue.fromJson(const <String, Object?>{
          'x': 3,
          'y': 4,
        }, path: 'offset').value,
        const Offset(3, 4),
      );
      expect(
        () => PositiveFiniteDoubleValue.of(0),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => PositiveFiniteDoubleValue.parse('bad'),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => NonNegativeFiniteDoubleValue.of(-1),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => NonNegativeFiniteDoubleValue.parse('bad'),
        throwsA(isA<ArgumentError>()),
      );
      expect(() => OpacityValue.of(2), throwsA(isA<ArgumentError>()));
      expect(() => OpacityValue.parse('bad'), throwsA(isA<ArgumentError>()));
      expect(
        () => FiniteOffsetValue.of(const Offset(double.nan, 0)),
        throwsA(isA<ArgumentError>()),
      );
    });

    test(
      'instance revision policy differentiates snapshot and scene rules',
      () {
        expect(InstanceRevisionValue.of(0).value, 0);
        expect(InstanceRevisionValue.parse('1').value, 1);
        expect(
          () => InstanceRevisionValue.of(0, allowZero: false),
          throwsA(isA<ArgumentError>()),
        );
        expect(
          () => InstanceRevisionValue.parse('bad'),
          throwsA(isA<ArgumentError>()),
        );
        expect(
          () => InstanceRevisionValue.of(-1),
          throwsA(isA<ArgumentError>()),
        );
        expect(
          () => InstanceRevisionValue.of(9007199254740992),
          throwsA(isA<ArgumentError>()),
        );
      },
    );

    test('text, font family and svg values enforce their policies', () {
      expect(TextContentValue.of('').value, '');
      expect(TextContentValue.parse('hello').value, 'hello');
      expect(
        () => TextContentValue.of('x' * (kMaxTextLength + 1)),
        throwsA(isA<ArgumentError>()),
      );
      expect(FontFamilyValue.of('Inter').value, 'Inter');
      expect(FontFamilyValue.parse('Roboto').value, 'Roboto');
      expect(() => FontFamilyValue.of(''), throwsA(isA<ArgumentError>()));
      expect(
        () => FontFamilyValue.of('x' * (kMaxFontFamilyLength + 1)),
        throwsA(isA<ArgumentError>()),
      );
      expect(SvgPathDataValue.of('M0 0 L1 1').value, 'M0 0 L1 1');
      expect(SvgPathDataValue.parse('M0 0 L2 2').value, 'M0 0 L2 2');
      expect(() => SvgPathDataValue.of(''), throwsA(isA<ArgumentError>()));
      expect(
        () => SvgPathDataValue.of('x' * (kMaxSvgPathDataLength + 1)),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('public snapshot constructors reject singular transforms', () {
      expect(
        () => RectNodeSnapshot(
          id: 'rect-singular',
          size: const Size(10, 10),
          transform: const Transform2D(a: 0, b: 0, c: 0, d: 0, tx: 0, ty: 0),
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test(
      'public node spec constructors reject invalid write values eagerly',
      () {
        expect(
          () => RectNodeSpec(size: const Size(1, 1), opacity: 1.1),
          throwsA(
            isA<ArgumentError>().having(
              (error) => error.name,
              'name',
              'opacity',
            ),
          ),
        );
        expect(
          () => TextNodeSpec(
            text: 'hello',
            fontSize: 0,
            color: const Color(0xFF000000),
          ),
          throwsA(
            isA<ArgumentError>().having(
              (error) => error.name,
              'name',
              'fontSize',
            ),
          ),
        );
        expect(
          () => PathNodeSpec(svgPathData: 'not-a-path'),
          throwsA(
            isA<ArgumentError>().having(
              (error) => error.name,
              'name',
              'svgPathData',
            ),
          ),
        );
        expect(
          () => RectNodeSpec(
            size: const Size(1, 1),
            transform: const Transform2D(a: 0, b: 0, c: 0, d: 0, tx: 0, ty: 0),
          ),
          throwsA(
            isA<ArgumentError>().having(
              (error) => error.name,
              'name',
              'transform',
            ),
          ),
        );
      },
    );

    test(
      'public node patch constructors validate present fields and keep absent fields untouched',
      () {
        expect(() => RectNodePatch(id: 'node-1'), returnsNormally);
        expect(
          () => RectNodePatch(
            id: 'node-1',
            common: CommonNodePatch(opacity: PatchField<double>.value(1.1)),
          ),
          throwsA(
            isA<ArgumentError>().having(
              (error) => error.name,
              'name',
              'opacity',
            ),
          ),
        );
        expect(
          () => RectNodePatch(id: 'node-1', size: PatchField<Size>.nullValue()),
          throwsA(
            isA<ArgumentError>().having((error) => error.name, 'name', 'size'),
          ),
        );
        expect(
          () => TextNodePatch(
            id: 'node-1',
            maxWidth: PatchField<double?>.value(0),
          ),
          throwsA(
            isA<ArgumentError>().having(
              (error) => error.name,
              'name',
              'maxWidth',
            ),
          ),
        );
        expect(
          () => CommonNodePatch(
            transform: PatchField<Transform2D>.value(
              const Transform2D(a: 0, b: 0, c: 0, d: 0, tx: 0, ty: 0),
            ),
          ),
          throwsA(
            isA<ArgumentError>().having(
              (error) => error.name,
              'name',
              'transform',
            ),
          ),
        );
      },
    );

    test('stroke spec and patch copy point lists at the public boundary', () {
      final specPoints = <Offset>[const Offset(0, 0), const Offset(1, 1)];
      final patchPoints = <Offset>[const Offset(0, 0), const Offset(2, 2)];

      final spec = StrokeNodeSpec(
        points: specPoints,
        thickness: 1,
        color: const Color(0xFF000000),
      );
      final patch = StrokeNodePatch(
        id: 'node-1',
        points: PatchField<List<Offset>>.value(patchPoints),
      );

      specPoints[1] = const Offset(10, 10);
      patchPoints[1] = const Offset(20, 20);

      expect(spec.points[1], const Offset(1, 1));
      expect(patch.points.value[1], const Offset(2, 2));
      expect(() => spec.points.add(const Offset(3, 3)), throwsUnsupportedError);
      expect(
        () => patch.points.value.add(const Offset(4, 4)),
        throwsUnsupportedError,
      );
    });

    test('scene palette boundary rejects empty public lists', () {
      expect(
        () => ScenePaletteSnapshot(penColors: const <Color>[]),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => ScenePaletteSnapshot(backgroundColors: const <Color>[]),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => ScenePaletteSnapshot(gridSizes: const <double>[]),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('fromJson helpers report boundary-specific validation errors', () {
      expect(
        () => NodeIdValue.fromJson(1, path: 'node.id'),
        throwsA(
          predicate(
            (error) =>
                error is SceneDataException &&
                error.code == SceneDataErrorCode.invalidFieldType &&
                error.path == 'node.id',
          ),
        ),
      );
      expect(
        () => LayerIdValue.fromJson('', path: 'layer.id'),
        throwsA(
          predicate(
            (error) =>
                error is SceneDataException &&
                error.code == SceneDataErrorCode.invalidValue &&
                error.path == 'layer.id',
          ),
        ),
      );
      expect(
        () => PositiveFiniteDoubleValue.fromJson('x', path: 'value'),
        throwsA(isA<SceneDataException>()),
      );
      expect(
        () =>
            PositiveFiniteDoubleValue.fromJson(double.infinity, path: 'value'),
        throwsA(isA<SceneDataException>()),
      );
      expect(
        () => PositiveFiniteDoubleValue.fromJson(0, path: 'value'),
        throwsA(isA<SceneDataException>()),
      );
      expect(
        () => NonNegativeFiniteDoubleValue.fromJson('x', path: 'value'),
        throwsA(isA<SceneDataException>()),
      );
      expect(
        () => NonNegativeFiniteDoubleValue.fromJson(
          double.negativeInfinity,
          path: 'value',
        ),
        throwsA(isA<SceneDataException>()),
      );
      expect(
        () => NonNegativeFiniteDoubleValue.fromJson(-1, path: 'value'),
        throwsA(isA<SceneDataException>()),
      );
      expect(
        () => OpacityValue.fromJson('x', path: 'opacity'),
        throwsA(isA<SceneDataException>()),
      );
      expect(
        () => OpacityValue.fromJson(double.nan, path: 'opacity'),
        throwsA(isA<SceneDataException>()),
      );
      expect(
        () => OpacityValue.fromJson(2, path: 'opacity'),
        throwsA(isA<SceneDataException>()),
      );
      expect(
        () => InstanceRevisionValue.fromJson('x', path: 'instanceRevision'),
        throwsA(isA<SceneDataException>()),
      );
      expect(
        () => InstanceRevisionValue.fromJson(1.5, path: 'instanceRevision'),
        throwsA(isA<SceneDataException>()),
      );
      expect(
        () => InstanceRevisionValue.fromJson(
          9007199254740992.0,
          path: 'instanceRevision',
        ),
        throwsA(isA<SceneDataException>()),
      );
      expect(
        () => InstanceRevisionValue.fromJson(
          9007199254740992,
          path: 'instanceRevision',
        ),
        throwsA(isA<SceneDataException>()),
      );
      expect(
        () => InstanceRevisionValue.fromJson(
          0,
          path: 'instanceRevision',
          allowZero: false,
        ),
        throwsA(isA<SceneDataException>()),
      );
      expect(
        () => FiniteOffsetValue.fromJson('x', path: 'offset'),
        throwsA(isA<SceneDataException>()),
      );
      expect(
        () => FiniteOffsetValue.fromJson(const <String, Object?>{
          'x': 1,
          'y': 'bad',
        }, path: 'offset'),
        throwsA(isA<SceneDataException>()),
      );
      expect(
        () => FiniteOffsetValue.fromJson(<String, Object?>{
          'x': double.infinity,
          'y': 0,
        }, path: 'offset'),
        throwsA(isA<SceneDataException>()),
      );
      expect(
        () => TextContentValue.fromJson(1, path: 'text'),
        throwsA(isA<SceneDataException>()),
      );
      expect(
        () =>
            TextContentValue.fromJson('x' * (kMaxTextLength + 1), path: 'text'),
        throwsA(isA<SceneDataException>()),
      );
      expect(
        () => FontFamilyValue.fromJson(1, path: 'fontFamily'),
        throwsA(isA<SceneDataException>()),
      );
      expect(
        () => FontFamilyValue.fromJson('', path: 'fontFamily'),
        throwsA(isA<SceneDataException>()),
      );
      expect(
        () => FontFamilyValue.fromJson(
          'x' * (kMaxFontFamilyLength + 1),
          path: 'fontFamily',
        ),
        throwsA(isA<SceneDataException>()),
      );
      expect(
        () => SvgPathDataValue.fromJson(1, path: 'svgPathData'),
        throwsA(isA<SceneDataException>()),
      );
      expect(
        () => SvgPathDataValue.fromJson('not svg', path: 'svgPathData'),
        throwsA(isA<SceneDataException>()),
      );
    });

    test(
      'validated constructors and equality stay stable without fast paths',
      () {
        expect(
          NodeIdValue.parse('node-fast'),
          equals(NodeIdValue.fromJson('node-fast', path: 'node.id')),
        );
        expect(
          LayerIdValue.parse('layer-fast').hashCode,
          LayerIdValue.fromJson('layer-fast', path: 'layer.id').hashCode,
        );
        expect(
          InstanceRevisionValue.of(5).toString(),
          'InstanceRevisionValue(5)',
        );
        expect(
          FiniteOffsetValue.of(const Offset(1, 2)).toString(),
          'FiniteOffsetValue(Offset(1.0, 2.0))',
        );
        expect(
          PositiveFiniteDoubleValue.of(3).toString(),
          'PositiveFiniteDoubleValue(3.0)',
        );
        expect(
          NonNegativeFiniteDoubleValue.of(0).toString(),
          'NonNegativeFiniteDoubleValue(0.0)',
        );
        expect(OpacityValue.of(1).toString(), 'OpacityValue(1.0)');
        expect(
          TextContentValue.of('abc').toString(),
          'TextContentValue(length: 3)',
        );
        expect(FontFamilyValue.of('Sans').toString(), 'FontFamilyValue(Sans)');
        expect(
          SvgPathDataValue.of('M0 0').toString(),
          'SvgPathDataValue(length: 4)',
        );
      },
    );
  });

  group('scene data exception sanitation', () {
    test('boundary factory preserves path, details, and sanitized source', () {
      final error = SceneDataException.boundary(
        code: SceneDataErrorCode.invalidValue,
        path: 'layers[0].id',
        details: const <String, Object?>{
          'template': 'duplicateLayerId',
          'opaque': <String, Object?>{'nested': 'ok'},
        },
        source: 'x' * 400,
      );

      expect(error.path, 'layers[0].id');
      expect(error.details['template'], 'duplicateLayerId');
      expect(
        error.message,
        'Field layers[0].id must be unique across content layers.',
      );
      expect(() => error.details['later'] = true, throwsUnsupportedError);
      expect(error.source, isA<Map<String, Object?>>());
    });

    test('duplicate layer id uses dedicated code and stable details', () {
      final error = SceneDataException.duplicateLayerId(
        path: 'layers[1].id',
        layerId: 'layer-dup',
      );

      expect(error.code, SceneDataErrorCode.duplicateLayerId);
      expect(error.path, 'layers[1].id');
      expect(error.details, const <String, Object?>{
        'template': 'duplicateLayerId',
      });
      expect(
        error.message,
        'Field layers[1].id must be unique across content layers.',
      );
      expect(error.source, 'layer-dup');
    });

    test('message factories cover missing field and generic invalid json', () {
      final missingField = SceneDataException.missingField(
        path: 'layers[0].id',
      );
      final invalidJsonPayload = SceneDataException.invalidJsonPayload();
      final jsonPayloadTooLarge = SceneDataException.jsonPayloadTooLarge(
        maxLength: 1024,
      );
      final genericPath = SceneDataException(
        code: SceneDataErrorCode.invalidValue,
        path: 'layers[0]',
        details: const <String, Object?>{'template': 'unknown'},
      );
      final genericCode = SceneDataException(
        code: SceneDataErrorCode.unsupportedSchemaVersion,
      );
      final duplicateNodeFallback = SceneDataException(
        code: SceneDataErrorCode.duplicateNodeId,
      );
      final duplicateLayerFallback = SceneDataException(
        code: SceneDataErrorCode.duplicateLayerId,
      );
      final outOfRangeFallback = SceneDataException(
        code: SceneDataErrorCode.outOfRange,
      );

      expect(missingField.message, 'Missing required field layers[0].id.');
      expect(invalidJsonPayload.message, 'Invalid scene JSON payload.');
      expect(
        jsonPayloadTooLarge.message,
        'Scene JSON payload must be <= 1024 characters.',
      );
      expect(genericPath.message, 'Field layers[0] is invalid.');
      expect(genericCode.message, 'Unsupported scene schema version.');
      expect(
        duplicateNodeFallback.message,
        'Duplicate node id is not allowed.',
      );
      expect(
        duplicateLayerFallback.message,
        'Duplicate content layer id is not allowed.',
      );
      expect(outOfRangeFallback.message, 'Field value is out of range.');
    });

    test('details sanitization keeps immutable json-like previews', () {
      final deepList = <Object?>[
        <Object?>[
          <Object?>[_ShortExampleSource()],
        ],
      ];
      final error = SceneDataException(
        code: SceneDataErrorCode.invalidValue,
        details: <String, Object?>{
          'longString': 'x' * 200,
          'smallList': <Object?>[1, 'two'],
          'largeList': List<int>.generate(20, (index) => index),
          'largeMap': <Object?, Object?>{
            for (var index = 0; index < 12; index++) 'k$index': index,
          },
          'iterable': Iterable<int>.generate(20, (index) => index),
          'deepList': deepList,
          'object': _ExampleSource(),
        },
      );

      final longString = _requireValue<Map<String, Object?>>(
        error.details['longString'] as Map<String, Object?>?,
        'Expected long string preview.',
      );
      expect(longString['kind'], 'string');

      expect(error.details['smallList'], <Object?>[1, 'two']);

      final largeList = _requireValue<Map<String, Object?>>(
        error.details['largeList'] as Map<String, Object?>?,
        'Expected large list preview.',
      );
      expect(largeList['kind'], 'list');
      expect(() => largeList['kind'] = 'changed', throwsUnsupportedError);
      expect(
        () => (largeList['preview'] as List<Object?>).add(99),
        throwsUnsupportedError,
      );

      final largeMap = _requireValue<Map<String, Object?>>(
        error.details['largeMap'] as Map<String, Object?>?,
        'Expected large map preview.',
      );
      expect(largeMap['kind'], 'map');
      expect(
        () => (largeMap['preview'] as Map<String, Object?>)['later'] = true,
        throwsUnsupportedError,
      );

      final iterable = _requireValue<Map<String, Object?>>(
        error.details['iterable'] as Map<String, Object?>?,
        'Expected iterable preview.',
      );
      expect(iterable['kind'], 'iterable');
      expect(
        () => (iterable['preview'] as List<Object?>).add(42),
        throwsUnsupportedError,
      );

      final deepListPreview = _requireValue<List<Object?>>(
        error.details['deepList'] as List<Object?>?,
        'Expected deep list snapshot.',
      );
      expect(deepListPreview.single, isA<List<Object?>>());
      final nestedPreview =
          ((deepListPreview.single as List<Object?>).single as List<Object?>)
              .single;
      expect(nestedPreview, isA<Map<String, Object?>>());

      final objectPreview = _requireValue<Map<String, Object?>>(
        error.details['object'] as Map<String, Object?>?,
        'Expected object preview.',
      );
      expect(objectPreview['kind'], 'object');
      expect(() => error.details['later'] = true, throwsUnsupportedError);
    });

    test(
      'message derivation uses raw details before diagnostics sanitization',
      () {
        final longFieldName = 'x' * 200;
        final error = SceneDataException(
          code: SceneDataErrorCode.invalidFieldType,
          path: 'layers[0].id',
          details: <String, Object?>{
            'template': 'fieldType',
            'fieldName': longFieldName,
            'expected': 'string',
          },
        );

        expect(error.message, 'Field $longFieldName must be a string.');
        expect(error.details['fieldName'], isA<Map<String, Object?>>());
      },
    );

    test('copies small structured source values into immutable snapshots', () {
      final scalarError = SceneDataException(
        code: SceneDataErrorCode.invalidValue,
        message: 'bad',
        source: 42,
      );
      final listSource = <Object?>[1, 'two', true];
      final setSource = <Object?>{'one', 2, true};
      final nestedList = <Object?>['x'];
      final mapSource = <Object?, Object?>{'ok': 1, 'nested': nestedList};
      final listError = SceneDataException(
        code: SceneDataErrorCode.invalidValue,
        message: 'bad',
        source: listSource,
      );
      final setError = SceneDataException(
        code: SceneDataErrorCode.invalidValue,
        message: 'bad',
        source: setSource,
      );
      final mapError = SceneDataException(
        code: SceneDataErrorCode.invalidValue,
        message: 'bad',
        source: mapSource,
      );

      expect(scalarError.source, 42);
      expect(listError.source, <Object?>[1, 'two', true]);
      expect(listError.source, isNot(same(listSource)));
      final listSourceCopy = _requireValue<List<Object?>>(
        listError.source as List<Object?>?,
        'Expected copied list source.',
      );
      expect(() => listSourceCopy.add('later'), throwsUnsupportedError);

      expect(setError.source, <Object?>{'one', 2, true});
      expect(setError.source, isNot(same(setSource)));
      final setSourceCopy = _requireValue<Set<Object?>>(
        setError.source as Set<Object?>?,
        'Expected copied set source.',
      );
      expect(() => setSourceCopy.add('later'), throwsUnsupportedError);

      expect(mapError.source, <Object?, Object?>{
        'ok': 1,
        'nested': <Object?>['x'],
      });
      expect(mapError.source, isNot(same(mapSource)));
      final copiedMap = _requireValue<Map<Object?, Object?>>(
        mapError.source as Map<Object?, Object?>?,
        'Expected copied map source.',
      );
      expect(copiedMap['nested'], isNot(same(nestedList)));
      expect(() => copiedMap['later'] = 3, throwsUnsupportedError);
    });

    test('truncates oversized string source values into preview payloads', () {
      final error = SceneDataException(
        code: SceneDataErrorCode.invalidValue,
        message: 'bad',
        source: 'x' * 300,
      );

      expect(error.source, isA<Map<String, Object?>>());
      final source = _requireValue<Map<String, Object?>>(
        error.source as Map<String, Object?>?,
        'Expected summarized string source.',
      );
      expect(source['kind'], 'string');
      expect(source['length'], 300);
      final preview = _requireValue<String>(
        source['preview'] as String?,
        'Expected string preview.',
      );
      expect(preview.length, greaterThan(256));
    });

    test('summarizes large collections and previews object diagnostics', () {
      final listError = SceneDataException(
        code: SceneDataErrorCode.invalidValue,
        message: 'bad',
        source: List<int>.generate(20, (index) => index),
      );
      final setError = SceneDataException(
        code: SceneDataErrorCode.invalidValue,
        message: 'bad',
        source: <int>{1, 2, 3, 4, 5, 6},
      );
      final mapError = SceneDataException(
        code: SceneDataErrorCode.invalidValue,
        message: 'bad',
        source: <Object?, Object?>{
          'short': 1,
          'x' * 300: 2,
          3: 4,
          'nested': <Object?>[
            <Object?>[_ShortExampleSource()],
          ],
          'tail': 5,
          'ignored': 6,
        },
      );
      final iterableError = SceneDataException(
        code: SceneDataErrorCode.invalidValue,
        message: 'bad',
        source: Iterable<int>.generate(20, (index) => index),
      );
      final diagnosticError = SceneDataException(
        code: SceneDataErrorCode.invalidValue,
        message: 'bad',
        source: StateError('boom'),
      );
      final objectError = SceneDataException(
        code: SceneDataErrorCode.invalidValue,
        message: 'bad',
        source: _ExampleSource(),
      );
      final shortObjectError = SceneDataException(
        code: SceneDataErrorCode.invalidValue,
        message: 'bad',
        source: _ShortExampleSource(),
      );

      expect(listError.source, isA<Map<String, Object?>>());
      final listSource = _requireValue<Map<String, Object?>>(
        listError.source as Map<String, Object?>?,
        'Expected list summary source.',
      );
      expect(listSource['kind'], 'list');
      expect(listSource['length'], 20);
      final listPreview = _requireValue<List<Object?>>(
        listSource['preview'] as List<Object?>?,
        'Expected list preview.',
      );
      expect(listPreview.length, 5);

      expect(setError.source, isA<Map<String, Object?>>());
      final setSource = _requireValue<Map<String, Object?>>(
        setError.source as Map<String, Object?>?,
        'Expected set summary source.',
      );
      expect(setSource['kind'], 'set');
      expect(setSource['length'], 6);
      final setPreview = _requireValue<List<Object?>>(
        setSource['preview'] as List<Object?>?,
        'Expected set preview.',
      );
      expect(setPreview.length, 5);

      expect(mapError.source, isA<Map<String, Object?>>());
      final mapSource = _requireValue<Map<String, Object?>>(
        mapError.source as Map<String, Object?>?,
        'Expected map summary source.',
      );
      expect(mapSource['kind'], 'map');
      expect(mapSource['length'], 6);
      final mapPreview = _requireValue<Map<String, Object?>>(
        mapSource['preview'] as Map<String, Object?>?,
        'Expected map preview.',
      );
      expect(mapPreview.containsKey('short'), isTrue);
      expect(mapPreview.keys.any((key) => key.contains('...')), isTrue);

      expect(iterableError.source, isA<Map<String, Object?>>());
      final iterableSource = _requireValue<Map<String, Object?>>(
        iterableError.source as Map<String, Object?>?,
        'Expected iterable summary source.',
      );
      expect(iterableSource['kind'], 'iterable');
      final iterablePreview = _requireValue<List<Object?>>(
        iterableSource['preview'] as List<Object?>?,
        'Expected iterable preview.',
      );
      expect(iterablePreview.length, 5);

      expect(diagnosticError.source, isA<Map<String, Object?>>());
      final diagnosticSource = _requireValue<Map<String, Object?>>(
        diagnosticError.source as Map<String, Object?>?,
        'Expected diagnostic source.',
      );
      expect(diagnosticSource['kind'], 'object');
      expect(diagnosticSource['type'], 'StateError');
      expect(diagnosticSource['preview'], contains('boom'));

      expect(objectError.source, isA<Map<String, Object?>>());
      final objectSource = _requireValue<Map<String, Object?>>(
        objectError.source as Map<String, Object?>?,
        'Expected object source.',
      );
      expect(objectSource['kind'], 'object');
      expect(objectSource['type'], '_ExampleSource');

      expect(shortObjectError.source, isA<Map<String, Object?>>());
      final shortObjectSource = _requireValue<Map<String, Object?>>(
        shortObjectError.source as Map<String, Object?>?,
        'Expected short object source.',
      );
      expect(shortObjectSource['kind'], 'object');
      expect(shortObjectSource['preview'], 'ShortExampleSource(ok)');
    });
  });

  group('boundary adoption', () {
    test(
      'encodeScene encodes background layer nodes through snapshot path',
      () {
        final encoded = encodeScene(
          SceneSnapshot(
            backgroundLayer: BackgroundLayerSnapshot(
              nodes: <NodeSnapshot>[
                RectNodeSnapshot(id: 'bg', size: Size(1, 1)),
              ],
            ),
            layers: <ContentLayerSnapshot>[ContentLayerSnapshot(id: 'layer-0')],
          ),
        );

        expect(encoded['backgroundLayer'], isA<Map<String, Object?>>());
        final backgroundLayer = _requireValue<Map<String, Object?>>(
          encoded['backgroundLayer'] as Map<String, Object?>?,
          'Expected encoded background layer.',
        );
        final nodes = _requireValue<List<Object?>>(
          backgroundLayer['nodes'] as List<Object?>?,
          'Expected encoded background nodes.',
        );
        expect(nodes, hasLength(1));
        final node = _requireValue<Map<String, Object?>>(
          nodes.single as Map<String, Object?>?,
          'Expected encoded background node.',
        );
        expect(node['id'], 'bg');
      },
    );

    test('public snapshot constructors reject blank ids and font family', () {
      expect(
        () => TextNodeSnapshot(
          id: 'node-0',
          text: 'hello',
          size: const Size(1, 1),
          color: const Color(0xFF000000),
          fontFamily: '',
        ),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => ContentLayerSnapshot(id: ' '),
        throwsA(isA<ArgumentError>()),
      );
    });

    test(
      'SceneBuilder.buildFromSnapshot accepts valid explicit font family',
      () {
        final snapshot = SceneBuilder.buildFromSnapshot(
          SceneSnapshot(
            layers: <ContentLayerSnapshot>[
              ContentLayerSnapshot(
                id: 'layer-0',
                nodes: <NodeSnapshot>[
                  TextNodeSnapshot(
                    id: 'node-0',
                    text: 'hello',
                    size: Size(1, 1),
                    color: Color(0xFF000000),
                    fontFamily: 'Inter',
                  ),
                ],
              ),
            ],
          ),
        );

        final textNode =
            snapshot.layers.single.nodes.single as TextNodeSnapshot;
        expect(textNode.fontFamily, 'Inter');
      },
    );

    test('decodeScene rejects blank layer ids and blank font family', () {
      final blankLayerId = <String, Object?>{
        'schemaVersion': schemaVersionWrite,
        'camera': <String, Object?>{'offsetX': 0, 'offsetY': 0},
        'background': <String, Object?>{
          'color': '#FFFFFFFF',
          'grid': <String, Object?>{
            'enabled': false,
            'cellSize': 10,
            'color': '#1F000000',
          },
        },
        'palette': <String, Object?>{
          'penColors': <Object?>['#FF000000'],
          'backgroundColors': <Object?>['#FFFFFFFF'],
          'gridSizes': <Object?>[10],
        },
        'layers': <Object?>[
          <String, Object?>{'id': '', 'nodes': <Object?>[]},
        ],
      };
      expect(
        () => decodeScene(blankLayerId),
        throwsA(
          predicate(
            (error) =>
                error is SceneDataException &&
                error.path == 'layers[0].id' &&
                error.message == 'Field layers[0].id must not be empty.',
          ),
        ),
      );

      final blankFontFamily = <String, Object?>{
        ...blankLayerId,
        'layers': <Object?>[
          <String, Object?>{
            'id': 'layer-0',
            'nodes': <Object?>[
              <String, Object?>{
                'id': 'node-0',
                'type': 'text',
                'transform': <String, Object?>{
                  'a': 1,
                  'b': 0,
                  'c': 0,
                  'd': 1,
                  'tx': 0,
                  'ty': 0,
                },
                'hitPadding': 0,
                'opacity': 1,
                'isVisible': true,
                'isSelectable': true,
                'isLocked': false,
                'isDeletable': true,
                'isTransformable': true,
                'text': 'hello',
                'size': <String, Object?>{'w': 1, 'h': 1},
                'fontSize': 16,
                'color': '#FF000000',
                'align': 'left',
                'isBold': false,
                'isItalic': false,
                'isUnderline': false,
                'fontFamily': '',
              },
            ],
          },
        ],
      };

      expect(
        () => decodeScene(blankFontFamily),
        throwsA(
          predicate(
            (error) =>
                error is SceneDataException &&
                error.path == 'layers[0].nodes[0].fontFamily' &&
                error.message ==
                    'Field layers[0].nodes[0].fontFamily must not be empty.',
          ),
        ),
      );
    });

    test('decodeScene reports required string boundary failures', () {
      final missingColor = _minimalSceneJson();
      final missingColorBackground = _requireValue<Map<String, Object?>>(
        missingColor['background'] as Map<String, Object?>?,
        'Expected background payload.',
      );
      missingColorBackground.remove('color');
      expect(
        () => decodeScene(missingColor),
        throwsA(
          predicate(
            (error) =>
                error is SceneDataException &&
                error.path == 'background.color' &&
                error.message == 'Missing required field background.color.',
          ),
        ),
      );

      final invalidColorType = _minimalSceneJson();
      final invalidColorBackground = _requireValue<Map<String, Object?>>(
        invalidColorType['background'] as Map<String, Object?>?,
        'Expected background payload.',
      );
      invalidColorBackground['color'] = 1;
      expect(
        () => decodeScene(invalidColorType),
        throwsA(
          predicate(
            (error) =>
                error is SceneDataException &&
                error.path == 'background.color' &&
                error.message == 'Field color must be a string.',
          ),
        ),
      );

      final oversizedImageId = _minimalSceneJson();
      oversizedImageId['layers'] = <Object?>[
        <String, Object?>{
          'id': 'layer-0',
          'nodes': <Object?>[
            <String, Object?>{
              ..._baseNodeJson(id: 'node-0', type: 'image'),
              'imageId': 'x' * (kMaxImageIdLength + 1),
              'size': const <String, Object?>{'w': 1, 'h': 1},
            },
          ],
        },
      ];
      expect(
        () => decodeScene(oversizedImageId),
        throwsA(
          predicate(
            (error) =>
                error is SceneDataException &&
                error.path == 'layers[0].nodes[0].imageId' &&
                error.message ==
                    'Field layers[0].nodes[0].imageId length must be <= '
                        '$kMaxImageIdLength characters.' &&
                error.source == kMaxImageIdLength + 1,
          ),
        ),
      );
    });

    test(
      'decodeScene rejects integer unsafe revisions and numeric boundaries',
      () {
        final unsafeRevisionScene = _minimalSceneJson();
        final unsafeRevisionNode = _singleNodeJson(unsafeRevisionScene);
        unsafeRevisionNode['instanceRevision'] = 9007199254740992;

        expect(
          () => decodeScene(unsafeRevisionScene),
          throwsA(
            predicate(
              (error) =>
                  error is SceneDataException &&
                  error.path == 'layers[0].nodes[0].instanceRevision' &&
                  error.message == 'Field instanceRevision must be an int.',
            ),
          ),
        );

        final negativeStrokeWidth = _minimalSceneJson();
        _singleNodeJson(negativeStrokeWidth)['strokeWidth'] = -1;
        expect(
          () => decodeScene(negativeStrokeWidth),
          throwsA(
            predicate(
              (error) =>
                  error is SceneDataException &&
                  error.path == 'layers[0].nodes[0].strokeWidth' &&
                  error.message ==
                      'Field layers[0].nodes[0].strokeWidth must be >= 0.',
            ),
          ),
        );

        final nonFiniteLinePoint = _minimalSceneJson();
        nonFiniteLinePoint['layers'] = <Object?>[
          <String, Object?>{
            'id': 'layer-0',
            'nodes': <Object?>[
              <String, Object?>{
                ..._baseNodeJson(id: 'node-0', type: 'line'),
                'localA': <String, Object?>{'x': double.infinity, 'y': 0},
                'localB': const <String, Object?>{'x': 1, 'y': 1},
                'thickness': 1,
                'color': '#FF000000',
              },
            ],
          },
        ];
        expect(
          () => decodeScene(nonFiniteLinePoint),
          throwsA(
            predicate(
              (error) =>
                  error is SceneDataException &&
                  error.path == 'layers[0].nodes[0].localA' &&
                  error.message ==
                      'Field layers[0].nodes[0].localA coordinates must be finite.',
            ),
          ),
        );
      },
    );
  });
}

Map<String, Object?> _minimalSceneJson() {
  return <String, Object?>{
    'schemaVersion': schemaVersionWrite,
    'camera': const <String, Object?>{'offsetX': 0, 'offsetY': 0},
    'background': <String, Object?>{
      'color': '#FFFFFFFF',
      'grid': const <String, Object?>{
        'enabled': false,
        'cellSize': 10,
        'color': '#1F000000',
      },
    },
    'palette': const <String, Object?>{
      'penColors': <Object?>['#FF000000'],
      'backgroundColors': <Object?>['#FFFFFFFF'],
      'gridSizes': <Object?>[10],
    },
    'layers': <Object?>[
      <String, Object?>{
        'id': 'layer-0',
        'nodes': <Object?>[
          <String, Object?>{
            ..._baseNodeJson(id: 'node-0', type: 'rect'),
            'size': const <String, Object?>{'w': 1, 'h': 1},
            'strokeWidth': 0,
          },
        ],
      },
    ],
  };
}

Map<String, Object?> _baseNodeJson({required String id, required String type}) {
  return <String, Object?>{
    'id': id,
    'type': type,
    'transform': const <String, Object?>{
      'a': 1,
      'b': 0,
      'c': 0,
      'd': 1,
      'tx': 0,
      'ty': 0,
    },
    'hitPadding': 0,
    'opacity': 1,
    'isVisible': true,
    'isSelectable': true,
    'isLocked': false,
    'isDeletable': true,
    'isTransformable': true,
  };
}

class _ExampleSource {
  @override
  String toString() => 'ExampleSource(value: ${'x' * 400})';
}

class _ShortExampleSource {
  @override
  String toString() => 'ShortExampleSource(ok)';
}
