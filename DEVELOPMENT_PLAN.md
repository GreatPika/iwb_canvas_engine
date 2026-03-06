

---

# Шаг 1. Зафиксировать среду, конвейер и правила анализа

## Цель шага

Сначала убрать неопределённость: этот шаг должен не "на всякий случай ужесточить CI", а зафиксировать, какие именно дыры уже есть в среде и конвейере, а затем закрыть их минимальным набором изменений. Базовая стратегия: сначала диагностировать расхождения между локальной политикой из `AGENTS.md`/`README` и реальным репозиторием, затем закрепить это в `pubspec.yaml`, `analysis_options.yaml`, workflow-файлах и bench-tooling без добавления новой "sync glue" логики.

## Что уже подтверждено по текущему состоянию

1. `analysis_options.yaml` сейчас почти пустой: кроме `flutter_lints` и одного правила он не фиксирует строгую политику анализа и не добавляет проектные запреты.
2. `.github/workflows/ci.yaml` уже запускает основные guardrails, но:
   - perf smoke diff остаётся неблокирующим через `|| true`;
   - `example/test/**` не входит в команду форматирования;
   - нет явной отдельной валидации примера как потребителя только публичного API.
3. `.github/workflows/perf_nightly.yaml` тоже оставляет perf diff неблокирующим через `|| true`, а при отсутствии baseline/current отчёта пишет `skipped` вместо падения job.
4. `tool/bench/run_load_profiles.dart` проверяет только факт наличия хотя бы одного кейса, но не доказывает полноту обязательного perf-набора.
5. `tool/bench/diff_load_profiles.dart` умеет показывать пропущенные кейсы и операции, но сам по себе не формулирует fail-fast политику по обязательным кейсам и допустимым порогам деградации.
6. `example/analysis_options.yaml` уже наследует корневой `analysis_options.yaml`, то есть отдельного "дрейфующего" анализа нет.
7. `example/pubspec.yaml` использует path-зависимость на пакет, поэтому проблема не в отдельной версии движка, а в том, что пример недостаточно жёстко встроен в обязательный конвейер проверок.

## Рекомендуемое решение

Рекомендуемый вариант: не добавлять новый orchestration-слой, а довести до строгого и проверяемого состояния уже существующие механизмы.

Почему это лучший вариант:

1. Он использует уже существующие точки контроля: `flutter analyze`, tool checks, benchmark scripts и GitHub Actions.
2. Он убирает ложную "зелёность" CI, где perf-проверки могут фактически не сработать, но job всё равно завершится успешно.
3. Он сохраняет один источник истины:
   - правила анализа живут в `analysis_options.yaml`;
   - обязательные проверки живут в workflow-файлах;
   - состав perf-набора и критерии валидности живут в `tool/bench/**`.
4. Он чище альтернативы с отдельным meta-скриптом-оркестратором, который дублировал бы команды из CI и создавал бы ещё одну точку расхождения.

## Альтернатива, которую не рекомендуется брать

Не рекомендуется вводить отдельный "bootstrap/check_all.dart" или shell-обёртку, которая повторно описывает все проверки и perf-политику вне CI. Это добавит второй источник истины для команд, порогов и обязательных кейсов, а значит быстро приведёт к дрейфу между локальным запуском и GitHub Actions.

## Что именно менять

### `pubspec.yaml`

[ ] Проверить, достаточно ли текущего pin/range для `analyzer` с учётом AST API, которую используют `tool/check_guardrails.dart`, `tool/check_import_boundaries.dart` и связанные tool-tests.
[ ] Если AST-совместимость реально зависит от конкретного minor/patch, сузить constraint `analyzer` до диапазона, который гарантированно проходит tool-checks; если текущий диапазон уже стабилен, явно зафиксировать в плане, что проблема не подтверждена и менять файл не нужно.
[ ] Добавить сюда только те dev-пакеты, без которых нельзя реализовать новые правила анализа или perf-валидацию; не вводить пакеты "на вырост".

### `analysis_options.yaml`

[ ] Перевести файл из минимального состояния в проектную policy-конфигурацию: оставить `flutter_lints` базой и поверх добавить только те правила, которые реально ловят нужные для пакета риски.
[ ] Зафиксировать набор правил против опасных приведений, неявных dynamic-flow и других конструкций, которые маскируют ошибки на публичной границе.
[ ] Добавить правила или validate-through-tool подход, который делает использование внутренних импортов и утечки изменяемых структур видимыми на CI, не дублируя уже существующие guardrails.
[ ] Явно сохранить покрытие `example/**` через общий корневой конфиг; отдельную policy для `example/` не заводить.

### `.github/workflows/ci.yaml`

