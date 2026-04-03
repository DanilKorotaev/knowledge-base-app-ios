# Coding Standards

Mandatory for all new code in this repository.

## 1) Protocol-first design

- Every service or repository is represented by a protocol.
- Production code depends on abstractions; use constructor injection.
- Avoid singletons for business logic.

Examples:

- `KnowledgeBaseAPIClientProtocol` + `StubKnowledgeBaseAPIClient` / `URLSessionKnowledgeBaseAPIClient`

## 2) Test coverage

- New production behavior should include tests in the same change.
- Prefer unit tests with injected dependencies and URLProtocol-style mocks for HTTP.

## 3) Definition of done

1. Protocol abstraction introduced or updated where applicable.
2. Tests added or updated.
3. Local tests green.
4. Docs or `docs/todo.md` updated if scope or config changed.

## 4) Project policy

- No secrets, tokens, or personal data in git.
- Externalize configuration (environment variables, Keychain, gitignored local files).
