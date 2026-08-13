import 'dart:async';
import 'dart:collection';
import 'dart:math';

import 'package:flutter/foundation.dart' show immutable, visibleForTesting;

// These events are emitted at the semantic sequence-owner seam. Test code
// owns accumulation, so release builds retain neither counters nor telemetry.
@visibleForTesting
enum IndexedOrderSequenceWorkEvent {
  buildOpen,
  buildInputVisit,
  buildClose,
  membershipLookup,
  rankNodeVisit,
  insertNodeVisit,
  removeNodeVisit,
  rebalance,
  orderedIterationVisit,
  finalFlattenVisit,
  finalFlattenPublication,
  discard,
  postClosureAttempt,
}

@immutable
@visibleForTesting
final class IndexedOrderSequenceLocation<T> {
  const IndexedOrderSequenceLocation({required this.value, required this.rank});

  final T value;
  final int rank;
}

// The audit deliberately reports semantic AVL facts without exposing the
// private node layout, rotation shape, or balancing decomposition.
@immutable
@visibleForTesting
final class IndexedOrderSequenceAudit {
  const IndexedOrderSequenceAudit({
    required this.isStrictlyAvlBalanced,
    required this.hasExactSubtreeCardinality,
    required this.hasExactRanks,
    required this.hasLookupParity,
    required this.count,
    required this.height,
  });

  final bool isStrictlyAvlBalanced;
  final bool hasExactSubtreeCardinality;
  final bool hasExactRanks;
  final bool hasLookupParity;
  final int count;
  final int height;
}

// This is a low-level store dependency, intentionally not exported from the
// package surface. Each owner creates its own node and lookup state.
// Navigation, mutation, balancing, lifecycle, and the invariant audit must
// remain together so every node change preserves one internal AVL contract.
// ignore: number-of-methods, response-for-class, weighted-methods-per-class
final class IndexedOrderSequence<T, I> {
  IndexedOrderSequence(Iterable<T> values, {required I Function(T) idOf})
    : _idOf = idOf {
    _build(values);
  }

  static final Object _workZoneKey = Object();

  final I Function(T) _idOf;
  final Map<I, _IndexedOrderNode<T, I>> _nodesById = {};
  _IndexedOrderNode<T, I>? _root;
  var _isOpen = true;

  @visibleForTesting
  static R observeWork<R>(
    void Function(IndexedOrderSequenceWorkEvent event) sink,
    R Function() operation,
  ) {
    return runZoned(operation, zoneValues: {_workZoneKey: sink});
  }

  int get length {
    _ensureOpen();
    return _sizeOf(_root);
  }

  bool get isEmpty => length == 0;

  T? get first {
    _ensureOpen();
    var node = _root;
    while (node != null) {
      final left = node.left;
      if (left == null) {
        return node.value;
      }
      node = left;
    }
    return null;
  }

  T? get last {
    _ensureOpen();
    var node = _root;
    while (node != null) {
      final right = node.right;
      if (right == null) {
        return node.value;
      }
      node = right;
    }
    return null;
  }

  Iterable<T> get orderedValues {
    _ensureOpen();
    return _IndexedOrderIterable<T, I>(this);
  }

  bool containsId(I id) => _nodeForId(id) != null;

  T? valueForId(I id) => _nodeForId(id)?.value;

  int? rankOf(I id) {
    final node = _nodeForId(id);
    return node == null ? null : _rankForNode(node);
  }

  IndexedOrderSequenceLocation<T>? locationForId(I id) {
    final node = _nodeForId(id);
    if (node == null) {
      return null;
    }
    return IndexedOrderSequenceLocation<T>(
      value: node.value,
      rank: _rankForNode(node),
    );
  }

  void insert(T value, {int? index}) {
    _ensureOpen();
    final id = _idOf(value);
    _record(IndexedOrderSequenceWorkEvent.membershipLookup);
    if (_nodesById.containsKey(id)) {
      throw ArgumentError.value(id, 'id', 'duplicate indexed sequence id');
    }

    final node = _IndexedOrderNode<T, I>(value: value, id: id);
    final rank = _clampRank(index, _sizeOf(_root));
    _root = _insertAt(_root, node, rank, parent: null);
    _root?.parent = null;
    _nodesById[id] = node;
  }