[ ] Сделать perf smoke diff блокирующим: убрать `|| true` и заменить логику `skipped` на fail-fast, если baseline/current отчёт отсутствует или diff невалиден.
[ ] Расширить формат-check так, чтобы он охватывал `example/test/**`, а не только `example/lib`.
[ ] Явно прогонять проверку примера как потребителя публичного API:
    - либо через `flutter analyze` на общем workspace, если этого достаточно;
    - либо через отдельный шаг, который адресно валидирует `example/lib` и `example/test`.
[ ] Сохранить `tool-tests` условными только по trigger list из `AGENTS.md`, но убедиться, что сам trigger list один-в-один совпадает между документом и workflow.
[ ] Не добавлять в CI параллельный "супер-скрипт"; править существующие job'ы.

### `.github/workflows/perf_nightly.yaml`

[ ] Убрать неблокирующий perf diff и сделать ночной workflow источником достоверного сигнала, а не просто генератором артефактов.
[ ] Заваливать job при неполном отчёте, пропавшем обязательном кейсе, пропавшей обязательной операции или превышении заданного порога деградации.
[ ] Оставить загрузку артефактов `if: always()`, чтобы даже при падении проверки было что анализировать вручную.

### `tool/bench/**`

[ ] В `tool/bench/run_load_profiles.dart` или соседнем вспомогательном модуле формализовать обязательный набор perf-кейсов для `smoke` и `full`.
[ ] В `tool/bench/diff_load_profiles.dart` добавить явную интерпретацию результата:
    - что считается невалидным отчётом;
    - какие missing cases/operations считаются ошибкой;
    - какие пороги по времени и памяти валят процесс.
[ ] Если для этого нужен отдельный конфигурационный файл с perf-порогами, хранить его рядом с `tool/bench/**` как единственный источник истины, а не размазывать пороги по workflow.
[ ] Добавить или обновить tool-tests так, чтобы неполный perf-отчёт, missing case и деградация выше порога воспроизводимо валили проверку.

### `example/**`

[ ] Убедиться, что пример использует только `package:iwb_canvas_engine/iwb_canvas_engine.dart` и не импортирует `src/**`; если проблема уже закрыта существующими guardrails, явно зафиксировать это и не плодить второй такой же механизм.
[ ] Подключить `example/test/widget_test.dart` к обязательным проверкам форматирования и анализа.
[ ] Добавить минимальный smoke-контур для примера только если текущих `flutter analyze` и `flutter test example/test` недостаточно для обнаружения регрессий.

## Конкретизация внедрения по порядку

1. Диагностировать реальное расхождение между документированной политикой проверок и текущими файлами:
   - `pubspec.yaml`
   - `analysis_options.yaml`
   - `.github/workflows/ci.yaml`
   - `.github/workflows/perf_nightly.yaml`
   - `tool/bench/run_load_profiles.dart`
   - `tool/bench/diff_load_profiles.dart`
   - `example/pubspec.yaml`
   - `example/analysis_options.yaml`
2. Для каждого расхождения пометить один из статусов:
   - проблема подтверждена, нужно менять;
   - проблема не подтверждена, шаг плана надо сузить или удалить;
   - нужно дополнительное решение в tool/bench.
3. Сначала править policy и инструменты, потом CI:
   - `analysis_options.yaml`
   - `tool/bench/**`
   - tests для tool/bench
   - workflow-файлы
4. После этого только при необходимости менять `pubspec.yaml`, если выяснится, что без этого AST/tooling не стабилизируются.
5. Завершить шаг только после того, как локальные обязательные команды и CI-логика будут описывать одну и ту же политику.

## Критерии приемки

[ ] Для каждого подпункта шага 1 есть явный результат диагностики: проблема подтверждена или опровергнута, без расплывчатого "наверное нужно".
[ ] `analysis_options.yaml` больше не является формальным минимальным файлом и реально выражает проектную политику анализа.
[ ] CI больше не может завершиться успешно, если perf smoke/nightly отчёт неполный, diff не был проверен или обязательный кейс/операция исчезли.
[ ] Обязательные локальные проверки из проектных инструкций и команды в GitHub Actions совпадают по смыслу и покрытию.
[ ] `example/` входит в обязательный контур анализа и форматирования; решение по тестам/сборке для примера явно принято и зафиксировано.
[ ] Состав обязательных perf-кейсов и пороги деградации находятся в одном месте и автоматически проверяются.
[ ] Для новых правил и perf-политики есть тестовое покрытие на уровне `test/tool/**`, если меняется tooling surface.

## Чеклист выполнения

[ ] Подтвердить или опровергнуть необходимость сужения `analyzer` в `pubspec.yaml`.
[ ] Усилить `analysis_options.yaml` только правилами с высокой полезностью для публичного API и guardrails.
[ ] Сделать perf diff в `.github/workflows/ci.yaml` блокирующим.
[ ] Сделать perf diff в `.github/workflows/perf_nightly.yaml` блокирующим.
[ ] Зафиксировать обязательный набор perf-кейсов и операций в `tool/bench/**`.
[ ] Зафиксировать пороги деградации в одном месте, а не в workflow.
[ ] Подключить `example/test/**` к обязательному форматированию и анализу.
[ ] Проверить и зафиксировать политику "example использует только публичный API".
[ ] Добавить/обновить tool-tests для новой perf-policy и fail-fast сценариев.
[ ] Сверить trigger list tool-tests между `AGENTS.md` и `.github/workflows/ci.yaml`.

