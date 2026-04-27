import 'dart:io';

import 'invariant_registry.dart';

const Set<String> _expectedArchitectureFamilyIds = <String>{
  'public_package_boundary',
  'contract_document_model_and_validated_fast_paths',
  'import_build_materialization',
  'serialization_and_schema',
  'core_scene_graph_geometry_and_spatial_indexes',
  'model_document_mutation_and_topology',
  'store_and_commit_path',
  'composition_root_and_facade',
  'interaction_runtime',
  'mutation_gateway',
  'view_runtime_and_pointer_hosting',
  'render_frame_admission_and_caches',
  'diagnostics_performance_and_debug_surfaces',
};

const Set<String> _expectedProofFamilyIds = <String>{
  'public_entrypoint_and_signature_proof',
  'guardrail_runner_and_artifact_model',
  'invariant_registry_and_proof_reachability',
  'verification_contract_and_workflow_drift',
};

const Set<String> _allowedStatuses = <String>{
  'locked',
  'known issue',
  'docs stale',
};

const List<String> _requiredFamilyHeadings = <String>[
  '## Purpose',
  '## Target Rules',
  '## Owners',
  '## Forbidden Shapes',
  '## Mechanical Evidence',
  '## Status',
  '## Update Triggers',
];

final RegExp _registryRowPattern = RegExp(r'^\|\s*`([^`]+)`\s*\|');
final RegExp _markdownLinkPattern = RegExp(r'\[([^\]]+)\]\(([^)]+)\)');
final RegExp _statusPattern = RegExp(r'`(locked|known issue|docs stale)`');
final RegExp _invariantPattern = RegExp(
  r'\bINV-(?:G|ENG|SER)-[A-Z0-9]+(?:-[A-Z0-9]+)*\b',
);
final RegExp _commandPattern = RegExp(
  r'dart run (tool/[^\s`]+\.dart)[^\r\n`]*',
);
final RegExp _flutterToolTestPattern = RegExp(
  r'flutter test[^\r\n`]*\btest/tool(?:\b|/)',
);
final RegExp _jsonOutPattern = RegExp(r'--json-out=(?:"([^"]+)"|([^\s`]+))');
final RegExp _mdOutPattern = RegExp(r'--md-out=(?:"([^"]+)"|([^\s`]+))');
final RegExp _mermaidOutPattern = RegExp(
  r'--mermaid-out=(?:"([^"]+)"|([^\s`]+))',
);
final RegExp _knownIssuePattern = RegExp(r'\bKI-\d+\b');

Future<void> main(List<String> args) async {
  final config = _Config.parse(args);
  final result = await _AtlasChecker(config).check();

  if (result.failures.isNotEmpty) {
    stderr.writeln('FAIL: architecture atlas check failed.');
    for (final failure in result.failures) {
      stderr.writeln('- $failure');
    }
    exitCode = 1;
    return;
  }

  stdout.writeln(
    'Architecture atlas OK '
    '(${_expectedArchitectureFamilyIds.length} architecture families, '
    '${_expectedProofFamilyIds.length} proof families).',
  );
}

class _Config {
  const _Config({required this.repoRoot, required this.docsRoot});

  factory _Config.parse(List<String> args) {
    var repoRoot = Directory.current;
    var docsRoot = Directory('${repoRoot.path}/docs');
    var hasExplicitDocsRoot = false;

    for (final arg in args) {
      if (arg.startsWith('--repo-root=')) {
        repoRoot = Directory(arg.substring('--repo-root='.length));
        if (!hasExplicitDocsRoot) {
          docsRoot = Directory('${repoRoot.path}/docs');
        }
        continue;
      }
      if (arg.startsWith('--docs-root=')) {
        docsRoot = Directory(arg.substring('--docs-root='.length));
        hasExplicitDocsRoot = true;
        continue;
      }
      _usage('Unknown argument `$arg`.');
    }

    return _Config(
      repoRoot: _canonicalDirectory(repoRoot),
      docsRoot: _canonicalDirectory(docsRoot),
    );
  }

  final Directory repoRoot;
  final Directory docsRoot;
}

class _AtlasChecker {
  _AtlasChecker(this.config)
    : _knownInvariantIds = invariants.map((invariant) => invariant.id).toSet();

