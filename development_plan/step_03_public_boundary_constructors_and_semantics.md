language: russian

# Шаг 3. Закрыть сырые публичные конструкторы и зафиксировать boundary-семантику

## Цель шага

После шага 2 в проекте уже должен появиться валидированный boundary-layer. Задача этого шага: перестать полагаться только на "позднюю" валидацию внутри builder/txn-путей и подтянуть enforcement к самим публичным контрактам `snapshot/spec/patch/write-txn`, не создавая при этом второй независимый набор правил. Важная граница шага: не переписывать заново runtime-model и не размазывать проверки по конструкторам, builder и patch-apply независимо друг от друга.

## Что уже подтверждено по текущему состоянию

1. Проблема с сырыми публичными конструкторами подтверждена:
   - `lib/src/contract/snapshot.dart`
   - `lib/src/contract/node_spec.dart`
   - `lib/src/contract/node_patch.dart`
   сейчас в основном только копируют коллекции, выставляют default'ы и не валидируют id, длины строк, диапазоны, safe-int и finiteness прямо в точке публичного создания объекта.
2. Поздняя валидация уже существует, но находится глубже, а не на boundary:
   - `txnNodeFromSpec(...)` валидирует `NodeSpec` через `sceneValidateNodeSpecValues(...)`;
   - `txnApplyNodePatch(...)` валидирует `NodePatch` через `sceneValidateNodePatchValues(...)`;
   - `sceneBuildFromSnapshot(...)` валидирует и канонизирует `SceneSnapshot`.
   Это значит, что проблема не в полном отсутствии защиты, а в том, что публичный контракт всё ещё позволяет собрать невалидный объект и донести его до следующего слоя.
3. Политика `TextNodeSnapshot.size` уже частично фактически определена кодом:
   - в import/build-пути текстовый размер пересчитывается через `recomputeDerivedTextSize(...)`;
   - входной `size` не является надёжным источником истины для layout-derived значения.
   То есть здесь нужна не новая политика "с нуля", а явная фиксация уже существующей канонизации.
4. Проблема "`backgroundLayer == null` как публичное состояние snapshot" в текущем API не подтверждена в прямом виде:
   - `SceneSnapshot.backgroundLayer` после конструктора всегда не-null, потому что `null` канонизируется в пустой `BackgroundLayerSnapshot()`;
   - при этом внутренняя модель `Scene` всё ещё допускает `backgroundLayer == null`, а `writeClearSceneKeepBackgroundResult()` умеет материализовать его лениво.
   Значит, реальная задача шага не "разрешить или запретить null вообще", а убрать плавающую трактовку между public snapshot boundary и internal runtime state.
5. Семантика `writeSelectionReplace([])` уже реализована и сейчас это no-op, а не clear:
   - метод нормализует вход;
   - если нормализованный набор пуст, он возвращает `false` и не очищает текущее выделение.
   Следовательно, здесь сначала нужно зафиксировать контракт, а не заново изобретать поведение.
6. Риск утечки изменяемых структур наружу частично уже закрыт:
   - `ClearSceneResult.removedNodeIds` копируется в `List.unmodifiable(...)`;
   - `SceneWriteTxn.selectedNodeIds` возвращается как `Set.unmodifiable(...)`;
   - snapshot/spec-контракты тоже оборачивают коллекции в immutable view.
   Значит, проблема не в полном отсутствии immutability discipline, а в том, что эта гарантия не везде явно описана и покрыта как публичный контракт.
7. Для `NodePatch` проблема "no-op без лишнего копирования" подтверждена точечно:
   - в `_txnSetOffsets(...)` входной список точек копируется через `List<Offset>.from(...)` ещё до проверки на equality;
   - публичных patch-полей для revision сейчас нет, поэтому отдельную policy для revision-патча на этом шаге придумывать не нужно.

## Рекомендуемое решение

Рекомендуемый вариант: сделать публичные boundary-типы thin-but-validating оболочкой над validated-layer из шага 2, а не самостоятельным вторым валидатором.

Что это означает на практике:

1. Публичные конструкторы `snapshot/spec/patch` больше не должны просто принимать "любой `String` / `double` / `Size` / `Offset`", если для этих значений уже существует validated-value или общий boundary helper.
2. При этом нельзя дублировать всю логику из builder и runtime-validation прямо в каждый конструктор. Правильная схема:
   - публичный constructor/factory валидирует через types/helpers из шага 2;
   - для уже канонизированных внутренних данных остаётся internal fast-path вроде `validated(...)`;
   - после перевода public boundary на validated-layer дублирующая primitive-валидация в downstream `spec/patch` путях удаляется или сводится к вызову того же единого helper/policy.
3. Нужно явно зафиксировать уже существующие, но пока расплывчатые публичные семантики:
   - `TextNodeSnapshot.size` является derived metadata, а не произвольным пользовательским вводом;
   - `SceneSnapshot.backgroundLayer` публично всегда каноничен и не-null;
   - `writeSelectionReplace([])` остаётся no-op, а явное очищение делается через `writeSelectionClear()`.