---

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

---

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

---

# Шаг 4. Сразу выровнять точный публичный API-контракт

## Цель шага

Этот шаг не про расширение API, а про снятие расхождений между публичной поверхностью пакета и его фактическим поведением. Нужно точно локализовать, где контракт уже корректен, но не зафиксирован явно, а где реально протекают внутренние детали: неточный export-surface, расплывчатые `throws`, неполный `SceneDataException.path`, незафиксированная семантика `TextAlign`, ослабленные return-типы и неявный порядок композиции transform. Делать это нужно через уже существующие public entrypoints, guardrails и тесты, без второго barrel-файла, compat-layer или новой "sync glue" логики.

## Что уже подтверждено по текущему состоянию

1. `lib/iwb_canvas_engine.dart` уже является единственной публичной точкой входа, а инвариант поддерживается `tool/check_guardrails.dart`, `tool/check_public_api_surface.dart` и `test/entrypoints/**`; проблема не в отсутствии barrel, а в точности и устойчивости контракта на этой поверхности.
2. Barrel уже экспортирует `src/model/scene_builder_api.dart` и `src/serialization/scene_codec.dart`, то есть `buildFromSnapshot/buildFromJson` и `encode/decode` уже являются частью внешнего API, а не внутренней детали реализации.
3. В `lib/src/serialization/scene_codec.dart` функция `_textAlignToString(...)` при unsupported `TextAlign` бросает `SceneDataException` с `code` и `source`, но без `path`; это уже конкретная локализованная дыра в encode-path диагностике.
4. В `lib/src/model/scene_builder_api.dart` публичные `buildFromSnapshot(...)` и `buildFromJson(...)` документированы слишком общо и не фиксируют точный `throws`-контракт, хотя фактически являются canonical public import gateway.
5. В `lib/src/controller/commands/draw_commands.dart` методы `writeDrawStroke(...)` и `writeDrawLine(...)` возвращают `String`, хотя внутренний публичный writer-контракт уже работает через `NodeId`; даже при текущем `typedef NodeId = String` это теряет намерение API и будущий migration seam.
6. В `lib/src/controller/scene_writer.dart` `writeSelectionTransform(...)` использует конкретный порядок композиции `delta.multiply(existing.node.transform)`, но этот порядок пока зафиксирован только кодом, а не публичным контрактом и тестами.
7. Guardrails уже защищают single-entrypoint и запрет экспорта mutable-core типов, но шаг должен отдельно подтвердить, что использование `lib/src/**` не закрепляется как поддерживаемый интеграционный путь через docs, tests и public surface tooling.
8. `TextAlign` уже проходит через `snapshot`, `node_spec`, `node_patch`, сериализацию и runtime builder, поэтому здесь нельзя оставлять "полуподдержанную" семантику: нужна одна явная политика на всей публичной границе.

## Рекомендуемое решение

Рекомендуемый вариант: не расширять API и не добавлять новый entrypoint, а сделать текущую публичную поверхность точной, минимальной и проверяемой.

Что это означает на практике:

1. Barrel `lib/iwb_canvas_engine.dart` остаётся единственным публичным входом, а состав экспортов проверяется не вручную, а через существующие guardrails и public API tests.
2. Для codec/builder/writer фиксируется точный контракт: какие типы возвращаются, какие ошибки допустимы, где обязателен `path`, и какая именно семантика считается поддержанной.
3. По `TextAlign` выбирается одна финальная политика и одинаково проводится через `snapshot/spec/patch`, `encode/decode` и runtime builder, чтобы unsupported-case не жил отдельно только в serializer.
4. Все публичные изменения этого шага остаются направленными на ясность контракта, а не на изобретение новых фасадов или "улучшайзинг" структуры пакета.

Почему это лучший вариант:

1. Он устраняет реальный contract drift без добавления второго источника истины в виде нового barrel-файла, адаптерного слоя или отдельного public-wrapper API.
2. Он подготавливает безопасную базу для следующих шагов с validated values и усилением типизации, не ломая пакет массовым рефакторингом публичной поверхности.
3. Он переиспользует уже существующие guardrails, `test/entrypoints/**`, public API surface checks и codec tests вместо параллельной ручной валидации.
4. Он позволяет в каждом пункте явно развести две ситуации:
   - проблема реально подтверждена и код надо менять;
   - проблема не подтверждена, тогда меняется формулировка контракта, тест или guardrail, а не поведение ради самого изменения.

## Альтернатива, которую не рекомендуется брать