  final _Config config;
  final Set<String> _knownInvariantIds;
  final List<String> _failures = <String>[];
  final Set<String> _referencedEvidencePaths = <String>{};
  final Set<String> _commandOutputEvidencePaths = <String>{};
  final Set<String> _freshnessCheckedCommands = <String>{};

  Future<_CheckResult> check() async {
    final entrypoint = _file('ARCHITECTURE_ATLAS.md');
    _requireFile(entrypoint, 'atlas entrypoint');
    if (entrypoint.existsSync()) {
      final source = entrypoint.readAsStringSync();
      _requireLink(source, 'architecture/overview.md', entrypoint.path);
      _requireLink(source, 'proof_architecture/overview.md', entrypoint.path);
    }

    _checkRegistry(
      kind: _FamilyKind.architecture,
      overviewPath: 'architecture/overview.md',
      sectionHeading: '## Owner Family Registry',
      expectedIds: _expectedArchitectureFamilyIds,
    );
    _checkRegistry(
      kind: _FamilyKind.proof,
      overviewPath: 'proof_architecture/overview.md',
      sectionHeading: '## Proof Family Registry',
      expectedIds: _expectedProofFamilyIds,
    );
    _checkFlowDocs();
    _checkEvidenceOrphans();
    await _checkEvidenceFreshness();

    return _CheckResult(List<String>.unmodifiable(_failures));
  }

  void _checkRegistry({
    required _FamilyKind kind,
    required String overviewPath,
    required String sectionHeading,
    required Set<String> expectedIds,
  }) {
    final overview = _file(overviewPath);
    _requireFile(overview, '$kind overview');
    if (!overview.existsSync()) {
      return;
    }

    final source = overview.readAsStringSync();
    final section = _section(source, sectionHeading);
    if (section == null) {
      _failures.add('${_rel(overview.path)} is missing `$sectionHeading`.');
      return;
    }

    final rows = <String>[];
    final seen = <String>{};
    for (final line in section.split('\n')) {
      final match = _registryRowPattern.firstMatch(line);
      if (match == null) {
        continue;
      }
      final id = _requireGroup(match, 1);
      rows.add(id);
      if (!seen.add(id)) {
        _failures.add('${_rel(overview.path)} duplicates family id `$id`.');
      }
      if (!expectedIds.contains(id)) {
        _failures.add(
          '${_rel(overview.path)} contains unknown family id `$id`.',
        );
      }
      final expectedLink = 'families/$id.md';
      if (!line.contains('($expectedLink)')) {
        _failures.add(
          '${_rel(overview.path)} family `$id` must link to `$expectedLink`.',
        );
      }
    }

    final missing = expectedIds.difference(rows.toSet()).toList()..sort();
    for (final id in missing) {
      _failures.add('${_rel(overview.path)} is missing expected family `$id`.');
    }

    for (final id in expectedIds) {
      _checkFamily(kind, id);
    }
    _checkUnknownFamilyFiles(kind, expectedIds);
  }

  void _checkFamily(_FamilyKind kind, String id) {
    final relativePath = '${kind.directory}/families/$id.md';
    final file = _file(relativePath);
    _requireFile(file, '$kind family `$id`');
    if (!file.existsSync()) {
      return;
    }

    final source = file.readAsStringSync();
    _expectHeadings(source, file, _requiredFamilyHeadings);
    if (kind == _FamilyKind.architecture) {
      _expectHeadings(source, file, const <String>['## Proof Links']);
      _checkProofLinks(file, source);
    }

    _checkStatus(file, source);
    _checkInvariantIds(file, source);
    if (kind == _FamilyKind.architecture) {
      _checkExpectedFamilyInvariantIds(file, id, source);
    }
    _checkEvidenceLinks(file, source);
    _checkToolCommands(file, source);
  }

  void _checkUnknownFamilyFiles(_FamilyKind kind, Set<String> expectedIds) {
    final familyDir = Directory(_file('${kind.directory}/families').path);
    if (!familyDir.existsSync()) {
      return;
    }

    for (final entity in familyDir.listSync()) {
      if (entity is! File || !entity.path.endsWith('.md')) {
        continue;
      }
      final id = _basename(entity.path).replaceFirst(RegExp(r'\.md$'), '');
      if (!expectedIds.contains(id)) {
        _failures.add(
          '${_rel(entity.path)} is not in the expected family set.',
        );
      }
    }
  }

