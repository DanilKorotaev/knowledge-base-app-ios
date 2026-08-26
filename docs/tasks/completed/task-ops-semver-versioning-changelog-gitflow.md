# Ops: SemVer, changelog и git-flow для iOS-сборок

**Статус:** Completed (2026-08-26) — variant A files + **auto PATCH on main→TestFlight** (no PR required)  
**Приоритет:** Средний–высокий  
**Категория:** Ops / CI / релизный процесс

**Связи:** `task-feature-api-client-version-metadata.md`, `docs/FASTLANE.md`, `docs/RELEASE_PROCESS.md`, `.github/workflows/deploy-testflight.yml`, `fastlane/Fastfile`, `project.yml`.

---

## Проблема

Сейчас в TestFlight и на устройстве:

| Поле | Поведение сегодня |
|------|-------------------|
| **Marketing version** (`CFBundleShortVersionString`) | Почти не меняется (в `project.yml` зафиксировано `0.1.0`; в UI пользователь видит **1.0** — расхождение с источником правды) |
| **Build** (`CFBundleVersion`) | Только `GITHUB_RUN_NUMBER` в lane `beta` (`increment_build_number`) |

Итог:

- По номеру сборки в TestFlight нельзя понять, **какой код** внутри, если не смотреть commit SHA вручную.
- В git **нет** истории «версия X = коммит Y + список изменений».
- ИИ-ассистент не может сопоставить репорт пользователя с конкретным diff без build number → commit mapping.
- Задача `task-feature-api-client-version-metadata` бесполезна, пока marketing version статична.

---

## Цель

1. **SemVer в git** — patch (и при необходимости minor/major) отражается в репозитории и в приложении.
2. **Changelog** — человекочитаемая история изменений по версиям.
3. **Трассируемость** — по `1.2.3 (build 412)` можно найти commit, тег и список изменений в репо.
4. **CI** — TestFlight по-прежнему автоматический; версионирование встроено в pipeline без ручной рутины на каждый фикс.

---

## Рекомендуемая модель версий

### Два числа Apple (оставляем оба)

- **Marketing version** — SemVer `MAJOR.MINOR.PATCH` (то, что видит пользователь и что шлём в `X-KB-App-Version`).
- **Build number** — монотонный integer (оставить **`GITHUB_RUN_NUMBER`** или ASC build; не смешивать с patch).

### Когда bump какой сегмент

| Событие | Bump | Кто |
|---------|------|-----|
| Обычный merge в `main` (fix, фича) | **PATCH** +1 | CI автоматически *или* автор PR вручную |
| Заметный релиз (новый экран, breaking API) | **MINOR** +1, PATCH=0 | Автор PR (чеклист) |
| Редкий breaking / смена контракта | **MAJOR** | Явное решение в PR |

**Не** bump patch на каждый push в feature-ветку — только на merge в `main` (иначе шум и конфликты).

---

## Варианты реализации (выбор)

### Вариант A — «Версия в PR» (рекомендуется для старта)

**Источник правды:** файл `VERSION` в корне репо (например `1.2.3`) + `CHANGELOG.md` (Keep a Changelog).

Workflow:

1. В PR автор при user-facing изменениях:
   - правит `VERSION` (patch/minor по правилам выше);
   - добавляет запись в `CHANGELOG.md` → секция `[Unreleased]` или новая версия.
2. CI **проверяет**: если менялся код приложения (`KnowledgeBaseApp/`, `Shared*/`), то `VERSION` должен отличаться от `main` (или есть changelog entry).
3. `fastlane beta` читает `VERSION` → `increment_version_number` / `update_info_plist` / sync в `project.yml` перед archive.
4. После успешного TestFlight — git tag `ios/v1.2.3` на merge commit.

**Плюсы:** осмысленный changelog, нет bot-коммитов, ИИ читает git напрямую.  
**Минусы:** дисциплина в PR; забыли bump — CI красный.

### Вариант B — «CI bump patch на каждый deploy»

После green CI на `main`, до `fastlane beta`:

1. Скрипт `scripts/ci/bump_patch_version.py` увеличивает PATCH в `VERSION`, дописывает в `CHANGELOG.md` заголовок версии + commit messages с последнего тега.
2. Bot commit `[skip ci] chore: release 1.2.4` + push.
3. Deploy workflow перезапускается или продолжает с новым SHA.

**Плюсы:** patch всегда синхронен с TestFlight.  
**Минусы:** шумные коммиты, слабый changelog без conventional commits, гонки при concurrent deploy.

### Вариант C — CalVer / build-only marketing

`MARKETING_VERSION = 2026.7.6` или `0.1.{GITHUB_RUN_NUMBER}`.

**Не рекомендуется** для вашей цели: в git всё равно не видно «что изменилось», только дата/номер.

### Рекомендация

**Старт с варианта A**, опционально позже добавить **B только для patch** на `workflow_dispatch` deploy без PR (hotfix).

---

## Git-flow (минимальные изменения)

Текущий поток уже близок к trunk-based:

```
feature/* → PR → CI → merge main → CI → Deploy TestFlight
```

Добавить:

1. **Теги** `ios/v{VERSION}` на каждый успешный TestFlight с main (annotated tag + ссылка на `CHANGELOG`).
2. **Опционально** `release/ios-{VERSION}` ветка только для hotfix в проде (если позже будет App Store вне TestFlight).
3. **PR template** — чеклист: `[ ] VERSION / CHANGELOG обновлены при user-facing изменениях`.
4. **Запрет** прямого push в `main` без PR (branch protection) — если ещё не включено.

Не вводить тяжёлый GitFlow (develop/release) без необходимости.

---

## Changelog

Формат: [Keep a Changelog](https://keepachangelog.com/) на русском или bilingual.

```markdown
# Changelog

## [Unreleased]

### Fixed
- ...

## [1.2.3] - 2026-07-06
### Added
- ...
```

**Источники записей:**

- вручную в PR (вариант A);
- или auto из squash commit message / labels (`changelog:fix`, `changelog:feature`);
- Telegram TestFlight уведомление — добавить ссылку на `CHANGELOG.md#123` (якорь версии).

Дополнительно: `docs/RELEASES.md` — краткая таблица для людей и ассистента:

| Version | Build (CI) | Git tag | Date | Notes |
|---------|------------|---------|------|-------|
| 1.2.3 | 412 | ios/v1.2.3 | 2026-07-06 | composer send fix |

Генерировать скриптом при deploy из `ci_testflight.json` + `VERSION`.

---

## Синхронизация с Xcode / XcodeGen

Сейчас `project.yml` задаёт `MARKETING_VERSION: "0.1.0"` статически; CI меняет только build.

**Нужно:**

1. Единый источник: `VERSION` (или только `project.yml`, но тогда bump коммитит и его).
2. Перед `xcodegen generate` / в `fastlane beta`: подставлять marketing version из `VERSION`.
3. После смены `project.yml` — `xcodegen generate` в CI (если проект генерируется в pipeline) или коммитить сгенерированный `.xcodeproj` согласно текущей практике репо.
4. Выровнять расхождение **1.0 в UI vs 0.1.0 в project.yml** — разовая синхронизация при внедрении.

---

## Интеграция с observability (следующий шаг)

После внедрения SemVer:

- `task-feature-api-client-version-metadata` — заголовки `X-KB-App-Version` / `X-KB-App-Build`.
- Бэкенд логирует пару version+build → можно искать в `docs/RELEASES.md` / git tag.
- Push `registerDevice` уже шлёт `app_version` — убедиться, что туда попадает тот же SemVer.

---

## Задачи (чеклист внедрения)

### Фаза 1 — договорённости и файлы

- [x] Выбрать вариант A или A+B (зафиксировать в `docs/FASTLANE.md`).
- [x] Добавить `VERSION` (стартовое значение, согласовать с текущим TestFlight).
- [x] Добавить `CHANGELOG.md` (перенести ключевые изменения последних недель ретроспективно — по желанию).
- [x] Добавить `docs/RELEASES.md` (шаблон таблицы).

### Фаза 2 — CI / Fastlane

- [x] `fastlane beta`: `get_version_number` ← читать из `VERSION`; не полагаться на застывший `project.yml`.
- [x] Скрипт sync: `VERSION` → `MARKETING_VERSION` в `project.yml` + `xcodegen` (если нужно).
- [x] После upload: Telegram + `ci_testflight.json` (marketing_version); `RELEASES.md` ведётся в PR без bot-commit.
- [x] Git tag `ios/v*` на success deploy (нужен `contents: write` для GITHUB_TOKEN или PAT).

### Фаза 3 — PR / качество

- [x] CI check на PR убран: версия поднимается автоматически на Deploy (main).
- [x] Обновить `.github/pull_request_template.md` — секция Version & release (optional PR path).
- [x] Документировать правила bump в `docs/RELEASE_PROCESS.md` (auto patch на main).

### Фаза 4 — продукт

- [x] Экран «О приложении»: `Version {VERSION} ({BUILD})` — копируемо для саппорта.
- [x] Связать с `task-feature-api-client-version-metadata`.

### Фаза 5 — опционально

- [ ] Conventional Commits + автогенерация changelog (git-cliff / release-please).
- [ ] GitHub Release notes из `CHANGELOG.md` при теге.

---

## Критерии приёмки

1. После merge в `main` и TestFlight marketing version в приложении **≠** вечное `1.0` и совпадает с `VERSION` в git на том же commit (или на tag deploy).
2. В репозитории есть `CHANGELOG.md` с записью для этой версии.
3. По версии из TestFlight / API-заголовка можно найти tag или строку в `docs/RELEASES.md`.
4. ИИ-ассистент, читая только репозиторий `knowledge-base-app-ios`, понимает, что изменилось между `1.2.2` и `1.2.3`.

---

## Риски

| Риск | Митигация |
|------|-----------|
| Забыли bump в PR | CI gate |
| Bot commit гонки | Только тег без push / вариант A |
| Watch + Widget targets не синхронизированы | Один `VERSION` на все targets в Fastlane |
| TestFlight build без merge в main | Только `workflow_dispatch` с явным ref |

---

## Вне scope

- App Store production release notes (можно переиспользовать CHANGELOG позже).
- Версионирование бэкенда `kb_app_api` (отдельная задача; API contract version уже есть в OpenAPI).
