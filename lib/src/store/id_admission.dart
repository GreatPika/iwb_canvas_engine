// Store-private immutable ID admission keeps prepared Store installation to
// backing swaps. A radix path is bounded by the validated ID length, never by
// unrelated document rows or the number of earlier sparse commits.

typedef IdAdmissionEnumerator = void Function(void Function(String) accept);
typedef IdAdmissionWorkRecorder =
    void Function(
      IdAdmissionWorkPhase phase,
      IdAdmissionWorkKind kind, {
      String? subject,
    });

enum IdAdmissionWorkPhase { reset, acceptedAdmission, generation }

enum IdAdmissionWorkKind {
  inputVisit,
  sparseLedgerVisit,
  cursorProbe,
  collision,
  advance,
  candidateObservation,
  reservation,
}

final class StoreIdAdmission {
  const StoreIdAdmission._({
    required this.prefix,
    required _IdAdmissionMembership reserved,
    required int next,
    required IdAdmissionWorkRecorder record,
  }) : _reserved = reserved,
       _next = next,
       _record = record;

  // ignore: halstead-volume, source-lines-of-code, reason: One callback gate closes seed ownership before normalization.
  factory StoreIdAdmission.fromEnumerated({
    required String prefix,
    required IdAdmissionEnumerator enumerate,
    required IdAdmissionWorkRecorder record,
  }) {
    var next = 0;
    var candidate = '$prefix$next';
    var ordered = true;
    var open = true;
    final seed = <String>{};
    try {
      enumerate((id) {
        if (!open) {
          throw StateError('ID admission bootstrap is closed.');
        }
        assert(() {
          record(IdAdmissionWorkPhase.reset, IdAdmissionWorkKind.inputVisit);
          return true;
        }(), 'id admission work observation failed');
        if (ordered && id == candidate) {
          assert(() {
            record(IdAdmissionWorkPhase.reset, IdAdmissionWorkKind.cursorProbe);
            record(IdAdmissionWorkPhase.reset, IdAdmissionWorkKind.collision);
            record(IdAdmissionWorkPhase.reset, IdAdmissionWorkKind.advance);
            return true;
          }(), 'id admission work observation failed');
          next += 1;
          candidate = '$prefix$next';
        } else if (id.startsWith(prefix)) {
          ordered = false;
          seed.add(id);
        }
      });
    } finally {
      open = false;
    }
    final reserved = _IdAdmissionMembership.seeded(seed);
    final normalized = _normalizedNext(
      prefix: prefix,
      reserved: reserved,
      next: next,
      phase: IdAdmissionWorkPhase.reset,
      record: record,
    );
    return StoreIdAdmission._(
      prefix: prefix,
      reserved: normalized - next == seed.length
          ? const _IdAdmissionMembership.empty()
          : reserved,
      next: normalized,
      record: record,
    );
  }

  final String prefix;
  final _IdAdmissionMembership _reserved;
  final int _next;
  final IdAdmissionWorkRecorder _record;

  String observeCandidate() {
    assert(() {
      _record(
        IdAdmissionWorkPhase.generation,
        IdAdmissionWorkKind.candidateObservation,
      );
      return true;
    }(), 'id admission work observation failed');
    return '$prefix$_next';
  }

  ({StoreIdAdmission admission, String value}) reserveCandidate(
    String candidate,
  ) {
    if (candidate != '$prefix$_next') {
      throw StateError('Id admission candidate is stale.');
    }
    assert(() {
      _record(IdAdmissionWorkPhase.generation, IdAdmissionWorkKind.reservation);
      return true;
    }(), 'id admission work observation failed');
    // The cursor is monotonic until Store replacement/reset. Once this exact
    // candidate advances it can never be queried again, so retaining it in the
    // generic membership radix only allocates a node without affecting lookup.
    final reserved = _reserved;
    assert(() {
      _record(IdAdmissionWorkPhase.generation, IdAdmissionWorkKind.advance);
      return true;
    }(), 'id admission work observation failed');
    final next = _normalizedNext(
      prefix: prefix,
      reserved: reserved,
      next: _next + 1,
      phase: IdAdmissionWorkPhase.generation,
      record: _record,
    );
    return (
      admission: StoreIdAdmission._(
        prefix: prefix,
        reserved: reserved,
        next: next,
        record: _record,
      ),
      value: candidate,
    );
  }

