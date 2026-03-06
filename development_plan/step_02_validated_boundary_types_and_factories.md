language: russian

# Шаг 2. Ввести валидированные типы и фабрики на публичной границе

## Цель шага

Не переписать заново всю валидацию сцены, а поднять уже существующие инварианты ближе к публичной границе. После этого шага `snapshot/spec/patch` и id/error-фабрики должны перестать быть "тонкой оболочкой над сырыми примитивами", но при этом нельзя плодить второй независимый слой правил поверх уже существующих `scene_limits.dart`, `scene_value_validation*.part.dart` и JSON decode-пути.

## Что уже подтверждено по текущему состоянию

1. `lib/src/contract/ids.dart` сейчас не задаёт никакой семантики кроме alias:
   - `NodeId = String`;
   - `LayerId = String`.
2. Публичные `snapshot/spec/patch`-контракты по-прежнему принимают сырые `String`, `int`, `double`, `Offset`, `Size` и держат их у себя без собственной типизированной валидации на входе.
3. Валидация уже существует, но сидит глубже:
   - `lib/src/model/scene_value_validation_primitives.part.dart` покрывает finite/sign/range/svg-path;
   - `lib/src/model/scene_value_validation_node.part.dart` валидирует `NodeSpec` и `NodePatch`;
   - `lib/src/model/scene_builder.dart` и related parts валидируют `SceneSnapshot` при build/decode.
4. Лимиты длины и safe-int уже централизованы в одном месте:
   - `lib/src/core/scene_limits.dart`;
   - `_optionalInt(...)` и `_requireString(..., maxLength: ...)` в JSON decode-пути.
5. Эти лимиты сейчас применяются несимметрично:
   - JSON decode-path проверяет длину `layer id`, `node id`, `text`, `fontFamily`, `svgPathData`;
   - in-memory public constructors и patch/spec surface эти же ограничения заранее не выражают.
6. `SceneDataException` уже умеет нести `code`, `message`, `path` и используется в decode-ошибках, включая `TextAlign`; проблема не в отсутствии `path` как концепции, а в том, что `source` передаётся как есть и легко может хранить слишком большой payload.
7. Генерация и распознавание "системных" id уже завязаны на legacy-формат:
   - `node-<n>` для node id;
   - `layer-<n>` для layer id.
   Это значит, что шаг нельзя делать как абстрактную замену `String` на "любой новый тип" без явной transitional policy.

## Рекомендуемое решение

Рекомендуемый вариант: ввести компактный слой валидированных boundary-value типов в `lib/src/contract/validated/**`, но не копировать в них всю validation logic заново. Правильная форма шага:

1. Оставить один источник истины для лимитов и базовых правил:
   - числовые пределы и длины живут в `lib/src/core/scene_limits.dart`;
   - базовые primitive-checks переиспользуются из model validation или выносятся в один общий helper, а не дублируются по десяти файлам.
2. Создать intent-revealing value wrappers только для реально разных инвариантов:
   - `NodeIdValue`
   - `LayerIdValue`
   - `InstanceRevisionValue`
   - `FiniteOffsetValue`
   - `PositiveFiniteDoubleValue`
   - `NonNegativeFiniteDoubleValue`
   - `OpacityValue`
   - `SvgPathDataValue`
   - `TextContentValue`
   - `FontFamilyValue`
3. Дать этим типам единый boundary API:
   - `parse(...)` для входной строки/сырого значения;
   - `of(...)` для уже типизированного runtime-ввода;
   - `fromJson(...)` только там, где это действительно JSON boundary;
   - `validated(...)` как внутренний fast-path для уже доказанно корректного значения.
4. Не делать на этом шаге тотальную замену всех публичных полей на новые типы. Этот шаг должен подготовить строительные блоки и migration surface, а закрытие сырых публичных конструкторов пойдёт в следующем шаге.
5. Одновременно нормализовать `SceneDataException`, чтобы ошибки на boundary возвращали компактный, безопасный и предсказуемый payload вместо сырого большого `source`.

