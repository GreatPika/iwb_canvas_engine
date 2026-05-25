import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

typedef PublicFlutterWidgetFactory = Widget Function(BuildContext context);

class PublicFlutterBarrelHolder {
  const PublicFlutterBarrelHolder({
    required this.key,
    required this.listenable,
  });

  final Key key;
  final ValueListenable<Object?> listenable;
}
