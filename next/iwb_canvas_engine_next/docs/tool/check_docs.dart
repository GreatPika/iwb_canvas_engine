import 'dart:io';

import 'package:yaml/yaml.dart';

const _sectionsRegistryPath = 'docs/_registry/sections.yaml';

const _globalCatalogSections = {
  'section_22_guardrails_machine_checks',
  'section_23_tests',
  'section_27_final_release_gates',
};

const _mustReadGlobalCatalogAllowlist = {
  'section_23_tests': {'section_22_guardrails_machine_checks'},
  'section_27_final_release_gates': {
    'section_22_guardrails_machine_checks',
    'section_23_tests',
  },
};

const _donorRelatedSectionCatalogExclusions = {
  'section_23_tests',
  'section_27_final_release_gates',
};

const _ownerAliases = {
  'Public': 'PublicAPI',
  'PublicAPI': 'PublicAPI',
  'Surface': 'Surface',
  'RuntimeRoot': 'RuntimeRoot',
  'Store': 'DocumentStoreKernel',
  'DocumentStoreKernel': 'DocumentStoreKernel',
  'Edit': 'EditKernel',
  'EditKernel': 'EditKernel',
  'InteractionEngine': 'InteractionEngine',
  'FrameEngine': 'FrameEngine',
  'Spatial': 'SpatialKernel',
  'SpatialKernel': 'SpatialKernel',
  'Resource': 'ResourceKernel',
  'ResourceKernel': 'ResourceKernel',
  'Codec': 'CodecBoundary',
  'CodecBoundary': 'CodecBoundary',
  'Diagnostics': 'DiagnosticsHub',
  'DiagnosticsHub': 'DiagnosticsHub',
};

const _allowedOwnerEdges = {
  'PublicAPI->RuntimeRoot',
  'Surface->RuntimeRoot',
  'RuntimeRoot->DocumentStoreKernel',
  'RuntimeRoot->EditKernel',
  'RuntimeRoot->InteractionEngine',
  'RuntimeRoot->FrameEngine',
  'RuntimeRoot->SpatialKernel',
  'RuntimeRoot->ResourceKernel',
  'RuntimeRoot->CodecBoundary',
  'RuntimeRoot->DiagnosticsHub',
  'EditKernel->DocumentStoreKernel',
  'EditKernel->DiagnosticsHub',
  'InteractionEngine->EditKernel',
  'InteractionEngine->SpatialKernel',
  'FrameEngine->DocumentStoreKernel',
  'FrameEngine->SpatialKernel',
  'FrameEngine->ResourceKernel',
  'SpatialKernel->DocumentStoreKernel',
  'CodecBoundary->DocumentStoreKernel',
  'CodecBoundary->DiagnosticsHub',
};

const _phaseDocs = {
  'P0': 'docs/implementation/p0_package_skeleton_and_hard_boundaries.md',
  'P1': 'docs/implementation/p1_legacy_oracle_lock.md',
  'P1.5': 'docs/implementation/p1_5_v1_scope_gate_before_public_api_freeze.md',
  'P2': 'docs/implementation/p2_public_api_v1_freeze.md',
  'P3': 'docs/implementation/p3_schema_v1_dto_validation_and_codec_skeleton.md',
  'P4': 'docs/implementation/p4_resources.md',
  'P5': 'docs/implementation/p5_store_kernel_and_projection_cache.md',
  'P6': 'docs/implementation/p6_edit_kernel.md',
  'P7': 'docs/implementation/p7_spatial_and_geometry.md',
  'P8': 'docs/implementation/p8_frame_engine_and_render_caches.md',
  'P9': 'docs/implementation/p9_interaction_engine.md',
  'P10': 'docs/implementation/p10_flutter_surface.md',
  'P12': 'docs/implementation/p12_benchmarks_diagrams_and_release_readiness.md',
};

final _errors = <String>[];
final _sectionIds = <String>{};

void main() {
  _checkRequiredEntrypoints();
  _checkSectionsRegistry();
  _checkDiagramCatalogRegistrySymmetry();
  _checkMarkdownPaths();
  _checkNoRetiredActiveReferences();
  _checkImplementationPhaseClarity();
  _checkDiagramContractAlignment();
  _checkSemanticDocumentationProbes();
  _checkArchitectureLenses();
  _checkRegistryWitnesses();

  if (_errors.isNotEmpty) {
    stderr.writeln('Docs check failed:');
    for (final error in _errors) {
      stderr.writeln('- $error');
    }
    exitCode = 1;
    return;
  }

  stdout.writeln('Docs check passed.');
}

void _checkRequiredEntrypoints() {
  const requiredFiles = [
    'docs/README.md',
    'docs/architecture/README.md',
    _sectionsRegistryPath,
  ];
  const requiredDirs = [
    'docs/architecture',
    'docs/contracts',
    'docs/implementation',
    'docs/verification',
    'docs/donors',
    'docs/indexes',
    '../../plan',
  ];

  for (final path in requiredFiles) {
    _requireFile(path);
  }
  for (final path in requiredDirs) {
    _requireDirectory(path);
  }
}

void _checkSectionsRegistry() {
  final sections = _loadYamlMapList(_sectionsRegistryPath);
  for (final section in sections) {
    final id = _stringField(section, 'id', 'section registry entry');
    final file = _stringField(section, 'file', id);
    if (!_sectionIds.add(id)) {
      _fail('duplicate section id: $id');
    }
    _requireFile(file);
  }

  for (final section in sections) {
    final id = _stringField(section, 'id', 'section registry entry');
    _checkReferenceList(section, 'must_read', id);
  }

  _checkMustReadGraph(sections);
}

void _checkDiagramCatalogRegistrySymmetry() {
  final sections = _loadYamlMapList(_sectionsRegistryPath);
  final catalog = _loadDiagramCatalog('docs/diagrams/README.md');
  final registry = <String, Set<String>>{};

  for (final section in sections) {
    final sectionId = _stringField(section, 'id', 'section registry entry');
    final diagrams = section['diagrams'];
    if (diagrams == null || diagrams is! YamlList) {
      _fail('$sectionId has no list field diagrams');
      continue;
    }
    for (final item in diagrams) {
      final diagramId = item.toString();
      if (diagramId == 'none') {
        continue;
      }
      registry.putIfAbsent(diagramId, () => <String>{}).add(sectionId);
      if (!catalog.containsKey(diagramId)) {
        _fail(
          '$sectionId references diagram $diagramId, '
          'but docs/diagrams/README.md does not catalog it',
        );
      }
    }
  }

  for (final entry in catalog.entries) {
    final diagramId = entry.key;
    final catalogSections = entry.value;
    if (catalogSections.isEmpty) {
      _fail('docs/diagrams/README.md catalog entry $diagramId has no sections');
    }
    final registrySections = registry[diagramId] ?? const <String>{};

    for (final sectionId in catalogSections) {
      if (!_sectionIds.contains(sectionId)) {
        _fail(
          'docs/diagrams/README.md references unknown section id $sectionId',
        );
        continue;
      }
      if (!registrySections.contains(sectionId)) {
        _fail(
          'diagram $diagramId is related to $sectionId in '
          'docs/diagrams/README.md, but $sectionId does not list $diagramId '
          'in docs/_registry/sections.yaml',
        );
      }
    }

    for (final sectionId in registrySections) {
      if (!catalogSections.contains(sectionId)) {
        _fail(
          '$sectionId lists diagram $diagramId in docs/_registry/sections.yaml, '
          'but docs/diagrams/README.md does not list $sectionId under '
          '$diagramId',
        );
      }
    }
  }

  final catalogedFiles = catalog.keys
      .map((diagramId) => 'docs/diagrams/$diagramId.mmd')
      .toSet();
  final diagramDir = Directory('docs/diagrams');
  if (diagramDir.existsSync()) {
    for (final file in diagramDir.listSync().whereType<File>()) {
      if (!file.path.endsWith('.mmd')) {
        continue;
      }
      if (!catalogedFiles.contains(file.path)) {
        _fail(
          '${file.path} exists but is not cataloged in docs/diagrams/README.md',
        );
      }
    }
  }
}

