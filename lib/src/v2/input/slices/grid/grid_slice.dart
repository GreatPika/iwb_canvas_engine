import '../../../../core/scene.dart';
import '../../../model/document.dart';

class V2GridSlice {
  bool writeNormalizeGrid({required Scene scene}) {
    return txnNormalizeGrid(scene);
  }
}
