import 'package:analyzer/diagnostic/diagnostic.dart';
import 'package:analyzer/source/line_info.dart';

List<String> formatCloneParseErrors(
  String filePath,
  List<Diagnostic> errors,
  LineInfo lineInfo,
) {
  if (errors.isEmpty) {
    return const <String>[];
  }

  return errors
      .map((error) {
        final location = lineInfo.getLocation(error.offset);
        return 'Parse error in $filePath:${location.lineNumber}:${location.columnNumber} '
            '[${error.diagnosticCode.lowerCaseName}]: ${error.message}';
      })
      .toList(growable: false);
}
