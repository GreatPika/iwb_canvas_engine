String topLevelUnroutedMaterializes() => _materialize(() => 'ok');

T _materialize<T>(T Function() create) => create();
