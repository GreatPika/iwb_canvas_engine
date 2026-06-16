final class PerformanceScenarioCatalogGroup {
  const PerformanceScenarioCatalogGroup({
    required this.id,
    required this.migration,
    required this.phases,
  });

  final String id;
  final String migration;
  final List<PerformanceScenarioCatalogPhase> phases;
}

final class PerformanceScenarioCatalogPhase {
  const PerformanceScenarioCatalogPhase({
    required this.kind,
    required this.name,
    required this.comparisonRole,
    this.repeats = 1,
    this.canonicalPreparation,
    this.resetReason,
    this.measuredAction,
  });

  final String kind;
  final String name;
  final String comparisonRole;
  final int repeats;
  final String? canonicalPreparation;
  final String? resetReason;
  final String? measuredAction;

  String get key => '$kind.$name';
}

final class PerformanceScenarioCatalogRun {
  const PerformanceScenarioCatalogRun({
    required this.scenarioGroup,
    required this.phase,
    required this.repeat,
    required this.reportKey,
  });

  final PerformanceScenarioCatalogGroup scenarioGroup;
  final PerformanceScenarioCatalogPhase phase;
  final int repeat;
  final String reportKey;

  String get scenarioGroupId => scenarioGroup.id;
  String get phaseKey => phase.key;
}

const performanceSteadyRepeatCount = 5;

final List<PerformanceScenarioCatalogGroup> performanceScenarioCatalogGroups =
    List<PerformanceScenarioCatalogGroup>.unmodifiable([
      const PerformanceScenarioCatalogGroup(
        id: 'load_document.100k',
        migration: 'redesigned',
        phases: [
          PerformanceScenarioCatalogPhase(
            kind: 'setup',
            name: 'fixture_json',
            comparisonRole: 'setup_context',
          ),
          PerformanceScenarioCatalogPhase(
            kind: 'warm',
            name: 'load_document',
            comparisonRole: 'first_use_action',
            canonicalPreparation: 'empty_runtime_with_prepared_json_fixture',
            resetReason: 'load_writes_document_state',
            measuredAction: 'load_document',
          ),
          PerformanceScenarioCatalogPhase(
            kind: 'steady',
            name: 'load_document',
            comparisonRole: 'steady_action',
            repeats: performanceSteadyRepeatCount,
            canonicalPreparation: 'empty_runtime_with_prepared_json_fixture',
            resetReason: 'load_writes_document_state',
            measuredAction: 'load_document',
          ),
        ],
      ),
      const PerformanceScenarioCatalogGroup(
        id: 'first_canvas_frame.50k',
        migration: 'redesigned',
        phases: [
          PerformanceScenarioCatalogPhase(
            kind: 'setup',
            name: 'preloaded_runtime',
            comparisonRole: 'setup_context',
          ),
          PerformanceScenarioCatalogPhase(
            kind: 'warm',
            name: 'first_canvas_frame',
            comparisonRole: 'first_use_action',
            canonicalPreparation:
                'preloaded_runtime_not_rendered_by_measured_surface',
            resetReason: 'first_frame_cost_disappears_after_render',
            measuredAction: 'first_canvas_frame',
          ),
          PerformanceScenarioCatalogPhase(
            kind: 'steady',
            name: 'first_canvas_frame',
            comparisonRole: 'steady_action',
            repeats: performanceSteadyRepeatCount,
            canonicalPreparation:
                'preloaded_runtime_not_rendered_by_measured_surface',
            resetReason: 'first_frame_cost_disappears_after_render',
            measuredAction: 'first_canvas_frame',
          ),
        ],
      ),
      const PerformanceScenarioCatalogGroup(
        id: 'camera_pan.100k',
        migration: 'redesigned',
        phases: [
          PerformanceScenarioCatalogPhase(
            kind: 'setup',
            name: 'loaded_document',
            comparisonRole: 'setup_context',
          ),
          PerformanceScenarioCatalogPhase(
            kind: 'warm',
            name: 'camera_pan',
            comparisonRole: 'first_use_action',
            canonicalPreparation:
                'loaded_document_camera_origin_settled_surface',
            resetReason: 'pan_accumulates_camera_offset',
            measuredAction: 'camera_pan',
          ),
          PerformanceScenarioCatalogPhase(
            kind: 'steady',
            name: 'camera_pan',
            comparisonRole: 'steady_action',
            repeats: performanceSteadyRepeatCount,
            canonicalPreparation:
                'loaded_document_camera_origin_settled_surface',
            resetReason: 'pan_accumulates_camera_offset',
            measuredAction: 'camera_pan',
          ),
        ],
      ),
      const PerformanceScenarioCatalogGroup(
        id: 'selection_move.50k',
        migration: 'redesigned',
        phases: [
          PerformanceScenarioCatalogPhase(
            kind: 'setup',
            name: 'loaded_selected_document',
            comparisonRole: 'setup_context',
          ),
          PerformanceScenarioCatalogPhase(
            kind: 'warm',
            name: 'selection_move',
            comparisonRole: 'first_use_action',
            canonicalPreparation: 'loaded_selected_document_original_geometry',
            resetReason: 'move_translates_selected_geometry',
            measuredAction: 'selection_move',
          ),
          PerformanceScenarioCatalogPhase(
            kind: 'steady',
            name: 'selection_move',
            comparisonRole: 'steady_action',
            repeats: performanceSteadyRepeatCount,
            canonicalPreparation: 'loaded_selected_document_original_geometry',
            resetReason: 'move_translates_selected_geometry',
            measuredAction: 'selection_move',
          ),
        ],
      ),
      const PerformanceScenarioCatalogGroup(
        id: 'marquee_select.50k',
        migration: 'redesigned',
        phases: [
          PerformanceScenarioCatalogPhase(
            kind: 'setup',
            name: 'loaded_document',
            comparisonRole: 'setup_context',
          ),
          PerformanceScenarioCatalogPhase(
            kind: 'warm',
            name: 'marquee_select',
            comparisonRole: 'first_use_action',
            canonicalPreparation:
                'loaded_document_move_mode_no_selection_settled_surface',
            resetReason: 'marquee_commit_replaces_selection',
            measuredAction: 'marquee_select',
          ),
          PerformanceScenarioCatalogPhase(
            kind: 'steady',
            name: 'marquee_select',
            comparisonRole: 'steady_action',
            repeats: performanceSteadyRepeatCount,
            canonicalPreparation:
                'loaded_document_move_mode_no_selection_settled_surface',
            resetReason: 'marquee_commit_replaces_selection',
            measuredAction: 'marquee_select',
          ),
        ],
      ),
      const PerformanceScenarioCatalogGroup(
        id: 'json_export.50k',
        migration: 'redesigned',
        phases: [
          PerformanceScenarioCatalogPhase(
            kind: 'setup',
            name: 'loaded_document',
            comparisonRole: 'setup_context',
          ),
          PerformanceScenarioCatalogPhase(
            kind: 'warm',
            name: 'json_export',
            comparisonRole: 'first_use_action',
            canonicalPreparation:
                'loaded_document_stable_order_no_pending_edit',
            resetReason: 'export_reset_keeps_repeats_comparable',
            measuredAction: 'json_export',
          ),
          PerformanceScenarioCatalogPhase(
            kind: 'steady',
            name: 'json_export',
            comparisonRole: 'steady_action',
            repeats: performanceSteadyRepeatCount,
            canonicalPreparation:
                'loaded_document_stable_order_no_pending_edit',
            resetReason: 'export_reset_keeps_repeats_comparable',
            measuredAction: 'json_export',
          ),
        ],
      ),
      const PerformanceScenarioCatalogGroup(
        id: 'eraser_dense_50k',
        migration: 'redesigned',
        phases: [
          PerformanceScenarioCatalogPhase(
            kind: 'setup',
            name: 'loaded_draw_mode_document',
            comparisonRole: 'setup_context',
          ),
          PerformanceScenarioCatalogPhase(
            kind: 'warm',
            name: 'eraser_dense',
            comparisonRole: 'first_use_action',
            canonicalPreparation:
                'loaded_draw_mode_eraser_document_without_prior_erasure',
            resetReason: 'eraser_removes_elements',
            measuredAction: 'eraser_dense',
          ),
          PerformanceScenarioCatalogPhase(
            kind: 'steady',
            name: 'eraser_dense',
            comparisonRole: 'steady_action',
            repeats: performanceSteadyRepeatCount,
            canonicalPreparation:
                'loaded_draw_mode_eraser_document_without_prior_erasure',
            resetReason: 'eraser_removes_elements',
            measuredAction: 'eraser_dense',
          ),
        ],
      ),
      for (final id in performanceSingleCurrentBehaviorGroupIds)
        PerformanceScenarioCatalogGroup(
          id: id,
          migration: 'single.current_behavior',
          phases: const [
            PerformanceScenarioCatalogPhase(
              kind: 'single',
              name: 'current_behavior',
              comparisonRole: 'current_behavior',
            ),
          ],
        ),
    ]);

