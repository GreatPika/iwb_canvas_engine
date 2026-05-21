import 'dart:async';
import 'dart:io';

import 'package:test/test.dart';

import '../../tool/guardrails/src/repository_paths.dart';

Future<void> _flutterTestQueue = Future<void>.value();

Future<void> runFlutterInPackageTest(String path) {
  final queued = _flutterTestQueue.then((_) {
    return _withFlutterTestLock(() => _runFlutterTest(path));
  });
  _flutterTestQueue = queued.catchError((Object _) {});

  return queued;
}

Future<void> _runFlutterTest(String path) {
  return Process.run('flutter', [
    'test',
    path,
  ], workingDirectory: repositoryRoot).then((result) {
    expect(result.exitCode, 0, reason: _processOutput(result));
  });
}

Future<T> _withFlutterTestLock<T>(Future<T> Function() run) async {
  final lockFile = File('$repositoryRoot/.dart_tool/flutter_test.lock');
  lockFile.parent.createSync(recursive: true);
  final lock = await lockFile.open(mode: FileMode.write);

  try {
    await _lockWhenAvailable(lock);

    return await run();
  } finally {
    await lock.unlock();
    await lock.close();
  }
}

Future<void> _lockWhenAvailable(RandomAccessFile lock) async {
  while (true) {
    try {
      await lock.lock();

      return;
    } on FileSystemException catch (error) {
      if (error.osError?.errorCode != 35) {
        rethrow;
      }
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
  }
}

String _processOutput(ProcessResult result) {
  return '''
stdout:
${result.stdout}

stderr:
${result.stderr}
''';
}