void _checkMarkdownPaths() {
  final roots = [
    Directory('docs/architecture'),
    Directory('docs/contracts'),
    Directory('docs/implementation'),
    Directory('docs/verification'),
    Directory('docs/donors'),
    Directory('docs/indexes'),
    Directory('docs/_registry'),
  ];

  for (final root in roots) {
    if (!root.existsSync()) {
      continue;
    }
    for (final file in root.listSync(recursive: true).whereType<File>()) {
      if (!file.path.endsWith('.md')) {
        continue;
      }
      final text = file.readAsStringSync();
      _checkSectionIdsInText(file.path, text);
      _checkDocumentPathsInText(file.path, text);
    }
  }

  for (final path in ['docs/README.md']) {
    final text = _read(path);
    _checkSectionIdsInText(path, text);
    _checkDocumentPathsInText(path, text);
  }
}

Map<String, Set<String>> _loadDiagramCatalog(String path) {
  _requireFile(path);
  final text = _read(path);
  final catalog = <String, Set<String>>{};
  final blocks = text.split(RegExp(r'^##\s+', multiLine: true));

  for (final block in blocks.skip(1)) {
    final lines = block.split('\n');
    if (lines.isEmpty) {
      continue;
    }
    final diagramId = lines.first.trim();
    if (diagramId.isEmpty) {
      _fail('$path contains an empty diagram heading');
      continue;
    }
    if (catalog.containsKey(diagramId)) {
      _fail('$path contains duplicate diagram entry $diagramId');
      continue;
    }

    String? plannedPath;
    final sections = <String>{};
    for (final line in lines.skip(1)) {
      final plannedPathMatch = RegExp(
        r'^- Planned path: `(docs/diagrams/[^`]+\.mmd)`$',
      ).firstMatch(line);
      if (plannedPathMatch != null) {
        plannedPath = plannedPathMatch.group(1);
        continue;
      }
      final sectionsMatch = RegExp(
        r'^- Related sections: (.+)$',
      ).firstMatch(line);
      if (sectionsMatch != null) {
        final relatedSections = _matchGroup(
          sectionsMatch,
          1,
          '$path related sections line',
        );
        for (final match in RegExp(
          r'`(section_[^`]+)`',
        ).allMatches(relatedSections)) {
          sections.add(_matchGroup(match, 1, '$path section reference'));
        }
      }
    }

    final expectedPath = 'docs/diagrams/$diagramId.mmd';
    if (plannedPath == null) {
      _fail('$path catalog entry $diagramId has no planned path');
    } else if (plannedPath != expectedPath) {
      _fail(
        '$path catalog entry $diagramId planned path must be $expectedPath, '
        'not $plannedPath',
      );
    }
    _requireFile(expectedPath, source: path);

    catalog[diagramId] = sections;
  }

  return catalog;
}

void _checkNoRetiredActiveReferences() {
  final retired = [
    'canonical truth remains',
    'iwb_canvas_engine_next_full_implementation_plan_v2',
    'iwb_canvas_engine_next_donor_inventory',
    'packages/iwb_canvas_engine_next',
    'ne'
        'w_api.',
    'ne'
        'w_core.',
    'no_o'
        'ld_public_types',
  ];
  final activeRoots = [
    Directory('docs/architecture'),
    Directory('docs/contracts'),
    Directory('docs/implementation'),
    Directory('docs/verification'),
    Directory('docs/donors'),
    Directory('docs/indexes'),
    Directory('docs/_registry'),
  ];

  for (final root in activeRoots) {
    if (!root.existsSync()) {
      continue;
    }
    for (final file in root.listSync(recursive: true).whereType<File>()) {
      final text = file.readAsStringSync();
      for (final token in retired) {
        if (text.contains(token)) {
          _fail('${file.path} contains retired reference: $token');
        }
      }
    }
  }
}

void _checkImplementationPhaseClarity() {
  final implementationDir = Directory('docs/implementation');
  if (!implementationDir.existsSync()) {
    return;
  }

  final forbiddenText = <String, RegExp>{
    'use human-readable donor decision copy/adapt in phase docs; copy_adapt is registry YAML only':
        RegExp(r'\bcopy_adapt\b'),
    'use human-readable donor decision adapt/rewrite in phase docs; adapt_rewrite is registry YAML only':
        RegExp(r'\badapt_rewrite\b'),
    'use human-readable donor decision rewrite-reference in phase docs; rewrite_reference is registry YAML only':
        RegExp(r'\brewrite_reference\b'),
  };

  for (final file
      in implementationDir.listSync(recursive: true).whereType<File>()) {
    if (!file.path.endsWith('.md')) {
      continue;
    }
    final text = file.readAsStringSync();
    for (final entry in forbiddenText.entries) {
      for (final match in entry.value.allMatches(text)) {
        _fail('${file.path}:${_lineNumber(text, match.start)} ${entry.key}');
      }
    }
  }
}

void _checkDiagramContractAlignment() {
  final files = <File>[];
  final diagramDir = Directory('docs/diagrams');
  if (diagramDir.existsSync()) {
    files.addAll(
      diagramDir
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.mmd')),
    );
  }

  for (final root in [
    Directory('docs/architecture'),
    Directory('docs/contracts'),
    Directory('docs/implementation'),
    Directory('docs/verification'),
    Directory('docs/donors'),
    Directory('docs/indexes'),
  ]) {
    if (!root.existsSync()) {
      continue;
    }
    files.addAll(
      root
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.md')),
    );
  }

  final forbiddenText = <String, RegExp>{
    'use controllerEpoch, not a separate tool epoch': RegExp(
      r'\btool epoch\b',
      caseSensitive: false,
    ),
    'use controllerEpoch, not controller/tool epoch': RegExp(
      r'\bcontroller/tool epoch\b',
      caseSensitive: false,
    ),
    'use explicit controllerEpoch mismatch, not mode/tool epoch mismatch':
        RegExp(r'\bmode/tool epoch mismatch\b', caseSensitive: false),
    'use controllerEpoch wording, not same-epoch': RegExp(
      r'\bsame-epoch\b',
      caseSensitive: false,
    ),
    'use controllerEpoch wording, not same epoch': RegExp(
      r'\bsame epoch\b',
      caseSensitive: false,
    ),
    'use controllerEpoch mismatch, not wrong epoch': RegExp(
      r'\bwrong epoch\b',
      caseSensitive: false,
    ),
    'use controllerEpoch mismatch, not stale epoch': RegExp(
      r'\bstale epoch\b',
      caseSensitive: false,
    ),
    'eraser candidates are deletable non-background, not visible deletable':
        RegExp(r'\bvisible deletable\b', caseSensitive: false),
    'ResourceKernel owns dirty ids/cache entries, not listener/cache references':
        RegExp(r'\blistener/cache references\b', caseSensitive: false),
    'resource disposal clears caches and dirty state, not listeners': RegExp(
      r'\bresource caches and listeners\b',
      caseSensitive: false,
    ),
    'disposed resources must not reopen listeners': RegExp(
      r'\breopen listeners\b',
      caseSensitive: false,
    ),
  };

  for (final file in files) {
    final text = file.readAsStringSync();
    for (final entry in forbiddenText.entries) {
      for (final match in entry.value.allMatches(text)) {
        _fail('${file.path}:${_lineNumber(text, match.start)} ${entry.key}');
      }
    }

    if (file.path.endsWith('.mmd')) {
      _checkStoreDoesNotDispatchRuntimeEffects(file.path, text);
      _checkInteractionDoesNotBypassEditKernel(file.path, text);
    }
  }
}

