import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/core/nodes.dart';
import 'package:iwb_canvas_engine/src/interactive/interaction_eligibility_policy.dart'
    as interaction_eligibility_policy;
import 'package:iwb_canvas_engine/src/interactive/internal/interactive_selection_utils.dart'
    as interactive_selection_utils;

void main() {
  group('interaction_eligibility_policy', () {
    test(
      'canonical predicates enforce interactive admissibility semantics',
      () {
        final selectable = RectNodeSnapshot(
          id: 'selectable',
          size: const Size(20, 10),
        );
        final hidden = RectNodeSnapshot(
          id: 'hidden',
          size: const Size(20, 10),
          isVisible: false,
        );
        final nonSelectable = RectNodeSnapshot(
          id: 'non-selectable',
          size: const Size(20, 10),
          isSelectable: false,
        );
        final locked = RectNodeSnapshot(
          id: 'locked',
          size: const Size(20, 10),
          isLocked: true,
        );
        final rigid = RectNodeSnapshot(
          id: 'rigid',
          size: const Size(20, 10),
          isTransformable: false,
        );
        final protected = RectNodeSnapshot(
          id: 'protected',
          size: const Size(20, 10),
          isDeletable: false,
        );

        expect(interaction_eligibility_policy.canSelect(selectable), isTrue);
        expect(interaction_eligibility_policy.canSelect(hidden), isFalse);
        expect(
          interaction_eligibility_policy.canSelect(nonSelectable),
          isFalse,
        );

        expect(interaction_eligibility_policy.canTransform(selectable), isTrue);
        expect(interaction_eligibility_policy.canTransform(locked), isFalse);
        expect(interaction_eligibility_policy.canTransform(rigid), isFalse);

        expect(
          interaction_eligibility_policy.canPreviewMove(selectable),
          isTrue,
        );
        expect(interaction_eligibility_policy.canPreviewMove(hidden), isFalse);
        expect(interaction_eligibility_policy.canPreviewMove(locked), isFalse);
        expect(
          interaction_eligibility_policy.canCommitMove(selectable),
          isTrue,
        );
        expect(interaction_eligibility_policy.canCommitMove(rigid), isFalse);

        expect(interaction_eligibility_policy.canDelete(selectable), isTrue);
        expect(interaction_eligibility_policy.canDelete(protected), isFalse);
      },
    );

    test(
      'selection shaping keeps snapshot order and shared policy filters',
      () {
        final previewable = RectNodeSnapshot(
          id: 'previewable',
          size: const Size(20, 10),
        );
        final hidden = RectNodeSnapshot(
          id: 'hidden',
          size: const Size(20, 10),
          isVisible: false,
        );
        final locked = RectNodeSnapshot(
          id: 'locked',
          size: const Size(20, 10),
          isLocked: true,
        );
        final protected = RectNodeSnapshot(
          id: 'protected',
          size: const Size(20, 10),
          isDeletable: false,
        );
        final snapshot = SceneSnapshot(
          layers: <ContentLayerSnapshot>[
            ContentLayerSnapshot(
              id: 'layer-auto-0',
              nodes: <NodeSnapshot>[hidden, previewable],
            ),
            ContentLayerSnapshot(
              id: 'layer-auto-1',
              nodes: <NodeSnapshot>[locked, protected],
            ),
          ],
        );

        expect(
          interaction_eligibility_policy
              .selectedPreviewMovableNodesInSnapshotOrder(
                snapshot: snapshot,
                selected: const <NodeId>{
                  'previewable',
                  'hidden',
                  'locked',
                  'protected',
                },
              )
              .map((node) => node.id),
          const <NodeId>['previewable', 'protected'],
        );
        expect(
          interaction_eligibility_policy
              .selectedTransformableNodesInSnapshotOrder(
                snapshot: snapshot,
                selected: const <NodeId>{
                  'previewable',
                  'hidden',
                  'locked',
                  'protected',
                },
              )
              .map((node) => node.id),
          const <NodeId>['hidden', 'previewable', 'protected'],
        );
        expect(
          interaction_eligibility_policy.deletableSelectedNodeIdsInSnapshot(
            snapshot: snapshot,
            selected: const <NodeId>{
              'previewable',
              'hidden',
              'locked',
              'protected',
            },
          ),
          const <NodeId>['hidden', 'previewable', 'locked'],
        );
        expect(
          interaction_eligibility_policy.centerWorldForNodeSnapshots(
            <NodeSnapshot>[previewable, protected],
          ),
          Offset.zero,
        );
      },
    );

    test('legacy session wrappers delegate to shared eligibility policy', () {
      final previewable = RectNodeSnapshot(
        id: 'previewable',
        size: const Size(20, 10),
      );
      final lockedProtected = RectNodeSnapshot(
        id: 'locked-protected',
        size: const Size(20, 10),
        isLocked: true,
        isDeletable: false,
      );
      final snapshot = SceneSnapshot(
        layers: <ContentLayerSnapshot>[
          ContentLayerSnapshot(
            id: 'layer-auto-2',
            nodes: <NodeSnapshot>[previewable, lockedProtected],
          ),
        ],
      );

      expect(
        interactive_selection_utils.selectedTransformableNodesInSnapshotOrder(
          snapshot: snapshot,
          selected: const <NodeId>{'previewable', 'locked-protected'},
        ),
        interaction_eligibility_policy
            .selectedTransformableNodesInSnapshotOrder(
              snapshot: snapshot,
              selected: const <NodeId>{'previewable', 'locked-protected'},
            ),
      );
      expect(
        interactive_selection_utils.deletableSelectedNodeIdsInSnapshot(
          snapshot: snapshot,
          selected: const <NodeId>{'previewable', 'locked-protected'},
        ),
        interaction_eligibility_policy.deletableSelectedNodeIdsInSnapshot(
          snapshot: snapshot,
          selected: const <NodeId>{'previewable', 'locked-protected'},
        ),
      );
      expect(
        interactive_selection_utils.centerWorldForNodeSnapshots(<NodeSnapshot>[
          previewable,
          lockedProtected,
        ]),
        interaction_eligibility_policy.centerWorldForNodeSnapshots(
          <NodeSnapshot>[previewable, lockedProtected],
        ),
      );
    });

    test('runtime scene-node helpers follow the shared move policy', () {
      final movable = RectNode(id: 'movable', size: const Size(20, 10));
      final hidden = RectNode(
        id: 'hidden',
        size: const Size(20, 10),
        isVisible: false,
      );
      final locked = RectNode(
        id: 'locked',
        size: const Size(20, 10),
        isLocked: true,
      );

      expect(
        interaction_eligibility_policy.canSelectSceneNode(movable),
        isTrue,
      );
      expect(
        interaction_eligibility_policy.canSelectSceneNode(hidden),
        isFalse,
      );
      expect(
        interaction_eligibility_policy.canPreviewMoveSceneNode(movable),
        isTrue,
      );
      expect(
        interaction_eligibility_policy.canPreviewMoveSceneNode(locked),
        isFalse,
      );
    });
  });
}