4. Для patch-путей нужно убрать лишние аллокации на no-op сценариях, но не ценой "sync glue" между patch и runtime-model.

Почему это лучший вариант:

1. Он закрывает дыру именно на публичной границе, а не только глубоко в runtime.
2. Он сохраняет один источник истины для primitive/boundary-инвариантов: validated-layer из шага 2.
3. Он не ломает уже существующую и полезную канонизацию в builder/txn-путях, а делает её явной и согласованной, оставляя внутри только те проверки, которые действительно относятся к scene-level semantics или runtime-specific invariants.
4. Он позволяет отдельно фиксировать contract semantics и отдельно оптимизировать no-op/copy behavior без массового rewrite model-layer.

## Альтернатива, которую не рекомендуется брать

Не рекомендуется просто добавить ещё по набору ручных проверок в `snapshot.dart`, `node_spec.dart`, `node_patch.dart`, `scene_writer.dart` и builder-пути независимо друг от друга. Такой подход быстро даст несколько почти одинаковых реализаций для id-length, text/font/path limits, opacity/range-policy и transform checks, после чего любая смена лимитов снова разъедется по слоям.

## Что именно менять

### `lib/src/contract/snapshot.dart`

[ ] Перевести публичное создание `SceneSnapshot` и `NodeSnapshot`-вариантов на валидирующие constructor/factory entry points, которые используют validated-layer из шага 2, а не принимают сырые значения без проверки.
[ ] Общие поля `id`, `instanceRevision`, `transform`, `opacity`, `hitPadding`, размеры и stroke-параметры пропускать через единый boundary helper/value types вместо локальных ad-hoc проверок.
[ ] Явно закрепить policy для `TextNodeSnapshot.size`: на import/build boundary это derived metadata, поэтому публичный API не должен трактовать произвольный входной `size` как источник истины.
[ ] Разделить public boundary и internal fast-path:
    - public constructor/factory валидирует и канонизирует;
    - internal `validated(...)`/equivalent используется только там, где snapshot уже построен из корректного runtime state.
[ ] Зафиксировать policy `backgroundLayer`:
    - публичный `SceneSnapshot` после создания всегда содержит не-null `backgroundLayer`;
    - если nullable input остаётся допустимым ради decode/import seam, это должно быть ограничено factory-слоем и явно задокументировано, а не оставаться неявной особенностью конструктора.

### `lib/src/contract/node_spec.dart`

[ ] Перевести все public `NodeSpec` конструкторы на ту же схему: валидирующий public entry point плюс внутренний fast-path для уже нормализованных значений.
[ ] Закрыть обходы по полям `id`, `text`, `fontFamily`, `svgPathData`, `opacity`, `hitPadding`, thickness/size/range и finite-transform, используя validated-layer из шага 2 вместо разрозненных локальных проверок.
[ ] Для геометрии и transform использовать validated значения/общие helpers, а не оставлять прямой приём "любого" `Offset`, `Size`, `double`, `Transform2D`.
[ ] Не добавлять в `NodeSpec` вторую независимую семантику текстового размера: `TextNodeSpec` по-прежнему должен описывать layout inputs, а не хранить самостоятельный `size`.
[ ] Сохранить совместимость с текущим write-path, где `txnNodeFromSpec(...)` остаётся потребителем уже валидированного boundary-объекта, а не последним местом, где впервые выясняется корректность входа.
[ ] После подключения validated public entry points удалить или свести к единому helper/policy дублирующую primitive-валидацию в downstream `spec`-пути; внутри оставить только runtime-specific и scene-level checks.

### `lib/src/contract/node_patch.dart`

[ ] Перевести public `NodePatch` и `CommonNodePatch` на валидирующие constructor/factory entry points, которые проверяют только присутствующие `PatchField`, но делают это через тот же validated-layer.
[ ] Гарантировать, что patch не может пронести мимо boundary-политики невалидные `text`, `fontFamily`, `svgPathData`, размеры, толщины, opacity, transform и другие scalar values.
[ ] Для `StrokeNodePatch.points` убрать лишнее копирование на no-op сценарии:
    - сначала определять, меняется ли содержимое;
    - только потом materialize/copy immutable list, если изменение действительно есть.
[ ] Не придумывать отдельную revision-patch policy без фактической API-поверхности: сейчас публичный `NodePatch` не экспонирует revision fields, значит этот пункт надо явно сузить, а не расширять.
[ ] Сохранить текущую downstream-логику пересчёта derived text size после layout-affecting patch, но не добавлять ради этого новый sync-layer между patch и runtime-model.
[ ] После подключения validated public entry points удалить или свести к единому helper/policy дублирующую primitive-валидацию в downstream `patch`-пути; внутри оставить только применение патча, canonicalization и runtime-specific checks.

### `lib/src/contract/scene_write_txn.dart`

[ ] Формально закрепить уже реализованную семантику `writeSelectionReplace(...)`: пустой или полностью невалидный после normalization набор ids даёт no-op, а явный clear остаётся обязанностью `writeSelectionClear()`.
[ ] Описать точные `throws`-контракты публичных методов:
    - `StateError` после завершения txn;
    - `ArgumentError`/`RangeError` там, где они реально возможны по текущей реализации;
    - без расплывчатых формулировок "может бросить ошибку".
