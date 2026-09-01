# Bug: отправка голоса/вложений из композера падает, после reopen работает только текст

**Статус:** 🟡 частично исправлено (2026-07-06)  
**Приоритет:** Высокий  
**Категория:** Баг, композер, голос

## Симптомы (репорт пользователя)

1. Записал голос → транскрибация ок → **сразу** «не удалось отправить сообщение».
2. В чате появляется bubble, но **пустой** (место есть, контента нет).
3. Повторная отправка с голосовым вложением — снова ошибка.
4. Закрыл чат → открыл снова: в поле ввода **только текст**, голоса нет → текст **уходит успешно**.
5. То же с **скриншотами**: с attachment — ошибка; убрал attachment — отправилось.

## Корневая причина (найдена)

`detachComposerForSend()` при старте отправки вызывал `composerDraftStore.clear(sessionId:)`, который **удалял каталог черновика вместе с файлами** (голос, фото), пока upload ещё читал те же URL из snapshot маршрута.

Цепочка:

```
sendComposed() → route(draft) → detachComposerForSend() → clear disk draft
→ streamVoiceMessage / multipartComposeBody → Data(contentsOf: deleted URL) → fail
→ restore draft in memory (мёртвые пути) → retry снова fail
→ reopen chat → из store только text (voice files уже удалены)
```

Связано с доработками **composer draft persistence** и **detach UI при send** (voice retry / Telegram composer).

## Исправление v1 (в коде)

- [x] **Не** вызывать `composerDraftStore.clear` в `detachComposerForSend` — только очистка in-memory UI.
- [x] Очистка store только в `clearSavedComposerDraft()` после **успешной** отправки.
- [x] Удалять optimistic bubbles (`kb-optimistic-*`) при ошибке send.
- [x] Тест `testFailedSendKeepsDraftStoreFilesForRetry`.

## Осталось / follow-up

- [ ] Inline retry UI вместо alert «не удалось отправить» (см. `task-ux-voice-transcription-retry-without-loss` — send path).
- [ ] Улучшить `VoicePipelineErrorMessage.forSend` — показывать `apiMessage` с бэкенда, не только generic.
- [ ] Security-scoped read для attachment URL при compose (если останутся кейсы без копии в draft store).
- [ ] E2E на устройстве: голос + 2 фото → send → retry без reopen.

## Файлы

- `KnowledgeBaseApp/ViewModels/ChatViewModel.swift` — `detachComposerForSend`, send error paths
- `KnowledgeBaseApp/Services/ComposerDraftStore.swift`
- `KnowledgeBaseAppTests/ComposerDraftStoreTests.swift`
