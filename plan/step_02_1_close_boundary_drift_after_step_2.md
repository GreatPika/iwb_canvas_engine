language: russian

# Шаг 2.1. Закрыть boundary-drift после шага 2

## Цель шага

Не заходя в шаг 3, добить оставшиеся дыры шага 2 так, чтобы у boundary-правил снова был один владелец. После этого `contract/validated/**` должен владеть `imageId`, canonical generated-id recognition и scalar numeric boundary-семантикой, а `model/` и JSON decode должны только переиспользовать этот слой с правильным `field/path` контекстом.

## Что закрывает этот шаг

1. `ImageIdValue` становится публичной частью validated boundary-layer и повторяет текущий контракт `imageId`:
   - обязательная строка;
   - `maxLength == kMaxImageIdLength`;
   - пустая строка остаётся допустимой, пока публичный контракт её не запрещает.
2. `imageId` проходит через один и тот же validated owner во всех уже существующих step-2 seams:
   - JSON decode;
   - snapshot validation;
   - runtime scene validation;
   - spec validation;
   - patch validation.
3. Legacy generated ids остаются `node-<n>` / `layer-<n>`, но распознавание становится строго canonical-only:
   - `node-0`, `node-7`, `layer-12` распознаются;
   - `node-01`, `layer-0007` и другие неканоничные формы не считаются generated ids.
4. Scalar numeric boundary rules получают одного владельца:
   - safe-int;
   - finite double;
   - non-negative double;
   - positive double;
   - opacity.
5. `scene_builder_json_require.part.dart` сохраняет только structural JSON plumbing и больше не держит вторую реализацию тех же numeric правил.

## Итог реализации

1. Добавлен публичный `ImageIdValue` и экспортирован через `validated.dart`.
2. `validatedTryParseGeneratedSeed(...)` больше не принимает leading-zero и другие неканоничные seed-формы.
3. Runtime/model validation для `snapshot/spec/patch` и JSON decode-path теперь используют тот же validated owner для `imageId`.
4. Scalar numeric validation в `scene_value_validation*.part.dart` и JSON require helpers сведена к вызовам validated helpers вместо локальной дублирующей логики.
5. Документация, changelog, roadmap и public API golden отражают новый boundary contract.

## Критерии приемки

[x] `ImageIdValue` доступен в публичном validated surface.
[x] Oversized `imageId` одинаково отсекается на decode/build/runtime/spec/patch boundary.
[x] Generated-id recognition симметричен генератору и не принимает leading-zero формы.
[x] Scalar numeric boundary rules больше не живут независимыми копиями в validated layer и JSON/model seams.
[x] Step 3 не расширен: публичные поля `imageId`, numeric scalars и constructors остаются `String`/`double`-совместимыми.
