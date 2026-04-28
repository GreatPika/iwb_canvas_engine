import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// INV:INV-G-NODEID-UNIQUE
// INV:INV-G-LAYERID-UNIQUE
// INV:INV-ENG-ID-INDEX-FROM-SCENE
// INV:INV-ENG-RUNTIME-SCENE-STRUCTURE-OWNER

void main() {
  test(
    'model scene insertion admission does not use derived maps as source of truth',
    () {
      final source = File(
        'lib/src/model/document_scene_insert.dart',
      ).readAsStringSync();

      expect(source, isNot(contains('nodeLocator.containsKey')));
      expect(source, isNot(contains('nodeLocator.length')));
      expect(source, isNot(contains('layerIndexById.containsKey')));
      expect(
        _functionBody(source, 'txnInsertNodeInScene'),
        allOf(
          isNot(contains('nodeLocator.containsKey')),
          isNot(contains('nodeLocator.length')),
        ),
      );
      expect(
        _functionBody(source, 'txnEnsureContentLayerInScene'),
        isNot(contains('layerIndexById.containsKey')),
      );
      expect(
        _functionBody(source, 'txnInsertContentLayerInScene'),
        isNot(contains('layerIndexById.containsKey')),
      );
    },
  );
}

String _functionBody(String source, String functionName) {
  final declaration = source.indexOf(functionName);
  if (declaration < 0) {
    fail('Expected $functionName declaration.');
  }
  final bodyStart = source.indexOf('{', declaration);
  if (bodyStart < 0) {
    fail('Expected $functionName body.');
  }

  var depth = 0;
  for (var index = bodyStart; index < source.length; index++) {
    final character = source.codeUnitAt(index);
    if (character == 0x7B) {
      depth++;
    } else if (character == 0x7D) {
      depth--;
      if (depth == 0) {
        return source.substring(bodyStart, index + 1);
      }
    }
  }
  fail('Expected complete $functionName body.');
}
