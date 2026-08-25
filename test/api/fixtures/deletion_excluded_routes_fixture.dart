// These are deliberately successful public routes outside deletion interception.
// Each test owns its route effect, while the shared resolver counter only proves
// that the configured deletion callback was never entered.

import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/runtime/runtime_root.dart';

import '../../support/runtime_root_with_committed_document_seed.dart';

// One named test per public family makes the absence of resolver interception
// auditable; extracting them would duplicate the shared runtime setup only.
// Keeping the route effects together is clearer than hiding them behind a
// helper that could accidentally turn several public families into one proof.
// ignore: halstead-volume, source-lines-of-code, maintainability-index
void main() {
  test('direct command removal stays outside deletion resolver', () {
    final scenario = _scenario();
    addTearDown(scenario.root.dispose);
    expect(scenario.root.commands.removeElement(CanvasElementId('a')), isTrue);
    expect(_ids(scenario.root), isNot(contains(CanvasElementId('a'))));
    expect(scenario.calls, 0);
  });
  test('public edit removal stays outside deletion resolver', () {
    final scenario = _scenario();
    addTearDown(scenario.root.dispose);
    scenario.root.edits.edit(
      (edit) => edit.removeElement(CanvasElementId('a')),
    );
    expect(_ids(scenario.root), isNot(contains(CanvasElementId('a'))));
    expect(scenario.calls, 0);
  });
  test('public element locking stays outside deletion resolver', () {
    final scenario = _scenario();
    addTearDown(scenario.root.dispose);
    scenario.root.edits.edit(
      (edit) => edit.updateElement(
        CanvasRectElementUpdate(
          id: CanvasElementId('a'),
          isLocked: const CanvasFieldSet(true),
        ),
      ),
    );
    final element = scenario.root.readDocument().layers.single.elements.single;
    expect(element.isLocked, isTrue);
    expect(scenario.calls, 0);
  });
  test('clear command stays outside deletion resolver', () {
    final scenario = _scenario();
    addTearDown(scenario.root.dispose);
    final result = scenario.root.commands.clearContent();
    expect(result.didClearContent, isTrue);
    expect(_ids(scenario.root), isEmpty);
    expect(scenario.calls, 0);
  });
  test('document load stays outside deletion resolver', () {
    final scenario = _scenario();
    addTearDown(scenario.root.dispose);
    scenario.root.edits.loadDocumentFromJson(
      encodeCanvasDocumentToJson(_loadedDocument()),
    );
    expect(_ids(scenario.root), [CanvasElementId('loaded')]);
    expect(scenario.calls, 0);
  });
  test('resource dirty mutation stays outside deletion resolver', () {
    final scenario = _scenario();
    addTearDown(scenario.root.dispose);
    final before = scenario.root.state.value.revisions.resourceVisual;
    scenario.root.resources.markResourceDirty(CanvasResourceId('image'));
    expect(scenario.root.state.value.revisions.resourceVisual, before + 1);
    expect(scenario.calls, 0);
  });
  test('general selection mutation stays outside deletion resolver', () {
    final scenario = _scenario();
    addTearDown(scenario.root.dispose);
    scenario.root.selection.setSelection([CanvasElementId('a')]);
    expect(scenario.root.selectedElementIds, {CanvasElementId('a')});
    expect(scenario.calls, 0);
  });
  test('non-eraser tool mutation stays outside deletion resolver', () {
    final scenario = _scenario();
    addTearDown(scenario.root.dispose);
    scenario.root.tools.setDrawTool(CanvasDrawTool.marker);
    expect(scenario.root.tools.drawStyle.tool, CanvasDrawTool.marker);
    expect(scenario.calls, 0);
  });
}

final class _Scenario {
  _Scenario(this.root, this._calls);

  final RuntimeRoot root;
  final int Function() _calls;

  int get calls => _calls();
}

_Scenario _scenario() {
  var calls = 0;
  final root = runtimeRootWithCommittedDocumentSeed(
    _document(),
    config: CanvasRuntimeConfig(
      deletionCommitResolver: (_) {
        calls += 1;
        return CanvasDeletionDecision.accept;
      },
    ),
  );
  return _Scenario(root, () => calls);
}

CanvasDocument _document() => CanvasDocument(
  resources: [
    CanvasImageResource(
      id: CanvasResourceId('image'),
      source: CanvasResourceSource.appKey('image'),
    ),
  ],
  layers: [
    CanvasLayer(
      id: CanvasLayerId('layer'),
      elements: [
        CanvasRectElement(id: CanvasElementId('a'), size: const Size(2, 2)),
      ],
    ),
  ],
);

CanvasDocument _loadedDocument() => CanvasDocument(
  layers: [
    CanvasLayer(
      id: CanvasLayerId('loaded-layer'),
      elements: [
        CanvasRectElement(
          id: CanvasElementId('loaded'),
          size: const Size(2, 2),
        ),
      ],
    ),
  ],
);

List<CanvasElementId> _ids(RuntimeRoot root) => [
  for (final layer in root.readDocument().layers)
    for (final element in layer.elements) element.id,
];
