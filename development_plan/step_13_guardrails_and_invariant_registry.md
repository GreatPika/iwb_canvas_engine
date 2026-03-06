language: russian

# Шаг 13. Ужесточить guardrails и реестр инвариантов

## `tool/check_import_boundaries.dart`

Сделать:

1. `Link` внутри `lib/src/**` — ошибка.
2. Анализировать `part`.
3. Анализировать `part of`.
4. Запретить новые `lib/src/*.dart`, кроме white list.
5. Добавить политику внешних пакетов по слоям.
6. Перекрыть обходы через `lib/*.dart`.

## `tool/src/layer_guardrails.dart`

Сделать:

1. Зафиксировать white list top-level слоёв.
2. Формально зафиксировать запрещённые и удалённые слои.
3. Согласовать с `check_import_boundaries`.

## `tool/check_guardrails.dart`

Сделать:

1. Убрать `skip` для `interactive/view`.
2. Проверять утечку изменяемых типов в сигнатуры.
3. Проверять write-only mutation по AST и опасным операциям, а не по имени.
4. Проверять epoch invalidation по смыслу, а не по наличию слова.
5. Защитить правило “один публичный вход”.

## `tool/check_invariant_coverage.dart`

Сделать:

1. Перестать считать комментарий `INV:...` покрытием.
2. Считать покрытием только:

   * реальную тестовую точку,
   * инструментальную проверку,
   * явный механизм доказательства.

## `tool/check_coverage.dart`

Сделать:

1. Убрать исключение для файла с реальной логикой.
2. Ужесточить требования для критичных файлов.

## `tool/invariant_registry.dart`

Сделать:

1. Добавить:

   * `INV-SER-SCHEMA-VERSION-CONTRACT`
   * инвариант монотонности `timestampMs`
   * инвариант инвалидирования `PathNode` cache
   * инвариант неизменяемости `ClearSceneResult.removedNodeIds`
   * инвариант корректного `code` для unsupported schema version
2. Переименовать существующие `INV-*`, которые содержат подчёркивания, в единый формат без `_`, например `UPPER-KEBAB-CASE`.
3. Добавить проверку, что новые ID не содержат `_`.

## `test/tool/**`

Добавить:

1. Отрицательный сценарий на каждый guardrail:

   * Link
   * part
   * part of
   * утечка `Scene`
   * fake `controllerEpoch`
   * мутирующий метод с нейтральным именем
   * формальное `INV:` без реальной проверки

