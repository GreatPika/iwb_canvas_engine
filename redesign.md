## 9. Action events объявляем notification stream, не undo/redo

**Проблема:** payloads action events не содержат enough data для полноценного undo/redo.

**Решение:** меняем контракт и названия.

```text
CanvasActionCommitted is a user-action notification stream.
It is not an undo/redo journal.
Undo/redo is application-owned.
```

Публичные события оставляем для:

```text
analytics
application notifications
toolbar state
domain reactions
external logging
```

Переименовать документационную формулировку:

```text
app's undo/redo action stream
```

в:

```text
app's user-action notification stream
```

Payloads не расширяем до inverse patches в v1.

**Итог:** API не обещает историю изменений там, где её нет.

---

# Две обязательные правки без отдельного редизайна

## 10. Operation matrix переводим на field-effect taxonomy

**Проблема:** строки вида `update visual only` и `update geometry/transform` слишком грубые. Реальная логика зависит от конкретного поля.

**Решение:** вводим центральную таблицу эффектов полей и один compiler.

```text
UpdateEffectCompiler
  input: element update DTO
  output: typed effects
```

Пример field taxonomy:

```text
opacity:
  elementVisualRevision
  repaint main
  no spatial

transform:
  boundsRevision
  elementVisualRevision
  spatial touched
  repaint main

hitPadding:
  boundsRevision
  spatial touched
  repaint none

isVisible:
  elementVisualRevision
  spatial touched
  repaint main
  selection normalization

isSelectable:
  selection normalization
  no document visual repaint

text:
  boundsRevision
  elementVisualRevision
  spatial touched
  repaint main

fontSize:
  boundsRevision
  elementVisualRevision
  spatial touched
  repaint main

resourceId:
  elementVisualRevision
  resource reference validation
  repaint main

metadata:
  projectionRevision
  no repaint by default
```

**Итог:** effects вычисляются единым способом, а не размазываются по handlers.

---

## 11. Non-invertible transform fallback убираем

**Проблема:** если transform должен быть invertible, coarse fallback для non-invertible transform скрывает corrupted state.

**Решение:** non-invertible transform запрещён на всех входах.

```text
public DTO construction rejects non-invertible transform
decode rejects non-invertible transform
edit update rejects non-invertible transform
loadDocument rejects non-invertible transform
```

Runtime corrupted row policy:

```text
non-invertible row is excluded from exact hit-test
diagnostic record emitted
no coarse candidate fallback
```

**Итог:** corrupted geometry не превращается в странные попадания.

---