Не рекомендуется решать этот шаг через новый `advanced.dart`, отдельный "public facade" поверх существующего API или через чисто документальный проход без проверки реального поведения. Первый вариант создаст второй источник истины для экспортов и контрактов. Второй оставит пользователя с красивой документацией, которая всё ещё может расходиться с фактическим `throws`, `path`, return types и semantics в рантайме.

## Что именно менять

### `lib/iwb_canvas_engine.dart`

[ ] Подтвердить, что barrel экспортирует только поддерживаемые публичные типы и функции, а не внутренние model/runtime детали.
[ ] Проверить, нужен ли экспорт validated types/factories из шага 2 для внешнего контракта; если не нужен, явно зафиксировать, что они остаются внутренним строительным слоем и barrel не расширяется.
[ ] Не допускать экспорта mutable-core типов и прямого нормализованного `src/**` surface сверх уже одобренного списка.
[ ] Если проблема не подтверждается и текущий export list уже корректен, ограничиться фиксацией этого решения в тестах/guardrails, а не менять файл ради косметики.

### `lib/src/serialization/scene_codec.dart`

[ ] Зафиксировать точные `throws`-контракты для `encodeSceneToJson(...)`, `decodeSceneFromJson(...)`, `encodeScene(...)` и `decodeScene(...)`, без расплывчатых формулировок "может бросить ошибку".
[ ] Привести doc comments к реальному поведению: где выполняется canonicalization, какие schema versions принимаются, где именно ожидается `SceneDataException`.
[ ] Для unsupported `TextAlign` на encode-path обеспечить не только корректный `code`, но и заполненный `path`, если путь на этом уровне известен или может быть прокинут без дублирования логики.
[ ] Если `_textAlignToString(...)` остаётся отдельной функцией, либо передавать в неё path-context явно, либо вызывать её только из места, где этот контекст уже определён и может быть инкапсулирован без второй независимой ветки ошибок.
[ ] Подтвердить или опровергнуть, что unsupported `TextAlign` должен отлавливаться именно в codec boundary; если правильнее ловить его раньше на canonicalization boundary, зафиксировать это и убрать двусмысленность контракта.

### `lib/src/model/scene_builder_api.dart`

[ ] Зафиксировать точный публичный контракт `buildFromSnapshot(...)` и `buildFromJson(...)`: что считается валидным входом, когда возвращается канонический `SceneSnapshot`, какие ошибки допустимы и на каком boundary они возникают.
[ ] Явно описать различие между "raw snapshot import" и "raw JSON import", если у них разные пути валидации, canonicalization или диагностики.
[ ] Не оставлять builder как "тонкий хелпер без контракта": раз он экспортируется из barrel, его doc comments и tests должны быть достаточны для внешнего интегратора.

### `lib/src/contract/**` и `lib/src/serialization/**`

[ ] По `TextAlign` выбрать одну финальную стратегию:
    - либо сузить публичный контракт до реально поддерживаемых значений;
    - либо полноценно поддержать весь релевантный набор значений в сериализации и модели.
[ ] Привести эту политику к одному источнику истины в:
    - `snapshot`;
    - `spec`;
    - `patch`;
    - `encode/decode`;
    - `builder/runtime`.
[ ] Зафиксировать единое поведение ошибки на unsupported align:
    - детерминированный `code`;
    - заполненный `path`, когда он известен;
    - одинаковая семантика для всех публичных входов.
[ ] Если после локализации выяснится, что проблема лежит не в `TextAlign`, а в общем расхождении enum-boundary semantics, сузить формулировку шага до реальной проблемы и не раздувать изменение до "переписать все enum-ы".

### `lib/src/controller/commands/draw_commands.dart`

[ ] Вернуть из `writeDrawStroke(...)` и `writeDrawLine(...)` `NodeId`, а не голый `String`, чтобы публичная сигнатура совпадала с writer-контрактом и не теряла смысловой тип.
[ ] Проверить остальные command-layer return types на ту же проблему и менять их только там, где это действительно публичный contract mismatch, а не вкусовщина.

### `lib/src/controller/scene_writer.dart`

[ ] Формально закрепить порядок композиции transform в `writeSelectionTransform(...)`, который сейчас фактически равен `delta.multiply(existing.node.transform)`.
[ ] Зафиксировать этот порядок как публичную семантику в doc comments и тестах, а не как случайную реализацию.
[ ] Подтвердить, нет ли других публичных write-методов, где behavior уже де-факто является контрактом, но пока не зафиксирован явно; если такие места есть, сузить их до минимально необходимого набора и не превращать шаг в общий rewrite всей документации writer-а.

### `tool/check_guardrails.dart` и `test/**`

[ ] Защитить правило "один публичный импортный вход" так, чтобы использование `package:iwb_canvas_engine/src/**` не закреплялось как нормальный контракт интеграции ни в tooling, ни в тестовой поверхности.
[ ] Проверить, достаточно ли текущих `test/entrypoints/**`, `test/public_api/**` и tool-tests, чтобы поймать:
    - лишний экспорт из barrel;
    - рассинхрон public surface;
    - ослабление `NodeId` до `String`;
    - потерю `path` в codec diagnostics;
    - смену порядка transform composition.
