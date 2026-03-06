language: russian

# Шаг 7. Перевести id и ревизии на безопасную политику

## Создать `lib/src/core/id_generator.dart`

Сделать:

1. Генератор `NodeId`
2. Генератор `LayerId`
3. Без зависимости от простого роста `int` как единственной стратегии

## Создать `lib/src/core/revision_policy.dart`

Сделать:

1. Безопасный диапазон ревизий
2. Политику `(epoch, revision)`
3. Политику переполнения

## `lib/src/controller/txn_context.dart`

Сделать:

1. Переписать:

   * `txnNextNodeId()`
   * `txnNextLayerId()`
   * `txnNextInstanceRevision()`
2. Перевести их на новую политику генерации.

## `lib/src/model/document_clone.dart`

Сделать:

1. Перестать использовать числовой разбор legacy-id как основной механизм.
2. Legacy-формат оставить только как совместимость на чтение.

## `lib/src/render/cache/**`

Сделать:

1. Ключи кешей перевести на новую ревизионную политику.
2. При необходимости добавить `epoch` в ключи.

