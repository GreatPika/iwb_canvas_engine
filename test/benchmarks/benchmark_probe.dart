import 'dart:convert';
import 'dart:io';

const _probeTestPath = 'test/benchmarks/benchmark_probe_flutter.dart';
const _probeTestName = 'benchmark probe executes requested case';

Future<void> main(List<String> args) async {
  final deviceId = _extractDeviceId(args);
  await Directory('.dart_tool').create(recursive: true);
  final lockFile = File(
    '.dart_tool/benchmark_probe.lock',
  ).openSync(mode: FileMode.write);
  try {
    await _lockProbe(lockFile);
    _ensureNativeAssetsManifest();
    final result = await Process.run(
      'flutter',
      [
        'test',
        if (deviceId != null) ...['-d', deviceId],
        _probeTestPath,
        '--plain-name',
        _probeTestName,
      ],
      environment: {
        ...Platform.environment,
        'BENCHMARK_PROBE_ARGS': jsonEncode(
          args.where((arg) => !arg.startsWith('--device=')).toList(),
        ),
      },
    );
    stdout.write(result.stdout);
    stderr.write(result.stderr);
    exitCode = result.exitCode;
  } finally {
    lockFile.unlockSync();
    lockFile.closeSync();
  }
}

String? _extractDeviceId(List<String> args) {
  for (final arg in args) {
    if (arg.startsWith('--device=')) {
      final value = arg.replaceFirst('--device=', '');
      if (value.isEmpty) {
        throw const FormatException('--device must not be empty.');
      }
      return value;
    }
  }
  return null;
}

Future<void> _lockProbe(RandomAccessFile lockFile) async {
  final deadline = DateTime.now().add(const Duration(minutes: 10));
  while (true) {
    try {
      lockFile.lockSync();
      return;
    } on FileSystemException {
      if (DateTime.now().isAfter(deadline)) {
        rethrow;
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
  }
}

void _ensureNativeAssetsManifest() {
  final source = File(
    'build/native_assets/${_nativeAssetsPlatform()}/native_assets.json',
  );
  if (!source.existsSync()) {
    source
      ..parent.createSync(recursive: true)
      ..writeAsStringSync('{"format-version":[1,0,0],"native-assets":{}}');
  }
  final target = File('build/unit_test_assets/NativeAssetsManifest.json');
  if (!target.existsSync()) {
    target.parent.createSync(recursive: true);
    source.copySync(target.path);
  }
}

String _nativeAssetsPlatform() {
  return switch (Platform.operatingSystem) {
    'macos' => 'macos',
    'linux' => 'linux',
    'windows' => 'windows',
    _ => Platform.operatingSystem,
  };
}
