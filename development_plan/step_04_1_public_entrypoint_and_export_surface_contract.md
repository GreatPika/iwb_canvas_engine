language: russian

# Шаг 4.1. Зафиксировать public entrypoint и export surface

## Цель шага

Этот шаг не про расширение public surface, а про формальную фиксацию уже существующей модели: у пакета есть один поддерживаемый public import root, а состав экспортов и public symbol surface контролируется guardrails и golden-тестами. Нужно закрыть именно contract drift на уровне entrypoint/export surface, не смешивая его с codec semantics, `TextAlign` и writer contract.

## Что этот шаг считает своим владельцем

1. Единственный поддерживаемый public entrypoint:
   - `lib/iwb_canvas_engine.dart`
2. Состав поддерживаемого export surface:
   - public contract types;
   - `SceneBuilder`;
   - serialization entrypoints;
   - `validated.dart`
3. Tooling и test enforcement:
   - `tool/check_guardrails.dart`
   - `tool/check_public_api_surface.dart`
   - `test/tool/**`
   - `test/entrypoints/**`

## Что уже подтверждено по текущему состоянию

1. `lib/iwb_canvas_engine.dart` уже является единственным root entrypoint, а инвариант поддерживается guardrails и entrypoint tests.
2. `validated.dart` уже экспортируется из barrel и входит в golden public symbol surface.
3. Guardrails уже запрещают второй entrypoint вроде `advanced.dart` и mutable-core leaks через barrel.
4. Основной риск шага не в отсутствии guardrails, а в том, чтобы явно зафиксировать эту модель как поддерживаемый контракт и не оставить двусмысленность вокруг `src/**`.

## Рекомендуемое решение

Рекомендуемый вариант: не менять модель публичного входа, а формально закрепить её как норму системы.

Что это означает на практике:

1. `lib/iwb_canvas_engine.dart` остаётся единственным поддерживаемым import root.
2. `validated.dart` остаётся официальной частью public API.
3. Новый barrel, compat-layer или "advanced" entrypoint не вводится.
4. Guardrails/golden tests продолжают быть источником истины для export surface.

## Что именно менять

### `lib/iwb_canvas_engine.dart`

[ ] Подтвердить, что barrel остаётся единственным публичным входом.
[ ] Сохранить экспорт `validated.dart` как часть поддерживаемого public surface.
[ ] Не добавлять новые entrypoint-файлы или дополнительные фасады.

### `tool/check_guardrails.dart` и `test/tool/**`

[ ] Проверить, что guardrails продолжают запрещать:
   - лишние root entrypoints;
   - mutable-core exports;
   - неоговорённый export drift.
[ ] Доработать tests/tooling только если текущий enforcement реально не закрывает этот риск.

### `tool/check_public_api_surface.dart` и `tool/goldens/public_api_symbols.txt`

[ ] Подтвердить, что golden symbol surface совпадает с barrel exports.
[ ] Не менять golden без подтверждённого изменения поддерживаемого контракта.

## Конкретизация внедрения по порядку

1. Проверить фактический export list и golden surface.
2. Подтвердить, что `validated.dart` остаётся поддерживаемым export.
3. Проверить, не закрепляют ли docs/tests использование `package:iwb_canvas_engine/src/**` как нормальный integration path.
4. Если drift не подтверждён, ограничиться фиксацией решения в umbrella docs и существующем tooling.

## Критерии приемки

[ ] `lib/iwb_canvas_engine.dart` остаётся единственным поддерживаемым public entrypoint.
[ ] `validated.dart` явно признан частью публичного контракта этого пакета.
[ ] Guardrails продолжают ловить mutable-core leaks и запрещённые entrypoint-ы.
[ ] Golden public symbol surface совпадает с barrel.
[ ] Использование `src/**` не закреплено как поддерживаемый путь интеграции.

## Тестовый контур

[ ] `test/tool/guardrails_*`
[ ] `test/tool/public_api_surface_tool_test.dart`
[ ] `test/entrypoints/basic_smoke_test.dart`
