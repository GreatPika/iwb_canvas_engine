import 'package:test/test.dart';

import '../support/flutter_consumer_test_harness.dart';

void main() {
  test(
    'external consumer completes the appearance partial-update workflow',
    () async {
      await expectLater(
        runFlutterConsumerTest(
          packageName: 'iwb_canvas_engine_appearance_partial_updates_consumer',
          testFileName: 'appearance_partial_updates_test.dart',
          testSource: _consumerSource,
        ),
        completes,
      );
    },
  );
}

const _consumerSource = '''
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';

void main() {
  test('reads and partially updates committed appearance without document reads', () {
    final source = CanvasDocument(
      background: CanvasBackground(
        color: const Color(0xFF102030),
        grid: CanvasGrid(
          enabled: true,
          cellSize: 12,
          color: const Color(0xAA010203),
        ),
      ),
      palette: CanvasPalette(
        penColors: const [Color(0xFF111111), Color(0xFF222222)],
        backgroundColors: const [Color(0xFF333333)],
        gridSizes: const [6, 12],
      ),
      layers: [
        CanvasLayer(
          id: CanvasLayerId('unrelated-layer'),
          elements: [
            CanvasRectElement(
              id: CanvasElementId('unrelated-element'),
              size: const Size(10, 20),
              fillColor: Color(0xFFABCDEF),
            ),
          ],
        ),
      ],
    );
    final runtime = CanvasRuntime(
      config: const CanvasRuntimeConfig(
        commitResolver: _acceptCommit,
      ),
    );
    addTearDown(runtime.dispose);
    runtime.edits.loadDocumentFromJson(encodeCanvasDocumentToJson(source));

    final before = runtime.readAppearance();
    expect(before.backgroundColor, const Color(0xFF102030));
    expect(before.grid.enabled, isTrue);
    expect(before.grid.cellSize, 12);
    expect(before.grid.color, const Color(0xAA010203));
    expect(
      before.palette.penColors,
      const [Color(0xFF111111), Color(0xFF222222)],
    );
    expect(before.palette.backgroundColors, const [Color(0xFF333333)]);
    expect(before.palette.gridSizes, const [6, 12]);

    runtime.edits.edit((edit) {
      edit.updatePalette(
        CanvasPaletteUpdate(
          penColors: const [Color(0xFF445566)],
        ),
      );
      edit.updateGrid(CanvasGridUpdate(cellSize: 24));
    });

    final after = runtime.readAppearance();
    expect(after.backgroundColor, const Color(0xFF102030));
    expect(after.grid.enabled, isTrue);
    expect(after.grid.cellSize, 24);
    expect(after.grid.color, const Color(0xAA010203));
    expect(after.palette.penColors, const [Color(0xFF445566)]);
    expect(after.palette.backgroundColors, const [Color(0xFF333333)]);
    expect(after.palette.gridSizes, const [6, 12]);
  });
}

const _lease = _Lease();

CanvasCommitResolution _acceptCommit(CanvasCommitRequest request) =>
    switch (request) {
      CanvasMoveCommitRequest(:final proposedDelta) => CanvasMoveCommitAccept(
        delta: proposedDelta,
        lease: _lease,
      ),
      _ => const CanvasCommitAccept(lease: _lease),
    };

final class _Lease implements CanvasCommitLease {
  const _Lease();

  @override
  void aborted() {}

  @override
  void committed() {}
}
''';