void _checkSemanticDocumentationProbes() {
  final loadContract = _read('docs/contracts/load_document.md');
  if (RegExp(
    r'atomic install committed document;\s*\n\s*\d+\.\s*clear selection',
  ).hasMatch(loadContract)) {
    _fail(
      'loadDocument contract still allows install followed by clear selection',
    );
  }
  if (!loadContract.contains('including cleared selection')) {
    _fail(
      'loadDocument contract must say selection is inside replacement payload',
    );
  }

  final loadSequence = _read('docs/diagrams/seq_load_document_success.mmd');
  if (loadSequence.contains(
    'assign new committed identity and clear selection',
  )) {
    _fail('seq_load_document_success still clears selection after install');
  }
  if (!loadSequence.contains('cleared selection') ||
      !loadSequence.contains('one commit boundary')) {
    _fail(
      'seq_load_document_success must show cleared selection inside one commit boundary',
    );
  }

  final pointerState = _read('docs/diagrams/state_pointer_session.mmd');
  final lineState = _read('docs/diagrams/state_two_tap_line.mmd');
  if (!pointerState.contains('active routed pointer only')) {
    _fail(
      'state_pointer_session must scope interactive=false cancel to active routed pointer',
    );
  }
  if (!lineState.contains('interactive=false with no active routed pointer')) {
    _fail(
      'state_two_tap_line must preserve pending line for non-active interactive=false',
    );
  }

  final resourceSequence = _read('docs/diagrams/seq_resource_resolution.mmd');
  final resourceState = _read('docs/diagrams/state_resource_resolution.mmd');
  final resourceDfd = _read('docs/diagrams/dfd_resource_resolution.mmd');
  if (!resourceSequence.contains(
        'reentrant edit/load/resource dirty/pointer mutation',
      ) ||
      !resourceState.contains('ReentrantMutationRejected') ||
      !resourceDfd.contains('ResolverReentry')) {
    _fail('resource resolver diagrams must include reentrancy rejection path');
  }

  final spatialContract = _read('docs/contracts/spatial_kernel.md');
  final cacheInvalidation = _read('docs/diagrams/dfd_cache_invalidation.mmd');
  if (!spatialContract.contains('maxFallbackCandidates = 4096') ||
      !cacheInvalidation.contains('SpatialBudgetExceeded')) {
    _fail('spatial fallback must document budget and budget-exceeded path');
  }

  final cachePolicy = _read('docs/contracts/cache_policy.md');
  if (!cachePolicy.contains('Capacity') ||
      !cachePolicy.contains('Eviction') ||
      !cachePolicy.contains('Metric/probe')) {
    _fail(
      'cache policy ledger must include capacity, eviction, and metric/probe',
    );
  }
  _checkCachePolicyRowsHaveCapacityEvictionProbe(cachePolicy);

  final editContract = _read('docs/contracts/edit_kernel.md');
  if (!editContract.contains(
    'CommitCompiler must not depend on concrete `FrameEngine`',
  )) {
    _fail(
      'EditKernel contract must forbid CommitCompiler concrete FrameEngine dependency',
    );
  }
  final diagramDir = Directory('docs/diagrams');
  for (final file in diagramDir.listSync().whereType<File>()) {
    if (!file.path.endsWith('.mmd')) {
      continue;
    }
    final text = file.readAsStringSync();
    if (RegExp(r'^\s*CC->>Frame\s*:', multiLine: true).hasMatch(text)) {
      _fail('${file.path} routes CommitCompiler directly to FrameEngine');
    }
  }
}

void _checkArchitectureLenses() {
  _checkOwnerEdgeMatrix();
  final operationRows = _checkOperationMatrixCompleteness();
  _checkRevisionInvalidationAlgebra(operationRows);
  _checkNegativeInvariantCoverage();
  _checkStateMachineTransitionCoverage();
  _checkFailurePathSymmetry();
  _checkHotPathBudgetLens();
  _checkDonorRiskLens();
  _checkFunctionalLedgerCoverage();
  _checkOwnerCouplingHeatmap(_loadYamlMapList(_sectionsRegistryPath));
}

void _checkOwnerEdgeMatrix() {
  _checkC4RelEdges('docs/diagrams/c4_component_runtime.mmd');
  _checkFlowchartOwnerEdges('docs/diagrams/c4_container.mmd');
}

void _checkC4RelEdges(String path) {
  final text = _read(path);
  final pattern = RegExp(r'^Rel\(([^,\s]+),\s*([^,\s]+),', multiLine: true);
  for (final match in pattern.allMatches(text)) {
    final source = _matchGroup(match, 1, '$path Rel source');
    final target = _matchGroup(match, 2, '$path Rel target');
    _checkAllowedOwnerEdge(path, text, match.start, source, target);
  }
}

void _checkFlowchartOwnerEdges(String path) {
  final text = _read(path);
  final pattern = RegExp(
    r'^\s*([A-Za-z0-9_]+)(?:\[[^\]]+\])?\s*-->\s*([A-Za-z0-9_]+)(?:\[[^\]]+\])?',
    multiLine: true,
  );
  for (final match in pattern.allMatches(text)) {
    final source = _matchGroup(match, 1, '$path flowchart source');
    final target = _matchGroup(match, 2, '$path flowchart target');
    _checkAllowedOwnerEdge(path, text, match.start, source, target);
  }
}

void _checkAllowedOwnerEdge(
  String path,
  String text,
  int offset,
  String source,
  String target,
) {
  final ownerSource = _ownerAliases[source];
  final ownerTarget = _ownerAliases[target];
  if (ownerSource == null || ownerTarget == null) {
    return;
  }
  final edge = '$ownerSource->$ownerTarget';
  if (!_allowedOwnerEdges.contains(edge)) {
    _fail(
      '$path:${_lineNumber(text, offset)} owner edge $edge is not in the allowed owner matrix',
    );
  }
}

List<Map<String, String>> _checkOperationMatrixCompleteness() {
  final rows = _operationMatrixRows();
  if (rows.length < 30) {
    _fail(
      'operation matrix has only ${rows.length} rows; expected broad v1 coverage',
    );
  }

  final operations = <String>{};
  for (final row in rows) {
    final operation = row['Operation'] ?? '';
    if (!operations.add(operation)) {
      _fail('operation matrix contains duplicate operation: $operation');
    }
    for (final entry in row.entries) {
      if (entry.value.isEmpty) {
        _fail('operation matrix row $operation has empty ${entry.key} cell');
      }
      if (RegExp(
        r'\b(maybe|tbd|unclear|not decided)\b',
        caseSensitive: false,
      ).hasMatch(entry.value)) {
        _fail(
          'operation matrix row $operation has ambiguous ${entry.key} cell: ${entry.value}',
        );
      }
    }

    final noEffectOperation =
        operation.contains('no-op') || operation.contains('failure');
    if (noEffectOperation) {
      _expectOperationCell(row, 'State touched', {'none'});
      _expectOperationCell(row, 'Revisions', {'none'});
      _expectOperationCell(row, 'Spatial', {'none'});
      _expectOperationCell(row, 'Projection', {'none'});
      _expectOperationCell(row, 'Repaint', {'none'});
      _expectOperationCell(row, 'Events', {'none'});
    }

    if (operation.startsWith('CanvasEdit.')) {
      _expectOperationCell(row, 'Events', {'none'});
    }

    if (operation.contains('preview') || operation == 'line first tap') {
      if (!(row['State touched'] ?? '').contains('preview')) {
        _fail(
          'operation matrix row $operation is preview-like but State touched does not say preview',
        );
      }
      _expectOperationCell(row, 'Projection', {'no'});
      _expectOperationCell(row, 'Events', {'none'});
    }
  }

  return rows;
}

