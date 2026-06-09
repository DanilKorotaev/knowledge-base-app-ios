# E2E (интеграционные тесты против реального API)

Тесты в `KnowledgeBaseAppTests/KnowledgeBaseAPIE2ETests.swift` ходят в развёрнутый **KB App API** по HTTPS. Без переменных окружения они **пропускаются** (`XCTSkip`), чтобы обычный `xcodebuild test` и CI оставались зелёными без секретов.

## Переменные

| Переменная | Назначение |
|------------|------------|
| `KB_E2E_API_BASE_URL` | Базовый URL без завершающего слэша, например `https://kb-api.example.com` |
| `KB_E2E_API_TOKEN` | Bearer-токен для `GET/POST /api/sessions` и сообщений |

Отдельно от префикса `KBAPP_`, который использует само приложение в рантайме.

**Локально после `./scripts/sync-secrets-xcconfig.sh`:** тестовый таргет подхватывает те же значения из `Config/Secrets.xcconfig` (через Info.plist). Явные `KB_E2E_*` в Scheme по-прежнему имеют приоритет.

Запросы E2E отправляют заголовок **`X-KB-App-E2E: 1`** — на сервере сессии создаются под `KB_APP_API_TEST_TELEGRAM_ID`, а не под `KB_APP_API_TELEGRAM_ID` владельца приложения.

## Запуск из Xcode

1. Выполните `./scripts/sync-secrets-xcconfig.sh` (или задайте `KB_E2E_*` вручную).
2. **Product → Scheme → Edit Scheme… → Test → Arguments** — опционально `KB_E2E_API_BASE_URL` / `KB_E2E_API_TOKEN`.
3. Запустите тесты (⌘U) или только `KnowledgeBaseAPIE2ETests`.

## Запуск из терминала

Переменные должны быть видны процессу `xcodebuild` (обычно наследуются тест-раннером):

```bash
cd /path/to/knowledge-base-app-ios
export KB_E2E_API_BASE_URL="https://your-api.example.com"
export KB_E2E_API_TOKEN="your-bearer-token"
xcodebuild test -scheme KnowledgeBaseApp -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:KnowledgeBaseAppTests/KnowledgeBaseAPIE2ETests
```

Подставьте актуальное имя симулятора (`xcrun simctl list devices available`).

## Что проверяется

- `GET /health` без заголовка `Authorization` (ожидается HTTP 200).
- С токеном: `POST /api/sessions`, `GET /api/sessions`, `POST …/sessions/{id}/messages` с `use_knowledge_base: false` (быстрый ответ без обхода базы знаний на стороне сервера, если так настроено).

## Ограничения

- Не заменяет ручной прогон UI, голоса и виджетов на устройстве.
- Нужен доступ с машины, где запускаются тесты, до указанного URL (VPN/allowlist).

**Roadmap:** расширение покрытия (SSE, voice, compose) — [task-backend-kb-app-api-sync.md](../tasks/pending/task-backend-kb-app-api-sync.md).