[ ] Если существующих тестов уже достаточно для части пунктов, не плодить новые проверки без необходимости; доработать только те, которые закрывают реально неподтверждённые контракты.

## Конкретизация внедрения по порядку

1. Начать с точной инвентаризации публичной поверхности шага:
   - barrel exports;
   - codec functions;
   - `SceneBuilder`;
   - command-layer return types;
   - writer semantics;
   - `TextAlign` boundary path.
2. Для каждого пункта отдельно отметить, проблема подтверждена кодом или нет:
   - если подтверждена, менять реализацию и тест;
   - если не подтверждена, сужать план до явной фиксации контракта через docs/tests/guardrails.
3. Сначала принять одно решение по `TextAlign`, потому что от него зависит и serializer contract, и builder semantics, и набор допустимых doc comments/tests.
4. Затем выровнять barrel и публичные сигнатуры:
   - проверить export list;
   - решить вопрос с validated exports;
   - вернуть `NodeId` в draw commands.
5. После этого выровнять public docs и diagnostics:
   - codec `throws`;
   - builder `throws`;
   - заполненный `path` для unsupported align;
   - единая формулировка supported/unsupported semantics.
6. Затем зафиксировать публичный behavior `writeSelectionTransform(...)` тестом и doc comments, чтобы порядок композиции перестал быть скрытой деталью реализации.
7. Завершать шаг только после того, как публичный API можно описать одной непротиворечивой моделью: barrel/export surface, сигнатуры, `throws`, ошибки и semantics больше не расходятся между собой.

## Критерии приемки

[ ] Для каждого риска внутри Шага 4 явно указано, он подтверждён кодом или опровергнут; в плане не осталось расплывчатых формулировок вида "проверить на всякий случай".
[ ] `lib/iwb_canvas_engine.dart` остаётся единственным публичным root entrypoint и не экспортирует mutable-core или случайные внутренние типы.
[ ] Решение по validated exports принято явно: либо они экспортируются как часть контракта, либо подтверждено, что они остаются внутренним слоем и barrel не расширяется.
[ ] `draw_commands` возвращает смысловой `NodeId` там, где публичный контракт работает с id узла, а не ослабляет его до `String`.
[ ] `SceneBuilder.buildFromSnapshot(...)` и `SceneBuilder.buildFromJson(...)` имеют точный, проверяемый `throws`-контракт и описанную boundary-семантику.
[ ] `encodeScene*` и `decodeScene*` имеют точный, проверяемый `throws`-контракт, совпадающий с фактическим поведением реализации.
[ ] Политика по `TextAlign` едина для `snapshot/spec/patch`, serialization и builder/runtime; unsupported-case не даёт расходящихся сценариев между входами.
[ ] Ошибка на unsupported `TextAlign` имеет детерминированный `code`, а `path` заполнен везде, где boundary уже знает точное расположение значения.
[ ] Порядок композиции в `writeSelectionTransform(...)` зафиксирован как публичная семантика и покрыт тестом.
[ ] Guardrails и public API tests гарантируют, что `src/**` не становится скрыто поддерживаемым публичным контрактом интеграции.

## Чеклист выполнения

[ ] Инвентаризировать текущую публичную поверхность `lib/iwb_canvas_engine.dart`, `scene_codec.dart`, `scene_builder_api.dart`, `draw_commands.dart` и `scene_writer.dart`.
[ ] Для каждого пункта Шага 4 отметить: проблема подтверждена кодом или опровергнута.
[ ] Принять и зафиксировать одно финальное решение по `TextAlign`.
[ ] Проверить, нужен ли export validated-layer из шага 2, и либо добавить его осознанно, либо явно зафиксировать отсутствие такого экспорта как норму.
[ ] Уточнить и при необходимости исправить `throws`-контракты codec entrypoints.
[ ] Уточнить и при необходимости исправить `throws`-контракты `SceneBuilder`.
[ ] Обеспечить заполненный `path` для unsupported `TextAlign` на корректном boundary.
[ ] Вернуть `NodeId` из публичных draw command entrypoints.
[ ] Зафиксировать и протестировать порядок композиции в `writeSelectionTransform(...)`.
[ ] Доработать guardrails и public API tests только там, где они реально не ловят contract drift этого шага.

---

# Шаг 5. Ввести единый `ScenePolicy`

## Создать `lib/src/model/scene_policy.dart`

В нём реализовать:

1. `validateImportSnapshot(...)`
2. `validateRuntimeSnapshot(...)`
3. `validateEncodeSnapshot(...)`
4. `validateNodeSpec(...)`
5. `validateNodePatch(...)`
6. `validateSceneCore(...)`
7. `validateSceneCounts(...)`
8. `validateSceneRanges(...)`
9. `validateSceneIds(...)`
10. `validateTextPolicy(...)`
11. `validateSvgPathPolicy(...)`
12. `validateBackgroundLayerPolicy(...)`

