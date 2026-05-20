import 'public_type_reference_hidden_bound.dart';

typedef PublicBoundedAlias<T extends HiddenPublicBound> = T Function(T value);

typedef ApprovedBoundedAlias<T extends ApprovedPublicBound> =
    T Function(T value);

extension PublicStringAccessors on String {
  int get publicLength => length;
}

class ApprovedPublicBound {}
