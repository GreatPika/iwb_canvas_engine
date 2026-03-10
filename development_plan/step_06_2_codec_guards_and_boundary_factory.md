language: russian

# Шаг 6.2. Ввести `codec_guards.dart` без нарушения layer DAG

## Цель шага

Сейчас transport-level guard logic для string decode и encode boundary размазана между
[scene_codec.dart](/Users/blackpika/iwb_canvas_engine/lib/src/serialization/scene_codec.dart)
и contract-level error helpers: локальные `try/catch`, ручная сборка
`SceneDataException` и отсутствие одного owner-а для payload-size policy.

Задача подшага: ввести serialization-local guard helper-ы в
`codec_guards.dart`, которые используют contract primitives шага `6.1`, но не
затягивают `model/` в запрещённую зависимость от `serialization/`.

## Зафиксированные решения (без повторного обсуждения в реализации)

1. Shared boundary factory и canonical `code/path/details` normalization
   определяются в `6.1` и остаются в разрешённом низком слое `contract/`,
   чтобы ими могли пользоваться и `model/`, и `serialization/`.
2. Новый internal owner serialization transport guards:
   [codec_guards.dart](/Users/blackpika/iwb_canvas_engine/lib/src/serialization/codec_guards.dart).
3. В `6.2` допустимы только такие helper-ы, которые закрывают serialization
   transport-level concerns:
   `_guardDecode`, `_guardEncode`.
4. `_guardBuild(...)` не живёт в `serialization/`; builder получает свой
   model-local wrapper в `6.3`, собранный на тех же contract primitives.
5. Payload-size limit для string JSON применяется до `jsonDecode`; oversized
   transport payload не должен доходить до parser или policy-owner-а.
6. Guards переводят системные исключения и boundary context в contract
   `code/path/details` шага `6.1`, но не владеют scene-level semantic
   decisions и не переопределяют diagnostics, уже принадлежащие `ScenePolicy`.
7. Path/context normalization принадлежит guard-layer; sanitization того, что
   реально сохраняется в `SceneDataException`, остаётся owner-ом `6.1`.
8. Любой новый limit на размер сырого JSON оформляется как named constant рядом
   с остальными boundary limits и документируется в том же изменении; magic
   number внутри guard helper недопустим.

## Граница шага

- In:
  - `lib/src/serialization/codec_guards.dart`;
  - payload-size guardrails;
  - общий catch/translation системных исключений;
  - path/context normalization для serialization boundary.
- Out:
  - builder-local `_guardBuild(...)`;
  - широкий docs/tests rollout contract-matrix шага `6.4`
    (кроме документации, напрямую требуемой новым raw JSON limit или shared
    contract primitives);
  - final adoption в `scene_codec.dart`;
  - пересмотр scene-level duplicate/range/background semantics.

## Последовательность реализации (только действия)

[x] Создать
    [lib/src/serialization/codec_guards.dart](/Users/blackpika/iwb_canvas_engine/lib/src/serialization/codec_guards.dart)
    и определить в нём `_guardDecode`, `_guardEncode`.
[x] Явно потреблять shared contract primitives шага `6.1`, не дублируя
    factory/template semantics локально в `serialization/`.
[x] Вынести в guard-layer payload-size limit для string JSON до `jsonDecode`.
[x] Если вводится отдельный raw JSON size limit, оформить его как named
    constant и задокументировать как публичный boundary contract в том же
    изменении.
[x] Централизовать перевод системных исключений и transport-level boundary
    context в `SceneDataException` через factory/template path из `6.1`.
[x] Локализовать в одном месте path/context normalization для codec boundary,
    не затягивая builder wrapper в `serialization/`.
[x] Явно отделить transport-level fail-fast guardrails от уже готовых
    `ScenePolicy`/decode ошибок, чтобы guard-layer не стал вторым owner-ом
    scene semantics.
[x] Подготовить точечные tests для huge JSON, non-object root, dependency-DAG
    и общего mapping transport failures, не смешивая их с full codec rollout.

## Критерии приёмки

[x] `codec_guards.dart` становится единственным owner-ом serialization
    transport guards для string/encode boundary.
[x] Oversized JSON payload отсекается до `jsonDecode`.
[x] Raw JSON size limit, если он добавлен, не скрыт в guard helper и имеет
    явное документированное значение.
[x] System/transport failures нормализуются в тот же contract
    `code/path/details`, что и остальные boundary.
[x] `scene_codec.dart` больше не обязан держать собственные ad hoc
    catch/mapping ветки для transport-level concerns.
[x] Новый guard-layer не забирает ownership scene-level policy semantics и не
    нарушает import boundaries проекта.

## Тестовый контур шага

[x] `test/serialization/scene_codec_validation_test.dart`
[x] `test/tool/import_boundaries_layers_tool_test.dart`
[x] `test/model/scene_builder_test.dart`
[x] Точечные сценарии:
    - huge JSON fails before `jsonDecode`
    - non-object root goes through unified guard contract
    - system exception mapping keeps deterministic `code/path/details`
    - transport guard helpers do not lose nested domain errors on rethrow
    - `model/` does not gain a dependency on `serialization/`
