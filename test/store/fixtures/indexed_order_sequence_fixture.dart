import 'dart:math';

import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/src/store/indexed_order_sequence.dart';

const _supportedSize = 200000;

typedef _IteratorIsolationPeers = ({
  IndexedOrderSequence<_Entry, String> first,
  IndexedOrderSequence<_Entry, String> second,
  IndexedOrderSequence<_Entry, String> mutationPeer,
  IndexedOrderSequence<_Entry, String> consumePeer,
  IndexedOrderSequence<_Entry, String> discardPeer,
});

void main() {
  test(
    'audits strict implicit AVL invariants through adversarial traces',
    () => expect(_audit().isStrictlyAvlBalanced, isTrue),
  );
  test(
    'matches an independent list and map oracle for indexed operations',
    () => expect(_matchesOracle().single.id, 'final'),
  );
  test(
    'keeps simultaneously live instances and retained inputs isolated',
    () => expect(_keepsInstancesIsolated().map((entry) => entry.id), const [
      'shared-a',
      'shared-b',
      'shared-c',
    ]),
  );
  test(
    'observes supported-size one-pass build and logarithmic rank work',
    () => expect(_observesWorkBounds(), hasLength(_supportedSize)),
  );
}

IndexedOrderSequenceAudit _audit() {
  final sequence = _sequenceFrom(
    List<_Entry>.generate(127, (index) => _Entry('seed-$index')),
  );
  _expectAudit(sequence, expectedCount: 127);
  _runAlternatingAvlTrace(sequence);
  _runRandomAvlTrace(sequence);
  return sequence.audit();
}

void _runAlternatingAvlTrace(IndexedOrderSequence<_Entry, String> sequence) {
  for (var index = 0; index < 96; index += 1) {
    sequence.insert(_Entry('front-$index'), index: 0);
    _expectAudit(sequence, expectedCount: 128 + index);
    sequence.insert(_Entry('back-$index'));
    _expectAudit(sequence, expectedCount: 129 + index);
    expect(sequence.remove('seed-$index'), isNotNull);
    _expectAudit(sequence, expectedCount: 128 + index);
  }
}

void _runRandomAvlTrace(IndexedOrderSequence<_Entry, String> sequence) {
  final random = Random(8173);
  var nextId = 0;
  for (var step = 0; step < 800; step += 1) {
    if (sequence.isEmpty || random.nextBool()) {
      sequence.insert(
        _Entry('random-${nextId++}'),
        index: random.nextInt(sequence.length + 3) - 1,
      );
    } else {
      final id = sequence.orderedValues
          .elementAt(random.nextInt(sequence.length))
          .id;
      expect(sequence.remove(id), isNotNull);
    }
    _expectAudit(sequence, expectedCount: sequence.length);
  }
}

List<_Entry> _matchesOracle() {
  final oracle = _SequenceOracle();
  final sequence = _sequenceFrom(const <_Entry>[]);
  _exerciseDeterministicOracleSemantics(sequence, oracle);
  _exerciseSeededOracleSemantics(sequence, oracle);
  return _consumeAndVerifyClosure(sequence, oracle);
}

void _exerciseDeterministicOracleSemantics(
  IndexedOrderSequence<_Entry, String> sequence,
  _SequenceOracle oracle,
) {
  _expectExact(sequence, oracle);
  oracle.insert(const _Entry('a'), index: 0);
  sequence.insert(const _Entry('a'), index: 0);
  oracle.insert(const _Entry('b'), index: 0);
  sequence.insert(const _Entry('b'), index: 0);
  oracle.insert(const _Entry('c'));
  sequence.insert(const _Entry('c'));
  oracle.insert(const _Entry('d'), index: -17);
  sequence.insert(const _Entry('d'), index: -17);
  oracle.insert(const _Entry('e'), index: 999);
  sequence.insert(const _Entry('e'), index: 999);
  _expectExact(sequence, oracle);

  expect(
    () => sequence.insert(const _Entry('a')),
    throwsA(isA<ArgumentError>()),
  );
  expect(
    () => _sequenceFrom([const _Entry('duplicate'), const _Entry('duplicate')]),
    throwsA(isA<ArgumentError>()),
  );
}