  StoreIdAdmission admitComplete(IdAdmissionEnumerator enumerate) {
    return _admit(
      phase: IdAdmissionWorkPhase.acceptedAdmission,
      values: enumerate,
    );
  }

  StoreIdAdmission admitLedger(Iterable<String> ids) {
    return _admit(
      phase: IdAdmissionWorkPhase.acceptedAdmission,
      values: (accept) {
        for (final id in ids) {
          assert(() {
            _record(
              IdAdmissionWorkPhase.acceptedAdmission,
              IdAdmissionWorkKind.sparseLedgerVisit,
              subject: id,
            );
            return true;
          }(), 'id admission work observation failed');
          accept(id);
        }
      },
    );
  }

  StoreIdAdmission _admit({
    required IdAdmissionWorkPhase phase,
    required IdAdmissionEnumerator values,
  }) {
    final currentCandidate = '$prefix$_next';
    var currentCandidateAdmitted = false;
    var reserved = _reserved;
    values((id) {
      assert(() {
        _record(phase, IdAdmissionWorkKind.inputVisit);
        return true;
      }(), 'id admission work observation failed');
      if (id == currentCandidate) {
        currentCandidateAdmitted = true;
      } else if (id.startsWith(prefix) &&
          _isAtOrBeyondCandidate(id, currentCandidate)) {
        reserved = reserved.add(id);
      }
    });
    final next = currentCandidateAdmitted
        ? _normalizedNextAfterCurrentCandidate(
            prefix: prefix,
            reserved: reserved,
            next: _next,
            phase: phase,
            record: _record,
          )
        : _next;
    return identical(reserved, _reserved) && next == _next
        ? this
        : StoreIdAdmission._(
            prefix: prefix,
            reserved: reserved,
            next: next,
            record: _record,
          );
  }
}

// These inputs are one inseparable cursor-normalization fact; a parameter DTO
// would obscure which owner data is examined before the assignment-only tail.
// ignore: number-of-parameters
int _normalizedNextAfterCurrentCandidate({
  required String prefix,
  required _IdAdmissionMembership reserved,
  required int next,
  required IdAdmissionWorkPhase phase,
  required IdAdmissionWorkRecorder record,
}) {
  assert(() {
    record(phase, IdAdmissionWorkKind.cursorProbe);
    record(phase, IdAdmissionWorkKind.collision);
    record(phase, IdAdmissionWorkKind.advance);
    return true;
  }(), 'id admission work observation failed');
  return _normalizedNext(
    prefix: prefix,
    reserved: reserved,
    next: next + 1,
    phase: phase,
    record: record,
  );
}

/// The three Store-owned immutable admission backings transferred together
/// with a prepared document. This is internal Store state, not a second ID
/// authority or a retained reservation history.
final class StoreIdAdmissions {
  const StoreIdAdmissions({
    required this.elements,
    required this.layers,
    required this.resources,
  });

  final StoreIdAdmission elements;
  final StoreIdAdmission layers;
  final StoreIdAdmission resources;
}

// These inputs are one inseparable cursor-normalization fact; a parameter DTO
// would obscure which owner data is examined before the assignment-only tail.
// ignore: number-of-parameters
int _normalizedNext({
  required String prefix,
  required _IdAdmissionMembership reserved,
  required int next,
  required IdAdmissionWorkPhase phase,
  required IdAdmissionWorkRecorder record,
}) {
  var candidateIndex = next;
  while (true) {
    final candidate = '$prefix$candidateIndex';
    assert(() {
      record(phase, IdAdmissionWorkKind.cursorProbe);
      return true;
    }(), 'id admission work observation failed');
    if (!reserved.contains(candidate)) {
      return candidateIndex;
    }
    assert(() {
      record(phase, IdAdmissionWorkKind.collision);
      return true;
    }(), 'id admission work observation failed');
    candidateIndex += 1;
    assert(() {
      record(phase, IdAdmissionWorkKind.advance);
      return true;
    }(), 'id admission work observation failed');
  }
}

// Generated decimal suffixes are monotonic by suffix length then lexical order.
// IDs behind the current candidate can never be queried again before reset, so
// retaining them would only grow the immutable sparse membership backing.
bool _isAtOrBeyondCandidate(String id, String candidate) {
  if (id.length != candidate.length) {
    return id.length > candidate.length;
  }
  return id.compareTo(candidate) >= 0;
}

