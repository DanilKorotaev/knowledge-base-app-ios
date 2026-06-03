# Чат: списки, code blocks, blockquote в Markdown

**Status:** ✅ Done (phase 1)  
**Приоритет:** 🟠 Высокий  
**Связанные:** [task-ux-chat-rich-messages.md](../completed/task-ux-chat-rich-messages.md)

## Контекст

Ответы Cursor (`content_format: markdown`) часто содержат списки, fenced code и цитаты. Построчный inline-рендер сохраняет `\n`, но не структуру блоков.

## Scope (фаза 1)

- [x] Маркированные и нумерованные списки (отступы 2 пробела = уровень)
- [x] Fenced code blocks ` ```lang `
- [x] Blockquote `>`
- [ ] `[[Wiki-links]]` — отдельная задача
- [ ] Task lists `- [ ]` — фаза 2
- [ ] Mermaid / диаграммы — фаза 3 или WebView

## Файлы

- `MarkdownSegmentParser.swift`
- `MarkdownTextBlockView.swift`, `MarkdownCodeBlockView.swift`

## Acceptance

- [x] Списки с bullet/номером и вложенным отступом читаемы
- [x] Код в ` ``` ` — моноширинный блок с фоном, длинные строки скроллятся
- [x] `> цитата` — полоса слева, без символа `>` в тексте
- [x] Таблицы и `---` по-прежнему работают
