import 'package:flutter/foundation.dart';

import 'canvas_contract_limits.dart';
import 'canvas_value_validators.dart';

@immutable
/// Public API v1 declaration for [CanvasElementId].
final class CanvasElementId {
  factory CanvasElementId(String value) {
    return CanvasElementId._(
      validateCanvasIdValue(
        value,
        path: 'element.id',
        maxLength: canvasMaxElementIdLength,
      ),
    );
  }

  const CanvasElementId._(this.value);
  final String value;

  @override
  bool operator ==(Object other) {
    return other is CanvasElementId && other.value == value;
  }

  @override
  int get hashCode => value.hashCode;
}

@immutable
/// Public API v1 declaration for [CanvasLayerId].
final class CanvasLayerId {
  factory CanvasLayerId(String value) {
    return CanvasLayerId._(
      validateCanvasIdValue(
        value,
        path: 'layer.id',
        maxLength: canvasMaxLayerIdLength,
      ),
    );
  }

  const CanvasLayerId._(this.value);
  final String value;

  @override
  bool operator ==(Object other) {
    return other is CanvasLayerId && other.value == value;
  }

  @override
  int get hashCode => value.hashCode;
}

@immutable
/// Public API v1 declaration for [CanvasResourceId].
final class CanvasResourceId {
  factory CanvasResourceId(String value) {
    return CanvasResourceId._(
      validateCanvasIdValue(
        value,
        path: 'resource.id',
        maxLength: canvasMaxResourceIdLength,
      ),
    );
  }

  const CanvasResourceId._(this.value);
  final String value;

  @override
  bool operator ==(Object other) {
    return other is CanvasResourceId && other.value == value;
  }

  @override
  int get hashCode => value.hashCode;
}

@immutable
/// Public API v1 declaration for [CanvasActionId].
final class CanvasActionId {
  factory CanvasActionId(String value) {
    return CanvasActionId._(
      validateCanvasIdValue(
        value,
        path: 'action.id',
        maxLength: canvasMaxActionIdLength,
      ),
    );
  }

  const CanvasActionId._(this.value);
  final String value;

  @override
  bool operator ==(Object other) {
    return other is CanvasActionId && other.value == value;
  }

  @override
  int get hashCode => value.hashCode;
}

@immutable
/// Public API v1 declaration for [CanvasInteractionRequestId].
final class CanvasInteractionRequestId {
  factory CanvasInteractionRequestId(String value) {
    return CanvasInteractionRequestId._(
      validateCanvasIdValue(
        value,
        path: 'interactionRequest.id',
        maxLength: canvasMaxInteractionRequestIdLength,
      ),
    );
  }

  const CanvasInteractionRequestId._(this.value);
  final String value;

  @override
  bool operator ==(Object other) {
    return other is CanvasInteractionRequestId && other.value == value;
  }

  @override
  int get hashCode => value.hashCode;
}