  T? remove(I id) {
    final node = _nodeForId(id);
    if (node == null) {
      return null;
    }
    _record(IndexedOrderSequenceWorkEvent.removeNodeVisit);
    final removedValue = node.value;
    final removedId = node.id;
    _nodesById.remove(removedId);

    var nodeToRemove = node;
    final right = node.right;
    if (node.left != null && right != null) {
      var successor = right;
      while (true) {
        final left = successor.left;
        if (left == null) {
          break;
        }
        _record(IndexedOrderSequenceWorkEvent.removeNodeVisit);
        successor = left;
      }
      node
        ..value = successor.value
        ..id = successor.id;
      _nodesById[successor.id] = node;
      nodeToRemove = successor;
    }

    _removePhysicalNode(nodeToRemove);
    return removedValue;
  }

  void clear() {
    _ensureOpen();
    _root = null;
    _nodesById.clear();
  }

  List<T> consume() {
    _ensureOpen();
    final flattened = <T>[];
    _visitInOrder(_root, (node) {
      _record(IndexedOrderSequenceWorkEvent.finalFlattenVisit);
      flattened.add(node.value);
    });
    _close();
    _record(IndexedOrderSequenceWorkEvent.finalFlattenPublication);
    return flattened;
  }

  void discard() {
    _ensureOpen();
    _close();
    _record(IndexedOrderSequenceWorkEvent.discard);
  }

  @visibleForTesting
  IndexedOrderSequenceAudit audit() {
    _ensureOpen();
    final visited = <_IndexedOrderNode<T, I>>{};
    final audit = _auditNode(
      _root,
      parent: null,
      firstRank: 0,
      visited: visited,
    );
    final lookupParity =
        audit.lookupParity &&
        visited.length == _nodesById.length &&
        visited.every((node) => identical(_nodesById[node.id], node));
    return IndexedOrderSequenceAudit(
      isStrictlyAvlBalanced: audit.isStrictlyAvlBalanced,
      hasExactSubtreeCardinality: audit.hasExactSubtreeCardinality,
      hasExactRanks: audit.hasExactRanks,
      hasLookupParity: lookupParity,
      count: audit.count,
      height: audit.height,
    );
  }

  void _build(Iterable<T> values) {
    _record(IndexedOrderSequenceWorkEvent.buildOpen);
    try {
      final entries = <T>[];
      final admittedIds = <I>{};
      for (final value in values) {
        _record(IndexedOrderSequenceWorkEvent.buildInputVisit);
        final id = _idOf(value);
        if (!admittedIds.add(id)) {
          throw ArgumentError.value(id, 'id', 'duplicate indexed sequence id');
        }
        entries.add(value);
      }
      _root = _buildBalanced(entries, 0, entries.length, parent: null);
    } finally {
      _record(IndexedOrderSequenceWorkEvent.buildClose);
    }
  }

  _IndexedOrderNode<T, I>? _buildBalanced(
    List<T> entries,
    int start,
    int end, {
    required _IndexedOrderNode<T, I>? parent,
  }) {
    if (start == end) {
      return null;
    }
    final middle = start + (end - start) ~/ 2;
    final value = entries[middle];
    final node = _IndexedOrderNode<T, I>(value: value, id: _idOf(value));
    node.parent = parent;
    _nodesById[node.id] = node;
    node.left = _buildBalanced(entries, start, middle, parent: node);
    node.right = _buildBalanced(entries, middle + 1, end, parent: node);
    _update(node);
    return node;
  }

  _IndexedOrderNode<T, I> _insertAt(
    _IndexedOrderNode<T, I>? root,
    _IndexedOrderNode<T, I> inserted,
    int rank, {
    required _IndexedOrderNode<T, I>? parent,
  }) {
    if (root == null) {
      inserted.parent = parent;
      return inserted;
    }
    _record(IndexedOrderSequenceWorkEvent.insertNodeVisit);
    final leftSize = _sizeOf(root.left);
    if (rank <= leftSize) {
      root.left = _insertAt(root.left, inserted, rank, parent: root);
    } else {
      root.right = _insertAt(
        root.right,
        inserted,
        rank - leftSize - 1,
        parent: root,
      );
    }
    return _rebalance(root);
  }

  void _removePhysicalNode(_IndexedOrderNode<T, I> node) {
    final replacement = node.left ?? node.right;
    final parent = node.parent;
    if (replacement != null) {
      replacement.parent = parent;
    }
    if (parent == null) {
      _root = replacement;
      _root?.parent = null;
      return;
    }
    if (identical(parent.left, node)) {
      parent.left = replacement;
    } else {
      parent.right = replacement;
    }
    _rebalanceUpwards(parent);
  }

