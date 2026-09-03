# Bug: eternal “processing” when last message is user without reply

**Status:** Fixed in code (pending TestFlight)  
**Priority:** High  
**Category:** Bug, chat, resume/poll

## Symptoms

Session 241 message `1675`: voice complaint saved, Cursor killed by API restart (~01:03), no assistant row. Opening the chat later showed endless processing / `pollReply` with no push.

## Root cause

`resumeAwaitingReplyIfNeeded` treated `messages.last?.role == .user` as “still awaiting” even without a live in-flight marker (and after poll exhaustion left `.waiting`).

## Fix

- Resume poll only with in-flight marker **or** a recent last-user (< 10 min, Share without marker).
- After poll exhaustion: clear marker and set `.idle` (stop spinning).

## Files

- `KnowledgeBaseApp/ViewModels/ChatViewModel.swift`
- `KnowledgeBaseAppTests/ChatViewModelTests.swift`
