# Changed files, diff, widgets, camera, deep link

**Completed:** 2026-04-04

## Files API (client)

- `KBChangedFile`, `FilesAPIClientProtocol`, `StubFilesAPIClient`
- `URLSessionKnowledgeBaseAPIClient` + `GET …/api/files/changes`, `POST …/api/files/revert`
- `ChangedFilesView`, `FileDiffView` (before/after, revert)

## Widgets

- Target `KnowledgeBaseWidgetExtension`: small quick-record, medium session placeholder, lock screen `accessoryCircular`
- URL `knowledgebase://record` + banner hint on `MainView`

## Chat

- `CameraPicker` (`UIImagePickerController`), button when camera is available

## Tests

- `FilesAPIClientTests.swift`
