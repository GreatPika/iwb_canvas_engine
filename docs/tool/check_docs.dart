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
  'P4': 'docs/implementation/p4_runtime_spine.md',
  'P5': 'docs/implementation/p5_edit_core.md',
  'P6': 'docs/implementation/p6_load_document.md',
  'P7': 'docs/implementation/p7_resources_and_images.md',
  'P8': 'docs/implementation/p8_geometry_and_spatial.md',
  'P9': 'docs/implementation/p9_frame_rendering_and_caches.md',
  'P10': 'docs/implementation/p10_selection_and_move.md',
  'P11': 'docs/implementation/p11_draw_tools.md',
  'P12': 'docs/implementation/p12_eraser_and_text_request.md',
  'P13': 'docs/implementation/p13_flutter_surface.md',
  'P14': 'docs/implementation/p14_benchmarks_diagrams_and_release_readiness.md',
};

const _phaseOrder = {
  'P0': 0,
  'P1': 10,
  'P1.5': 15,
  'P2': 20,
  'P3': 30,
  'P4': 40,
  'P5': 50,
  'P6': 60,
  'P7': 70,
  'P8': 80,
  'P9': 90,
  'P10': 100,
  'P11': 110,
  'P12': 120,
  'P13': 130,
  'P14': 140,
};

final _errors = <String>[];
final _sectionIds = <String>{};