  void _rebalanceUpwards(_IndexedOrderNode<T, I> start) {
    _IndexedOrderNode<T, I>? current = start;
    while (current != null) {
      final parent = current.parent;
      final rebalanced = _rebalance(current);
      if (parent == null) {
        _root = rebalanced;
        rebalanced.parent = null;
      } else if (identical(parent.left, current)) {
        parent.left = rebalanced;
        rebalanced.parent = parent;
      } else {
        parent.right = rebalanced;
        rebalanced.parent = parent;
      }
      current = parent;
    }
  }

  _IndexedOrderNode<T, I> _rebalance(_IndexedOrderNode<T, I> node) {
    _record(IndexedOrderSequenceWorkEvent.rebalance);
    _update(node);
    final balance = _heightOf(node.left) - _heightOf(node.right);
    if (balance > 1) {
      final left = node.left;
      if (left == null) {
        throw StateError('IndexedOrderSequence lost its left AVL branch.');
      }
      if (_heightOf(left.left) < _heightOf(left.right)) {
        node.left = _rotateLeft(left);
      }
      return _rotateRight(node);
    }
    if (balance < -1) {
      final right = node.right;
      if (right == null) {
        throw StateError('IndexedOrderSequence lost its right AVL branch.');
      }
      if (_heightOf(right.right) < _heightOf(right.left)) {
        node.right = _rotateRight(right);
      }
      return _rotateLeft(node);
    }
    return node;
  }

  _IndexedOrderNode<T, I> _rotateLeft(_IndexedOrderNode<T, I> node) {
    final pivot = node.right;
    if (pivot == null) {
      throw StateError(
        'IndexedOrderSequence cannot rotate left without a pivot.',
      );
    }
    final transfer = pivot.left;
    final parent = node.parent;
    pivot
      ..parent = parent
      ..left = node;
    node
      ..parent = pivot
      ..right = transfer;
    transfer?.parent = node;
    _update(node);
    _update(pivot);
    return pivot;
  }

  _IndexedOrderNode<T, I> _rotateRight(_IndexedOrderNode<T, I> node) {
    final pivot = node.left;
    if (pivot == null) {
      throw StateError(
        'IndexedOrderSequence cannot rotate right without a pivot.',
      );
    }
    final transfer = pivot.right;
    final parent = node.parent;
    pivot
      ..parent = parent
      ..right = node;
    node
      ..parent = pivot
      ..left = transfer;
    transfer?.parent = node;
    _update(node);
    _update(pivot);
    return pivot;
  }

  _IndexedOrderNode<T, I>? _nodeForId(I id) {
    _ensureOpen();
    _record(IndexedOrderSequenceWorkEvent.membershipLookup);
    return _nodesById[id];
  }

  int _rankForNode(_IndexedOrderNode<T, I> node) {
    var rank = _sizeOf(node.left);
    _IndexedOrderNode<T, I>? current = node;
    while (current != null) {
      _record(IndexedOrderSequenceWorkEvent.rankNodeVisit);
      final parent = current.parent;
      if (parent != null && identical(parent.right, current)) {
        rank += _sizeOf(parent.left) + 1;
      }
      current = parent;
    }
    return rank;
  }

  int _rankForNodeUnchecked(_IndexedOrderNode<T, I> node) {
    var rank = _sizeOf(node.left);
    _IndexedOrderNode<T, I>? current = node;
    while (current != null) {
      final parent = current.parent;
      if (parent != null && identical(parent.right, current)) {
        rank += _sizeOf(parent.left) + 1;
      }
      current = parent;
    }
    return rank;
  }

  void _visitInOrder(
    _IndexedOrderNode<T, I>? node,
    void Function(_IndexedOrderNode<T, I> node) visit,
  ) {
    if (node == null) {
      return;
    }
    _visitInOrder(node.left, visit);
    visit(node);
    _visitInOrder(node.right, visit);
  }