List<Map<String, String>> _operationMatrixRows() {
  final text = _read('docs/contracts/operation_matrix.md');
  const header =
      '| Operation | State touched | Revisions | Spatial | Projection | Repaint | Events |';
  final start = text.indexOf(header);
  if (start < 0) {
    _fail('operation matrix table header is missing or changed');
    return const [];
  }
  final rows = <Map<String, String>>[];
  final columns = [
    'Operation',
    'State touched',
    'Revisions',
    'Spatial',
    'Projection',
    'Repaint',
    'Events',
  ];
  for (final line in text.substring(start).split('\n').skip(1)) {
    if (!line.startsWith('|')) {
      break;
    }
    if (line.contains('---')) {
      continue;
    }
    final cells = line.split('|').skip(1).toList();
    if (cells.isNotEmpty && cells.last.trim().isEmpty) {
      cells.removeLast();
    }
    if (cells.length != columns.length) {
      _fail(
        'operation matrix row has ${cells.length} cells, expected ${columns.length}: $line',
      );
      continue;
    }
    rows.add({
      for (var i = 0; i < columns.length; i += 1) columns[i]: cells[i].trim(),
    });
  }
  return rows;
}

void _expectOperationCell(
  Map<String, String> row,
  String column,
  Set<String> allowed,
) {
  final value = row[column] ?? '';
  if (!allowed.contains(value)) {
    _fail(
      'operation matrix row ${row['Operation']} expected $column to be one of ${allowed.join(', ')}, got "$value"',
    );
  }
}

void _checkRevisionInvalidationAlgebra(List<Map<String, String>> rows) {
  for (final row in rows) {
    final operation = row['Operation'] ?? '';
    final revisions = row['Revisions'] ?? '';
    final spatial = row['Spatial'] ?? '';
    final projection = row['Projection'] ?? '';
    final repaint = row['Repaint'] ?? '';
    final events = row['Events'] ?? '';

    final projectionRevisionChanged =
        revisions.contains('projection') ||
        revisions.contains('all document-level');
    if (projectionRevisionChanged && projection != 'evict') {
      _fail(
        'operation matrix row $operation changes projection revision but Projection is "$projection"',
      );
    }
    if (projection == 'evict' && !projectionRevisionChanged) {
      _fail(
        'operation matrix row $operation evicts projection without projection/all-document revision',
      );
    }

    if (operation == 'markResourceDirty') {
      if (revisions != 'resourceVisualRevision' ||
          spatial != 'no' ||
          projection != 'no' ||
          repaint != 'main' ||
          events != 'none') {
        _fail(
          'operation matrix row markResourceDirty must only change resourceVisualRevision, resource cache, and main repaint',
        );
      }
    }

    if (operation == 'loadDocument success') {
      if (!revisions.contains('all document-level') ||
          !revisions.contains('epoch') ||
          spatial != 'rebuild' ||
          projection != 'evict' ||
          repaint != 'main + overlay') {
        _fail(
          'operation matrix row loadDocument success does not model full replacement effects',
        );
      }
    }

    if (events != 'none' && revisions == 'none') {
      _fail(
        'operation matrix row $operation emits events without a revision effect',
      );
    }
  }
}

void _checkNegativeInvariantCoverage() {
  final sections = _loadYamlMapList(_sectionsRegistryPath);
  final guardrails = _collectRegistryIds(sections, 'guardrails');
  final tests = _collectRegistryIds(sections, 'tests');

  final probes = [
    (
      path: 'docs/contracts/interaction_engine.md',
      text: 'InteractionEngine commits only through EditKernel',
      guardrail: 'interaction.no_concrete_store_imports',
      test: 'test.interaction.state_machines',
    ),
    (
      path: 'docs/contracts/edit_kernel.md',
      text: 'CommitCompiler must not depend on concrete `FrameEngine`',
      guardrail: 'edit.typed_effects_no_frame_dependency',
      test: 'test.edit_kernel.typed_effects_no_frame_dependency',
    ),
    (
      path: 'docs/contracts/spatial_kernel.md',
      text: 'Full clone of spatial index for ordinary edit is forbidden',
      guardrail: 'spatial.no_full_clone_ordinary_edit',
      test: 'test.spatial.no_full_clone_for_touched_update',
    ),
    (
      path: 'docs/contracts/resources.md',
      text:
          'Painters and frame paint code never call `CanvasResourceResolver` directly',
      guardrail: 'resources.resolver_boundary_owned_by_resource_kernel',
      test: 'test.resources.painter_never_calls_resolver_directly',
    ),
    (
      path: 'docs/contracts/cache_policy.md',
      text: 'no cache keys tied to old snapshots',
      guardrail: 'cache.keys_use_next_revisions_only',
      test: 'test.frame.cache_keys_do_not_use_legacy_snapshot_shape',
    ),
  ];

  for (final probe in probes) {
    if (!_read(probe.path).contains(probe.text)) {
      _fail('${probe.path} is missing negative invariant text: ${probe.text}');
    }
    if (!guardrails.contains(probe.guardrail)) {
      _fail(
        'negative invariant ${probe.text} has no registry guardrail ${probe.guardrail}',
      );
    }
    if (!tests.contains(probe.test)) {
      _fail(
        'negative invariant ${probe.text} has no registry test ${probe.test}',
      );
    }
  }

  for (final section in sections) {
    final sectionId = _stringField(section, 'id', 'section registry entry');
    final assumptions = _stringListField(section, 'do_not_assume', sectionId);
    if (assumptions.contains('none')) {
      continue;
    }
    final sectionGuardrails = _stringListField(
      section,
      'guardrails',
      sectionId,
    ).where((item) => item != 'none').toList();
    final sectionTests = _stringListField(
      section,
      'tests',
      sectionId,
    ).where((item) => item != 'none').toList();
    if (sectionGuardrails.isEmpty && sectionTests.isEmpty) {
      _fail('$sectionId has negative assumptions but no guardrails or tests');
    }
  }
}

void _checkStateMachineTransitionCoverage() {
  const requiredTokens = {
    'docs/diagrams/state_runtime_lifecycle.mmd': [
      'loadDocument success',
      'loadDocument failure',
      'dispose()',
      'StateError',
    ],
    'docs/diagrams/state_edit_session.mmd': [
      'Rollback',
      'FutureRejected',
      'nested edit',
      'stale handle',
    ],
    'docs/diagrams/state_pointer_session.mmd': [
      'interactive=false',
      'loadDocument success',
      'loadDocument failure',
      'stale terminal',
      'controllerEpoch',
      'dispose',
    ],
    'docs/diagrams/state_selected_move.mmd': [
      'interactive=false',
      'loadDocument success',
      'loadDocument failure',
      'resolver',
      'stale terminal',
      'controllerEpoch',
      'dispose',
    ],
    'docs/diagrams/state_two_tap_line.mmd': [
      'interactive=false',
      'loadDocument success',
      'loadDocument failure',
      'terminal',
      'controllerEpoch',
      'dispose',
    ],
    'docs/diagrams/state_resource_resolution.mmd': [
      'ReentrantMutationRejected',
      'markResourceDirty',
      'resourceRevision',
      'dispose',
    ],
  };

  for (final entry in requiredTokens.entries) {
    _requireFile(entry.key);
    final text = _read(entry.key).toLowerCase();
    for (final token in entry.value) {
      if (!text.contains(token.toLowerCase())) {
        _fail(
          '${entry.key} state machine is missing required transition token: $token',
        );
      }
    }
  }
}