final List<PerformanceScenarioCatalogRun> performanceScenarioCatalogRuns =
    List<PerformanceScenarioCatalogRun>.unmodifiable([
      for (final group in performanceScenarioCatalogGroups)
        for (final phase in group.phases)
          for (var repeat = 1; repeat <= phase.repeats; repeat += 1)
            PerformanceScenarioCatalogRun(
              scenarioGroup: group,
              phase: phase,
              repeat: repeat,
              reportKey: performanceReportKey(
                scenarioGroup: group.id,
                phaseKind: phase.kind,
                phaseName: phase.name,
                repeat: repeat,
              ),
            ),
    ]);

const performanceSingleCurrentBehaviorGroupIds = [
  'load_document.1k',
  'load_document.10k',
  'load_document.50k',
  'camera_pan.50k',
  'selection_tap.10k',
  'selection_move.10k',
  'pencil_draw.10k',
  'marker_draw.10k',
  'line_two_tap.50k',
  'eraser_normal.50k',
  'context_delete.10k',
  'text_edit.open_commit',
  'text_style_change.10k',
  'resource_image_cold',
  'resource_image_warm',
  'resource_mark_dirty',
  'missing_resource',
  'surface_runtime_swap',
  'dispose_during_preview',
];

String performanceReportKey({
  required String scenarioGroup,
  required String phaseKind,
  required String phaseName,
  required int repeat,
}) {
  if (repeat < 1 || repeat > 999) {
    throw RangeError.range(repeat, 1, 999, 'repeat');
  }
  return '$scenarioGroup'
      '__$phaseKind.$phaseName'
      '__repeat_${repeat.toString().padLeft(3, '0')}';
}