void main() {
  _checkRequiredEntrypoints();
  _checkSectionsRegistry();
  _checkDiagramCatalogRegistrySymmetry();
  _checkImplementationDiagramPhaseReferences();
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
    'plan',
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

void _checkImplementationDiagramPhaseReferences() {
  final catalogPhases = _loadDiagramCatalogPhases('docs/diagrams/README.md');
  final phaseReferences = <String, Set<String>>{};

  for (final entry in _phaseDocs.entries) {
    final phase = entry.key;
    final path = entry.value;
    final references = phaseReferences.putIfAbsent(phase, () => <String>{});
    _requireFile(path);
    final text = _read(path);
    final heading = RegExp(
      r'^## Diagrams to read or update\s*$',
      multiLine: true,
    ).firstMatch(text);
    if (heading == null) {
      _fail('$path has no "Diagrams to read or update" section');
      continue;
    }
    final rest = text.substring(heading.end);
    final nextHeading = RegExp(r'^##\s+', multiLine: true).firstMatch(rest);
    final section = nextHeading == null
        ? rest
        : rest.substring(0, nextHeading.start);
    for (final match in RegExp(
      r'^- `([^`]+)` -> `docs/diagrams/[^`]+\.mmd`$',
      multiLine: true,
    ).allMatches(section)) {
      final diagramId = _matchGroup(match, 1, '$path diagram reference');
      references.add(diagramId);
      final phases = catalogPhases[diagramId];
      if (phases == null) {
        _fail(
          '$path references diagram $diagramId, '
          'but docs/diagrams/README.md does not catalog it',
        );
        continue;
      }
      if (!phases.contains(phase)) {
        _fail(
          '$path references diagram $diagramId, but '
          'docs/diagrams/README.md does not list $phase under $diagramId',
        );
      }
    }
  }

  final p14References = phaseReferences['P14'] ?? const <String>{};
  for (final entry in catalogPhases.entries) {
    if (!entry.value.contains('P14')) {
      continue;
    }
    if (!p14References.contains(entry.key)) {
      _fail(
        'docs/implementation/p14_benchmarks_diagrams_and_release_readiness.md '
        'must list P14 catalog diagram ${entry.key}',
      );
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

Map<String, Set<String>> _loadDiagramCatalogPhases(String path) {
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
      continue;
    }

    final phases = <String>{};
    for (final line in lines.skip(1)) {
      final phasesMatch = RegExp(r'^- Related phases: (.+)$').firstMatch(line);
      if (phasesMatch == null) {
        continue;
      }
      final relatedPhases = _matchGroup(
        phasesMatch,
        1,
        '$path related phases line',
      );
      for (final match in RegExp(r'`(P[^`]+)`').allMatches(relatedPhases)) {
        final phase = _matchGroup(match, 1, '$path phase reference');
        phases.add(phase);
        if (!_phaseDocs.containsKey(phase)) {
          _fail(
            '$path catalog entry $diagramId references unknown phase $phase',
          );
        }
      }
    }

    catalog[diagramId] = phases;
  }

  return catalog;
}

void _checkNoRetiredActiveReferences() {
  final retired = [
    'canonical truth remains',
    'iwb_canvas_engine'
        '_next_full_implementation_plan_v2',
    'iwb_canvas_engine'
        '_next_donor_inventory',
    'packages/iwb_canvas_engine'
        '_next',
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
  final pointerDfd = _read('docs/diagrams/dfd_pointer_preview_commit.mmd');
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
  if (!pointerState.contains(
        'Invalid down facts are rejected before runtime routing',
      ) ||
      !pointerState.contains(
        'Invalid terminal facts for an active route enter cleanup only',
      ) ||
      !pointerState.contains('Invalid terminal facts enter cleanup only') ||
      !pointerDfd.contains(
        'subgraph FlutterBridge["Flutter bridge boundary"]',
      ) ||
      !pointerDfd.contains(
        'Pointer adapter\\nfinite down/move normalization\\nbefore runtime routing',
      ) ||
      !pointerDfd.contains(
        'InvalidDownMoveEvent -.->|"no runtime route, preview, repaint, edit, or event"| Surface',
      ) ||
      !pointerDfd.contains(
        'PointerAdapter -->|"terminal sample for active route\\nfinite or cleanup-only invalid"| Sample',
      ) ||
      !pointerDfd.contains(
        'TokenGate -.->|"stale/invalid terminal sample\\ncleanup only, no commit intent"| TerminalCleanup',
      )) {
    _fail(
      'pointer adapter diagrams must reject invalid down/move before runtime and route invalid terminal to cleanup-only',
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
  if (!spatialContract.contains(
        'operation-matrix `clearContent` may reset to an empty index',
      ) ||
      !cacheInvalidation.contains(
        'Operation-matrix clearContent\\nempty spatial reset only',
      ) ||
      !cacheInvalidation.contains(
        'Spatial rebuild/reset\\nreplacement/load or clearContent empty reset only',
      )) {
    _fail(
      'spatial clearContent empty reset must be distinct from generic full clone and replacement cache invalidation',
    );
  }

  final resourceContract = _read('docs/contracts/resources.md');
  final cachePolicy = _read('docs/contracts/cache_policy.md');
  if (!cachePolicy.contains('Capacity') ||
      !cachePolicy.contains('Eviction') ||
      !cachePolicy.contains('Metric/probe')) {
    _fail(
      'cache policy ledger must include capacity, eviction, and metric/probe',
    );
  }
  if (!resourceContract.contains(
    '| ImageResolveCache | Resource | resourceId/resourceRevision |',
  )) {
    _fail('ResourceKernel contract must own ImageResolveCache core policy');
  }
  _checkCachePolicyRowsHaveCapacityEvictionProbe(
    'docs/contracts/cache_policy.md',
    cachePolicy,
  );
  _checkCachePolicyRowsHaveCapacityEvictionProbe(
    'docs/contracts/resources.md',
    resourceContract,
  );
  _checkHotPathDesignContract();

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
  const frameMetaOperations = {
    'setCameraOffset',
    'setBackgroundColor',
    'setGrid',
  };

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

    if (frameMetaOperations.contains(operation)) {
      if (!revisions.contains('frameMeta') ||
          revisions.contains('elementVisual')) {
        _fail(
          'operation matrix row $operation must use frameMeta revision and must not change elementVisual revision',
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
      test: 'test.edit.typed_effects_no_frame_dependency',
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
      path: 'docs/contracts/resources.md',
      text:
          'budget-exceeded results are not cached as null, missing, or resolved images',
      guardrail: 'resources.resolver_frame_budget',
      test: 'test.resources.resolver_frame_budget',
    ),
    (
      path: 'docs/contracts/frame_rendering.md',
      text:
          'PaintPlanCache key must not include frameMetaRevision, selectedMoveDelta, or',
      guardrail: 'frame.paint_plan_excludes_preview_delta',
      test: 'test.frame.paint_plan_excludes_preview_delta',
    ),
    (
      path: 'docs/contracts/cache_policy.md',
      text: 'no cache keys tied to legacy snapshots',
      guardrail: 'cache.keys_use_next_revisions_only',
      test: 'test.frame.cache_keys_do_not_use_legacy_snapshot_shape',
    ),
    (
      path: 'docs/contracts/cache_policy.md',
      text: '`frameMetaRevision` is not a PaintPlanCache key component',
      guardrail: 'cache.frame_meta_not_element_visual',
      test: 'test.frame.camera_pan_preserves_ordinary_paint_plan',
    ),
    (
      path: 'docs/contracts/geometry.md',
      text: 'terminal budget exceeded -> cleanup/no-op, no partial erase',
      guardrail: 'geometry.eraser_exact_budget_no_partial',
      test: 'test.geometry.eraser_exact_budget_no_partial_commit',
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
      'ResolverBudgetGate',
      'dispose',
    ],
    'docs/diagrams/state_eraser.mmd': [
      'budget exceeded',
      'no partial erase',
      '4096 candidates',
      '32768 exact checks',
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
        'PaintPlanCache stores only ordinary committed RenderElementRecord data',
      ],
    ),
    (
      path: 'docs/diagrams/dfd_main_paint_frame.mmd',
      tokens: [
        'forbidden in paint hot path',
        'not read by main paint',
        'ResourceKernel-owned resolver boundary',
        'ordinary committed records only',
        'not stored in PaintPlanCache',
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
      path: 'docs/contracts/resources.md',
      tokens: [
        'kMaxSyncResourceResolverCallsPerFrame = 128',
        'budget-exceeded results are not cached as null, missing, or resolved images',
      ],
    ),
    (
      path: 'docs/contracts/geometry.md',
      tokens: [
        'kMaxEraserPreviewCandidatesPerSample = 512',
        'kMaxEraserTerminalExactChecks = 32768',
        'terminal budget exceeded -> cleanup/no-op, no partial erase',
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

  _checkRequiredBenchmarkCases();
}

void _checkHotPathDesignContract() {
  for (final file in Directory(
    'docs',
  ).listSync(recursive: true).whereType<File>()) {
    if (file.path.startsWith('docs/tool/')) {
      continue;
    }
    if (!file.path.endsWith('.md') &&
        !file.path.endsWith('.mmd') &&
        !file.path.endsWith('.yaml')) {
      continue;
    }
    final text = file.readAsStringSync();
    var start = 0;
    while (true) {
      final index = text.indexOf('visualRevision', start);
      if (index == -1) {
        break;
      }
      final prefixStart = index >= 16 ? index - 16 : 0;
      final prefix = text.substring(prefixStart, index);
      if (!prefix.endsWith('element') && !prefix.endsWith('resource')) {
        _fail(
          '${file.path}:${_lineNumber(text, index)} ambiguous visualRevision token; use elementVisualRevision, frameMetaRevision, or resourceVisualRevision',
        );
      }
      start = index + 'visualRevision'.length;
    }
  }

  final frameRendering = _read('docs/contracts/frame_rendering.md');
  if (!frameRendering.contains('elementVisualRevision') ||
      !frameRendering.contains('frameMetaRevision') ||
      !frameRendering.contains(
        'PaintPlanCache key must not include frameMetaRevision, selectedMoveDelta, or',
      )) {
    _fail(
      'frame rendering contract must split elementVisual/frameMeta and exclude preview from PaintPlanCache',
    );
  }
  _requireTokens(
    'docs/contracts/frame_rendering.md',
    [
      'ordinary opacity must not create an implicit group opacity or offscreen layer in the hot paint path',
      'any future saveLayer-producing effect must be explicit in RenderElementRecord',
      'counted by the frame.paint_candidates offscreen-layer metric',
      'Text, path, and stroke cache misses are bounded by the current render record',
      'primitive cache miss must not trigger CanvasDocument projection, full-scene',
      'candidate rebuild, global sort, resolver calls, or repaint scheduling',
    ],
    'define opacity/saveLayer and render primitive cache miss hot-path policy',
  );
  _requireTokens(
    'docs/implementation/p13_flutter_surface.md',
    [
      'Flutter painters apply ordinary element/stroke opacity through primitive paint alpha',
      'Flutter painters do not call `Canvas.saveLayer` for ordinary opacity in the hot paint path',
      'any future Flutter `Canvas.saveLayer` effect must be explicit, budgeted, probed by the frame paint benchmark',
    ],
    'bind Flutter Canvas.saveLayer policy to the Flutter surface implementation plan',
  );

  final cachePolicy = _read('docs/contracts/cache_policy.md');
  if (!cachePolicy.contains(
        '| PaintPlanCache | Frame | structural/bounds/elementVisual/viewport/selection |',
      ) ||
      !cachePolicy.contains('It must not store') ||
      !cachePolicy.contains('selected-move supplement records') ||
      !cachePolicy.contains('`selectedMoveDelta`') ||
      !cachePolicy.contains('`previewDelta`') ||
      !cachePolicy.contains(
        '`frameMetaRevision` is not a PaintPlanCache key component',
      )) {
    _fail(
      'cache policy must keep PaintPlanCache ordinary-only and independent from frameMeta/preview',
    );
  }
  _requireTokens(
    'docs/contracts/cache_policy.md',
    [
      'Text/path/stroke render cache misses are local to the current render record key',
      'one miss can fill one bounded cache entry',
      'must not trigger CanvasDocument projection, full-scene candidate rebuild,',
      'global sort, resolver calls, repaint scheduling',
    ],
    'bound text/path/stroke render cache miss behavior',
  );

  _requireTokens(
    'docs/diagrams/dfd_main_paint_frame.mmd',
    [
      'ordinary committed records only',
      'not stored in PaintPlanCache',
      'PaintAlphaPolicy["Ordinary opacity policy\\nelement/stroke opacity -> primitive paint alpha\\nno implicit saveLayer"]',
      'ExplicitLayerEffect["Future saveLayer effect\\nexplicit RenderElementRecord field,\\nbudgeted, metric-counted,\\nand guarded by contract update"]',
      'frame.paint_candidates offscreen-layer metric',
      'MainPainter -.->|"forbidden ordinary opacity path"| ExplicitLayerEffect',
      r'ImageResolveCache -->|"cache miss"| ResolverFrameBudget',
      r'ResolverFrameBudget -->|"budget available\nsync read request"| AppResolver',
      r'ResolverFrameBudget -.->|"budget exceeded\nResourceKernel-owned probe + at most one pending\nthrottled follow-up repaint"| BudgetPlaceholder',
      r'BudgetPlaceholder -.->|"bounded placeholder\nno cache write"| ResolvedAssets',
    ],
    'show ordinary paint caching and resolver budget-gated cache-miss flow',
  );
  _forbidTokens(
    'docs/diagrams/dfd_main_paint_frame.mmd',
    [
      r'ResolvePaintAsset -->|"cache miss only\nsync read request"| AppResolver',
      r'ResolvePaintAsset -->|"cache miss: sync resolve request"| AppResolver',
    ],
    'main paint DFD must not bypass resolver budget',
  );

  _requireTokens(
    'docs/diagrams/seq_main_paint.mmd',
    [
      'lookup ordinary paint plan by structural, bounds, elementVisual, viewport, and selection keys',
      'Selected supplement records are per-frame and are not stored in PaintPlanCache',
      'else per-frame resolver budget exceeded',
      'else cache miss and resolver budget available',
      'no null/missing cache write',
      'Ordinary element and stroke opacity is applied through primitive paint alpha',
      'It must not call Canvas.saveLayer in the hot ordinary opacity path',
      'Any future saveLayer-producing effect must be explicit in RenderElementRecord, budgeted, counted by the frame.paint_candidates offscreen-layer metric, and guarded by a contract update before implementation',
    ],
    'show ordinary paint plan reuse and budget-gated resolver calls',
  );
  _forbidTokens(
    'docs/diagrams/seq_main_paint.mmd',
    ['else sync resolver call required'],
    'main paint sequence must name cache miss as budget available before resolver call',
  );

  for (final path in [
    'docs/diagrams/seq_selected_move_preview_commit.mmd',
    'docs/diagrams/seq_selected_move_cancel.mmd',
  ]) {
    _requireTokens(
      path,
      [
        'participant PlanCache as PaintPlanCache',
        'lookup ordinary paint plan by structural, bounds, elementVisual, viewport, and selection keys',
        'store ordinary committed records only',
        'filter movable selected ids from ordinary records for this frame',
        'query selected supplement shifted by -previewDelta',
        'build per-frame supplement records with previewDelta',
        'merge filtered ordinary records and supplement by orderToken',
        'not stored in PaintPlanCache',
      ],
      'show selected-move preview as ordinary-plan reuse plus per-frame supplement',
    );
    _forbidTokens(path, [
      'query viewport plus selected supplement',
      'ordinary and selected candidate handles',
    ], 'selected-move witness must not use the legacy direct preview path');
  }

  _requireTokens('docs/contracts/resources.md', [
    '| ImageResolveCache | Resource | resourceId/resourceRevision | resource dirty/descriptor change | 1024 entries | target/all invalidation, then LRU |',
    'kMaxSyncResourceResolverCallsPerFrame = 128',
    'ResourceKernel owns the budget-exceeded retry scheduler',
    'budget-exceeded results may schedule at most one pending throttled follow-up repaint',
    'the pending follow-up repaint flag is cleared by the next main frame resource pass',
    'painters and app resolvers must not schedule budget-exceeded follow-up repaints',
    'budget-exceeded results are not cached as null, missing, or resolved images',
  ], 'define bounded resolver budget behavior');
  _requireTokens(
    'docs/diagrams/dfd_resource_resolution.mmd',
    [
      r'ImageResolveCache -->|"cache miss"| ResolverFrameBudget',
      r'ResolverFrameBudget -->|"budget available\nsync resolve request"| AppResolver',
      r'ResolverFrameBudget -.->|"budget exceeded\nResourceKernel-owned probe + at most one pending\nthrottled follow-up repaint"| BudgetPlaceholder',
      r'BudgetPlaceholder -.->|"bounded placeholder\nno cache write"| PaintAsset',
    ],
    'route every cache miss through resolver budget before AppResolver',
  );
  _forbidTokens(
    'docs/diagrams/dfd_resource_resolution.mmd',
    [
      r'ResolvePaintAsset -->|"cache miss: sync resolve request"| AppResolver',
      r'ResolvePaintAsset -->|"cache miss only\nsync read request"| AppResolver',
    ],
    'resource DFD must not bypass resolver budget',
  );
  _requireTokens(
    'docs/diagrams/state_resource_resolution.mmd',
    [
      'CacheMiss --> ResolverBudgetGate: check per-frame resolver budget',
      'ResolverBudgetGate --> BudgetExceededPlaceholder: budget exhausted',
      'ResolverBudgetGate --> SyncResolverCall: budget available',
      'BudgetExceededPlaceholder --> PlaceholderResult: return bounded placeholder without cache write',
      'ResourceKernel owns',
      'Painters and app resolvers must not',
    ],
    'show resolver budget as the only cache-miss path to sync resolver call',
  );
  _requireTokens(
    'docs/diagrams/seq_resource_resolution.mmd',
    [
      'else per-frame resolver budget exceeded',
      'bounded placeholder, ResourceKernel records probe and at most one pending throttled follow-up repaint, no null/missing cache write',
      'ResourceKernel owns the resolver boundary and budget-exceeded retry scheduler',
      'else cache miss and resolver budget available',
    ],
    'show budget exceeded before resolver call and forbid cache writes on that path',
  );

  _requireTokens(
    'docs/contracts/geometry.md',
    [
      'kMaxEraserPreviewCandidatesPerSample = 512',
      'kMaxEraserPreviewExactChecksPerSample = 4096',
      'kMaxEraserTerminalCandidates = 4096',
      'kMaxEraserTerminalExactChecks = 32768',
      'terminal budget exceeded -> cleanup/no-op, no partial erase',
      'budget exceeded does not mutate document, selection, spatial index, projection,',
    ],
    'define exact eraser budgets and non-mutating exceeded behavior',
  );
  _requireTokens(
    'docs/contracts/spatial_kernel.md',
    [
      'query request -> revision/generation gate -> tile/outlier union -> candidate budget gate -> typed result',
      'query tile count > 50000 -> fallback candidate union with diagnostic counter',
      'fallback candidate count > maxFallbackCandidates -> typed budget-exceeded result',
      'budget-exceeded result contains no partial candidates and does not mutate indexes',
      'invalid index can request rebuild/retry only outside the hot pointer/paint path',
    ],
    'define spatial query budget hot-path behavior',
  );
  _requireTokens(
    'docs/diagrams/dfd_spatial_query_budget.mmd',
    [
      'QueryBoundary["Spatial query boundary\\nread-only hot path"]',
      'TileBudget["Tile budget gate\\nmax query tiles = 50000"]',
      'CandidateBudget["Candidate budget gate\\nmaxFallbackCandidates = 4096"]',
      'BudgetExceeded["Typed budget-exceeded result\\nno partial candidates"]',
      'InvalidIndex["Invalid index fallback\\nno full-scene scan"]',
      'BudgetExceeded -.->|"defer rebuild/retry\\noutside pointer/paint hot path"| RuntimeRoot',
      'InvalidIndex -.->|"forbidden full-scene scan"| TypedResult',
    ],
    'show spatial query budget without full-scene scan or partial candidates',
  );
  _requireTokens(
    'docs/diagrams/seq_spatial_touched_update.mmd',
    [
      'compile SpatialDelta from touched added/removed/geometry/transform ids',
      'prepare removals from previous memberships',
      'prepare additions from new hitBoundsWorld and paintBoundsWorld',
      'validate ids, generations, structuralRevision, and prepared memberships',
      'Ordinary edit scope contains touched ids only. Full spatial clone for ordinary edit is forbidden.',
      'discard prepared delta without applying partial removals/additions',
      'read new committed bounds and generation for added/geometry/transform ids',
      'Applier->>Runtime: request rebuild or retry outside hot pointer/paint path',
      'Full rebuild/reset is reserved for replacement/load or operation-matrix empty reset paths, not ordinary touched edits.',
      'Runtime->>Spatial: rebuild full spatial index from replacement tables',
      'Load rebuild is a RuntimeRoot post-install effect, not an ordinary touched update.',
    ],
    'show touched spatial update without ordinary full clone or partial stale apply',
  );
  _requireOrderedTokens(
    'docs/diagrams/seq_spatial_touched_update.mmd',
    [
      'read previous membership for touched ids',
      'read new committed bounds and generation for added/geometry/transform ids',
      'prepare removals from previous memberships',
      'prepare additions from new hitBoundsWorld and paintBoundsWorld',
      'validate ids, generations, structuralRevision, and prepared memberships',
    ],
    'must prepare and validate a complete touched spatial delta before apply',
  );
  _requireOrderedTokens(
    'docs/diagrams/seq_spatial_touched_update.mmd',
    [
      'typed invalid-index result',
      'Applier->>Runtime: request rebuild or retry outside hot pointer/paint path',
    ],
    'must route invalid-index scheduling through the applier/runtime boundary',
  );
  _requireTokens(
    'docs/diagrams/seq_hit_test_candidate_resolution.mmd',
    [
      'normalized finite CanvasPointerSample or finite query envelope',
      'else bounded candidate handles returned',
      'candidate handles(id, generation, orderToken, structuralRevision)',
      'stale candidate rejected',
      'exact family hit with transform, local bounds, hit padding, and slop',
      'handles in reverse layer order and reverse element order',
      'first exact hit wins',
      'Legacy SceneNode traversal and legacy scene order logic are not normative input.',
    ],
    'show hit-test candidate resolution with stale rejection and next-owned ordering',
  );
  _requireOrderedTokens(
    'docs/diagrams/seq_hit_test_candidate_resolution.mmd',
    [
      'alt spatial query budget exceeded',
      'typed budget-exceeded result with no partial candidates',
      'else bounded candidate handles returned',
      'candidate handles(id, generation, orderToken, structuralRevision)',
    ],
    'must not expose candidate handles on the budget-exceeded hit-test path',
  );
  _requireTokens(
    'docs/diagrams/state_eraser.mmd',
    [
      'CandidateRefresh --> CorridorPreview: budget exceeded / corridor-only preview, no partial tentative ids',
      'FinalCandidates --> CleanupOnly: budget exceeded / cleanup no-op, no partial erase',
    ],
    'show eraser budget exceeded as preview-only or terminal cleanup-only',
  );
  _requireTokens(
    'docs/diagrams/seq_eraser_commit.mmd',
    [
      'alt preview candidate/check budget exceeded',
      'alt terminal candidate/check budget exceeded',
      'Terminal budget is 4096 candidates / 32768 exact checks',
      'no partial erase, document mutation, selection mutation, spatial index mutation, projection/cache eviction, main repaint, or erase action',
    ],
    'show eraser budget exceeded cannot partially commit',
  );
  _requireTokens(
    'docs/diagrams/seq_eraser_exact_budget.mmd',
    [
      'alt preview spatial budget exceeded',
      'else preview spatial candidates returned',
      'alt preview candidate/check budget exceeded',
      'Preview budget is 512 candidates / 4096 exact checks per sample.',
      'publish corridor-only preview, no tentative ids',
      'Preview budget exceeded produces no document mutation, selection change, spatial update, projection/cache eviction, main repaint, or erase action.',
      'alt terminal spatial budget exceeded',
      'else terminal spatial candidates returned',
      'alt terminal candidate/check budget exceeded',
      'Terminal budget is 4096 candidates / 32768 exact checks.',
      'Empty terminal exact set is cleanup/no-op',
      'no document mutation, selection mutation, spatial index mutation, projection/cache eviction, main repaint, public document notification, or erase action',
      'CC->>Applier: hand off compiled CommitPlan',
      'Applier->>SpatialApply: apply touched removals only',
      'Applier->>Projection: evict by projectionRevision',
      'Applier->>Events: materialize erase action after install',
      'Preview->>Frame: request overlay cleanup repaint',
      'terminal exact checks for deletable non-background candidates',
      'exact deletable non-background ids',
      'Terminal budget exceeded is cleanup/no-op: no partial erase, document mutation, selection mutation, spatial index mutation, projection/cache eviction, main repaint, or erase action.',
    ],
    'show engine-level eraser exact budget as non-partial preview or cleanup-only terminal behavior',
  );
  _requireOrderedTokens(
    'docs/diagrams/seq_eraser_exact_budget.mmd',
    [
      'alt preview spatial budget exceeded',
      'else preview spatial candidates returned',
      'IE->>Geometry: preview exact checks for deletable non-background candidates',
    ],
    'must run preview exact eraser checks only after spatial candidates exist',
  );
  _requireOrderedTokens(
    'docs/diagrams/seq_eraser_exact_budget.mmd',
    [
      'alt terminal spatial budget exceeded',
      'else terminal spatial candidates returned',
      'IE->>Geometry: terminal exact checks',
    ],
    'must run terminal exact eraser checks only after spatial candidates exist',
  );
  _requireOrderedTokens(
    'docs/diagrams/seq_eraser_exact_budget.mmd',
    [
      'EK->>CC: compile exact touched set and staged erase action',
      'CC->>Applier: hand off compiled CommitPlan',
      'Applier->>Store: atomic install',
      'Applier->>SpatialApply: apply touched removals only',
      'Applier->>Projection: evict by projectionRevision',
      'Applier->>Events: materialize erase action after install',
      'Applier->>Frame: publish committed main repaint bus',
      'Preview->>Frame: request overlay cleanup repaint',
    ],
    'must route successful eraser commit effects through CommitApplier',
  );
  _requireTokens(
    'docs/diagrams/seq_schema_v1_decode_encode_order.mmd',
    [
      'raw JSON length check',
      'schemaVersion gate(read exactly {1})',
      'known v1 field validation and unknown non-metadata policy',
      'primitive validation(colors, finite numbers, ids)',
      'resource validation(appKey source only)',
      'duplicate id checks',
      'missing resource reference checks',
      'metadata validation(JSON-only bounded extension area)',
      'materialize immutable CanvasDocument DTO',
      'Decode failure does not materialize partial DTOs and does not mutate runtime or store state.',
      'validate public DTO before writing JSON',
      'preserve layer/resource/element order',
      'omit nullable optional family fields only where schema allows',
      'write uppercase color hex',
      'preserve metadata only as JSON-compatible values',
      'performs no runtime/store side effects during decode or encode',
    ],
    'show schema v1 decode/encode ordering and no runtime side effects',
  );
  _requireOrderedTokens(
    'docs/diagrams/seq_schema_v1_decode_encode_order.mmd',
    [
      'Schema-->>Codec: validated v1 document facts',
      'Codec->>DTO: materialize immutable CanvasDocument DTO',
      'DTO-->>Codec: decoded document',
      'Codec-->>API: decoded document',
    ],
    'must keep schema validators as helpers and DTO materialization inside CodecBoundary',
  );
  _requireOrderedTokens(
    'docs/diagrams/seq_schema_v1_decode_encode_order.mmd',
    [
      'Schema->>Diagnostics: create codec diagnostic with code, path, and sanitized details',
      'Diagnostics-->>Codec: CanvasDataException safe public projection',
      'Codec--x API: throw CanvasDataException',
      'API--x App: throw CanvasDataException',
    ],
    'must project decode failures through CodecBoundary rather than directly from schema validators',
  );
  _requireOrderedTokens(
    'docs/diagrams/seq_schema_v1_decode_encode_order.mmd',
    [
      'Codec->>Schema: validate public DTO before writing JSON',
      'Schema-->>Codec: public DTO accepted',
      'Codec->>Codec: canonicalize default fields',
      'Codec->>Codec: preserve layer/resource/element order',
    ],
    'must keep canonical encode ownership inside CodecBoundary after DTO validation',
  );
}

void _checkRequiredBenchmarkCases() {
  final benchmarks = _read('docs/verification/benchmarks.md');
  const requiredCases = [
    'edit.set_camera_offset',
    'frame.selected_move_preview_cached_ordinary_plan',
    'resources.resolve_sync_cold_budget',
    'input.eraser_budget_exceeded',
    'load_document.success',
    'load_document.failure',
    'input.line_preview',
    'edit.add_line',
    'runtime.dispose_during_gesture',
  ];
  for (final benchmarkCase in requiredCases) {
    if (!benchmarks.contains('`$benchmarkCase`')) {
      _fail('benchmarks.md is missing required case `$benchmarkCase`');
    }
  }
}

void _checkFunctionalLedgerCoverage() {
  final inventoryRows = _legacyCapabilityRows();
  final ledgerRows = _functionalLedgerRows();
  if (inventoryRows.length < 40) {
    _fail(
      'legacy capability inventory has only ${inventoryRows.length} rows; expected broad legacy capability coverage',
    );
  }
  final inventoryCapabilities = _validateCoverageRows(
    inventoryRows,
    label: 'legacy capability inventory',
  );
  final ledgerCapabilities = _validateCoverageRows(
    ledgerRows,
    label: 'functional ledger',
  );
  _checkSetEquality(
    'legacy capability inventory vs functional ledger capabilities',
    inventoryCapabilities,
    ledgerCapabilities,
  );

  final tests = <String>{};
  for (final row in ledgerRows) {
    final capability = row['Capability'] ?? '';
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
  if (!registryTests.contains(
    'test.functional_ledger.legacy_capability_inventory',
  )) {
    _fail(
      'legacy capability inventory rows are not backed by test.functional_ledger.legacy_capability_inventory',
    );
  }
  if (!registryTests.contains('test.functional_ledger.row_specific_tests')) {
    _fail(
      'functional ledger rows are not backed by test.functional_ledger.row_specific_tests',
    );
  }
}

Set<String> _validateCoverageRows(
  List<Map<String, String>> rows, {
  required String label,
}) {
  final capabilities = <String>{};
  for (final row in rows) {
    final capability = row['Capability'] ?? '';
    if (!capabilities.add(capability)) {
      _fail('$label has duplicate capability $capability');
    }
    for (final entry in row.entries) {
      if (entry.value.isEmpty ||
          RegExp(
            r'\b(tbd|todo|unknown|not decided)\b',
            caseSensitive: false,
          ).hasMatch(entry.value)) {
        _fail(
          '$label row $capability has incomplete ${entry.key}: ${entry.value}',
        );
      }
    }
  }
  return capabilities;
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
  return _markdownTableRows(
    path: 'docs/verification/functional_ledger.md',
    header: '| Capability | Next API v1 | Required test id |',
    columns: ['Capability', 'Next API v1', 'Required test id'],
    label: 'functional ledger',
  );
}

List<Map<String, String>> _legacyCapabilityRows() {
  return _markdownTableRows(
    path: 'docs/verification/legacy_capability_inventory.md',
    header: '| Capability | Legacy oracle | Evidence focus |',
    columns: ['Capability', 'Legacy oracle', 'Evidence focus'],
    label: 'legacy capability inventory',
  );
}

List<Map<String, String>> _markdownTableRows({
  required String path,
  required String header,
  required List<String> columns,
  required String label,
}) {
  final text = _read(path);
  final start = text.indexOf(header);
  if (start < 0) {
    _fail('$label table header is missing or changed');
    return const [];
  }
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
        '$label row has ${cells.length} cells, expected ${columns.length}: $line',
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

void _checkCachePolicyRowsHaveCapacityEvictionProbe(String path, String text) {
  for (final line in text.split('\n')) {
    if (!line.startsWith('| ')) {
      continue;
    }
    if (line.contains('---') || line.contains('| Cache |')) {
      continue;
    }
    final cells = line.split('|').skip(1).map((cell) => cell.trim()).toList();
    if (cells.length < 8) {
      _fail('$path row has too few columns: $line');
      continue;
    }
    final capacity = cells[4];
    final eviction = cells[5];
    final probe = cells[6];
    if (capacity.isEmpty || eviction.isEmpty || probe.isEmpty) {
      _fail('$path row lacks capacity, eviction, or probe: $line');
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
  final guardrailIndexTests = _markdownIndexCodeWitnesses(
    'docs/indexes/by_guardrail.md',
    'Tests',
  );
  final testIndexGuardrails = _markdownIndexCodeWitnesses(
    'docs/indexes/by_test_area.md',
    'Guardrails',
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
  _checkGuardrailTestIndexSymmetry(guardrailIndexTests, testIndexGuardrails);
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

Map<String, Set<String>> _markdownIndexCodeWitnesses(
  String path,
  String label,
) {
  _requireFile(path);
  final text = _read(path);
  final valuesByHeading = <String, Set<String>>{};
  final blocks = text.split(RegExp(r'^##\s+', multiLine: true));

  for (final block in blocks.skip(1)) {
    final lines = block.split('\n');
    final heading = lines.first.trim();
    final body = lines.skip(1).join('\n');
    final match = RegExp(
      '^- ${RegExp.escape(label)}: (.+)\$',
      multiLine: true,
    ).firstMatch(body);
    if (match == null) {
      _fail('$path heading $heading has no $label witness line');
      valuesByHeading[heading] = const <String>{};
      continue;
    }
    final line = _matchGroup(match, 1, '$path $heading $label line');
    valuesByHeading[heading] = RegExp(r'`([^`]+)`')
        .allMatches(line)
        .map((match) => _matchGroup(match, 1, '$path $label reference'))
        .where((id) => id != 'none')
        .toSet();
  }

  return valuesByHeading;
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

void _checkGuardrailTestIndexSymmetry(
  Map<String, Set<String>> guardrailToTests,
  Map<String, Set<String>> testToGuardrails,
) {
  for (final entry in guardrailToTests.entries) {
    final guardrail = entry.key;
    for (final test in entry.value) {
      final testGuardrails = testToGuardrails[test] ?? const <String>{};
      if (!testGuardrails.contains(guardrail)) {
        _fail(
          'docs/indexes/by_test_area.md $test must list $guardrail because '
          'docs/indexes/by_guardrail.md lists $test',
        );
      }
    }
  }

  for (final entry in testToGuardrails.entries) {
    final test = entry.key;
    for (final guardrail in entry.value) {
      final guardrailTests = guardrailToTests[guardrail] ?? const <String>{};
      if (!guardrailTests.contains(test)) {
        _fail(
          'docs/indexes/by_guardrail.md $guardrail must list $test because '
          'docs/indexes/by_test_area.md lists $guardrail',
        );
      }
    }
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
  final sectionsById = {
    for (final section in sections)
      _stringField(section, 'id', 'section registry entry'): section,
  };
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
      if (!_globalCatalogSections.contains(id) &&
          !_globalCatalogSections.contains(reference)) {
        final referenceSection = sectionsById[reference];
        if (referenceSection != null) {
          final phase = _earliestPhaseOrder(section, id);
          final referencePhase = _earliestPhaseOrder(
            referenceSection,
            reference,
          );
          if (phase != null &&
              referencePhase != null &&
              referencePhase > phase) {
            _fail(
              '$id earliest phase ${_earliestPhaseLabel(section, id)} must_read points to later $reference earliest phase ${_earliestPhaseLabel(referenceSection, reference)}',
            );
          }
        }
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

int? _earliestPhaseOrder(YamlMap section, String id) {
  int? earliest;
  for (final phase in _stringListField(section, 'phases', id)) {
    final order = _phaseOrder[phase];
    if (order == null) {
      _fail('$id references unknown phase $phase');
      continue;
    }
    if (earliest == null || order < earliest) {
      earliest = order;
    }
  }
  return earliest;
}

String _earliestPhaseLabel(YamlMap section, String id) {
  String? earliestPhase;
  int? earliestOrder;
  for (final phase in _stringListField(section, 'phases', id)) {
    final order = _phaseOrder[phase];
    if (order == null) {
      continue;
    }
    if (earliestOrder == null || order < earliestOrder) {
      earliestOrder = order;
      earliestPhase = phase;
    }
  }
  return earliestPhase ?? 'unknown';
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

void _requireTokens(String path, List<String> tokens, String message) {
  final text = _read(path);
  for (final token in tokens) {
    if (!text.contains(token)) {
      _fail('$path $message; missing token: $token');
    }
  }
}

void _requireOrderedTokens(String path, List<String> tokens, String message) {
  final text = _read(path);
  var offset = 0;
  for (final token in tokens) {
    final nextOffset = text.indexOf(token, offset);
    if (nextOffset == -1) {
      _fail('$path $message; missing ordered token after $offset: $token');
    }
    offset = nextOffset + token.length;
  }
}

void _forbidTokens(String path, List<String> tokens, String message) {
  final text = _read(path);
  for (final token in tokens) {
    final offset = text.indexOf(token);
    if (offset != -1) {
      _fail('$path:${_lineNumber(text, offset)} $message; found: $token');
    }
  }
}

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