void _checkFailurePathSymmetry() {
  const pairs = {
    'docs/diagrams/seq_edit_success.mmd': 'docs/diagrams/seq_edit_rollback.mmd',
    'docs/diagrams/seq_load_document_success.mmd':
        'docs/diagrams/seq_load_document_failure.mmd',
    'docs/diagrams/seq_selected_move_preview_commit.mmd':
        'docs/diagrams/seq_selected_move_cancel.mmd',
  };
  for (final entry in pairs.entries) {
    _requireFile(entry.key);
    _requireFile(entry.value);
  }

  final operationRows = _operationMatrixRows();
  final operations = operationRows
      .map((row) => row['Operation'] ?? '')
      .where((operation) => operation.isNotEmpty)
      .toSet();
  for (final operation in [
    'loadDocument success',
    'loadDocument failure',
    'no-op edit',
  ]) {
    if (!operations.contains(operation)) {
      _fail(
        'operation matrix is missing failure/no-op symmetry row: $operation',
      );
    }
  }

  final editRollback = _read('docs/diagrams/seq_edit_rollback.mmd');
  if (!editRollback.toLowerCase().contains('rollback') ||
      !editRollback.contains('unchanged')) {
    _fail(
      'seq_edit_rollback must explicitly show rollback and unchanged state',
    );
  }
  final loadFailure = _read('docs/contracts/load_document.md');
  if (!loadFailure.contains('Failure ordering') ||
      !loadFailure.contains('active gesture is not interrupted')) {
    _fail('loadDocument contract must keep explicit failure ordering');
  }
}

void _checkHotPathBudgetLens() {
  final probes = [
    (
      path: 'docs/contracts/frame_rendering.md',
      tokens: [
        'painters do not live-read runtime',
        'painters do not materialize CanvasDocument',
        'stale spatial candidate is rejected',
      ],
    ),
    (
      path: 'docs/diagrams/dfd_main_paint_frame.mmd',
      tokens: [
        'forbidden in paint hot path',
        'not read by main paint',
        'ResourceKernel-owned resolver boundary',
      ],
    ),
    (
      path: 'docs/diagrams/dfd_overlay_frame.mmd',
      tokens: [
        'forbidden in paint hot path',
        'not read by overlay paint',
        'no DocumentStore, InteractionEngine',
      ],
    ),
    (
      path: 'docs/contracts/spatial_kernel.md',
      tokens: [
        'maxFallbackCandidates = 4096',
        'no fallback path may scan the full scene silently',
      ],
    ),
    (
      path: 'docs/contracts/diagnostics.md',
      tokens: ['no DiagnosticRecord allocation on successful pointer move'],
    ),
  ];

  for (final probe in probes) {
    final text = _read(probe.path);
    for (final token in probe.tokens) {
      if (!text.contains(token)) {
        _fail('${probe.path} is missing hot-path budget token: $token');
      }
    }
  }

  final forbiddenDiagramCalls = <String, RegExp>{
    'painters must not read store directly': RegExp(
      r'^\s*(Painter|MainPainter|OverlayPainter)->>Store\s*:',
      multiLine: true,
    ),
    'painters must not call resolver directly': RegExp(
      r'^\s*(Painter|MainPainter|OverlayPainter)->>Resolver\s*:',
      multiLine: true,
    ),
    'paint frame must not materialize public projection': RegExp(
      r'^\s*Frame->>Projection\s*:',
      multiLine: true,
    ),
  };
  for (final file in Directory('docs/diagrams').listSync().whereType<File>()) {
    if (!file.path.endsWith('.mmd')) {
      continue;
    }
    final text = file.readAsStringSync();
    for (final entry in forbiddenDiagramCalls.entries) {
      for (final match in entry.value.allMatches(text)) {
        _fail('${file.path}:${_lineNumber(text, match.start)} ${entry.key}');
      }
    }
  }
}

void _checkFunctionalLedgerCoverage() {
  final rows = _functionalLedgerRows();
  if (rows.length < 40) {
    _fail(
      'functional ledger has only ${rows.length} rows; expected broad legacy capability coverage',
    );
  }
  final tests = <String>{};
  for (final row in rows) {
    final capability = row['Capability'] ?? '';
    for (final entry in row.entries) {
      if (entry.value.isEmpty ||
          RegExp(
            r'\b(tbd|todo|unknown|not decided)\b',
            caseSensitive: false,
          ).hasMatch(entry.value)) {
        _fail(
          'functional ledger row $capability has incomplete ${entry.key}: ${entry.value}',
        );
      }
    }
    final testId = _stripBackticks(row['Required test id'] ?? '');
    if (!testId.startsWith('functional.')) {
      _fail(
        'functional ledger row $capability has non-functional test id $testId',
      );
    }
    if (!tests.add(testId)) {
      _fail('functional ledger has duplicate required test id $testId');
    }
  }
  final registryTests = _collectRegistryIds(
    _loadYamlMapList(_sectionsRegistryPath),
    'tests',
  );
  if (!registryTests.contains('test.functional_ledger.row_specific_tests')) {
    _fail(
      'functional ledger rows are not backed by test.functional_ledger.row_specific_tests',
    );
  }
}

void _checkDonorRiskLens() {
  final donors = _loadYamlMapList('docs/_registry/donors.yaml');
  const allowedDecisions = {
    'copy',
    'copy_adapt',
    'adapt',
    'adapt_rewrite',
    'rewrite_reference',
    'avoid',
  };
  const requiredListFields = {
    'source_paths',
    'target_phases',
    'use_for',
    'do_not_copy',
    'required_tests',
    'blocks',
    'related_sections',
  };

  final donorDecisionById = <String, String>{};
  for (final donor in donors) {
    final donorId = _stringField(donor, 'id', 'donor registry entry');
    final decision = _stringField(donor, 'decision', donorId);
    donorDecisionById[donorId] = decision;
    if (!allowedDecisions.contains(decision)) {
      _fail('donor $donorId has unsupported decision $decision');
    }
    _stringField(donor, 'target_owner', donorId);
    _stringField(donor, 'notes', donorId);

    for (final field in requiredListFields) {
      final values = _stringListField(donor, field, donorId);
      if (values.isEmpty) {
        _fail('donor $donorId has empty $field');
      }
    }

    final targetPhases = _stringListField(donor, 'target_phases', donorId);
    final blocks = _stringListField(donor, 'blocks', donorId);
    if (decision == 'avoid') {
      if (targetPhases.length != 1 || targetPhases.single != 'avoid') {
        _fail('avoid donor $donorId must use target_phases: avoid');
      }
    } else {
      for (final phase in targetPhases) {
        if (!phase.startsWith('P')) {
          _fail('donor $donorId has non-phase target $phase');
        }
      }
      for (final block in blocks) {
        if (!block.startsWith('P')) {
          _fail('donor $donorId has non-phase block $block');
        }
      }
    }
  }

  final sections = _loadYamlMapList(_sectionsRegistryPath);
  for (final section in sections) {
    final sectionId = _stringField(section, 'id', 'section registry entry');
    for (final donorId in _stringListField(section, 'donors', sectionId)) {
      if (donorId == 'none') {
        continue;
      }
      final decision = donorDecisionById[donorId];
      if (decision == 'avoid' && !_globalCatalogSections.contains(sectionId)) {
        _fail(
          '$sectionId uses avoid donor $donorId as ordinary donor evidence',
        );
      }
    }
  }
}

String _stripBackticks(String value) {
  final trimmed = value.trim();
  if (trimmed.length >= 2 && trimmed.startsWith('`') && trimmed.endsWith('`')) {
    return trimmed.substring(1, trimmed.length - 1);
  }
  return trimmed;
}

