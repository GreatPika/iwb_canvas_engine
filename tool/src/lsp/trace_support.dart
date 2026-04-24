import 'language_server_client.dart';
import 'symbol_locator.dart';

final class LspCallItem {
  const LspCallItem({
    required this.name,
    required this.detail,
    required this.repoRelativePath,
    required this.line,
    required this.character,
    required this.raw,
  });

  final String name;
  final String detail;
  final String repoRelativePath;
  final int line;
  final int character;
  final Map<String, Object?> raw;

  String get label => detail.isEmpty ? name : '$detail.$name';

  String get key => '$repoRelativePath:$line:$character:$label';
}

final class FlowSideBranch {
  const FlowSideBranch({required this.label, required this.repoRelativePath});

  final String label;
  final String repoRelativePath;
}

final class StitchedFlowStep {
  const StitchedFlowStep({
    required this.item,
    required this.transition,
    required this.sideBranches,
  });

  final LspCallItem item;
  final String transition;
  final List<FlowSideBranch> sideBranches;
}

final class StitchedFlow {
  const StitchedFlow({required this.start, required this.steps});

  final LspCallItem start;
  final List<StitchedFlowStep> steps;
}

Future<LspCallItem?> prepareCallItemForSymbol(
  LanguageServerClient client,
  LocatedSymbol symbol,
) async {
  await client.openFile(symbol.repoRelativePath);
  return prepareCallItemAtPosition(
    client,
    repoRelativePath: symbol.repoRelativePath,
    line: symbol.line,
    character: symbol.character,
  );
}

Future<LspCallItem?> prepareCallItemAtPosition(
  LanguageServerClient client, {
  required String repoRelativePath,
  required int line,
  required int character,
}) async {
  await client.openFile(repoRelativePath);
  final prepared = await client.requestWithFileRetry(
    'textDocument/prepareCallHierarchy',
    <String, Object?>{
      'textDocument': <String, Object?>{
        'uri': client.resolveUri(repoRelativePath).toString(),
      },
      'position': <String, Object?>{'line': line, 'character': character},
    },
  );
  final items = prepared as List<Object?>? ?? const <Object?>[];
  if (items.isEmpty) {
    return null;
  }
  return _callItemFromMap(
    client,
    (items.first as Map<Object?, Object?>).cast<String, Object?>(),
  );
}

Future<List<LspCallItem>> collectCallHierarchyItems(
  LanguageServerClient client,
  LspCallItem item, {
  required String method,
  required bool includeExternal,
}) async {
  final raw = await client.requestWithFileRetry(method, <String, Object?>{
    'item': item.raw,
  });
  final entries = raw as List<Object?>? ?? const <Object?>[];
  final results = <LspCallItem>[];
  for (final entry in entries.whereType<Map<Object?, Object?>>()) {
    final cast = entry.cast<String, Object?>();
    final nested =
        (method == 'callHierarchy/incomingCalls' ? cast['from'] : cast['to'])
            as Map<Object?, Object?>? ??
        const <Object?, Object?>{};
    final mapped = nested.cast<String, Object?>();
    final uri = mapped['uri'] as String? ?? '';
    if (!includeExternal && !client.isRepoUri(uri)) {
      continue;
    }
    results.add(_callItemFromMap(client, mapped));
  }
  return results;
}

Future<List<LspCallItem>> collectImplementationItems(
  LanguageServerClient client,
  LspCallItem item, {
  required bool includeExternal,
}) async {
  final raw = await client.requestWithFileRetry(
    'textDocument/implementation',
    <String, Object?>{
      'textDocument': <String, Object?>{
        'uri': client.resolveUri(item.repoRelativePath).toString(),
      },
      'position': <String, Object?>{
        'line': item.line,
        'character': item.character,
      },
    },
  );
  final results = <LspCallItem>[];
  final seen = <String>{};
  for (final entry
      in (raw as List<Object?>? ?? const <Object?>[])
          .whereType<Map<Object?, Object?>>()) {
    final cast = entry.cast<String, Object?>();
    final uri = cast['uri'] as String? ?? '';
    if (!includeExternal && !client.isRepoUri(uri)) {
      continue;
    }
    final range =
        (cast['range'] as Map<Object?, Object?>? ?? const <Object?, Object?>{})
            .cast<String, Object?>();
    final start =
        (range['start'] as Map<Object?, Object?>? ?? const <Object?, Object?>{})
            .cast<String, Object?>();
    final repoRelativePath = client.toRepoRelativePath(uri);
    final prepared = await prepareCallItemAtPosition(
      client,
      repoRelativePath: repoRelativePath,
      line: start['line'] as int? ?? 0,
      character: start['character'] as int? ?? 0,
    );
    if (prepared == null || !seen.add(prepared.key)) {
      continue;
    }
    results.add(prepared);
  }
  return results;
}

