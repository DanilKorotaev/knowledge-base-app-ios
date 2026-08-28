# UX: Structured UI / chat fullscreen image viewer (zoom & share)

**Status:** pending  
**Vault:** `Документация/Задачи/task-structured-ui-next.md`  
**Scope:** iOS (`FullscreenImageViewer`, SUI `image` tap, chat attachment grid)

## Problem

Сейчас тап по картинке (вложение в чате или нода `image` в Structured UI) открывает **fullscreen sheet снизу вверх**: чёрный фон, `scaledToFit`, крестик закрытия. Работает, но это MVP:

- нет pinch-to-zoom / pan по `ScrollView` или `UIScrollView`
- нет double-tap zoom
- нет Share (`UIActivityViewController` / `ShareLink`)
- нет Save to Photos (опционально)
- нет индикатора загрузки для больших remote-изображений в fullscreen

## Done when

- [ ] Единый viewer для chat attachments и Structured UI `image` (не дублировать логику)
- [ ] Zoom: pinch + double-tap; pan когда zoom > 1
- [ ] Toolbar: Close, Share (минимум); опционально Save
- [ ] Safe area / Dynamic Island; VoiceOver labels
- [ ] Unit/UI smoke: открытие viewer из SUI image node

## Notes

Текущая реализация: `AttachmentImageGrid.swift` → `FullscreenImageViewer`.  
Не путать с Quick Look для `file` нод — там отдельный путь.

## References

- `KnowledgeBaseApp/Views/Chat/AttachmentImageGrid.swift`
- `KnowledgeBaseApp/Views/Chat/StructuredUIMediaNodes.swift`
