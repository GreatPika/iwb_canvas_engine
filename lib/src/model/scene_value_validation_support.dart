typedef SceneValidationField<T> = ({T value, String field});

typedef SceneValidationErrorReporter =
    Never Function({
      required Object? value,
      required String field,
      required String message,
    });

typedef SceneValueValidator<T> =
    void Function(
      T value, {
      required String field,
      required SceneValidationErrorReporter onError,
    });

void sceneValidateFields<T>(
  List<SceneValidationField<T>> values, {
  required SceneValidationErrorReporter onError,
  required SceneValueValidator<T> validateValue,
}) {
  for (final entry in values) {
    validateValue(entry.value, field: entry.field, onError: onError);
  }
}

void sceneValidateOptionalValue<T>(
  T? value, {
  required String field,
  required SceneValidationErrorReporter onError,
  required SceneValueValidator<T> validateValue,
}) {
  if (value == null) return;
  validateValue(value, field: field, onError: onError);
}

void sceneValidateArgumentBoundary({
  required String field,
  required Object? value,
  required SceneValidationErrorReporter onError,
  required void Function() validate,
}) {
  try {
    validate();
  } on ArgumentError catch (error) {
    final argumentName = error.name;
    final reportedField = argumentName is String ? argumentName : field;
    sceneValidationFail(
      onError: onError,
      value: value,
      field: reportedField,
      message: sceneMessageFromArgumentError(error),
    );
  }
}

Never sceneValidationFail({
  required SceneValidationErrorReporter onError,
  required Object? value,
  required String field,
  required String message,
}) {
  return onError(value: value, field: field, message: message);
}

String sceneMessageFromArgumentError(ArgumentError error) {
  final message = error.message;
  if (message is String && message.isNotEmpty) {
    final first = message[0];
    final lowerFirst = first.toLowerCase();
    if (first == lowerFirst) {
      return message;
    }
    return '$lowerFirst${message.substring(1)}';
  }
  return 'is invalid.';
}