## `lib/src/core/scene_limits.dart`

Сделать:

1. Оставить только константы.
2. Выровнять использование лимитов через `ScenePolicy`.
3. Добавить недостающий лимит размера JSON-входа.

## `lib/src/model/scene_builder.dart`

Сделать:

1. Убрать размазанную валидацию.
2. Перевести:

   * структурную проверку,
   * диапазоны,
   * лимиты,
   * policy background layer
     в `ScenePolicy`.
3. Убрать дублирование владения правилами.

## `lib/src/model/scene_builder_json_require.part.dart`

Сделать:

1. Safe-int проверять:

   * и для `int`,
   * и для `num`.
2. Делегировать в validated-слой и `ScenePolicy`.
3. Закрыть:

   * пустые id,
   * длинные id,
   * длинные строки,
   * длинные path data.

## `lib/src/model/scene_value_validation.dart`

## `lib/src/model/scene_value_validation_primitives.part.dart`

## `lib/src/model/scene_value_validation_node.part.dart`

## `lib/src/model/scene_value_validation_top_level.part.dart`

Сделать:

1. Превратить эти модули во внутренние примитивы `ScenePolicy`, а не во второй независимый источник правил.
2. Добавить:

   * лимиты `kMax*`,
   * политику пустых/длинных id,
   * политику `svgPathData`,
   * политику `TextNodeSnapshot.size`,
   * политику `backgroundLayer`.
3. Убрать **двойной проход** проверки уникальности `NodeId/LayerId`:

   * оставить один владелец проверки уникальности,
   * второй слой либо удалить,
   * либо свести к вызову первого.
4. Добиться одинакового кода и типа ошибки для дублей `NodeId/LayerId` через все публичные входы.

## `lib/src/core/scene.dart`

Сделать:

1. Выбрать одну внутреннюю форму `backgroundLayer`.
2. Убрать плавающую семантику “то null, то обязателен”.
3. Под это привести:

   * builder,
   * serialization,
   * runtime model.
4. Довести до конца политику `ensureBackgroundLayer`.
5. Выбрать судьбу `SceneDataErrorCode.multipleBackgroundLayers`:

   * либо реально реализовать путь, где он выбрасывается, и покрыть тестом,
   * либо удалить как мёртвый код.
6. Зафиксировать одно детерминированное поведение:

   * отсутствие фона,
   * множественность фона,
   * нормализация фона на входе.

---

# Шаг 6. Нормализовать всю внешнюю границу данных и ошибок

## `lib/src/model/scene_builder_api.dart`

Сделать:

1. Обернуть `buildFromJson(...)` в единый `_guardBuild(...)`.
2. Убрать сырой `Map<String, Object?>.from(rawJson)` из незащищённого пути.

## `lib/src/serialization/scene_codec.dart`

Сделать:

1. `decodeSceneFromJson(String)`:

   * лимит размера входа до `jsonDecode`,
   * общий `catch`,
   * нормализация в `SceneDataException`.
2. `decodeScene(Map<String, dynamic>)`:

   * убрать сырой `Map.from(...)` вне guard-слоя.
3. `encodeScene(...)` и `encodeSceneDocument(...)`:

   * прогонять через `encodePolicy`,
   * гарантировать симметрию `encode -> decode`.
4. Ошибки сериализации должны не терять `path`, включая ошибки `TextAlign`.

## Создать `lib/src/serialization/codec_guards.dart`

Реализовать:

1. `_guardDecode`
2. `_guardBuild`
3. `_guardEncode`
4. усечение `source`
5. нормализацию `path`
6. перевод системных исключений в доменные

---

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

---

# Шаг 8. Ввести ядро операций записи

## Создать `lib/src/controller/mutation_op.dart`

Добавить типы операций:

1. `InsertNodeOp`
2. `PatchNodeOp`
3. `DeleteNodeOp`
4. `DeleteNodesBulkOp`
5. `ReplaceSceneOp`
6. `SetBackgroundColorOp`
7. `SetGridEnabledOp`
8. `SetGridCellSizeOp`
9. `SetCameraOffsetOp`
10. `TransformSelectionOp`
11. `TranslateSelectionOp`

## Создать `lib/src/controller/mutation_executor.dart`

Сделать единый маршрут:

1. preconditions
2. apply
3. postcheck
4. changeSet
5. commit preparation

## `lib/src/controller/scene_writer.dart`

Сделать:

1. Перевести write-методы на общий исполнитель операций.
2. Не держать локальные частные правила там, где ими должен владеть `ScenePolicy`.
3. Убрать лишние копии selection и signals.
4. `selectedNodeIds` отдавать как безопасное представление, без лишнего пересоздания.

## `lib/src/controller/scene_controller.dart`