Почему это лучший вариант:

1. Он устраняет текущий разрыв между JSON boundary и in-memory boundary, не добавляя второй источник истины.
2. Он позволяет мигрировать API поэтапно: сначала вводим validated values и фабрики, потом подключаем их в `snapshot/spec/patch`.
3. Он сохраняет совместимость с уже существующими `node-*` / `layer-*` генераторами и seed-логикой.
4. Он не превращает шаг в массовый rewrite всех моделей сразу.

## Альтернатива, которую не рекомендуется брать

Не рекомендуется просто "раскидать проверки" по конструкторам `SceneSnapshot`, `NodeSpec`, `NodePatch`, `ids.dart` и JSON decode независимо друг от друга. Это даст быстрый локальный эффект, но создаст несколько почти одинаковых наборов правил для длины, finite-checks, safe-int и `svgPathData`, которые начнут расходиться при первом же изменении лимитов или текста ошибок.

## Что именно менять

### `lib/src/contract/validated/**`

[ ] Создать каталог `lib/src/contract/validated/**` как единый boundary-layer для value objects, а не как набор разрозненных helper-функций.
[ ] Добавить intent-revealing entry files:
    - `node_id_value.dart`
    - `layer_id_value.dart`
    - `instance_revision_value.dart`
    - `finite_offset_value.dart`
    - `positive_finite_double_value.dart`
    - `non_negative_finite_double_value.dart`
    - `opacity_value.dart`
    - `svg_path_data_value.dart`
    - `text_content_value.dart`
    - `font_family_value.dart`
[ ] Не копировать в каждый файл одинаковую low-level логику; вынести общие проверки пустоты, длины, finite, знака и safe-int в один внутренний helper рядом с этим каталогом.
[ ] Привязать все длины и числовые лимиты к `lib/src/core/scene_limits.dart`, а не дублировать числа в новых типах.
[ ] Зафиксировать единый контракт фабрик:
    - `parse(...)` для внешнего необработанного ввода;
    - `of(...)` для runtime-значений;
    - `fromJson(...)` только для JSON boundary;
    - `validated(...)` только как внутренний shortcut без повторной логики на каждом call site.
[ ] Для `SvgPathDataValue`, `TextContentValue`, `FontFamilyValue`, `NodeIdValue`, `LayerIdValue` явно покрыть проверки пустоты/длины.
[ ] Для `InstanceRevisionValue` явно покрыть safe-int и политику знака: определить отдельно допустимость `0` на snapshot boundary и обязательную положительность для internal scene node.
[ ] Для `OpacityValue`, `PositiveFiniteDoubleValue`, `NonNegativeFiniteDoubleValue`, `FiniteOffsetValue` использовать существующие finite/range semantics, а не придумывать новую математику.

### `lib/src/contract/ids.dart`

[ ] Убрать ситуацию, где `ids.dart` выражает только alias без правил создания и разбора.
[ ] Оставить наружную совместимость на переходном этапе, но ввести фабричный слой поверх `NodeIdValue` и `LayerIdValue`, чтобы новый код больше не создавал id напрямую через "любой String".
[ ] Явно разделить три сценария:
    - parse входного id;
    - generate нового id;
    - validate/recognize legacy-generated id формата `node-<n>` и `layer-<n>`.
[ ] Не ломать существующие `txnNextNodeId()`, `txnNextLayerId()`, `txnInitialNodeIdSeed()` и `txnInitialLayerIdSeed()` на этом шаге; вместо этого подготовить для них migration seam.
[ ] Зафиксировать, где остаётся `String`-совместимость ради API, а где новый код обязан идти через фабрики.

### `lib/src/contract/scene_data_exception.dart`

[ ] Ввести нормализацию `source`, чтобы большие JSON payloads, длинные `svgPathData` и другие oversized values не сохранялись целиком в исключении.
[ ] Сделать усечение и sanitation источника данных детерминированными:
    - ограничить длину строк;
    - безопасно представлять большие коллекции/карты;
    - не терять типовую диагностику для маленьких значений.