void _exerciseSeededOracleSemantics(
  IndexedOrderSequence<_Entry, String> sequence,
  _SequenceOracle oracle,
) {
  final random = Random(12089);
  var nextId = 0;
  for (var step = 0; step < 3000; step += 1) {
    if (oracle.isEmpty || random.nextInt(3) != 0) {
      final entry = _Entry('generated-${nextId++}');
      final index = switch (random.nextInt(5)) {
        0 => null,
        1 => -random.nextInt(8) - 1,
        2 => oracle.length + random.nextInt(8) + 1,
        _ => random.nextInt(oracle.length + 1),
      };
      oracle.insert(entry, index: index);
      sequence.insert(entry, index: index);
    } else {
      final id = random.nextBool()
          ? oracle.values[random.nextInt(oracle.length)].id
          : 'missing-$step';
      expect(sequence.remove(id), oracle.remove(id));
    }
    _expectExact(sequence, oracle);
  }
}

List<_Entry> _consumeAndVerifyClosure(
  IndexedOrderSequence<_Entry, String> sequence,
  _SequenceOracle oracle,
) {
  sequence.clear();
  oracle.clear();
  _expectExact(sequence, oracle);
  sequence.insert(const _Entry('final'));
  oracle.insert(const _Entry('final'));
  final consumed = sequence.consume();
  expect(consumed, oracle.values);
  expect(() => sequence.length, throwsStateError);
  expect(() => sequence.containsId('final'), throwsStateError);
  expect(() => sequence.orderedValues.toList(), throwsStateError);
  expect(
    () => sequence.insert(const _Entry('after-consume')),
    throwsStateError,
  );
  expect(() => sequence.remove('final'), throwsStateError);
  expect(() => sequence.consume(), throwsStateError);

  final discarded = _sequenceFrom([const _Entry('discarded')]);
  discarded.discard();
  expect(() => discarded.first, throwsStateError);
  expect(() => discarded.discard(), throwsStateError);
  return consumed;
}

List<_Entry> _keepsInstancesIsolated() {
  final retainedInput = <_Entry>[
    const _Entry('shared-a'),
    const _Entry('shared-b'),
    const _Entry('shared-c'),
  ];
  final first = _sequenceFrom(retainedInput);
  final second = _sequenceFrom(retainedInput);
  final mutationPeer = _sequenceFrom(retainedInput);
  final consumePeer = _sequenceFrom(retainedInput);
  final discardPeer = _sequenceFrom(retainedInput);
  _verifyIndependentIteratorBacking((
    first: first,
    second: second,
    mutationPeer: mutationPeer,
    consumePeer: consumePeer,
    discardPeer: discardPeer,
  ));
  _verifyCrossInstanceMutation(first, second, retainedInput);
  return _consumeAndDiscardIsolatedInstances(first, second);
}

void _verifyIndependentIteratorBacking(_IteratorIsolationPeers peers) {
  final first = peers.first;
  final second = peers.second;
  final mutationPeer = peers.mutationPeer;
  final consumePeer = peers.consumePeer;
  final discardPeer = peers.discardPeer;
  final firstIterator = first.orderedValues.iterator;
  final secondIterator = second.orderedValues.iterator;

  _expectIteratorValue(firstIterator, 'shared-a');
  _expectIteratorValue(secondIterator, 'shared-a');
  _expectIteratorValue(firstIterator, 'shared-b');
  _expectIteratorValue(secondIterator, 'shared-b');

  mutationPeer.insert(const _Entry('peer-only'), index: 1);
  expect(mutationPeer.remove('shared-c'), isNotNull);
  mutationPeer.clear();
  expect(mutationPeer.consume(), isEmpty);
  expect(consumePeer.consume(), const [
    _Entry('shared-a'),
    _Entry('shared-b'),
    _Entry('shared-c'),
  ]);
  _expectIteratorValue(firstIterator, 'shared-c');
  expect(firstIterator.moveNext(), isFalse);

  discardPeer.discard();
  _expectIteratorValue(secondIterator, 'shared-c');
  expect(secondIterator.moveNext(), isFalse);
}

