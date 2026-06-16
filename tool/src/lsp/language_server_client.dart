import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

// The LSP client owns one protocol session; splitting request, notification,
// lifecycle, and stream parsing would hide the state that keeps ids ordered.
// ignore: number-of-methods, response-for-class, weighted-methods-per-class
final class LanguageServerClient {
  LanguageServerClient._({
    required Process process,
    required this.root,
    required this.rootUri,
  }) : _process = process {
    _stdoutSubscription = _process.stdout.listen(_handleStdoutChunk);
    _stderrSubscription = _process.stderr
        .transform(utf8.decoder)
        .listen(_stderrBuffer.write);
  }

  static Future<LanguageServerClient> start({Directory? root}) async {
    final workingRoot = Directory((root ?? Directory.current).absolute.path);
    final process = await Process.start('dart', const <String>[
      'language-server',
      '--protocol=lsp',
      '--client-id=iwb_canvas_engine',
      '--client-version=1',
    ], workingDirectory: workingRoot.path);
    final client = LanguageServerClient._(
      process: process,
      root: workingRoot,
      rootUri: workingRoot.uri.toString(),
    );
    await client._initialize();
    return client;
  }

  final Process _process;
  final Directory root;
  final String rootUri;
  final BytesBuilder _stdoutBuffer = BytesBuilder(copy: false);
  final StringBuffer _stderrBuffer = StringBuffer();
  final Map<int, Completer<Object?>> _pending = <int, Completer<Object?>>{};
  late final StreamSubscription<List<int>> _stdoutSubscription;
  late final StreamSubscription<String> _stderrSubscription;

  int _nextRequestId = 1;
  bool _closed = false;
  final Set<String> _openedFiles = <String>{};

  Future<void> _initialize() async {
    await request('initialize', <String, Object?>{
      'processId': pid,
      'rootUri': rootUri,
      'workspaceFolders': <Object?>[
        <String, Object?>{
          'uri': rootUri,
          'name': root.uri.pathSegments.isEmpty
              ? root.path
              : root.uri.pathSegments.last,
        },
      ],
      'capabilities': <String, Object?>{
        'workspace': <String, Object?>{
          'workspaceFolders': true,
          'symbol': <String, Object?>{},
        },
        'textDocument': <String, Object?>{
          'references': <String, Object?>{},
          'definition': <String, Object?>{},
          'implementation': <String, Object?>{},
          'documentSymbol': <String, Object?>{},
          'callHierarchy': <String, Object?>{},
          'typeHierarchy': <String, Object?>{},
        },
      },
    });
    notify('initialized', const <String, Object?>{});
  }

  Future<void> close() async {
    if (_closed) {
      return;
    }
    notify('exit', null);
    _closed = true;
    await _stdoutSubscription.cancel();
    await _stderrSubscription.cancel();
    _process.kill();
  }

  Uri resolveUri(String repoRelativePath) {
    return Uri.file('${root.path}${Platform.pathSeparator}$repoRelativePath');
  }

  String toRepoRelativePath(String uriString) {
    final uri = Uri.parse(uriString);
    final filePath = uri.toFilePath(windows: Platform.isWindows);
    final rootPrefix = '${root.path}${Platform.pathSeparator}'.replaceAll(
      '\\',
      '/',
    );
    final normalized = filePath.replaceAll('\\', '/');
    if (normalized.startsWith(rootPrefix)) {
      return normalized.replaceFirst(rootPrefix, '');
    }
    return normalized;
  }

  bool isRepoUri(String uriString) {
    final normalizedRoot = root.path.replaceAll('\\', '/');
    final filePath = Uri.parse(
      uriString,
    ).toFilePath(windows: Platform.isWindows);
    final normalizedFilePath = filePath.replaceAll('\\', '/');
    return normalizedFilePath == normalizedRoot ||
        normalizedFilePath.startsWith('$normalizedRoot/');
  }

  Future<void> openFile(String repoRelativePath) async {
    final normalized = repoRelativePath.replaceAll('\\', '/');
    if (_openedFiles.contains(normalized)) {
      return;
    }
    final file = File('${root.path}${Platform.pathSeparator}$normalized');
    final text = file.readAsStringSync();
    notify('textDocument/didOpen', <String, Object?>{
      'textDocument': <String, Object?>{
        'uri': resolveUri(normalized).toString(),
        'languageId': 'dart',
        'version': 1,
        'text': text,
      },
    });
    _openedFiles.add(normalized);
  }

