import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('SceneCommands keeps exact command surface without retired aliases', () {
    final source = File(
      'lib/src/controller/commands/scene_commands.dart',
    ).readAsStringSync();

    const retainedExactMethods = <String>[
      'List<NodeId>? writeSelectionReplaceExactResult(',
      'bool writeSelectionToggleExactChange(',
      'bool writeSelectionClearExactChange()',
      '({int selectedCount, bool changed}) writeSelectionSelectAllExactResult(',
      'bool writeBackgroundColorSetExactChange(',
      'bool writeGridEnabledSetExactChange(',
      'bool writeGridCellSizeSetExactChange(',
      'bool writeCameraOffsetSetExactChange(',
    ];
    for (final method in retainedExactMethods) {
      expect(source, contains(method), reason: 'Missing $method');
    }

    const retiredAliasDeclarations = <String>[
      'writeSelectionReplace',
      'writeSelectionToggle',
      'writeSelectionClear',
      'writeSelectionSelectAll',
      'writeBackgroundColorSet',
      'writeGridEnabledSet',
      'writeGridCellSizeSet',
      'writeCameraOffsetSet',
    ];
    for (final method in retiredAliasDeclarations) {
      expect(
        source,
        isNot(
          contains(
            RegExp(
              '^\\s+(?:[\\w<>{}?,.:() ]+\\s+)?$method\\s*\\(',
              multiLine: true,
            ),
          ),
        ),
        reason: 'Retired alias declaration reappeared: $method',
      );
    }
  });
}