void _expectIteratorValue(Iterator<_Entry> iterator, String expectedId) {
  expect(iterator.moveNext(), isTrue);
  expect(iterator.current.id, expectedId);
}

void _verifyCrossInstanceMutation(
  IndexedOrderSequence<_Entry, String> first,
  IndexedOrderSequence<_Entry, String> second,
  List<_Entry> retainedInput,
) {
  retainedInput
    ..clear()
    ..add(const _Entry('caller-only'));
  _expectOrder(first, const ['shared-a', 'shared-b', 'shared-c']);
  _expectOrder(second, const ['shared-a', 'shared-b', 'shared-c']);

  first.insert(const _Entry('first-only'), index: 1);
  expect(first.remove('shared-c'), isNotNull);
  _expectOrder(first, const ['shared-a', 'first-only', 'shared-b']);
  _expectOrder(second, const ['shared-a', 'shared-b', 'shared-c']);
  expect(second.locationForId('shared-c')?.rank, 2);
}

List<_Entry> _consumeAndDiscardIsolatedInstances(
  IndexedOrderSequence<_Entry, String> first,
  IndexedOrderSequence<_Entry, String> second,
) {
  first.clear();
  _expectOrder(first, const []);
  _expectOrder(second, const ['shared-a', 'shared-b', 'shared-c']);
  expect(first.consume(), isEmpty);
  _expectOrder(second, const ['shared-a', 'shared-b', 'shared-c']);
  final secondValues = second.orderedValues.toList(growable: false);

  second.discard();
  expect(() => second.valueForId('shared-a'), throwsStateError);
  return secondValues;
}

List<_Entry> _observesWorkBounds() {
  final trace = _buildSupportedSequence();
  _verifySupportedRankWork(trace);
  return _verifyIterationAndFinalFlatten(trace);
}

_SupportedTrace _buildSupportedSequence() {
  final buildWork = _SequenceWork();
  final sequenceInput = List<_Entry>.generate(
    _supportedSize,
    (index) => _Entry('entry-$index'),
    growable: false,
  );
  final oracle = _SequenceOracle.from(
    List<_Entry>.generate(
      _supportedSize,
      (index) => _Entry('entry-$index'),
      growable: false,
    ),
  );
  late IndexedOrderSequence<_Entry, String> sequence;
  IndexedOrderSequence.observeWork(buildWork.record, () {
    sequence = _sequenceFrom(sequenceInput);
  });
  expect(buildWork.count(IndexedOrderSequenceWorkEvent.buildOpen), 1);
  expect(
    buildWork.count(IndexedOrderSequenceWorkEvent.buildInputVisit),
    _supportedSize,
  );
  expect(buildWork.count(IndexedOrderSequenceWorkEvent.buildClose), 1);
  expect(buildWork.count(IndexedOrderSequenceWorkEvent.insertNodeVisit), 0);
  _expectAudit(sequence, expectedCount: _supportedSize);
  return _SupportedTrace(sequence, oracle);
}

void _verifySupportedRankWork(_SupportedTrace trace) {
  final sequence = trace.sequence;
  _expectLookupWork(sequence, 'entry-100000');
  for (var cycle = 0; cycle < 8; cycle += 1) {
    _runSupportedRankCycle(trace, cycle);
  }
}

void _runSupportedRankCycle(_SupportedTrace trace, int cycle) {
  final firstRemovedId = 100000 + cycle * 3;
  _insertAtIndependentRanks(
    trace,
    _Entry('front-$cycle'),
    _InsertionSite.front,
  );
  _expectRemovalWork(trace, 'entry-$firstRemovedId');
  _insertAtIndependentRanks(
    trace,
    _Entry('middle-$cycle'),
    _InsertionSite.middle,
  );
  _expectRemovalWork(trace, 'entry-${firstRemovedId + 1}');
  _insertAtIndependentRanks(trace, _Entry('back-$cycle'), _InsertionSite.back);
  _expectRemovalWork(trace, 'entry-${firstRemovedId + 2}');
}

