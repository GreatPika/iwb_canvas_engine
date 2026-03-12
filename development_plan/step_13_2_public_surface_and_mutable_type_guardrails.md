language: russian

# Шаг 13.2. Ужесточить public/export guardrails, mutable type leak scan и single-entry discipline

## Цель шага

После `13.1` structural import topology уже должна быть закрыта, но сам public
surface всё ещё останется уязвимым, если `tool/check_guardrails.dart`
продолжит пропускать части exported/runtime signatures:

- `interactive` и `view` сейчас частично обходят export scan через `skip`;
- mutable runtime types всё ещё можно протащить в сигнатуры как «почти
  допустимый» API surface;
- правило «один публичный вход» может быть ослаблено новыми public entrypoint-ами
  или обходами через несогласованный export surface.

Задача подшага: сделать `tool/check_guardrails.dart` owner-ом public/export
guardrails и mutable type leak detection в signatures без смешивания с semantic
AST-проверками `13.3`.

## Что уже подтверждено по текущему состоянию

1. [check_guardrails.dart](/Users/blackpika/iwb_canvas_engine/tool/check_guardrails.dart)
   уже содержит exported API scan policy и guardrail mutable core type names.
2. Там же `interactive` и `view` сейчас идут через `skip`-политику для части
   surface, что оставляет неполный coverage public/export signatures.
3. Single-public-entry rule уже существует как invariant, но исходный шаг
   прямо требует его дополнительно защитить от обходов.
4. Public/export checks и semantic AST checks живут в одном tool-файле, но это
   не означает, что они должны иметь один ownership.

## Зафиксированные решения (без повторного обсуждения в реализации)

1. `13.2` владеет только signature/public surface checks в
   `tool/check_guardrails.dart`.
2. `interactive` и `view` больше не могут оставаться в полном `skip`, если
   конкретный surface реально можно и нужно просканировать как exported API.
   Исключения допустимы только точечные и мотивированные.
3. Guardrail mutable type leak-ов проверяет именно сигнатуры exported/runtime
   API и не подменяет semantic mutation checks `13.3`.
4. Правило «один публичный вход» остаётся owner-ом этого подшага:
   public surface должен оставаться выровненным на sanctioned entrypoint-ы и
   не открывать обходные export-пути.
5. Этот подшаг не решает:
   - write-only mutation semantics;
   - epoch invalidation semantics;
   - `SceneDataException` factory-only throw policy;
   - invariant registry/coverage.

## Граница шага

- In:
  - exported/runtime signature scan;
  - mutable type leak detection в сигнатурах;
  - `skip`-policy для `interactive` и `view`;
  - single-public-entrypoint discipline.
- Out:
  - import topology;
  - semantic AST guardrails;
  - invariant ids и coverage proof contract;
  - line coverage allow-list.

## Точная реализация, которую должен описывать код

1. Exported API scan policy в `check_guardrails.dart` различает:
   - full scan;
   - точечный skip с жёстко объяснённой причиной;
   - запрещённый полный blind spot.
2. `interactive` и `view` после подшага либо реально сканируются, либо имеют
   минимальные целевые исключения вместо broad skip.
3. Mutable runtime/core types не могут появляться в exported/runtime
   signatures там, где публичный contract обязан оставаться immutable/value-safe.
4. Проверка single public entrypoint ловит как прямые, так и обходные способы
   открыть дополнительный public surface.
5. Подшаг не меняет detection rules write-only mutation или epoch invalidation;
   это остаётся ownership `13.3`.

## Последовательность реализации (только действия)

- [x] Убрать broad `skip` для `interactive` и `view`, оставив только
      минимально обоснованные исключения.
- [x] Довести scan exported/runtime signatures до полного покрытия нужного
      public surface.
- [x] Ужесточить guardrail mutable type leak-ов в сигнатурах.
- [x] Защитить правило «один публичный вход» от обходов через export surface.
- [x] Не смешивать эти проверки с semantic AST-rules шага `13.3`.

## Критерии приёмки

- [x] `tool/check_guardrails.dart` является owner-ом public/export guardrails,
      но не semantic mutation/epoch checks.
- [x] `interactive` и `view` больше не имеют необоснованного blind skip для
      surface, который может быть просканирован.
- [x] Утечка изменяемых типов в exported/runtime signatures приводит к
      tool failure.
- [x] Single-public-entry rule защищён от обходных export/public entrypoint-ов.
- [x] Подшаг не вводит semantic AST rules для write-only mutation,
      `controllerEpoch` или `SceneDataException`; это остаётся `13.3`.
- [x] Повторная диагностика
      `dcm calculate-metrics tool/check_guardrails.dart test/tool/guardrails_layout_and_entrypoints_tool_test.dart test/tool/guardrails_public_contracts_tool_test.dart test/tool/guardrails_interactive_api_tool_test.dart --report-all`
      приложена к результату шага; новые или step-owned methods не содержат
      `HIGH`/`VERY HIGH` по `cyclomatic-complexity`,
      `maximum-nesting-level` и `source-lines-of-code`, а целевой предел
      остаётся `10 / 4 / 40`.

## Тестовый контур шага

- [x] `test/tool/guardrails_public_contracts_tool_test.dart` с отрицательным
      сценарием на утечку `Scene` или другого mutable runtime type в public
      signature
- [x] `test/tool/guardrails_interactive_api_tool_test.dart` как regression
      guard, что `interactive` surface больше не выпадает из scan-а
- [x] `test/tool/guardrails_layout_and_entrypoints_tool_test.dart` с
      отрицательным сценарием на нарушение single-public-entry discipline
- [x] `test/tool/support/public_entrypoint_contract.dart` обновляется только
      как test fixture public surface, а не как второй owner policy

## Диагностика шага

- [x] До завершения подшага приложен `dcm calculate-metrics`-отчёт по
      `tool/check_guardrails.dart` и связанным step-owned tool tests.
- [x] Signature-scan helper-ы и новые exported-surface predicates
      укладываются в предел `10 / 4 / 40`.
- [x] Ни один hotspot в `tool/check_guardrails.dart`, относящийся к public
      surface scan, не остаётся «ничьим» между `13.2` и `13.3`.
