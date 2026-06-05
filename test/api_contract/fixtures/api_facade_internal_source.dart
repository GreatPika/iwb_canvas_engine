import 'package:flutter/foundation.dart';

@internal
void leakedInternalHelper() => _ignoreInternalHelperCall();

int _ignoreInternalHelperCall() => 0;

final class PublicFixtureType {}
