language: russian

# Шаг 13.3. Перевести mutation, epoch invalidation и boundary-error rules на semantic AST guardrails

## Цель шага

После `13.2` public surface уже должен быть просканирован, но behavioral drift
всё ещё останется возможным, если `tool/check_guardrails.dart` продолжит
полагаться на слабые признаки:

- write-only mutation можно обойти нейтральным именем метода;
- fake `controllerEpoch` можно подложить без реального invalidation смысла;
- прямой `throw SceneDataException(...)` можно размазать по коду, потеряв один
  boundary-error factory owner.

Задача подшага: перевести эти guardrails на semantic AST detection, где
tooling смотрит на опасные операции и реальный boundary shape, а не на одно
совпадение имени.

## Что уже подтверждено по текущему состоянию

1. [check_guardrails.dart](/Users/blackpika/iwb_canvas_engine/tool/check_guardrails.dart)
   уже содержит primitive AST visitors и controller symbol collection.
2. Исходный шаг прямо требует:
   - проверять write-only mutation по AST и опасным операциям, а не по имени;
   - проверять epoch invalidation по смыслу, а не по наличию слова;
   - запретить прямой `throw SceneDataException` вне централизованного factory.
3. Эти проверки концептуально отличаются от public signature scan и поэтому
   не должны смешиваться с ownership `13.2`.

## Зафиксированные решения (без повторного обсуждения в реализации)

1. `13.3` владеет только semantic AST-guardrails в `check_guardrails.dart`.
2. Write-only mutation определяется по опасным операциям и mutation surface,
   а не по префиксу имени или whitelist-у удобных названий.
3. `epoch invalidation` считается выполненным только при наличии реального
   invalidation path, а не формального упоминания `controllerEpoch`.
4. Прямой `throw SceneDataException(...)` вне boundary error factory запрещён.
   Разрешён только явный allow-list для:
   - самой централизованной factory;
   - targeted tests, которые проверяют этот boundary contract.
5. Этот подшаг не решает:
   - mutable type leak signatures;
   - import topology;
   - invariant registry/coverage;
   - line coverage gate.

## Граница шага

- In:
  - semantic AST-detection для mutation surface;
  - semantic проверка `epoch invalidation`;
  - factory-only throw policy для `SceneDataException`.
- Out:
  - public/export signature scan;
  - invariant ids и proof coverage;
  - import/link/part boundaries;
  - coverage exclusions.

## Точная реализация, которую должен описывать код

1. Guardrail write-only mutation ищет mutation-capable AST shapes и опасные
   операции, а не только имена методов.
2. Guardrail `epoch invalidation` валидирует semantic path:
   update/replacement действительно должен приводить к expected invalidation
   effect, а не к фиктивному marker-у.
3. Guardrail `SceneDataException` различает:
   - direct throw вне allow-list;
   - допустимый throw в централизованной factory;
   - targeted tests, которые намеренно строят boundary fixture.
4. Подшаг не меняет exported API scan policy и не вводит новые invariant ids.

## Последовательность реализации (только действия)

- [ ] Перевести write-only mutation guardrail на semantic AST detection.
- [ ] Перевести `epoch invalidation` guardrail на semantic invalidation path.
- [ ] Запретить direct `throw SceneDataException(...)` вне allow-list boundary
      factory и tests.
- [ ] Явно развести эти проверки с public/export scan ownership `13.2`.

## Критерии приёмки

- [ ] Мутирующий метод с нейтральным именем не обходит write-only mutation
      guardrail.
- [ ] Fake `controllerEpoch` без реального invalidation path не проходит
      semantic guardrail.
- [ ] Direct `throw SceneDataException(...)` вне factory/test allow-list
      приводит к tool failure.
- [ ] Allow-list для `SceneDataException` минимален и принадлежит только этому
      owner-у.
- [ ] Подшаг не становится second owner-ом public signature scan.
- [ ] Повторная диагностика
      `dcm calculate-metrics tool/check_guardrails.dart test/tool/guardrails_public_contracts_tool_test.dart test/tool/guardrails_layout_and_entrypoints_tool_test.dart --report-all`
      приложена к результату шага; новые или step-owned methods не содержат
      `HIGH`/`VERY HIGH` по `cyclomatic-complexity`,
      `maximum-nesting-level` и `source-lines-of-code`, а целевой предел
      остаётся `10 / 4 / 40`.

## Тестовый контур шага

- [ ] `test/tool/guardrails_public_contracts_tool_test.dart` с отрицательными
      сценариями:
      - fake `controllerEpoch`
      - мутирующий метод с нейтральным именем
      - direct `throw SceneDataException(...)` вне factory
- [ ] Если потребуется отдельный fixture, он остаётся test-only и не вводит
      второй owner policy вне `check_guardrails.dart`

## Диагностика шага

- [ ] До завершения подшага приложен `dcm calculate-metrics`-отчёт по
      semantic AST surface в `tool/check_guardrails.dart`.
- [ ] Любые новые visitor/helper-модули для AST detection укладываются в предел
      `10 / 4 / 40`.
- [ ] Если hotspot остаётся в `check_guardrails.dart`, он явно закреплён за
      semantic ownership этого подшага, а не размыт между `13.2` и `13.3`.