Сделать:

1. `write(...)` перевести на общий исполнитель.
2. Коммит выполнять только после postcheck.
3. `dispose()`:

   * либо запрещён во время write,
   * либо откладывается.
4. Из hot path убрать:

   * debug copies,
   * commit phase copying,
   * лишние списки и клонирования.

---

# Шаг 9. Довести командный слой до правильной сложности и семантики

## `lib/src/controller/commands/draw_commands.dart`

Сделать:

1. `writeDrawStroke(...)`:

   * использовать одну каноническую политику точек,
   * не возвращать список, который потом может быть неожиданно разделён с внешним кодом.
2. `writeEraseNodes(...)`:

   * перейти на bulk delete.
3. Возвращать `NodeId`, а не `String`.

## `lib/src/controller/commands/scene_commands.dart`

Сделать:

1. `writeBackgroundColorSet(...)`
2. `writeGridEnabledSet(...)`
3. `writeGridCellSizeSet(...)`
4. `writeCameraOffsetSet(...)`

Они должны:

* не строить full snapshot до/после;
* использовать `changed`;
* сравнивать уже нормализованное значение;
* не слать ложные сигналы.

## `lib/src/model/document.dart`

Сделать:

1. Все пути удаления перевести на bulk-вариант.
2. Убрать квадратичные маршруты удаления.
3. Для `writeDeleteSelection` не делать полный скан документа, когда выбор маленький и есть локатор.
4. Для патча точек штриха:

   * сначала сравнивать длину и элементы,
   * копировать список только при реальном изменении,
   * **не менять `pointsRevision` на no-op**,
   * **не создавать новый список на no-op**.

## `lib/src/controller/scene_writer.dart`

Сделать:

1. Оптимизировать:

   * `writeDeleteSelection()`
   * `writeSelectionSelectAll()`
   * `writeSelectionTransform()`
   * `writeSignalEnqueue(...)`
2. Убрать лишние проходы.
3. Убрать лишние копии.
4. Закрепить transform order.
5. Закрепить семантику пустой selection replacement.

---

# Шаг 10. Вынести pointer-router в правильную форму

## `lib/src/view/scene_view_interactive.dart`

Сделать:

1. В самом начале `_handlePointerEvent(...)`:

   * отсекать `NaN/Infinity`
   * до:

     * `_captureActivePointer`
     * `handlePointer`
     * `_pointerTracker.handle`
     * `_syncPendingFlushTimer`

2. Исправить `Duration(milliseconds: ...)` через явный `toInt()`.

3. Развести пространства:

   * raw pointer ids
   * internal slot ids

4. Исправить `_resolvePointerId(...)`:

   * удерживаемый raw-pointer сохраняет свой internal id до конца жизни.

5. Изменить reset-политику:

   * нельзя сбрасывать tracking, пока есть хоть один живой raw-pointer.

6. Изменить порядок:

   * сначала release slot,
   * потом reset и очистка таблиц.

7. Убрать линейный поиск минимума в `_acquirePointerSlot()`.

8. Заменить ручное сравнение `PointerInputSettings` по полям на более надёжную схему.

9. `flushPending`:

   * не создавать коллекции, если результат дальше не используется.

10. Проверить `mounted` во всех отложенных путях и слушателях.

11. Пересмотреть смену pointer settings при активном жесте.

---

# Шаг 11. Вынести gesture-machine и единый предикат допустимости

## `lib/src/interactive/scene_controller_interactive.dart`

Сделать:

1. В конструкторе та же валидация `dragStartSlop`, что и в сеттере.
2. Отдельно выбрать и закрепить **одно правило** для:

   * `setDragStartSlop(...)`
   * `pointerSettings.tapSlop`
     если сейчас одно допускает `0`, а другое требует `> 0`.
3. В `handlePointer(...)`:

   * `cancel` не отбрасывается из-за невалидной позиции,
   * `up` с невалидной позицией трактуется как `cancel`.
4. На `down`:

   * фиксировать baseline `dragStartSlop` для текущего жеста.
5. `replaceScene(...)`:

   * отменяет активный жест полностью.
6. `setCameraOffset(...)`:

   * отменяет активный жест полностью.
7. Сохранить монотонность `timestampMs`.
8. Привести preview/commit к одному предикату допустимости.

## `lib/src/interactive/internal/interactive_move_session.dart`

Сделать:

1. Preview использует тот же предикат, что commit:

   * `isLocked`
   * `isTransformable`
   * `isSelectable`
2. На `cancel`:

   * откатить baseline выбора.
3. Убрать дублирующие `onStateChanged`.
4. Логику допустимости держать не в нескольких местах, а в одном.

## `lib/src/interactive/internal/interactive_draw_coordinator.dart`

Сделать:

1. Допустимость удаления и рисования привести к общей политике.
2. Проверить восстановление после безопасного `cancel`.

## `lib/src/interactive/internal/interactive_draw_line_engine.dart`