List<Map<String, String>> _functionalLedgerRows() {
  final text = _read('docs/verification/functional_ledger.md');
  const header =
      '| Capability | Legacy oracle | Next API v1 | Required test id |';
  final start = text.indexOf(header);
  if (start < 0) {
    _fail('functional ledger table header is missing or changed');
    return const [];
  }
  final columns = [
    'Capability',
    'Legacy oracle',
    'Next API v1',
    'Required test id',
  ];
  final rows = <Map<String, String>>[];
  for (final line in text.substring(start).split('\n').skip(1)) {
    if (!line.startsWith('|')) {
      break;
    }
    if (line.contains('---')) {
      continue;
    }
    final cells = line.split('|').skip(1).toList();
    if (cells.isNotEmpty && cells.last.trim().isEmpty) {
      cells.removeLast();
    }
    if (cells.length != columns.length) {
      _fail(
        'functional ledger row has ${cells.length} cells, expected ${columns.length}: $line',
      );
      continue;
    }
    rows.add({
      for (var i = 0; i < columns.length; i += 1) columns[i]: cells[i].trim(),
    });
  }
  return rows;
}

void _checkOwnerCouplingHeatmap(List<YamlMap> sections) {
  final mustReadInDegree = <String, int>{};
  for (final section in sections) {
    final sectionId = _stringField(section, 'id', 'section registry entry');
    for (final reference in _stringListField(section, 'must_read', sectionId)) {
      if (reference.startsWith('section_')) {
        mustReadInDegree[reference] = (mustReadInDegree[reference] ?? 0) + 1;
      }
    }
  }

  for (final section in sections) {
    final sectionId = _stringField(section, 'id', 'section registry entry');
    final isGlobal = _globalCatalogSections.contains(sectionId);
    if (isGlobal) {
      continue;
    }
    final diagrams = _stringListField(
      section,
      'diagrams',
      sectionId,
    ).where((item) => item != 'none').length;
    final guardrails = _stringListField(
      section,
      'guardrails',
      sectionId,
    ).where((item) => item != 'none').length;
    final tests = _stringListField(
      section,
      'tests',
      sectionId,
    ).where((item) => item != 'none').length;
    final donors = _stringListField(
      section,
      'donors',
      sectionId,
    ).where((item) => item != 'none').length;
    final phases = _stringListField(section, 'phases', sectionId).length;

    if (diagrams > 20) {
      _fail(
        '$sectionId has $diagrams diagrams; split owner or phase navigation before it becomes a hub',
      );
    }
    if (guardrails > 15) {
      _fail('$sectionId has $guardrails guardrails; owner may be too broad');
    }
    if (tests > 15) {
      _fail('$sectionId has $tests tests; owner may be too broad');
    }
    if (donors > 15) {
      _fail('$sectionId has $donors donors; donor reuse may be too broad');
    }
    if (phases > 6) {
      _fail(
        '$sectionId feeds $phases phases; section may be acting as a hidden global hub',
      );
    }
  }

  for (final entry in mustReadInDegree.entries) {
    if (entry.value > 10) {
      _fail(
        '${entry.key} has must_read in-degree ${entry.value}; prerequisite graph is becoming hub-shaped',
      );
    }
  }
}

void _checkCachePolicyRowsHaveCapacityEvictionProbe(String text) {
  for (final line in text.split('\n')) {
    if (!line.startsWith('| ')) {
      continue;
    }
    if (line.contains('---') || line.contains('| Cache |')) {
      continue;
    }
    final cells = line.split('|').skip(1).map((cell) => cell.trim()).toList();
    if (cells.length < 8) {
      _fail('cache policy row has too few columns: $line');
      continue;
    }
    final capacity = cells[4];
    final eviction = cells[5];
    final probe = cells[6];
    if (capacity.isEmpty || eviction.isEmpty || probe.isEmpty) {
      _fail('cache policy row lacks capacity, eviction, or probe: $line');
    }
  }
}

void _checkRegistryWitnesses() {
  final sections = _loadYamlMapList(_sectionsRegistryPath);
  final sectionsById = {
    for (final section in sections)
      _stringField(section, 'id', 'section registry entry'): section,
  };

  if (File('docs/_registry/guardrails.yaml').existsSync()) {
    _fail(
      'docs/_registry/guardrails.yaml must not exist; sections.yaml owns guardrail registry links',
    );
  }
  if (File('docs/_registry/tests.yaml').existsSync()) {
    _fail(
      'docs/_registry/tests.yaml must not exist; sections.yaml owns test registry links',
    );
  }

  _checkGeneratedContextBlocks(sections, sectionsById);
  _checkGuardrailAndTestWitnesses(sections);
  _checkDonorWitnesses(sections);
  _checkPhaseReadFirstWitnesses(sections);
}

void _checkGeneratedContextBlocks(
  List<YamlMap> sections,
  Map<String, YamlMap> sectionsById,
) {
  final contextPattern = RegExp(
    r'<!-- CONTEXT:BEGIN -->[\s\S]*?<!-- CONTEXT:END -->(?:\r?\n)*',
  );

  for (final section in sections) {
    final id = _stringField(section, 'id', 'section registry entry');
    final file = _stringField(section, 'file', id);
    if (!File(file).existsSync()) {
      continue;
    }
    final text = _read(file);
    final matches = contextPattern.allMatches(text).toList();
    if (matches.isEmpty) {
      _fail('$file is missing a generated CONTEXT capsule');
      continue;
    }
    if (matches.length > 1) {
      _fail('$file contains more than one generated CONTEXT capsule');
      continue;
    }
    final match = matches.first;
    if (match.start != 0) {
      _fail('$file CONTEXT capsule must be the first block');
      continue;
    }
    final expected = _renderExpectedContext(section, sectionsById);
    final actual = text.substring(match.start, match.end);
    if (actual != expected) {
      _fail(
        '$file CONTEXT capsule is not generated from $_sectionsRegistryPath',
      );
    }
  }
}

String _renderExpectedContext(
  YamlMap section,
  Map<String, YamlMap> sectionsById,
) {
  final id = _stringField(section, 'id', 'section registry entry');
  final file = _stringField(section, 'file', id);
  final title = _stringField(section, 'title', id);
  final buffer = StringBuffer()
    ..writeln('<!-- CONTEXT:BEGIN -->')
    ..writeln('Registry id: `$id`')
    ..writeln('Registry source: `$_sectionsRegistryPath`')
    ..writeln('Document path: `$file`')
    ..writeln('Owns:');
  _writeLiteralList(buffer, [title]);
  buffer.writeln('Must read before editing:');
  _writeContextReferenceList(
    buffer,
    _stringListField(section, 'must_read', id),
    sectionsById,
  );
  buffer.writeln('Feeds phases:');
  _writeCodeList(buffer, _stringListField(section, 'phases', id));
  buffer.writeln('Related donors:');
  _writeCodeList(buffer, _stringListField(section, 'donors', id));
  buffer.writeln('Related diagrams:');
  _writeCodeList(buffer, _stringListField(section, 'diagrams', id));
  buffer.writeln('Required tests:');
  _writeCodeList(buffer, _stringListField(section, 'tests', id));
  buffer.writeln('Guardrails:');
  _writeCodeList(buffer, _stringListField(section, 'guardrails', id));
  buffer.writeln('Do not assume:');
  _writeLiteralList(buffer, _stringListField(section, 'do_not_assume', id));
  buffer
    ..writeln('<!-- CONTEXT:END -->')
    ..writeln();
  return buffer.toString();
}

void _writeContextReferenceList(
  StringBuffer buffer,
  List<String> values,
  Map<String, YamlMap> sectionsById,
) {
  for (final value in values) {
    final section = sectionsById[value];
    if (section != null) {
      buffer.writeln('- `$value` -> `${_stringField(section, 'file', value)}`');
      continue;
    }
    buffer.writeln('- `$value`');
  }
}

void _writeLiteralList(StringBuffer buffer, List<String> values) {
  for (final value in values) {
    buffer.writeln('- $value');
  }
}

