import 'package:test/test.dart';

Matcher diagnostic({required String category, required String detail}) {
  return allOf(contains('$category violation:'), contains(detail));
}