  void _checkProofLinks(File file, String source) {
    final proofLinks = _markdownLinkPattern
        .allMatches(source)
        .map((match) => _requireGroup(match, 2))
        .where((link) => link.contains('proof_architecture/families/'))
        .toList(growable: false);

    if (proofLinks.isEmpty) {
      _failures.add(
        '${_rel(file.path)} must link to at least one proof family.',
      );
      return;
    }

    for (final link in proofLinks) {
      final id = _basename(link).replaceFirst(RegExp(r'\.md(?:#.*)?$'), '');
      if (!_expectedProofFamilyIds.contains(id)) {
        _failures.add('${_rel(file.path)} links unknown proof family `$id`.');
        continue;
      }
      final proofFile = _file('proof_architecture/families/$id.md');
      if (!proofFile.existsSync()) {
        _failures.add('${_rel(file.path)} links missing proof family `$id`.');
      }
    }
  }

  void _checkStatus(File file, String source) {
    final statusSection = _section(source, '## Status');
    if (statusSection == null) {
      return;
    }

    final statuses = _statusPattern
        .allMatches(statusSection)
        .map((match) => _requireGroup(match, 1))
        .toList(growable: false);
    if (statuses.length != 1) {
      _failures.add(
        '${_rel(file.path)} must declare exactly one status from '
        '${_allowedStatuses.join(', ')}.',
      );
      return;
    }

    final status = statuses.single;
    if (!_allowedStatuses.contains(status)) {
      _failures.add('${_rel(file.path)} has unsupported status `$status`.');
    }
    if (status == 'known issue' && !_hasKnownIssueMarkdownLink(statusSection)) {
      _failures.add(
        '${_rel(file.path)} status `known issue` must link a KI id to '
        'KNOWN_ISSUES.md or a dedicated plan step.',
      );
    }
  }

  void _checkInvariantIds(File file, String source) {
    final ids = _invariantPattern
        .allMatches(source)
        .map((match) => _requireGroup(match, 0))
        .toSet();
    for (final id in ids) {
      if (!_knownInvariantIds.contains(id)) {
        _failures.add('${_rel(file.path)} references unknown invariant `$id`.');
      }
    }
  }

  void _checkExpectedFamilyInvariantIds(File file, String id, String source) {
    final expectedIds = architectureFamilyInvariantIds[id] ?? const <String>{};
    final actualIds = _invariantPattern
        .allMatches(source)
        .map((match) => _requireGroup(match, 0))
        .toSet();
    final missing = expectedIds.difference(actualIds).toList()..sort();
    if (missing.isEmpty) {
      return;
    }

    _failures.add(
      '${_rel(file.path)} is missing expected invariant links: '
      '${missing.map((missingId) => '`$missingId`').join(', ')}.',
    );
  }

  void _checkEvidenceLinks(File file, String source) {
    for (final match in _markdownLinkPattern.allMatches(source)) {
      final link = _requireGroup(match, 2);
      final evidencePath = _evidencePathFromLink(file, link);
      if (evidencePath == null) {
        continue;
      }
      _referencedEvidencePaths.add(evidencePath);
      if (!_file(evidencePath).existsSync()) {
        _failures.add('${_rel(file.path)} links missing evidence `$link`.');
      }
    }
  }

  void _checkToolCommands(File file, String source) {
    _checkToolTestCommands(file, source);

    final commandMatches = _commandPattern.allMatches(source).toList();
    if (commandMatches.isEmpty) {
      _failures.add(
        '${_rel(file.path)} must name repository-local tool commands.',
      );
      return;
    }

    for (final match in commandMatches) {
      final toolPath = _requireGroup(match, 1);
      final command = _requireGroup(match, 0);
      if (!File('${config.repoRoot.path}/$toolPath').existsSync()) {
        _failures.add(
          '${_rel(file.path)} references missing command `$toolPath`.',
        );
      }
      _checkGeneratedEvidenceCommand(file, command, toolPath);
    }
  }

  void _checkToolTestCommands(File file, String source) {
    for (final match in _flutterToolTestPattern.allMatches(source)) {
      _failures.add(
        '${_rel(file.path)} must run test/tool/** through '
        '`dart run tool/run_tool_tests.dart`, not `${_requireGroup(match, 0)}`.',
      );
    }
  }

