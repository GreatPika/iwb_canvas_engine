@Tags(['tool'])
@Timeout(Duration(minutes: 2))
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'support/tool_process_test_support.dart';

void main() {
  group('tool/analysis/find_similar_clones.dart', () {
    test('groups all connected duplicate blocks into one cluster', () async {
      final sandbox = await createToolSandbox(
        tempPrefix: 'iwb_canvas_engine_find_similar_clones_tool_test_',
        toolFiles: const <String>[
          'tool/analysis/find_similar_clones.dart',
          'tool/analysis/src/clone_analysis_cli.dart',
          'tool/analysis/src/clone_analysis_collector.dart',
          'tool/analysis/src/clone_analysis_config.dart',
          'tool/analysis/src/clone_analysis_engine.dart',
          'tool/analysis/src/clone_analysis_models.dart',
          'tool/analysis/src/clone_analysis_report.dart',
        ],
      );

      try {
        writeSandboxFile(sandbox, 'lib/duplicates.dart', '''
int alpha(int x) {
  var value = x + 1;
  value = value * 2;
  value = value - 3;
  value = value.abs();
  value = value + 4;
  value = value * 5;
  return value;
}

int beta(int y) {
  var value = y + 1;
  value = value * 2;
  value = value - 3;
  value = value.abs();
  value = value + 4;
  value = value * 5;
  return value;
}

int gamma(int z) {
  var value = z + 1;
  value = value * 2;
  value = value - 3;
  value = value.abs();
  value = value + 4;
  value = value * 5;
  return value;
}
''');

        final textResult = await runSandboxTool(
          sandbox,
          'analysis/find_similar_clones.dart',
          args: const <String>[
            '--clusters',
            '--top',
            '10',
            'lib',
            '10',
            '5',
            '3',
            '2',
            '0.4',
            '20',
          ],
        );

        expect(textResult.exitCode, 0, reason: textResult.stderr.toString());
        final stdout = textResult.stdout.toString();
        expect(stdout, contains('Found clone clusters: 1'));
        expect(stdout, contains('members=3'));
        expect(stdout, contains('pairs=3'));
        expect(stdout, contains('Cluster 1  [3 members, 3 pairs, structural]'));
        expect(
          stdout,
          contains(
            'bestPair=alpha <-> beta  overlap=81.0%  sharedFingerprints=17',
          ),
        );
        expect(stdout, contains('function alpha'));
        expect(stdout, contains('function beta'));
        expect(stdout, contains('function gamma'));

        final topClusterResult = await runSandboxTool(
          sandbox,
          'analysis/find_similar_clones.dart',
          args: const <String>[
            '--clusters',
            '--top',
            '1',
            'lib',
            '10',
            '5',
            '3',
            '2',
            '0.4',
            '20',
          ],
        );

        expect(
          topClusterResult.exitCode,
          0,
          reason: topClusterResult.stderr.toString(),
        );
        final topClusterStdout = topClusterResult.stdout.toString();
        expect(topClusterStdout, contains('Found clone clusters: 1'));
        expect(topClusterStdout, contains('members=3'));
        expect(topClusterStdout, contains('pairs=3'));
        expect(topClusterStdout, contains('topResults=top 1 clusters'));

        final jsonResult = await runSandboxTool(
          sandbox,
          'analysis/find_similar_clones.dart',
          args: const <String>[
            '--json',
            '--clusters',
            'lib',
            '10',
            '5',
            '3',
            '2',
            '0.4',
            '20',
          ],
        );

        expect(jsonResult.exitCode, 0, reason: jsonResult.stderr.toString());
        final payload =
            jsonDecode(jsonResult.stdout.toString()) as Map<String, Object?>;
        final config = payload['config'] as Map<String, Object?>;
        final clusters = payload['clusters'] as List<Object?>;
        expect(payload.containsKey('results'), isFalse);
        expect(config['reportMode'], 'clusters');
        expect(clusters, hasLength(1));

        final cluster = clusters.single as Map<String, Object?>;
        expect(cluster['memberCount'], 3);
        expect(cluster['pairCount'], 3);
        final bestPair = cluster['bestPair'] as Map<String, Object?>;
        expect((
          (bestPair['a'] as Map<String, Object?>)['name'],
          (bestPair['b'] as Map<String, Object?>)['name'],
        ), anyOf(equals(('alpha', 'beta')), equals(('beta', 'alpha'))));

        final members = cluster['members'] as List<Object?>;
        final names = members
            .map(
              (member) =>
                  ((member as Map<String, Object?>)['block']
                      as Map<String, Object?>)['name'],
            )
            .toList();
        expect(names, containsAll(<String>['alpha', 'beta', 'gamma']));
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    });
  });
}