  // One traversal cross-checks the coupled balance, cardinality, rank, parent,
  // and lookup claims; splitting it would repeat traversal or hide a mismatch.
  // ignore: cyclomatic-complexity, halstead-volume
  _IndexedOrderAuditState _auditNode(
    _IndexedOrderNode<T, I>? node, {
    required _IndexedOrderNode<T, I>? parent,
    required int firstRank,
    required Set<_IndexedOrderNode<T, I>> visited,
  }) {
    if (node == null) {
      return const _IndexedOrderAuditState.empty();
    }
    visited.add(node);
    final left = _auditNode(
      node.left,
      parent: node,
      firstRank: firstRank,
      visited: visited,
    );
    final rank = firstRank + left.count;
    final right = _auditNode(
      node.right,
      parent: node,
      firstRank: rank + 1,
      visited: visited,
    );
    final count = left.count + right.count + 1;
    final height = max(left.height, right.height) + 1;
    return _IndexedOrderAuditState(
      count: count,
      height: height,
      isStrictlyAvlBalanced:
          left.isStrictlyAvlBalanced &&
          right.isStrictlyAvlBalanced &&
          (left.height - right.height).abs() <= 1 &&
          node.height == height,
      hasExactSubtreeCardinality:
          left.hasExactSubtreeCardinality &&
          right.hasExactSubtreeCardinality &&
          node.size == count,
      hasExactRanks:
          left.hasExactRanks &&
          right.hasExactRanks &&
          identical(node.parent, parent) &&
          _rankForNodeUnchecked(node) == rank,
      lookupParity: left.lookupParity && right.lookupParity,
    );
  }

  void _close() {
    _isOpen = false;
    _root = null;
    _nodesById.clear();
  }

  void _ensureOpen() {
    if (_isOpen) {
      return;
    }
    _record(IndexedOrderSequenceWorkEvent.postClosureAttempt);
    throw StateError('IndexedOrderSequence was already consumed.');
  }

  void _record(IndexedOrderSequenceWorkEvent event) {
    assert(() {
      final sink = Zone.current[_workZoneKey];
      if (sink is void Function(IndexedOrderSequenceWorkEvent)) {
        sink(event);
      }
      return true;
    }(), 'indexed order sequence work observation failed');
  }
}

final class _IndexedOrderNode<T, I> {
  _IndexedOrderNode({required this.value, required this.id});

  T value;
  I id;
  _IndexedOrderNode<T, I>? parent;
  _IndexedOrderNode<T, I>? left;
  _IndexedOrderNode<T, I>? right;
  int height = 1;
  int size = 1;
}

final class _IndexedOrderAuditState {
  const _IndexedOrderAuditState({
    required this.count,
    required this.height,
    required this.isStrictlyAvlBalanced,
    required this.hasExactSubtreeCardinality,
    required this.hasExactRanks,
    required this.lookupParity,
  });

  const _IndexedOrderAuditState.empty()
    : count = 0,
      height = 0,
      isStrictlyAvlBalanced = true,
      hasExactSubtreeCardinality = true,
      hasExactRanks = true,
      lookupParity = true;

  final int count;
  final int height;
  final bool isStrictlyAvlBalanced;
  final bool hasExactSubtreeCardinality;
  final bool hasExactRanks;
  final bool lookupParity;
}

final class _IndexedOrderIterable<T, I> extends IterableBase<T> {
  _IndexedOrderIterable(this._sequence);

  final IndexedOrderSequence<T, I> _sequence;

  @override
  Iterator<T> get iterator => _IndexedOrderIterator<T, I>(_sequence);
}

final class _IndexedOrderIterator<T, I> implements Iterator<T> {
  _IndexedOrderIterator(this._sequence) {
    _sequence._ensureOpen();
    _pushLeft(_sequence._root);
  }

  final IndexedOrderSequence<T, I> _sequence;
  final List<_IndexedOrderNode<T, I>> _stack = [];
  T? _current;

  @override
  T get current => _current as T;

  @override
  bool moveNext() {
    _sequence._ensureOpen();
    if (_stack.isEmpty) {
      return false;
    }
    final node = _stack.removeLast();
    _current = node.value;
    _pushLeft(node.right);
    _sequence._record(IndexedOrderSequenceWorkEvent.orderedIterationVisit);
    return true;
  }

  void _pushLeft(_IndexedOrderNode<T, I>? node) {
    var current = node;
    while (current != null) {
      _stack.add(current);
      current = current.left;
    }
  }
}

int _clampRank(int? requestedRank, int length) {
  final rank = requestedRank ?? length;
  if (rank < 0) {
    return 0;
  }
  if (rank > length) {
    return length;
  }
  return rank;
}

int _heightOf<T, I>(_IndexedOrderNode<T, I>? node) => node?.height ?? 0;

int _sizeOf<T, I>(_IndexedOrderNode<T, I>? node) => node?.size ?? 0;

void _update<T, I>(_IndexedOrderNode<T, I> node) {
  node
    ..height = max(_heightOf(node.left), _heightOf(node.right)) + 1
    ..size = _sizeOf(node.left) + _sizeOf(node.right) + 1;
}
