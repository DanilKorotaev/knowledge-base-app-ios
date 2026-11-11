# Crashlytics: что сделать руками

Код рассчитан на то, что этих шагов ещё нет. Пока нет `GoogleService-Info.plist` и секрета CI, сборка, TestFlight и текущие логи работают как раньше. Crashlytics просто не стартует. Когда файлы лягут на места, нужна пересборка.

`GoogleService-Info.plist` и JSON ключ сервисного аккаунта в git не коммитить. Значения секретов не копировать в чат и в этот файл.

## Куда что кладётся

- `GoogleService-Info.plist` — в `KnowledgeBaseApp/Resources/GoogleService-Info.plist`. Путь в `.gitignore`.
- Тот же plist для CI — секрет репозитория `FIREBASE_GOOGLE_SERVICE_INFO_PLIST_BASE64` (содержимое файла в base64). GitHub → Settings → Secrets and variables → Actions. Если секрета нет, workflow не падает и собирает билд без Crashlytics.
- JSON сервисного аккаунта BigQuery — только у процесса, который читает выгрузку. В приложение и в git он не входит.

Отдельный токен в `.ipa` не зашивается. Телефон шлёт лог обычным входом в приложение. Забрать файл может админ тем же логином, что и для `/admin/`.

## 1. Проект Firebase

1. Открыть [Firebase Console](https://console.firebase.google.com/).
2. Add project. Имя любое. Google Analytics для этого проекта не включать.
3. Add app → iOS.
4. Bundle ID: `com.coredan.KnowledgeBaseApp`. Nickname можно оставить `KnowledgeBaseApp`.
5. Скачать `GoogleService-Info.plist`.
6. Положить его в `KnowledgeBaseApp/Resources/GoogleService-Info.plist`.
7. Проверить, что `git status` его не показывает. Если показывает, не делать `git add`.

## 2. Crashlytics в консоли

1. В том же проекте открыть Crashlytics и нажать Enable.
2. Отчёт появится после пересборки с этим plist, запуска без отладчика Xcode, тестового крэша и повторного открытия приложения.

## 3. Blaze и BigQuery

Crashlytics в консоли бесплатный. Чтобы забирать крэши наружу, нужна выгрузка в BigQuery. Поток `_REALTIME` есть только на плане Blaze.

Абонентки нет: привязывается карта, счёт за использование. Для крэшей одного приложения ожидаемая сумма — ноль или доли цента. Первый 1 ТБ запросов BigQuery в месяц и первые 10 ГБ хранения бесплатны. Потоковая запись — $0.01 за 200 МБ.

1. Project settings → Usage and billing → Modify plan → Blaze. Привязать карту.
2. В Google Cloud включить budget alert на небольшую сумму, чтобы другой случайно включённый продукт не пришёл счётом.
3. Firebase → Project settings → Integrations → BigQuery → Link. Включить экспорт Crashlytics и streaming.
4. Регион датасета выбрать один раз, потом он не меняется.
5. После включения поток может молчать до часа. Дневная таблица может появиться в течение 48 часов. Читателю нужна таблица с суффиксом `_REALTIME`.

## 4. Сервисный аккаунт

1. Google Cloud → IAM → Service accounts → Create.
2. Выдать ему чтение датасета Crashlytics: BigQuery Data Viewer на этот датасет и BigQuery Job User на проект, чтобы можно было выполнить запрос.
3. Keys → Add key → JSON. Файл хранить вне репозитория.

## 5. Пересборка

Локально достаточно открыть проект: plist уже в Resources. Для TestFlight секрет `FIREBASE_GOOGLE_SERVICE_INFO_PLIST_BASE64` должен появиться до запуска Deploy. Workflow сам запишет plist в рабочую копию. Если секрета нет, сборка не падает, в этот билд Crashlytics не входит.

dSYM уходит в Crashlytics после экспорта архива, и шаг ждёт окончания загрузки. Строка `Successfully exported and compressed dSYM file` — это только локальный zip, не отправка в Firebase.

## 6. Куда слать крэш

Один раз, после того как приём логов и читатель BigQuery уже есть:

1. В приложении создать сессию, например «Крэши iOS».
2. Настройки ingress: токен с источником `ios`.
3. Binding с ключом `ios-crashes` на эту сессию.
4. Правило: `source=ios`, типы `app.crash` и `app.crash_logs`, действие — сессия `ios-crashes`, политика `enqueue_agent`.
5. В админке `/admin/` оставить включённым приём файлов логов. Выключение перестаёт принимать файлы, стек в Crashlytics при этом остаётся.
6. В Debug-меню приложения пункт «Отправлять файл лога после крэша» по умолчанию включён.

Читатель BigQuery и правило можно включить в любой момент после ключей. До этого крэши с телефона копятся в Crashlytics и уедут в ingress со следующей выгрузки.
