# Chat: text send + history

**Status:** Pending  
**Depends on:** KB App API message/session endpoints.

## Scope

- Load session messages.
- Send text query; display assistant replies (streaming TBD).
- Empty vs knowledge-base mode when API supports it.

## Acceptance

- Client uses `KnowledgeBaseAPIClientProtocol` extensions or dedicated `ChatAPIClientProtocol` as the surface grows.