  void _checkGeneratedEvidenceCommand(
    File file,
    String command,
    String toolPath,
  ) {
    final jsonOut = _outputPath(_jsonOutPattern, command);
    final mdOut = _outputPath(_mdOutPattern, command);
    final mermaidOut = _outputPath(_mermaidOutPattern, command);
    final hasGeneratedOutput =
        jsonOut != null || mdOut != null || mermaidOut != null;

    if (!hasGeneratedOutput) {
      return;
    }

    if (toolPath == 'tool/lsp_trace_symbol.dart') {
      if (jsonOut == null || mermaidOut == null) {
        _failures.add(
          '${_rel(file.path)} lsp_trace_symbol evidence commands must include '
          '--json-out and --mermaid-out.',
        );
      }
    } else if (toolPath == 'tool/trace_export_namespace.dart' ||
        toolPath == 'tool/trace_proof_inventory.dart') {
      if (jsonOut == null || mdOut == null) {
        _failures.add(
          '${_rel(file.path)} $toolPath evidence commands must include '
          '--json-out and --md-out.',
        );
      }
    } else if (!toolPath.startsWith('tool/audit_')) {
      _failures.add(
        '${_rel(file.path)} uses unsupported generated evidence command '
        '`$toolPath`.',
      );
    }

    for (final output in <String?>[jsonOut, mdOut, mermaidOut]) {
      if (output == null) {
        continue;
      }
      final evidencePath = _evidencePathFromCommandOutput(output);
      if (evidencePath == null) {
        _failures.add(
          '${_rel(file.path)} generated output `$output` must target atlas '
          'evidence.',
        );
        continue;
      }
      _commandOutputEvidencePaths.add(evidencePath);
      _referencedEvidencePaths.add(evidencePath);
      if (!_file(evidencePath).existsSync()) {
        _failures.add(
          '${_rel(file.path)} generated output `$output` does not exist.',
        );
      }
    }

    if (File('${config.repoRoot.path}/$toolPath').existsSync()) {
      _freshnessCheckedCommands.add(command);
    }
  }

  Future<void> _checkEvidenceFreshness() async {
    final tempRoot = await Directory.systemTemp.createTemp(
      'architecture_atlas_freshness_',
    );
    try {
      for (final command in _freshnessCheckedCommands) {
        await _checkCommandFreshness(tempRoot, command);
      }
    } finally {
      if (tempRoot.existsSync()) {
        tempRoot.deleteSync(recursive: true);
      }
    }
  }

  Future<void> _checkCommandFreshness(
    Directory tempRoot,
    String command,
  ) async {
    final tokens = _splitCommand(command);
    if (tokens.length < 3 || tokens[0] != 'dart' || tokens[1] != 'run') {
      return;
    }

    final outputPaths = <String, String>{};
    final rewrittenArgs = <String>[];
    for (final token in tokens.skip(2)) {
      rewrittenArgs.add(
        _rewriteOutputArg(
          token: token,
          tempRoot: tempRoot,
          outputPaths: outputPaths,
        ),
      );
    }
    if (outputPaths.isEmpty) {
      return;
    }

    final result = await Process.run('dart', <String>[
      'run',
      ...rewrittenArgs,
    ], workingDirectory: config.repoRoot.path);
    if (result.exitCode != 0) {
      _failures.add(
        'Generated evidence command failed while checking freshness: '
        '`$command`\n${result.stderr}',
      );
      return;
    }

    for (final entry in outputPaths.entries) {
      final committedEvidence = _file(entry.key);
      final generatedEvidence = File(entry.value);
      if (!generatedEvidence.existsSync()) {
        _failures.add(
          'Generated evidence command did not write `${entry.key}`: `$command`.',
        );
        continue;
      }
      if (!committedEvidence.existsSync()) {
        continue;
      }
      if (committedEvidence.readAsStringSync() !=
          generatedEvidence.readAsStringSync()) {
        _failures.add('${entry.key} is stale; regenerate it with `$command`.');
      }
    }
  }

