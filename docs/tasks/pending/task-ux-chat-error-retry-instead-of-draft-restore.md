# UX: ошибка ответа — Retry на bubble, без возврата текста в композер

**Статус:** Запланировано  
**Приоритет:** Высокий  
**Категория:** UX чата, ошибки, composer draft

## Проблема

После отправки бывают сценарии:

1. **Сервер записал в чат сообщение-ошибку** («произошла ошибка, обратитесь к администратору») — пайплайн формально «завершён», ошибка уже в ленте.
2. **Таймаут / обрыв клиента**, после чего ответ всё же появляется (или ошибка уже в истории).

Сейчас клиент часто:

- считает send failed;
- **восстанавливает черновик** в поле ввода (`composerDraft = draft` + `scheduleComposerDraftSave`);
- пользователю приходится вручную чистить композер, хотя сообщение уже «ушло» / ответ (пусть ошибочный) уже в чате.

Это неудобно: композер захламляется старым текстом.

## Цель

- Если пользовательский запрос уже принят / в ленте есть соответствующий user (+ assistant error или финальный ответ) — **не возвращать текст в input**.
- Для recoverable failure показать **кнопку «Повторить» на bubble** (user или assistant-error), а не наполнять композер.
- Поле ввода остаётся пустым (как после успешного detach), пока пользователь сам не начнёт новый ввод.

## Предлагаемый подход (анализ)

Разделить исходы send:

| Исход | Композер | Bubble |
|-------|----------|--------|
| Успех (assistant OK) | clear draft store | обычный |
| Серверная ошибка **как сообщение в чате** | clear draft | опционально Retry / «спросить снова» |
| Клиентский fail **до** принятия (нет user в БД) | можно вернуть draft **или** Retry на optimistic | Retry предпочтительнее |
| SSE drop, но reply still in flight | **не** restore draft | см. resume-streaming task |

Конкретно:

1. После catch: если `resumeAwaitingReplyIfNeeded()` / reload показывает assistant (в т.ч. error text) — `clearSavedComposerDraft()`, без restore в UI.
2. Классифицировать assistant content как `isPipelineErrorMessage` (эвристика / `error.code` с API, если появится).
3. UI: `Retry` на user bubble или на error-assistant → повторный send того же payload (хранить last sent snapshot отдельно от «живого» draft).
4. Не путать с voice transcription retry (`task-ux-voice-transcription-retry-without-loss` — уже про запись до send).

## Acceptance

- [ ] Серверная ошибка в ленте → input пустой, draft на диске очищен.
- [ ] Таймаут SSE при уже принятом user → нет автозаполнения композера старым текстом.
- [ ] Есть кнопка «Повторить» для последнего failed/error turn; повтор создаёт новый запрос без ручного copy-paste из input.
- [ ] Реальный fail «не дошло до сервера» — Retry или явный restore draft (зафиксировать один UX в реализации).
- [ ] Тест: mock stream fail + messages already contain assistant error → composer empty.

## Затронутые файлы (ориентир)

- `ChatViewModel.swift` — catch в `sendStreamingText` / `sendSingleVoice` / `sendComposedMessage`
- `ComposerDraftStore` / `clearSavedComposerDraft`
- `RichMessageBubbleView` / новый `MessageRetryBar`
- опционально API: структурированный `error` в assistant message (backend task)

## Связанные задачи

- `task-ux-chat-resume-streaming-after-background.md`
- `task-bug-composer-send-voice-attachments-failure.md`
- `task-ux-voice-transcription-retry-without-loss.md` (completed)