Сделать:

1. Пересмотреть таймеры и pending-state при cancel и при смене сцены.
2. Не допускать утечки активной pending-линии после общего сброса интерактива.

## Создать `lib/src/interactive/interaction_eligibility_policy.dart`

Добавить:

1. `canSelect(...)`
2. `canPreviewMove(...)`
3. `canCommitMove(...)`
4. `canDelete(...)`
5. `canTransform(...)`

Этим модулем должны пользоваться:

* interactive move
* selection
* delete
* writer/runtime, где релевантно

---

# Шаг 12. Перевести рендер и кеши на структурно безопасную форму

## Создать `lib/src/render/canvas_scope.dart`

Добавить:

1. `withSave(...)`
2. `withTranslate(...)`
3. `withTransform(...)`

## `lib/src/render/scene_painter.dart`

Сделать:

1. Перевести все `save/restore` на `canvas_scope.dart`.
2. Убрать повторные запросы в геометрический кеш в пределах одного кадра.
3. Использовать единый генератор линий сетки.
4. Добавить гистерезис на пороге плотности.
5. Проверить политику `previewDelta`.

## `lib/src/render/cache/scene_static_layer_cache.dart`

Сделать:

1. Сетка должна использовать ту же реализацию, что и painter.
2. Убрать дублирование алгоритма.

## `lib/src/render/cache/scene_text_layout_cache.dart`

Сделать:

1. Убрать цвет из ключа, если цвет не влияет на layout.
2. Перепроверить состав ключа layout.

## `lib/src/render/cache/scene_path_metrics_cache.dart`

## `lib/src/render/cache/scene_stroke_path_cache.dart`

## `lib/src/render/cache/scene_render_caches.dart`

Сделать:

1. Перевести ключи на новую ревизионную политику.
2. Защитить внутреннее содержимое от внешней мутации.
3. Прописать явную политику для невалидных transform.

## `tool/invariant_registry.dart`

Добавить:

1. Инвариант инвалидирования `PathNode` cache.
2. Инвариант контракта ревизий.
3. Инвариант монотонности timestamp.
4. Инвариант неизменяемости `ClearSceneResult`.

---

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

---

# Шаг 14. Закрыть тестами и невозвратом все этапы

## `test/serialization/**`

Добавить и обновить:

1. bad map → всегда `SceneDataException`
2. huge JSON → доменная ошибка до `jsonDecode`
3. safe-int для `int`
4. unsupported schema version → правильный `code`
5. `TextAlign` по финальной политике
6. unsupported align → заполненный `path`
7. пустые и длинные id
8. симметрия `encode -> decode`

## `test/model/**`

Добавить и обновить:

1. policy `backgroundLayer`
2. `TextNodeSnapshot.size`
3. лимиты `kMax*` не только на JSON-пути
4. legacy id format reading
5. revision policy
6. отсутствие двойной проверки уникальности с расхождением по ошибкам
7. выбранная судьба `multipleBackgroundLayers`
8. выбранная судьба `ensureBackgroundLayer`

## `test/controller/**`

Добавить и обновить:

1. `writeSelectionReplace([])` по финальной семантике
2. bulk delete для всех путей
3. transform composition order
4. `dispose()` во время write
5. неизменяемость `ClearSceneResult`
6. no-op patch точек:

   * не копирует список,
   * не меняет `pointsRevision`

## `test/interactive/**`

Добавить и обновить:

1. `dragStartSlop` constructor validation
2. `dragStartSlop` frozen on down
3. invalid `up/cancel`
4. cancel rollback of selection baseline
5. replaceScene cancels active gesture
6. setCameraOffset cancels active gesture
7. monotonic timestamp
8. preview/commit parity for locked/untransformable nodes
9. единое правило для `dragStartSlop` и `tapSlop = 0`

## `test/view/**`

Добавить и обновить:

1. invalid pointer filtered before side effects
2. slot release order
3. raw-id/slot-id separation
4. no reset while raw pointers alive
5. mounted guard
6. no useless collections on flush path

## `test/render/**`

Добавить и обновить:

1. save/restore integrity
2. grid line generation bounded by actual step
3. same grid algorithm in painter and static cache
4. no color in text layout cache key if layout unchanged
5. path cache invalidation invariant
6. revision contract for caches

## `test/core/**`

Добавить и обновить:

1. validated value types
2. id factories
3. revision policy
4. one-owner defaults

---

# Финальный критерий готовности

Работа закончена только когда для **каждой** проблемы из этапов 0–10 выполнены одновременно три вещи:

1. изменён конкретный файл,
2. применён конкретный механизм закрытия,
3. есть конкретный тест, guardrail или CI-проверка, которая не даст проблеме вернуться.

Если хочешь, следующим сообщением я превращу **этот уже исправленный план** в самый жёсткий формат:
**по каждому файлу — список точных правок внутри файла**, без фаз и без абстракций.
