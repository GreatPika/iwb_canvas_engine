import 'package:flutter_test/flutter_test.dart';

import 'fixtures/scripts.dart';
import 'harness/adapters.dart';
import 'harness/normalize.dart';

// INV:INV-V2-TXN-ATOMIC-COMMIT
// INV:INV-V2-EPOCH-INVALIDATION

void main() {
  group('v1/v2 engine parity harness', () {
    for (final script in buildParityScripts()) {
      test(script.name, () {
        final v1Adapter = V1HarnessAdapter();
        final v2Adapter = V2HarnessAdapter();
        addTearDown(v1Adapter.dispose);
        addTearDown(v2Adapter.dispose);

        for (final step in script.steps) {
          v1Adapter.apply(step.operation);
          v2Adapter.apply(step.operation);
        }

        final v1Result = v1Adapter.result();
        final v2Result = v2Adapter.result();

        expect(
          canonicalJsonString(v2Result.sceneJsonCanonical),
          canonicalJsonString(v1Result.sceneJsonCanonical),
          reason: '${script.name}: scene json mismatch',
        );
        expect(
          v2Result.selectedNodeIds,
          v1Result.selectedNodeIds,
          reason: '${script.name}: selection mismatch',
        );
        expect(
          _canonicalEvents(v2Result.events),
          _canonicalEvents(v1Result.events),
          reason: '${script.name}: normalized events mismatch',
        );
      });
    }
  });
}

List<Map<String, Object?>> _canonicalEvents(
  List<NormalizedParityEvent> events,
) {
  return events
      .map((event) {
        return <String, Object?>{
          'type': event.type,
          'nodeIds': canonicalNodeIds(event.nodeIds),
          'payload': canonicalPayloadSubset(event.payloadSubset),
        };
      })
      .toList(growable: false);
}
