# Feature: метаданные версии iOS-клиента в API-запросах

**Статус:** Реализовано — 2026-08-26  
**Приоритет:** Средний  
**Категория:** Observability, API, поддержка

**Зависит от:** `task-ops-semver-versioning-changelog-gitflow.md` (completed 2026-08-26) — SemVer in `VERSION` now feeds marketing version / headers.

## Зачем

При багах вроде «отправка с вложениями падает» ассистент и бэкенд должны видеть **какая сборка** приложения у пользователя, без уточняющих вопросов.

Сейчас `appVersion` уходит только в `registerDevice` (push). Обычные chat/compose запросы **не** несут версию клиента.

## Предложение

### HTTP-заголовки (все запросы KB App API)

| Заголовок | Пример | Источник |
|-----------|--------|----------|
| `X-KB-App-Version` | `1.2.0` | `CFBundleShortVersionString` |
| `X-KB-App-Build` | `42` | `CFBundleVersion` |
| `X-KB-App-Platform` | `ios` | константа |
| `X-KB-App-OS` | `18.5` | `UIDevice.current.systemVersion` |

Опционально: `User-Agent: KnowledgeBaseApp/1.2.0 (iOS 18.5; build 42)`.

### iOS

- [x] `KBClientMetadata` — единый provider (version, build, os).
- [x] Добавить заголовки в `KBRequestInterceptor` / `KBHTTPTransport`.
- [x] Заголовки на всех запросах через `KBHTTPTransport` (Alamofire + SSE bytes) (compose/multipart path).
- [x] Unit-тест: adapt request содержит заголовки.

### Backend (`kb_app_api`)

- [x] Middleware: `request.state.client_meta` + log на POST.
- [x] Логировать client_meta для mutating `/api/*`.
- [ ] Опционально: сохранять `client_version` в таблице messages (низкий приоритет).
- [ ] Обновить `KB_APP_API_CONTRACT.md` / OpenAPI.

### Settings (опционально)

Показать версию+build в «О приложении» (если ещё нет) — чтобы пользователь мог продиктовать.

## Критерии приёмки

1. Любой POST чата в логах сервера содержит version/build клиента.
2. Не ломает существующие клиенты (заголовки optional на бэкенде).
3. E2E тест или smoke проверяет наличие заголовка.

## Связанные файлы

- `KnowledgeBaseApp/Networking/KBRequestInterceptor.swift`
- `KnowledgeBaseApp/Networking/KBHTTPTransport.swift`
- `KnowledgeBaseApp/Services/KnowledgeBaseAPIClient.swift`
- `knowledge-base-bot/kb_app_api/`