[ ] Нормализовать создание ошибки через единый internal constructor/helper, чтобы `code`, `path` и безопасный `source` оформлялись одинаково.
[ ] Сохранить и расширить политику обязательного `path` для boundary-ошибок там, где путь известен:
    - JSON decode;
    - scene build/canonicalization;
    - encode-path;
    - enum parsing вроде `TextAlign`.
[ ] Не превращать `SceneDataException` в контейнер для полного сырого документа; он должен нести диагноз, а не копию входа.

## Конкретизация внедрения по порядку

1. Свести в один список все инварианты, которые уже живут в runtime/model/decode:
   - finite/sign/range;
   - safe-int;
   - длины id/text/fontFamily/svgPathData;
   - legacy id format.
2. Для каждого инварианта пометить, где он уже enforced, а где boundary ещё дырявый:
   - `snapshot/spec/patch`;
   - JSON decode;
   - id generation/parsing;
   - `SceneDataException`.
3. Сначала собрать новый validated layer в `lib/src/contract/validated/**` и общий helper для переиспользуемых primitive checks.
4. Затем подключить `ids.dart` к новым value types, но без насильственной массовой замены всех call sites в репозитории.
5. После этого нормализовать `SceneDataException` и унифицировать safe `source`/`path` policy на decode/build/encode boundary.
6. Завершить шаг только после того, как станет понятно, что следующий шаг может закрывать сырые конструкторы, не изобретая правила заново.

## Критерии приемки

[ ] Для каждого инварианта из шага 2 указано одно место истины: лимит, range-rule или safe-int policy не продублированы бесконтрольно в нескольких слоях.
[ ] `lib/src/contract/validated/**` содержит отдельные value types для id/revision/numeric/text/svg boundary-value сценариев и не сводится к набору несвязанных util-функций.
[ ] Новый boundary-layer покрывает те же проверки, которые уже обязательны в JSON decode-path, для значений `id`, `text`, `fontFamily`, `svgPathData`, `opacity`, finite offsets и revision.
[ ] `ids.dart` больше не оставляет создание новых id на усмотрение любого произвольного `String`, при этом legacy-формат `node-*` / `layer-*` остаётся явно поддержанным и распознаваемым.
[ ] `SceneDataException` больше не хранит целиком oversized `source`, но сохраняет полезные `code`, `message`, `path` и безопасный контекст.
[ ] Ошибки decode/build/encode boundary используют согласованную policy для `path`; существующие сценарии вроде ошибки `TextAlign` не деградируют.
[ ] Шаг подготавливает миграцию на валидированные публичные конструкторы, но сам по себе не требует мгновенного тотального rewrite всех `snapshot/spec/patch` call sites.

## Чеклист выполнения

[ ] Подтвердить полный список инвариантов, которые уже есть в `scene_limits.dart`, decode-пути и model validation.
[ ] Создать `lib/src/contract/validated/**` и общий helper без копипаста primitive checks.
[ ] Реализовать `NodeIdValue` и `LayerIdValue` с parse/generate/legacy-format policy.
[ ] Реализовать `InstanceRevisionValue`, `FiniteOffsetValue`, `PositiveFiniteDoubleValue`, `NonNegativeFiniteDoubleValue`, `OpacityValue`.
[ ] Реализовать `SvgPathDataValue`, `TextContentValue`, `FontFamilyValue` на базе существующих лимитов длины и parse-policy.
[ ] Подключить `lib/src/contract/ids.dart` к новому фабричному слою без мгновенного массового переписывания всех call sites.
[ ] Нормализовать `lib/src/contract/scene_data_exception.dart`, включая усечение и sanitation `source`.
[ ] Зафиксировать policy обязательного `path` для decode/build/encode boundary.
[ ] Добавить тесты на validated values, legacy id format, safe-int, длины и sanitation ошибок.
[ ] Убедиться, что шаг 3 сможет использовать новый validated layer как единственный источник boundary-валидации, а не добавлять ещё один.