[ ] Зафиксировать как контракт, а не как случайную деталь реализации, что `ClearSceneResult.removedNodeIds` и `selectedNodeIds` наружу отдаются в неизменяемом виде.
[ ] Проверить и задокументировать, какие ещё публично возвращаемые структуры обязаны быть immutable snapshots, чтобы не было расхождения между docstring и реальным поведением.
[ ] Не менять поведение только ради документации, если оно уже корректно и покрыто invariants; если проблема не подтверждена, ограничиться явной фиксацией контракта и тестом.

## Конкретизация внедрения по порядку

1. Для каждого публичного boundary-типа из шага 3 пометить, где проблема реально подтверждена, а где уже есть корректная реализация, но не хватает явного контракта:
   - `snapshot.dart`
   - `node_spec.dart`
   - `node_patch.dart`
   - `scene_write_txn.dart`
2. Сначала перевести `snapshot.dart` на validated/canonical public creation и отдельно зафиксировать две конфликтные сегодня semantics:
   - derived `TextNodeSnapshot.size`;
   - always-canonical public `backgroundLayer`.
3. Затем тем же шаблоном перевести `node_spec.dart`, чтобы write-insert path получал уже валидированный boundary-object, а не валидировал его впервые глубоко внутри.
4. После этого перевести `node_patch.dart`, включая policy "validate only present fields" и оптимизацию no-op для списков точек.
5. Затем удалить или схлопнуть дублирующую primitive-валидацию из downstream `txnNodeFromSpec(...)` / `txnApplyNodePatch(...)` и соседних `spec/patch`-validator paths, оставив внутри только scene-level invariants, canonicalization и runtime-specific checks.
6. Последним пройтись по `scene_write_txn.dart`: задокументировать подтверждённые semantics, сузить/убрать неподтверждённые предположения и добавить тесты на immutability + documented throws.
7. Завершать шаг только после того, как станет невозможно легально создать через public API объект, который явно нарушает уже зафиксированные boundary-инварианты, и при этом внутри не останется второго независимого владельца тех же primitive-rules.

## Критерии приемки

[ ] Для каждого пункта шага 3 явно указано, проблема подтверждена или опровергнута текущим кодом; в плане не осталось подвешенных формулировок вида "возможно тут null/clear/утечка".
[ ] Публичные `snapshot/spec/patch` entry points больше не являются тонкой оболочкой над сырыми примитивами и используют validated-layer из шага 2 как единственный источник boundary-валидации.
[ ] Внутренние `spec/patch` downstream-пути больше не дублируют primitive boundary-валидацию независимым набором правил; внутри оставлены только scene-level invariants, canonicalization и runtime-specific checks.
[ ] `TextNodeSnapshot.size` имеет одну явную политику во всех публичных входах: это derived value, а не свободно задаваемый пользовательский источник истины.
[ ] `SceneSnapshot.backgroundLayer` имеет одну явную публичную семантику: после создания snapshot каноничен; nullable/import seam, если он остаётся, ограничен и задокументирован.
[ ] `NodeSpec` и `NodePatch` больше не позволяют пронести мимо публичной границы невалидные id, text/font/path values, диапазоны, safe-int и non-finite geometry.
[ ] No-op сценарии для patch-обновления списков точек не создают лишних копий без необходимости.
[ ] Контракт `writeSelectionReplace(...)` однозначно фиксирует no-op vs clear semantics и совпадает с реализацией и тестами.
[ ] Публичные возвращаемые структуры `SceneWriteTxn` не отдают изменяемые внутренние коллекции наружу; immutability гарантирована тестами или явной проверкой контракта.
[ ] Публичные `throws`-контракты `SceneWriteTxn` совпадают с фактическим поведением реализации.

## Чеклист выполнения

[ ] Подтвердить и зафиксировать, какие проблемы шага 3 реально есть в `snapshot/spec/patch/write-txn`, а какие уже решены кодом и требуют только сужения формулировки плана.
[ ] Перевести `lib/src/contract/snapshot.dart` на validated/canonical public creation.
[ ] Явно закрепить policy для `TextNodeSnapshot.size`.
[ ] Явно закрепить public policy для `SceneSnapshot.backgroundLayer`.
[ ] Перевести `lib/src/contract/node_spec.dart` на валидирующие public entry points.
[ ] Перевести `lib/src/contract/node_patch.dart` на валидирующие public entry points.
[ ] Удалить или схлопнуть дублирующую primitive-валидацию из downstream `spec/patch`-путей после подключения validated public entry points.
[ ] Убрать лишнее копирование в no-op сценарии для patch-обновления списков точек.
[ ] Зафиксировать, что revision-patch surface на этом шаге не расширяется без отдельного требования продукта.
[ ] Обновить `lib/src/contract/scene_write_txn.dart` так, чтобы `writeSelectionReplace(...)`, immutability и `throws` были описаны точно и проверяемо.
[ ] Добавить или обновить тесты на public boundary-семантику snapshot/spec/patch/write-txn, а не только на глубокий runtime-path.