/// Immutable binary Patricia membership with exact UTF-16 string equality.
///
/// Each UTF-16 unit occupies a local 17-bit lane: `0` is the terminal and a
/// real unit is `codeUnit + 1`. This makes a terminal distinct from every
/// valid code unit and preserves prefix and surrogate-pair identity.
final class _IdAdmissionMembership {
  const _IdAdmissionMembership.empty() : _root = null, _seed = const {};

  const _IdAdmissionMembership._(this._root, this._seed);

  factory _IdAdmissionMembership.seeded(Set<String> seed) =>
      _IdAdmissionMembership._(null, seed);

  final _PatriciaNode? _root;
  final Set<String> _seed;

  bool contains(String value) {
    if (_seed.contains(value)) {
      return true;
    }
    var node = _root;
    if (node == null) {
      return false;
    }
    while (node is _PatriciaBranch) {
      node = _bitAt(value, node.bit) ? node.one : node.zero;
    }
    return (node as _PatriciaLeaf).value == value;
  }

  // Path-copy insertion stays together so both copied directions are audited
  // against the one differing bit without mutable published nodes.
  // ignore: halstead-volume
  _IdAdmissionMembership add(String value) {
    if (_seed.contains(value)) {
      return this;
    }
    final root = _root;
    if (root == null) {
      return _IdAdmissionMembership._(_PatriciaLeaf(value), _seed);
    }
    final leaf = _findLeaf(root, value);
    if (leaf.value == value) {
      return this;
    }
    final differingBit = _firstDifferingBit(value, leaf.value);
    final branches = <_PatriciaBranch>[];
    final directions = <bool>[];
    var node = root;
    while (node is _PatriciaBranch) {
      final branch = node;
      if (branch.bit >= differingBit) {
        break;
      }
      final oneDirection = _bitAt(value, branch.bit);
      branches.add(branch);
      directions.add(oneDirection);
      node = oneDirection ? branch.one : branch.zero;
    }
    final insertedLeaf = _PatriciaLeaf(value);
    _PatriciaNode rebuilt = _bitAt(value, differingBit)
        ? _PatriciaBranch(differingBit, node, insertedLeaf)
        : _PatriciaBranch(differingBit, insertedLeaf, node);
    for (var index = branches.length - 1; index >= 0; index -= 1) {
      final branch = branches[index];
      rebuilt = directions[index]
          ? _PatriciaBranch(branch.bit, branch.zero, rebuilt)
          : _PatriciaBranch(branch.bit, rebuilt, branch.one);
    }
    return _IdAdmissionMembership._(rebuilt, _seed);
  }
}

sealed class _PatriciaNode {
  const _PatriciaNode();
}

final class _PatriciaLeaf extends _PatriciaNode {
  const _PatriciaLeaf(this.value);

  final String value;
}

final class _PatriciaBranch extends _PatriciaNode {
  const _PatriciaBranch(this.bit, this.zero, this.one);

  final int bit;
  final _PatriciaNode zero;
  final _PatriciaNode one;
}

_PatriciaLeaf _findLeaf(_PatriciaNode root, String value) {
  var node = root;
  while (node is _PatriciaBranch) {
    node = _bitAt(value, node.bit) ? node.one : node.zero;
  }
  return node as _PatriciaLeaf;
}

int _firstDifferingBit(String left, String right) {
  final unitLength =
      (left.length > right.length ? left.length : right.length) + 1;
  for (var unitIndex = 0; unitIndex < unitLength; unitIndex += 1) {
    final difference =
        _encodedUnit(left, unitIndex) ^ _encodedUnit(right, unitIndex);
    if (difference == 0) {
      continue;
    }
    return unitIndex * 17 + 17 - difference.bitLength;
  }
  throw StateError('Distinct ID strings had no differing encoded unit.');
}

bool _bitAt(String value, int bit) {
  final unitIndex = bit ~/ 17;
  final localBit = bit % 17;
  return (_encodedUnit(value, unitIndex) & (1 << (16 - localBit))) != 0;
}

int _encodedUnit(String value, int unitIndex) {
  return unitIndex < value.length ? value.codeUnitAt(unitIndex) + 1 : 0;
}