  void _checkFlowDocs() {
    for (final relativePath in const <String>[
      'architecture/execution_flows.md',
      'proof_architecture/proof_flows.md',
    ]) {
      final flowFile = _file(relativePath);
      if (!flowFile.existsSync()) {
        continue;
      }
      final source = flowFile.readAsStringSync();
      _checkEvidenceLinks(flowFile, source);
      _checkToolCommands(flowFile, source);
    }
  }

  void _checkEvidenceOrphans() {
    for (final root in const <String>[
      'architecture/evidence',
      'proof_architecture/evidence',
    ]) {
      final directory = Directory(_file(root).path);
      if (!directory.existsSync()) {
        continue;
      }
      for (final entity in directory.listSync(recursive: true)) {
        if (entity is! File) {
          continue;
        }
        final relativePath = _rel(entity.path);
        if (!_referencedEvidencePaths.contains(relativePath) &&
            !_commandOutputEvidencePaths.contains(relativePath)) {
          _failures.add(
            '$relativePath is committed evidence but is not referenced.',
          );
        }
      }
    }
  }

  File _file(String relativePath) =>
      File('${config.docsRoot.path}/$relativePath');

  void _requireFile(File file, String label) {
    if (!file.existsSync()) {
      _failures.add('Missing $label at ${_rel(file.path)}.');
    }
  }

  void _requireLink(String source, String target, String filePath) {
    if (!source.contains('($target)')) {
      _failures.add('${_rel(filePath)} must link to `$target`.');
    }
  }

  void _expectHeadings(String source, File file, List<String> headings) {
    var previousIndex = -1;
    for (final heading in headings) {
      final index = source.indexOf(heading);
      if (index == -1) {
        _failures.add('${_rel(file.path)} is missing `$heading`.');
        continue;
      }
      if (index < previousIndex) {
        _failures.add('${_rel(file.path)} heading `$heading` is out of order.');
      }
      previousIndex = index;
    }
  }

  String? _section(String source, String heading) {
    final start = source.indexOf(heading);
    if (start == -1) {
      return null;
    }
    final bodyStart = source.indexOf('\n', start);
    if (bodyStart == -1) {
      return '';
    }
    final nextHeading = RegExp(
      r'\n##\s+',
    ).firstMatch(source.substring(bodyStart + 1));
    if (nextHeading == null) {
      return source.substring(bodyStart + 1).trim();
    }
    return source
        .substring(bodyStart + 1, bodyStart + 1 + nextHeading.start)
        .trim();
  }

  String? _evidencePathFromLink(File file, String link) {
    if (link.startsWith('http://') ||
        link.startsWith('https://') ||
        link.startsWith('#')) {
      return null;
    }
    final cleanLink = link.split('#').first;
    final absolute = _normalizePath('${file.parent.path}/$cleanLink');
    final docsRootPath = _normalizePath(config.docsRoot.path);
    if (!absolute.startsWith('$docsRootPath/')) {
      return null;
    }
    final relativePath = absolute.substring(docsRootPath.length + 1);
    if (relativePath.startsWith('architecture/evidence/') ||
        relativePath.startsWith('proof_architecture/evidence/')) {
      return relativePath;
    }
    return null;
  }

  String? _evidencePathFromCommandOutput(String output) {
    final cleaned = output.split('#').first;
    final direct = cleaned
        .replaceFirst(RegExp(r'^\$DOCS_ROOT/'), '')
        .replaceFirst(RegExp(r'^docs/'), '');
    if (direct.startsWith('architecture/evidence/') ||
        direct.startsWith('proof_architecture/evidence/')) {
      return direct;
    }

    final absolute = _normalizePath(
      cleaned.startsWith('/') ? cleaned : '${config.repoRoot.path}/$cleaned',
    );
    final docsRootPath = _normalizePath(config.docsRoot.path);
    if (absolute.startsWith('$docsRootPath/')) {
      final relativePath = absolute.substring(docsRootPath.length + 1);
      if (relativePath.startsWith('architecture/evidence/') ||
          relativePath.startsWith('proof_architecture/evidence/')) {
        return relativePath;
      }
    }
    return null;
  }

  String _rel(String path) {
    final absolute = _normalizePath(path);
    final docsRootPath = _normalizePath(config.docsRoot.path);
    if (absolute == docsRootPath) {
      return '.';
    }
    if (absolute.startsWith('$docsRootPath/')) {
      return absolute.substring(docsRootPath.length + 1);
    }
    return absolute;
  }