void _writeCodeList(StringBuffer buffer, List<String> values) {
  for (final value in values) {
    buffer.writeln('- `$value`');
  }
}

void _checkGuardrailAndTestWitnesses(List<YamlMap> sections) {
  final registryGuardrailSections = _collectRegistrySectionMap(
    sections,
    'guardrails',
  );
  final registryTestSections = _collectRegistrySectionMap(sections, 'tests');
  final registryGuardrails = registryGuardrailSections.keys.toSet();
  final registryTests = registryTestSections.keys.toSet();

  final guardrailTable = RegExp(r'^\| `([^`]+)` \|', multiLine: true)
      .allMatches(_read('docs/verification/guardrails.md'))
      .map((match) => _matchGroup(match, 1, 'guardrail table row'))
      .where((id) => id != 'Guardrail')
      .toSet();
  final guardrailIndex = _markdownHeadings('docs/indexes/by_guardrail.md');
  final testDocIds = RegExp(r'`(test\.[^`]+)`')
      .allMatches(_read('docs/verification/tests.md'))
      .map((match) => _matchGroup(match, 1, 'test id reference'))
      .toSet();
  final testIndex = _markdownHeadings('docs/indexes/by_test_area.md');
  final guardrailIndexSections = _markdownIndexSections(
    'docs/indexes/by_guardrail.md',
  );
  final testIndexSections = _markdownIndexSections(
    'docs/indexes/by_test_area.md',
  );

  _checkSetEquality(
    'sections.yaml guardrails vs docs/verification/guardrails.md',
    registryGuardrails,
    guardrailTable,
  );
  _checkSetEquality(
    'sections.yaml guardrails vs docs/indexes/by_guardrail.md',
    registryGuardrails,
    guardrailIndex,
  );
  _checkSetEquality(
    'sections.yaml tests vs docs/verification/tests.md',
    registryTests,
    testDocIds,
  );
  _checkSetEquality(
    'sections.yaml tests vs docs/indexes/by_test_area.md',
    registryTests,
    testIndex,
  );
  _checkIndexSectionWitnesses(
    'docs/indexes/by_guardrail.md',
    registryGuardrailSections,
    guardrailIndexSections,
  );
  _checkIndexSectionWitnesses(
    'docs/indexes/by_test_area.md',
    registryTestSections,
    testIndexSections,
  );
}

Set<String> _collectRegistryIds(List<YamlMap> sections, String field) {
  final ids = <String>{};
  for (final section in sections) {
    final sectionId = _stringField(section, 'id', 'section registry entry');
    for (final item in _stringListField(section, field, sectionId)) {
      if (item != 'none') {
        ids.add(item);
      }
    }
  }
  return ids;
}

Map<String, Set<String>> _collectRegistrySectionMap(
  List<YamlMap> sections,
  String field,
) {
  final ids = <String, Set<String>>{};
  for (final section in sections) {
    final sectionId = _stringField(section, 'id', 'section registry entry');
    for (final item in _stringListField(section, field, sectionId)) {
      if (item != 'none') {
        ids.putIfAbsent(item, () => <String>{}).add(sectionId);
      }
    }
  }
  return ids;
}

Set<String> _markdownHeadings(String path) {
  _requireFile(path);
  return RegExp(r'^##\s+(.+)$', multiLine: true)
      .allMatches(_read(path))
      .map((match) => _matchGroup(match, 1, '$path heading').trim())
      .toSet();
}

Map<String, Set<String>> _markdownIndexSections(String path) {
  _requireFile(path);
  final text = _read(path);
  final sectionsByHeading = <String, Set<String>>{};
  final blocks = text.split(RegExp(r'^##\s+', multiLine: true));

  for (final block in blocks.skip(1)) {
    final lines = block.split('\n');
    final heading = lines.first.trim();
    final body = lines.skip(1).join('\n');
    final match = RegExp(
      r'^- Sections: (.+)$',
      multiLine: true,
    ).firstMatch(body);
    if (match == null) {
      _fail('$path heading $heading has no Sections witness line');
      sectionsByHeading[heading] = const <String>{};
      continue;
    }
    final sectionLine = _matchGroup(match, 1, '$path $heading Sections line');
    sectionsByHeading[heading] = RegExp(r'`(section_[^`]+)`')
        .allMatches(sectionLine)
        .map((match) => _matchGroup(match, 1, '$path section reference'))
        .toSet();
  }

  return sectionsByHeading;
}

void _checkSetEquality(String label, Set<String> expected, Set<String> actual) {
  final missing = expected.difference(actual).toList()..sort();
  final extra = actual.difference(expected).toList()..sort();
  for (final id in missing) {
    _fail('$label missing $id');
  }
  for (final id in extra) {
    _fail('$label has stale or unknown $id');
  }
}

void _checkIndexSectionWitnesses(
  String path,
  Map<String, Set<String>> expected,
  Map<String, Set<String>> actual,
) {
  for (final entry in expected.entries) {
    final id = entry.key;
    final expectedSections = entry.value;
    final actualSections = actual[id] ?? const <String>{};
    _checkSetEquality(
      'sections.yaml $id sections vs $path',
      expectedSections,
      actualSections,
    );
  }
}

void _checkDonorWitnesses(List<YamlMap> sections) {
  final donors = _loadYamlMapList('docs/_registry/donors.yaml');
  final donorsById = <String, YamlMap>{};
  for (final donor in donors) {
    final donorId = _stringField(donor, 'id', 'donor registry entry');
    if (donorsById.containsKey(donorId)) {
      _fail('duplicate donor id: $donorId');
    }
    donorsById[donorId] = donor;
    final seenRelatedSections = <String>{};
    for (final sectionId in _stringListField(
      donor,
      'related_sections',
      donorId,
    )) {
      if (!seenRelatedSections.add(sectionId)) {
        _fail('donor $donorId has duplicate related section $sectionId');
      }
      if (!_sectionIds.contains(sectionId)) {
        _fail('donor $donorId references unknown section id $sectionId');
      }
    }
  }

  final registryDonorSections = <String, Set<String>>{};
  for (final section in sections) {
    final sectionId = _stringField(section, 'id', 'section registry entry');
    for (final donorId in _stringListField(section, 'donors', sectionId)) {
      if (donorId == 'none') {
        continue;
      }
      if (!donorsById.containsKey(donorId)) {
        _fail('$sectionId references unknown donor id $donorId');
      }
      if (!_donorRelatedSectionCatalogExclusions.contains(sectionId)) {
        registryDonorSections
            .putIfAbsent(donorId, () => <String>{})
            .add(sectionId);
      }
    }
  }

  for (final entry in registryDonorSections.entries) {
    final donorId = entry.key;
    final donor = donorsById[donorId];
    if (donor == null) {
      continue;
    }
    final relatedSections = _stringListField(
      donor,
      'related_sections',
      donorId,
    ).toSet();
    for (final sectionId in entry.value) {
      if (!relatedSections.contains(sectionId)) {
        _fail(
          'donor $donorId is used by $sectionId in $_sectionsRegistryPath, '
          'but docs/_registry/donors.yaml does not list $sectionId as related',
        );
      }
    }
  }
}