Future<StitchedFlow> tracePrimaryOutgoingFlow(
  LanguageServerClient client,
  LspCallItem start, {
  required int depth,
  required bool includeExternal,
}) async {
  final steps = <StitchedFlowStep>[];
  final visited = <String>{start.key};
  var current = start;
  var remainingDepth = depth;

  while (remainingDepth > 0) {
    final outgoing = await collectCallHierarchyItems(
      client,
      current,
      method: 'callHierarchy/outgoingCalls',
      includeExternal: includeExternal,
    );
    if (outgoing.isEmpty) {
      final implementations = await collectImplementationItems(
        client,
        current,
        includeExternal: includeExternal,
      );
      final implementation = _selectSingleNewImplementation(
        current,
        implementations,
        visited,
      );
      if (implementation == null) {
        break;
      }
      steps.add(
        StitchedFlowStep(
          item: implementation,
          transition: 'implementation',
          sideBranches: const <FlowSideBranch>[],
        ),
      );
      visited.add(implementation.key);
      current = implementation;
      continue;
    }

    final chosen = _pickPrimaryOutgoing(current, outgoing);
    final sideBranches = outgoing
        .where((candidate) => candidate.key != chosen.key)
        .map(
          (candidate) => FlowSideBranch(
            label: candidate.label,
            repoRelativePath: candidate.repoRelativePath,
          ),
        )
        .toList(growable: false);
    steps.add(
      StitchedFlowStep(
        item: chosen,
        transition: 'call',
        sideBranches: sideBranches,
      ),
    );
    visited.add(chosen.key);
    current = chosen;
    remainingDepth--;

    final implementations = await collectImplementationItems(
      client,
      current,
      includeExternal: includeExternal,
    );
    final implementation = _selectSingleNewImplementation(
      current,
      implementations,
      visited,
    );
    if (implementation == null) {
      continue;
    }
    steps.add(
      StitchedFlowStep(
        item: implementation,
        transition: 'implementation',
        sideBranches: const <FlowSideBranch>[],
      ),
    );
    visited.add(implementation.key);
    current = implementation;
  }

  return StitchedFlow(
    start: start,
    steps: List<StitchedFlowStep>.unmodifiable(steps),
  );
}

LspCallItem _callItemFromMap(
  LanguageServerClient client,
  Map<String, Object?> map,
) {
  final selectionRange =
      (map['selectionRange'] as Map<Object?, Object?>? ??
              map['range'] as Map<Object?, Object?>? ??
              const <Object?, Object?>{})
          .cast<String, Object?>();
  final start =
      (selectionRange['start'] as Map<Object?, Object?>? ??
              const <Object?, Object?>{})
          .cast<String, Object?>();
  final uri = map['uri'] as String? ?? '';
  return LspCallItem(
    name: map['name'] as String? ?? '<unknown>',
    detail: map['detail'] as String? ?? '',
    repoRelativePath: client.toRepoRelativePath(uri),
    line: start['line'] as int? ?? 0,
    character: start['character'] as int? ?? 0,
    raw: map,
  );
}

LspCallItem _pickPrimaryOutgoing(LspCallItem current, List<LspCallItem> items) {
  final sorted = items.toList(growable: false)
    ..sort((left, right) {
      final scoreCompare =
          _scoreOutgoing(current, right) - _scoreOutgoing(current, left);
      if (scoreCompare != 0) {
        return scoreCompare;
      }
      final pathCompare = left.repoRelativePath.compareTo(
        right.repoRelativePath,
      );
      if (pathCompare != 0) {
        return pathCompare;
      }
      return left.label.compareTo(right.label);
    });
  return sorted.first;
}

int _scoreOutgoing(LspCallItem current, LspCallItem candidate) {
  var score = 0;
  if (candidate.name == current.name) {
    score += 100;
  }
  if (candidate.detail == current.detail) {
    score += 10;
  }
  if (!candidate.name.startsWith('_')) {
    score += 5;
  }
  if (candidate.repoRelativePath == current.repoRelativePath) {
    score -= 5;
  }
  return score;
}

LspCallItem? _selectSingleNewImplementation(
  LspCallItem current,
  List<LspCallItem> implementations,
  Set<String> visited,
) {
  final distinct = implementations
      .where(
        (candidate) =>
            candidate.key != current.key && !visited.contains(candidate.key),
      )
      .toList(growable: false);
  if (distinct.length != 1) {
    return null;
  }
  return distinct.single;
}