  bool _hasKnownIssueMarkdownLink(String statusSection) {
    for (final match in _markdownLinkPattern.allMatches(statusSection)) {
      final text = _requireGroup(match, 1);
      final target = _requireGroup(match, 2);
      final linksKnownIssueSource =
          target.contains('KNOWN_ISSUES.md') || target.contains('plan/');
      if (!linksKnownIssueSource) {
        continue;
      }
      if (_knownIssuePattern.hasMatch(text) ||
          _knownIssuePattern.hasMatch(target.toUpperCase())) {
        return true;
      }
    }
    return false;
  }
}

class _CheckResult {
  const _CheckResult(this.failures);

  final List<String> failures;
}

enum _FamilyKind {
  architecture('architecture'),
  proof('proof_architecture');

  const _FamilyKind(this.directory);

  final String directory;

  @override
  String toString() => directory;
}

String? _outputPath(RegExp pattern, String command) {
  final match = pattern.firstMatch(command);
  if (match == null) {
    return null;
  }
  return match.group(1) ?? match.group(2);
}

String _rewriteOutputArg({
  required String token,
  required Directory tempRoot,
  required Map<String, String> outputPaths,
}) {
  for (final flag in const <String>[
    '--json-out=',
    '--md-out=',
    '--mermaid-out=',
  ]) {
    if (!token.startsWith(flag)) {
      continue;
    }
    final originalOutput = token.substring(flag.length);
    final evidencePath = _evidencePathFromOutputToken(originalOutput);
    if (evidencePath == null) {
      return token;
    }
    final generatedPath = '${tempRoot.path}/$evidencePath';
    File(generatedPath).parent.createSync(recursive: true);
    outputPaths[evidencePath] = generatedPath;
    return '$flag$generatedPath';
  }
  return token;
}

String? _evidencePathFromOutputToken(String output) {
  final direct = output
      .replaceFirst(RegExp(r'^\$DOCS_ROOT/'), '')
      .replaceFirst(RegExp(r'^docs/'), '');
  if (direct.startsWith('architecture/evidence/') ||
      direct.startsWith('proof_architecture/evidence/')) {
    return direct;
  }
  return null;
}

List<String> _splitCommand(String command) {
  final tokens = <String>[];
  final buffer = StringBuffer();
  String? quote;

  void flush() {
    if (buffer.isEmpty) {
      return;
    }
    tokens.add(buffer.toString());
    buffer.clear();
  }

  for (var index = 0; index < command.length; index += 1) {
    final char = command[index];
    if (quote != null) {
      if (char == quote) {
        quote = null;
      } else {
        buffer.write(char);
      }
      continue;
    }
    if (char == '"' || char == "'") {
      quote = char;
      continue;
    }
    if (char.trim().isEmpty) {
      flush();
      continue;
    }
    buffer.write(char);
  }
  flush();
  return tokens;
}

String _basename(String path) {
  final cleanPath = path.split('#').first;
  final index = cleanPath.lastIndexOf('/');
  return index == -1 ? cleanPath : cleanPath.substring(index + 1);
}

String _requireGroup(RegExpMatch match, int group) {
  final value = match.group(group);
  if (value == null) {
    throw StateError('Missing regex group $group in ${match.group(0)}');
  }
  return value;
}

Directory _canonicalDirectory(Directory directory) {
  if (!directory.existsSync()) {
    return directory.absolute;
  }
  return Directory(directory.resolveSymbolicLinksSync());
}

String _normalizePath(String path) {
  final isAbsolute = path.startsWith('/');
  final parts = path.split('/').where((part) => part.isNotEmpty);
  final output = <String>[];
  for (final part in parts) {
    if (part == '.') {
      continue;
    }
    if (part == '..') {
      if (output.isNotEmpty) {
        output.removeLast();
      }
      continue;
    }
    output.add(part);
  }
  return '${isAbsolute ? '/' : ''}${output.join('/')}';
}

Never _usage(String message) {
  stderr.writeln(message);
  stderr.writeln(
    'Usage: dart run tool/check_architecture_atlas.dart '
    '[--docs-root=<path>] [--repo-root=<path>]',
  );
  exit(64);
}
