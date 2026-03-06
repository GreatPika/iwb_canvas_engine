language: russian

# Шаг 3.1. Перевести public snapshot boundary на validated semantics

## Цель шага

После шагов `2` и `2.1` validated-layer уже существует и владеет boundary-rules для id, revision, finite/numeric scalar values и строковых полей. Задача этого шага: подключить этот слой к публичным `snapshot`-контрактам так, чтобы `SceneSnapshot` и `NodeSnapshot`-варианты перестали быть thin wrappers над сырыми примитивами, но при этом не появился второй набор primitive-проверок рядом с builder/runtime validation.

Этот шаг должен закрыть именно snapshot-boundary. Он не включает `NodeSpec`, `NodePatch`, `SceneWriteTxn`, точный export-surface и release-facing public API alignment из шага `4`.

## Что этот шаг считает своим владельцем

1. Публичное создание:
   - `SceneSnapshot`
   - `BackgroundLayerSnapshot`
   - `ContentLayerSnapshot`
   - `NodeSnapshot` и все его публичные варианты
2. Явную boundary-семантику:
   - `TextNodeSnapshot.size` как derived metadata
   - `SceneSnapshot.backgroundLayer` как canonical non-null public state
3. Разделение:
   - public validating entry points
   - internal fast-path для уже валидированных/канонизированных данных

## Что уже подтверждено по текущему состоянию

1. `lib/src/contract/snapshot.dart` сейчас в основном:
   - копирует коллекции в immutable views;
   - выставляет default values;
   - не валидирует id, ranges, safe-int и finiteness на boundary.
2. Immutable discipline на snapshot boundary уже частично есть:
   - коллекции оборачиваются в immutable views;
   - проблема шага не в отсутствии immutability как таковой, а в отсутствии validating boundary-semantics на тех же entry points.
3. `SceneSnapshot.backgroundLayer` на публичной границе уже канонизируется в non-null через `backgroundLayer ?? BackgroundLayerSnapshot()`.
4. Внутренняя модель `Scene` всё ещё допускает `backgroundLayer == null`, поэтому задача шага не запретить nullable runtime-state вообще, а зафиксировать публичную snapshot-semantics отдельно от internal runtime-state.
5. В import/build path для текста размер уже пересчитывается из layout inputs, а не читается как произвольный user-controlled source of truth.
6. Step `2` уже ввёл validated owners для `NodeIdValue`, `LayerIdValue`, `InstanceRevisionValue`, `FiniteOffsetValue`, `NonNegativeFiniteDoubleValue`, `PositiveFiniteDoubleValue`, `OpacityValue`, `ImageIdValue`, `TextContentValue`, `FontFamilyValue`, `SvgPathDataValue`.

## Рекомендуемое решение

Рекомендуемый вариант: перевести public `snapshot` entry points на thin-but-validating factories/constructors, которые используют validated-layer из шага `2` как единственный источник boundary-правил, а для уже канонизированных внутренних данных оставить отдельный internal fast-path.

Что это означает на практике:

1. Публичный вход больше не должен принимать "любой `String` / `int` / `double` / `Offset` / `Size`" без прохождения через validated owner или общий boundary helper.
2. Политика `TextNodeSnapshot.size` закрепляется явно:
   - это derived metadata;
   - import/build boundary может игнорировать вход и пересчитывать значение;
   - публичный API не должен трактовать `size` как независимый источник layout-truth.
3. Политика `backgroundLayer` закрепляется явно:
   - после публичного создания `SceneSnapshot.backgroundLayer` всегда non-null;
   - nullable seam, если нужен для decode/import plumbing, остаётся локальным и не становится расплывчатой особенностью публичного API.
4. Дублирующая primitive-валидация не добавляется в builder/runtime-path;
   downstream слои по-прежнему владеют только scene-level invariants, canonicalization и runtime-specific checks.

## Что именно менять

### `lib/src/contract/snapshot.dart`

[ ] Перевести публичное создание `SceneSnapshot` и `NodeSnapshot`-вариантов на валидирующие entry points, которые используют validated-layer из шага `2`.
[ ] Пропускать общие boundary-поля `id`, `instanceRevision`, `transform`, `opacity`, `hitPadding`, `size`, `thickness`, `fontSize`, `maxWidth`, `lineHeight`, `start`, `end`, `points` через единый validated owner/helper, а не через локальные ad-hoc checks.
[ ] Явно закрепить, что `TextNodeSnapshot.size` является derived metadata, а не свободным пользовательским вводом.
[ ] Сохранить и формализовать canonical non-null public semantics для `SceneSnapshot.backgroundLayer`.
[ ] Ввести внутренний fast-path только для уже валидированных snapshot-данных, чтобы runtime/builder не платили повторной boundary-валидацией там, где данные уже каноничны.

### Граница с соседними шагами

[ ] Не переносить сюда `NodeSpec`/`NodePatch`; это владелец шага `3.2`.
[ ] Не переносить сюда `SceneWriteTxn`, `writeSelectionReplace(...)`, immutability/throws semantics и downstream cleanup; это владелец шага `3.3`.
[ ] Не переносить сюда barrel/export-surface, release-facing docs и точный public API contract; это владелец шага `4`.

## Конкретизация внедрения по порядку

1. Подтвердить по каждому публичному snapshot-полю, где уже есть корректная семантика, а где boundary всё ещё сырая.
2. Сначала перевести top-level `SceneSnapshot`, `BackgroundLayerSnapshot`, `ContentLayerSnapshot` на validated/canonical public creation.
3. Затем тем же шаблоном перевести `NodeSnapshot`-варианты, начиная с общих полей базового `NodeSnapshot`.
4. Отдельно зафиксировать две ключевые semantics:
   - `TextNodeSnapshot.size` как derived metadata;
   - `backgroundLayer` как canonical non-null public state.
5. Добавить internal fast-path для путей, где snapshot уже построен из корректного runtime state или builder canonicalization.
6. Оставить downstream runtime validation только там, где она относится к scene-level invariants и canonicalization, а не к повторному primitive boundary enforcement.

## Критерии приемки

[ ] Публичные snapshot entry points больше не являются тонкой оболочкой над сырыми примитивами.
[ ] Уже существующая immutability discipline snapshot-коллекций сохранена и дополнена validating semantics, а не сломана или заменена новым sync-layer.
[ ] Вся boundary-валидация snapshot-полей использует validated-layer из шагов `2` и `2.1` как единственный источник primitive-правил.
[ ] `TextNodeSnapshot.size` имеет одну явную семантику: derived metadata, а не произвольный пользовательский источник истины.
[ ] `SceneSnapshot.backgroundLayer` имеет одну явную публичную семантику: после создания snapshot он всегда canonical и non-null.
[ ] Internal fast-path существует только для уже валидированных данных и не становится альтернативным публичным API.
[ ] В builder/runtime path не появляется второй независимый набор primitive-checks.

## Тестовый контур

[ ] Добавить тесты на public creation `SceneSnapshot` и `NodeSnapshot`-вариантов через validated semantics.
[ ] Добавить тесты на rejection невалидных id, revision, ranges, non-finite geometry и строковых boundary-values на snapshot boundary.
[ ] Добавить тесты на canonical non-null `backgroundLayer`.
[ ] Добавить тесты на derived handling `TextNodeSnapshot.size`, включая сценарий, где import/build path пересчитывает размер.
[ ] Добавить тесты на то, что internal fast-path не становится обходом публичной boundary-валидации.