void _checkPhaseReadFirstWitnesses(List<YamlMap> sections) {
  final registryPhases = <String, Set<String>>{};
  for (final section in sections) {
    final id = _stringField(section, 'id', 'section registry entry');
    for (final phase in _stringListField(section, 'phases', id)) {
      registryPhases.putIfAbsent(phase, () => <String>{}).add(id);
    }
  }

  for (final phase in registryPhases.keys) {
    final phaseDoc = _phaseDocs[phase];
    if (phaseDoc == null) {
      _fail('phase $phase has no implementation phase document mapping');
      continue;
    }
    _requireFile(phaseDoc, source: _sectionsRegistryPath);
  }

  for (final entry in _phaseDocs.entries) {
    final phase = entry.key;
    final phaseDoc = entry.value;
    if (!File(phaseDoc).existsSync()) {
      continue;
    }
    final readFirst = _readFirstSectionIds(phaseDoc);
    final registrySections = registryPhases[phase] ?? const <String>{};
    for (final sectionId in readFirst) {
      if (!_sectionIds.contains(sectionId)) {
        _fail('$phaseDoc Read first references unknown section $sectionId');
        continue;
      }
      if (!registrySections.contains(sectionId) &&
          !_globalCatalogSections.contains(sectionId)) {
        _fail(
          '$phaseDoc Read first lists $sectionId, but $sectionId does not feed phase $phase',
        );
      }
    }
  }
}

Set<String> _readFirstSectionIds(String path) {
  final match = RegExp(
    r'^## Read first\s*$([\s\S]*?)(?=^## |\z)',
    multiLine: true,
  ).firstMatch(_read(path));
  if (match == null) {
    _fail('$path has no "Read first" section');
    return const {};
  }
  final readFirstBlock = _matchGroup(match, 1, '$path Read first section');
  return RegExp(r'`(section_[^`]+)`')
      .allMatches(readFirstBlock)
      .map((match) => _matchGroup(match, 1, '$path Read first reference'))
      .toSet();
}

void _checkMustReadGraph(List<YamlMap> sections) {
  final graph = <String, List<String>>{};
  final sectionIds = <String>{};
  for (final section in sections) {
    final id = _stringField(section, 'id', 'section registry entry');
    sectionIds.add(id);
    final references = _stringListField(section, 'must_read', id);
    if (references.contains('none') && references.length > 1) {
      _fail('$id must_read cannot mix "none" with concrete references');
    }
    final sectionReferences = <String>[];
    for (final reference in references) {
      if (reference == 'none' || !reference.startsWith('section_')) {
        continue;
      }
      sectionReferences.add(reference);
      if (_globalCatalogSections.contains(reference) &&
          !(_mustReadGlobalCatalogAllowlist[id]?.contains(reference) ??
              false)) {
        _fail(
          '$id must_read points to global catalog $reference; use tests, guardrails, indexes, or phase docs for navigation instead',
        );
      }
    }
    if (!_globalCatalogSections.contains(id) && sectionReferences.length > 4) {
      _fail(
        '$id must_read has ${sectionReferences.length} section prerequisites; ordinary sections must have at most 4',
      );
    }
    graph[id] = sectionReferences;
  }

  final visiting = <String>{};
  final visited = <String>{};
  final path = <String>[];

  void visit(String id) {
    if (visited.contains(id)) {
      return;
    }
    if (visiting.contains(id)) {
      final start = path.indexOf(id);
      final cycle = [...path.sublist(start), id].join(' -> ');
      _fail('must_read graph contains a cycle: $cycle');
      return;
    }
    visiting.add(id);
    path.add(id);
    for (final next in graph[id] ?? const <String>[]) {
      if (sectionIds.contains(next)) {
        visit(next);
      }
    }
    path.removeLast();
    visiting.remove(id);
    visited.add(id);
  }

  for (final id in graph.keys) {
    visit(id);
  }
}

void _checkStoreDoesNotDispatchRuntimeEffects(String path, String text) {
  final pattern = RegExp(
    r'^\s*Store->>(Frame|Spatial|Events|Resources|Interaction|Signals)\s*:',
    multiLine: true,
  );
  for (final match in pattern.allMatches(text)) {
    final target = match.group(1);
    _fail(
      '$path:${_lineNumber(text, match.start)} '
      'DocumentStoreKernel must not dispatch post-commit effects to $target; '
      'route them through RuntimeRoot or CommitApplier',
    );
  }
}

void _checkInteractionDoesNotBypassEditKernel(String path, String text) {
  final pattern = RegExp(
    r'^\s*(IE|Interaction)->>(Store|Draft|Events)\s*:',
    multiLine: true,
  );
  for (final match in pattern.allMatches(text)) {
    final target = match.group(2);
    _fail(
      '$path:${_lineNumber(text, match.start)} '
      'InteractionEngine must not commit by calling $target directly; '
      'route committed mutations and staged actions through EditKernel',
    );
  }
}

int _lineNumber(String text, int offset) {
  var line = 1;
  for (var i = 0; i < offset; i += 1) {
    if (text.codeUnitAt(i) == 10) {
      line += 1;
    }
  }
  return line;
}

void _checkReferenceList(YamlMap map, String field, String owner) {
  final value = map[field];
  if (value == null || value is! YamlList) {
    _fail('$owner has no list field $field');
    return;
  }
  for (final item in value) {
    final reference = item.toString();
    if (reference == 'none') {
      continue;
    }
    if (reference.startsWith('section_')) {
      if (!_sectionIds.contains(reference)) {
        _fail('$owner references unknown section id $reference');
      }
    } else if (reference.startsWith('docs/')) {
      _requirePath(reference);
    }
  }
}

void _checkSectionIdsInText(String sourcePath, String text) {
  for (final match in RegExp(r'`(section_[^`]+)`').allMatches(text)) {
    final id = match.group(1);
    if (id == null) {
      _fail('$sourcePath contains a malformed section reference');
      continue;
    }
    if (!_sectionIds.contains(id)) {
      _fail('$sourcePath references unknown section id $id');
    }
  }
}

void _checkDocumentPathsInText(String sourcePath, String text) {
  final patterns = [RegExp(r'`(docs/[^`]+)`'), RegExp(r'\]\((docs/[^)]+)\)')];
  for (final pattern in patterns) {
    for (final match in pattern.allMatches(text)) {
      final path = match.group(1);
      if (path == null) {
        _fail('$sourcePath contains a malformed document path reference');
        continue;
      }
      if (path.contains(' and ')) {
        continue;
      }
      _requirePath(path, source: sourcePath);
    }
  }
}

String _matchGroup(Match match, int group, String context) {
  final value = match.group(group);
  if (value == null) {
    _fail('$context has no regex group $group');
    return '';
  }
  return value;
}

List<YamlMap> _loadYamlMapList(String path) {
  _requireFile(path);
  final value = loadYaml(_read(path));
  if (value is! YamlList) {
    _fail('$path must contain a YAML list');
    return const [];
  }

  final items = <YamlMap>[];
  for (final item in value) {
    if (item is YamlMap) {
      items.add(item);
    } else {
      _fail('$path must contain only YAML map entries');
    }
  }
  return items;
}

String _stringField(YamlMap map, String field, String owner) {
  final value = map[field];
  if (value is String) {
    return value;
  }
  _fail('$owner must have string field $field');
  return '';
}

List<String> _stringListField(YamlMap map, String field, String owner) {
  final value = map[field];
  if (value is! YamlList) {
    _fail('$owner must have list field $field');
    return const [];
  }
  final items = <String>[];
  for (final item in value) {
    if (item is String) {
      items.add(item);
    } else {
      _fail('$owner field $field must contain only strings');
    }
  }
  return items;
}

String _read(String path) => File(path).readAsStringSync();

void _requirePath(String path, {String? source}) {
  final normalized = path.split('#').first.split(RegExp(r'\s')).first;
  if (normalized.endsWith('/')) {
    _requireDirectory(normalized, source: source);
  } else {
    _requireFile(normalized, source: source);
  }
}

void _requireFile(String path, {String? source}) {
  if (!File(path).existsSync()) {
    _fail('${source ?? 'required path'} references missing file $path');
  }
}

void _requireDirectory(String path, {String? source}) {
  if (!Directory(path).existsSync()) {
    _fail('${source ?? 'required path'} references missing directory $path');
  }
}

void _fail(String message) {
  _errors.add(message);
}