void _insertAtIndependentRanks(
  _SupportedTrace trace,
  _Entry entry,
  _InsertionSite site,
) {
  final sequence = trace.sequence;
  final oracle = trace.oracle;
  final oracleIndex = _insertionIndex(site, oracle.length);
  oracle.insert(entry, index: oracleIndex);
  final sequenceIndex = _insertionIndex(site, sequence.length);
  _expectBoundedMutationWork(
    sequence,
    IndexedOrderSequenceWorkEvent.insertNodeVisit,
    () => sequence.insert(entry, index: sequenceIndex),
  );
  _expectCurrentOwnerState(trace);
}

int _insertionIndex(_InsertionSite site, int length) => switch (site) {
  _InsertionSite.front => 0,
  _InsertionSite.middle => length ~/ 2,
  _InsertionSite.back => length,
};

void _expectRemovalWork(_SupportedTrace trace, String id) {
  final sequence = trace.sequence;
  final oracle = trace.oracle;
  final expected = oracle.remove(id);
  trace.removedIds.add(id);
  _Entry? actual;
  _expectBoundedMutationWork(
    sequence,
    IndexedOrderSequenceWorkEvent.removeNodeVisit,
    () => actual = sequence.remove(id),
  );
  expect(actual, expected);
  _expectCurrentOwnerState(trace);
}

List<_Entry> _verifyIterationAndFinalFlatten(_SupportedTrace trace) {
  final sequence = trace.sequence;
  final oracle = trace.oracle;
  final iterationWork = _SequenceWork();
  final iterated = IndexedOrderSequence.observeWork(
    iterationWork.record,
    () => sequence.orderedValues.toList(growable: false),
  );
  expect(iterated, oracle.values);
  expect(
    iterationWork.count(IndexedOrderSequenceWorkEvent.orderedIterationVisit),
    oracle.length,
  );

  final flattenWork = _SequenceWork();
  final flattened = IndexedOrderSequence.observeWork(
    flattenWork.record,
    sequence.consume,
  );
  expect(flattened, oracle.values);
  expect(
    flattenWork.count(IndexedOrderSequenceWorkEvent.finalFlattenVisit),
    oracle.length,
  );
  expect(
    flattenWork.count(IndexedOrderSequenceWorkEvent.finalFlattenPublication),
    1,
  );
  expect(() => sequence.consume(), throwsStateError);
  return flattened;
}

IndexedOrderSequence<_Entry, String> _sequenceFrom(Iterable<_Entry> values) {
  return IndexedOrderSequence<_Entry, String>(
    values,
    idOf: (value) => value.id,
  );
}

void _expectExact(
  IndexedOrderSequence<_Entry, String> sequence,
  _SequenceOracle oracle,
) {
  expect(sequence.length, oracle.length);
  expect(sequence.first, oracle.first);
  expect(sequence.last, oracle.last);
  expect(sequence.orderedValues.toList(growable: false), oracle.values);
  for (var index = 0; index < oracle.length; index += 1) {
    final entry = oracle.values[index];
    _expectEntryAt(sequence, entry, index);
  }
  expect(sequence.containsId('missing'), isFalse);
  expect(sequence.valueForId('missing'), isNull);
  expect(sequence.rankOf('missing'), isNull);
  expect(sequence.locationForId('missing'), isNull);
}

void _expectCurrentOwnerState(_SupportedTrace trace) {
  final sequence = trace.sequence;
  final oracle = trace.oracle;
  _expectAudit(sequence, expectedCount: oracle.length);
  _expectExact(sequence, oracle);
  for (final id in trace.removedIds) {
    expect(oracle.containsId(id), isFalse);
    expect(sequence.containsId(id), isFalse);
  }
}

void _expectEntryAt(
  IndexedOrderSequence<_Entry, String> sequence,
  _Entry entry,
  int index,
) {
  expect(sequence.containsId(entry.id), isTrue);
  expect(sequence.valueForId(entry.id), entry);
  expect(sequence.rankOf(entry.id), index);
  final location = sequence.locationForId(entry.id);
  expect(location?.value, entry);
  expect(location?.rank, index);
}

