import 'dart:ui';

import 'package:iwb_canvas_engine/src/core/transform2d.dart';

import '../harness/event_script.dart';

List<HarnessScript> buildParityScripts() {
  return <HarnessScript>[
    HarnessScript(
      name: 'script_01_crud_and_selection',
      steps: const <HarnessStep>[
        HarnessStep(
          tag: 'add rect A',
          operation: AddRectOp(
            id: 'rect-a',
            position: Offset(100, 120),
            size: Size(80, 50),
            fillColor: Color(0xFF42A5F5),
          ),
        ),
        HarnessStep(
          tag: 'add text A',
          operation: AddTextOp(
            id: 'text-a',
            position: Offset(240, 140),
            size: Size(180, 48),
            text: 'Parity',
          ),
        ),
        HarnessStep(
          tag: 'set selection',
          operation: ReplaceSelectionOp(ids: <String>['rect-a']),
        ),
        HarnessStep(
          tag: 'toggle selection text',
          operation: ToggleSelectionOp(id: 'text-a'),
        ),
        HarnessStep(
          tag: 'patch rect style',
          operation: PatchRectStyleOp(
            id: 'rect-a',
            fillColor: Color(0xFF66BB6A),
            strokeColor: Color(0xFF1B5E20),
            strokeWidth: 2,
          ),
        ),
        HarnessStep(
          tag: 'delete text',
          operation: DeleteNodeOp(id: 'text-a'),
        ),
      ],
    ),
    HarnessScript(
      name: 'script_02_transform_and_bounds',
      steps: const <HarnessStep>[
        HarnessStep(
          tag: 'add rect A',
          operation: AddRectOp(
            id: 'rect-a',
            position: Offset(100, 140),
            size: Size(70, 40),
          ),
        ),
        HarnessStep(
          tag: 'add rect B',
          operation: AddRectOp(
            id: 'rect-b',
            position: Offset(240, 140),
            size: Size(70, 40),
          ),
        ),
        HarnessStep(
          tag: 'select both',
          operation: ReplaceSelectionOp(ids: <String>['rect-a', 'rect-b']),
        ),
        HarnessStep(
          tag: 'translate selection',
          operation: TranslateSelectionOp(delta: Offset(30, -20)),
        ),
        HarnessStep(
          tag: 'patch common transform rect-b',
          operation: PatchNodeCommonOp(
            id: 'rect-b',
            kind: HarnessNodeKind.rect,
            transform: Transform2D(a: 1, b: 0, c: 0, d: 1, tx: 320, ty: 80),
          ),
        ),
        HarnessStep(
          tag: 'replace scene',
          operation: ReplaceSceneOp(
            sceneJson: <String, dynamic>{
              'schemaVersion': 2,
              'camera': <String, dynamic>{'offsetX': 12, 'offsetY': -6},
              'background': <String, dynamic>{
                'color': '#FFFFFFFF',
                'grid': <String, dynamic>{
                  'enabled': true,
                  'cellSize': 25,
                  'color': '#1F000000',
                },
              },
              'palette': <String, dynamic>{
                'penColors': <String>['#FF000000'],
                'backgroundColors': <String>['#FFFFFFFF'],
                'gridSizes': <num>[20, 25, 40],
              },
              'layers': <Map<String, dynamic>>[
                <String, dynamic>{'isBackground': true, 'nodes': <Object>[]},
                <String, dynamic>{
                  'isBackground': false,
                  'nodes': <Map<String, dynamic>>[
                    <String, dynamic>{
                      'id': 'rect-c',
                      'type': 'rect',
                      'transform': <String, dynamic>{
                        'a': 1,
                        'b': 0,
                        'c': 0,
                        'd': 1,
                        'tx': 180,
                        'ty': 140,
                      },
                      'hitPadding': 0,
                      'opacity': 1,
                      'isVisible': true,
                      'isSelectable': true,
                      'isLocked': false,
                      'isDeletable': true,
                      'isTransformable': true,
                      'size': <String, dynamic>{'w': 90, 'h': 60},
                      'strokeWidth': 1,
                      'fillColor': '#FFAB47BC',
                    },
                  ],
                },
              ],
            },
          ),
        ),
      ],
    ),
    HarnessScript(
      name: 'script_03_draw_pipeline',
      steps: const <HarnessStep>[
        HarnessStep(
          tag: 'draw stroke',
          operation: DrawStrokeOp(
            id: 'stroke-a',
            points: <Offset>[
              Offset(100, 100),
              Offset(120, 110),
              Offset(140, 125),
            ],
            thickness: 4,
            color: Color(0xFF1E88E5),
          ),
        ),
        HarnessStep(
          tag: 'draw line',
          operation: DrawLineOp(
            id: 'line-a',
            start: Offset(180, 120),
            end: Offset(280, 210),
            thickness: 3,
            color: Color(0xFFEF5350),
          ),
        ),
        HarnessStep(
          tag: 'erase stroke',
          operation: EraseNodesOp(ids: <String>['stroke-a']),
        ),
      ],
    ),
    HarnessScript(
      name: 'script_04_grid_and_visual_flags',
      steps: const <HarnessStep>[
        HarnessStep(
          tag: 'enable grid',
          operation: SetGridEnabledOp(value: true),
        ),
        HarnessStep(
          tag: 'set dense grid',
          operation: SetGridCellSizeOp(value: 0.5),
        ),
        HarnessStep(
          tag: 'add rect',
          operation: AddRectOp(
            id: 'rect-a',
            position: Offset(200, 180),
            size: Size(120, 50),
            fillColor: Color(0xFFFFEE58),
          ),
        ),
        HarnessStep(
          tag: 'patch opacity',
          operation: PatchNodeCommonOp(
            id: 'rect-a',
            kind: HarnessNodeKind.rect,
            opacity: 0.5,
          ),
        ),
      ],
    ),
    HarnessScript(
      name: 'script_05_mixed_batch',
      steps: const <HarnessStep>[
        HarnessStep(
          tag: 'add rect A',
          operation: AddRectOp(
            id: 'rect-a',
            position: Offset(100, 120),
            size: Size(90, 40),
          ),
        ),
        HarnessStep(
          tag: 'add rect B',
          operation: AddRectOp(
            id: 'rect-b',
            position: Offset(240, 130),
            size: Size(70, 50),
          ),
        ),
        HarnessStep(
          tag: 'add text',
          operation: AddTextOp(
            id: 'text-a',
            position: Offset(210, 240),
            size: Size(200, 40),
            text: 'Mixed batch',
          ),
        ),
        HarnessStep(
          tag: 'select A+B',
          operation: ReplaceSelectionOp(ids: <String>['rect-a', 'rect-b']),
        ),
        HarnessStep(
          tag: 'translate',
          operation: TranslateSelectionOp(delta: Offset(-15, 25)),
        ),
        HarnessStep(
          tag: 'toggle text',
          operation: ToggleSelectionOp(id: 'text-a'),
        ),
        HarnessStep(
          tag: 'patch rect B style',
          operation: PatchRectStyleOp(
            id: 'rect-b',
            fillColor: Color(0xFF8D6E63),
            strokeColor: Color(0xFF4E342E),
            strokeWidth: 3,
          ),
        ),
        HarnessStep(
          tag: 'draw line',
          operation: DrawLineOp(
            id: 'line-a',
            start: Offset(80, 300),
            end: Offset(360, 300),
            thickness: 2,
            color: Color(0xFF26A69A),
          ),
        ),
        HarnessStep(
          tag: 'draw stroke',
          operation: DrawStrokeOp(
            id: 'stroke-a',
            points: <Offset>[
              Offset(120, 340),
              Offset(190, 355),
              Offset(260, 350),
            ],
            thickness: 5,
            color: Color(0xFF5C6BC0),
          ),
        ),
        HarnessStep(
          tag: 'erase line',
          operation: EraseNodesOp(ids: <String>['line-a']),
        ),
        HarnessStep(
          tag: 'enable grid',
          operation: SetGridEnabledOp(value: true),
        ),
        HarnessStep(
          tag: 'set grid size',
          operation: SetGridCellSizeOp(value: 32),
        ),
        HarnessStep(
          tag: 'delete text',
          operation: DeleteNodeOp(id: 'text-a'),
        ),
      ],
    ),
  ];
}