  Future<Object?> request(String method, Object? params) {
    if (_closed) {
      throw StateError('Language server client is closed.');
    }
    final id = _nextRequestId++;
    final completer = Completer<Object?>();
    _pending[id] = completer;
    _writeMessage(<String, Object?>{
      'jsonrpc': '2.0',
      'id': id,
      'method': method,
      'params': params,
    });
    return completer.future;
  }

  Future<Object?> requestWithFileRetry(
    String method,
    Object? params, {
    Duration retryDelay = const Duration(milliseconds: 300),
    int retryCount = 4,
  }) async {
    for (var attempt = 0; ; attempt++) {
      try {
        return await request(method, params);
      } on LanguageServerError catch (error) {
        final isRetryable =
            error.code == -32007 &&
            error.message.contains('File is not being analyzed');
        if (!isRetryable || attempt >= retryCount) {
          rethrow;
        }
        await Future<void>.delayed(retryDelay);
      }
    }
  }

  void notify(String method, Object? params) {
    if (_closed) {
      throw StateError('Language server client is closed.');
    }
    _writeMessage(<String, Object?>{
      'jsonrpc': '2.0',
      'method': method,
      'params': params,
    });
  }

  String get stderrText => _stderrBuffer.toString();

  void _writeMessage(Map<String, Object?> message) {
    final json = jsonEncode(message);
    final header = 'Content-Length: ${utf8.encode(json).length}\r\n\r\n';
    _process.stdin.write(header);
    _process.stdin.write(json);
  }

  void _handleStdoutChunk(List<int> chunk) {
    _stdoutBuffer.add(chunk);
    _drainStdoutBuffer();
  }

  // The stdout parser is a streaming frame state machine; keeping header,
  // body, pending-request, and error handling adjacent makes partial reads safe.
  // ignore: cyclomatic-complexity, halstead-volume, source-lines-of-code
  void _drainStdoutBuffer() {
    while (true) {
      final bytes = _stdoutBuffer.toBytes();
      final headerEnd = _indexOfSequence(bytes, _headerDelimiterBytes);
      if (headerEnd == -1) {
        return;
      }
      final headerText = utf8.decode(bytes.sublist(0, headerEnd));
      final contentLengthMatch = RegExp(
        r'Content-Length:\s*(\d+)',
        caseSensitive: false,
      ).firstMatch(headerText);
      if (contentLengthMatch == null) {
        throw StateError('LSP response missing Content-Length header.');
      }
      final contentLengthGroup = contentLengthMatch.group(1);
      if (contentLengthGroup == null) {
        throw StateError('LSP response has malformed Content-Length header.');
      }
      final contentLength = int.parse(contentLengthGroup);
      final bodyStart = headerEnd + _headerDelimiterBytes.length;
      final messageEnd = bodyStart + contentLength;
      if (bytes.length < messageEnd) {
        return;
      }
      final bodyText = utf8.decode(bytes.sublist(bodyStart, messageEnd));
      final remaining = bytes.sublist(messageEnd);
      _stdoutBuffer.clear();
      if (remaining.isNotEmpty) {
        _stdoutBuffer.add(remaining);
      }

      final decoded = jsonDecode(bodyText);
      if (decoded is! Map<String, Object?>) {
        continue;
      }
      final id = decoded['id'];
      if (id is! int) {
        continue;
      }
      final completer = _pending.remove(id);
      if (completer == null) {
        continue;
      }
      final error = decoded['error'];
      if (error is Map<String, Object?>) {
        completer.completeError(
          LanguageServerError(
            code: error['code'] as int? ?? -1,
            message: error['message'] as String? ?? 'Unknown LSP error',
            data: error['data'],
          ),
        );
        continue;
      }
      completer.complete(decoded['result']);
    }
  }
}

final class LanguageServerError implements Exception {
  const LanguageServerError({
    required this.code,
    required this.message,
    this.data,
  });

  final int code;
  final String message;
  final Object? data;

  @override
  String toString() => 'LanguageServerError(code: $code, message: $message)';
}

const List<int> _headerDelimiterBytes = <int>[13, 10, 13, 10];

int _indexOfSequence(List<int> source, List<int> pattern) {
  if (pattern.isEmpty || source.length < pattern.length) {
    return -1;
  }
  for (var index = 0; index <= source.length - pattern.length; index++) {
    var matched = true;
    for (var offset = 0; offset < pattern.length; offset++) {
      if (source[index + offset] != pattern[offset]) {
        matched = false;
        break;
      }
    }
    if (matched) {
      return index;
    }
  }
  return -1;
}