void _expectOrder(
  IndexedOrderSequence<_Entry, String> sequence,
  List<String> ids,
) {
  expect(sequence.orderedValues.map((entry) => entry.id), ids);
  for (var index = 0; index < ids.length; index += 1) {
    expect(sequence.rankOf(ids[index]), index);
  }
}

void _expectAudit(
  IndexedOrderSequence<_Entry, String> sequence, {
  required int expectedCount,
}) {
  final audit = sequence.audit();
  expect(audit.isStrictlyAvlBalanced, isTrue);
  expect(audit.hasExactSubtreeCardinality, isTrue);
  expect(audit.hasExactRanks, isTrue);
  expect(audit.hasLookupParity, isTrue);
  expect(audit.count, expectedCount);
}

void _expectLookupWork(
  IndexedOrderSequence<_Entry, String> sequence,
  String id,
) {
  final work = _SequenceWork();
  IndexedOrderSequence.observeWork(work.record, () {
    expect(sequence.containsId(id), isTrue);
    expect(sequence.locationForId(id)?.value.id, id);
    expect(sequence.rankOf(id), isNotNull);
  });
  expect(work.count(IndexedOrderSequenceWorkEvent.membershipLookup), 3);
  expect(
    work.count(IndexedOrderSequenceWorkEvent.rankNodeVisit),
    lessThanOrEqualTo(sequence.audit().height * 2),
  );
}

void _expectBoundedMutationWork(
  IndexedOrderSequence<_Entry, String> sequence,
  IndexedOrderSequenceWorkEvent nodeEvent,
  void Function() operation,
) {
  final heightBefore = sequence.audit().height;
  final work = _SequenceWork();
  IndexedOrderSequence.observeWork(work.record, operation);
  expect(work.count(nodeEvent), lessThanOrEqualTo(heightBefore + 1));
  expect(
    work.count(IndexedOrderSequenceWorkEvent.rebalance),
    lessThanOrEqualTo(heightBefore + 1),
  );
}

final class _SupportedTrace {
  _SupportedTrace(this.sequence, this.oracle);

  final IndexedOrderSequence<_Entry, String> sequence;
  final _SequenceOracle oracle;
  final Set<String> removedIds = {};
}

enum _InsertionSite { front, middle, back }

@immutable
final class _Entry {
  const _Entry(this.id);

  final String id;

  @override
  bool operator ==(Object other) => other is _Entry && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

final class _SequenceOracle {
  _SequenceOracle.from(Iterable<_Entry> entries) {
    for (final entry in entries) {
      insert(entry);
    }
  }

  _SequenceOracle();

  final List<_Entry> values = [];
  final Map<String, _Entry> _byId = {};

  int get length => values.length;
  bool get isEmpty => values.isEmpty;
  _Entry? get first => values.isEmpty ? null : values.first;
  _Entry? get last => values.isEmpty ? null : values.last;

  bool containsId(String id) => _byId.containsKey(id);

  void insert(_Entry value, {int? index}) {
    if (_byId.containsKey(value.id)) {
      throw ArgumentError.value(
        value.id,
        'id',
        'duplicate indexed sequence id',
      );
    }
    values.insert(_clampIndex(index, values.length), value);
    _byId[value.id] = value;
  }

  _Entry? remove(String id) {
    final value = _byId.remove(id);
    if (value == null) {
      return null;
    }
    values.remove(value);
    return value;
  }

  void clear() {
    values.clear();
    _byId.clear();
  }
}

final class _SequenceWork {
  final _counts = <IndexedOrderSequenceWorkEvent, int>{};

  void record(IndexedOrderSequenceWorkEvent event) {
    _counts.update(event, (count) => count + 1, ifAbsent: () => 1);
  }

  int count(IndexedOrderSequenceWorkEvent event) => _counts[event] ?? 0;
}

int _clampIndex(int? index, int length) {
  final requested = index ?? length;
  if (requested < 0) {
    return 0;
  }
  if (requested > length) {
    return length;
  }
  return requested;
}
