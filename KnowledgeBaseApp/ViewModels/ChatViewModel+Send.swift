import Foundation

extension ChatViewModel {
    func send() async {
        await sendComposed()
    }

    func sendComposed() async {
        let preliminaryRoute = ChatComposerSendPlanner.route(for: composerDraft)
        if case .unsupported(let message) = preliminaryRoute {
            errorMessage = message
            return
        }

        isSending = true
        errorMessage = nil
        pendingSendRetry = nil
        scrollIntent = .none
        defer { isSending = false }

        // Snapshot before detach — needed for Retry without stuffing the composer.
        let sendSnapshot = composerDraft

        do {
            try await ensureServerSessionIfNeeded(using: sendSnapshot)
        } catch {
            errorMessage = error.localizedDescription
            return
        }

        // After draft→server promote, media may live under the new session draft folder.
        // Rebuild the route from remapped URLs so upload does not read deleted `draft:` paths.
        let resolvedSnapshot = remappedComposerDraftForCurrentSession(sendSnapshot)
        let route = ChatComposerSendPlanner.route(for: resolvedSnapshot)
        if case .unsupported(let message) = route {
            errorMessage = message
            return
        }

        // Clear composer immediately so voice/photo chips do not linger while the
        // assistant reply streams (including after backgrounding the app).
        detachComposerForSend()

        let succeeded: Bool
        switch route {
        case .unsupported:
            return
        case .textOnly(let text):
            succeeded = await sendStreamingText(
                text,
                optimisticContent: text,
                retryDraft: ChatComposerDraft(text: text)
            )
        case .singleAttachment(let attachment):
            succeeded = await sendSingleAttachment(attachment, retryDraft: resolvedSnapshot)
        case .singleVoice(let clip, let text):
            succeeded = await sendSingleVoice(clip: clip, text: text, retryDraft: resolvedSnapshot)
        case .compose(let draft):
            succeeded = await sendComposedMessage(draft)
        }

        if succeeded {
            clearSavedComposerDraft()
            offerPipelineErrorRetryIfNeeded()
        }
    }

    /// Creates the server session on first send for local drafts; no-op otherwise.
    func ensureServerSessionIfNeeded(using draft: ChatComposerDraft? = nil) async throws {
        guard session.isLocalDraft else { return }

        if let existing = sessionPromotionTask {
            _ = try await existing.value
            return
        }

        let snapshot = draft ?? composerDraft
        let creator = sessionCreator
        let useKB = useKnowledgeBase
        let oldId = session.id
        let title = Self.suggestedTitle(from: snapshot)

        let task = Task<KBSession, Error> { @MainActor in
            guard let creator else {
                throw KnowledgeBaseAPIError.invalidResponse(
                    statusCode: 400,
                    apiMessage: "Cannot create session: missing session client"
                )
            }
            let created = try await creator.createSession(title: title, useKnowledgeBase: useKB)
            self.promoteLocalDraft(from: oldId, to: created)
            return created
        }
        sessionPromotionTask = task

        do {
            _ = try await task.value
            sessionPromotionTask = nil
        } catch {
            sessionPromotionTask = nil
            throw error
        }
    }

    /// Prefer media paths already copied into the current session's draft store.
    private func remappedComposerDraftForCurrentSession(_ snapshot: ChatComposerDraft) -> ChatComposerDraft {
        guard let stored = composerDraftStore.load(sessionId: session.id)?.draft else {
            return snapshot
        }
        var result = snapshot
        let voiceById = Dictionary(uniqueKeysWithValues: stored.voiceClips.map { ($0.id, $0) })
        result.voiceClips = snapshot.voiceClips.map { voiceById[$0.id] ?? $0 }
        let attachmentById = Dictionary(uniqueKeysWithValues: stored.attachments.map { ($0.id, $0) })
        result.attachments = snapshot.attachments.map { attachmentById[$0.id] ?? $0 }
        return result
    }

    private static func suggestedTitle(from draft: ChatComposerDraft) -> String {
        draft.suggestedSessionTitle
    }

    func shouldShowSendRetry(for message: KBMessage) -> Bool {
        pendingSendRetry?.anchorMessageId == message.id
    }

    func retryFailedSend() async {
        guard let retry = pendingSendRetry else { return }
        pendingSendRetry = nil
        errorMessage = nil

        switch retry.kind {
        case .draft(let draft):
            await resendFailedDraft(draft)
        case .text(let text):
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }
            isSending = true
            defer { isSending = false }
            do {
                try await ensureServerSessionIfNeeded(using: ChatComposerDraft(text: trimmed))
            } catch {
                errorMessage = error.localizedDescription
                return
            }
            let ok = await sendStreamingText(
                trimmed,
                optimisticContent: trimmed,
                retryDraft: ChatComposerDraft(text: trimmed)
            )
            if ok {
                clearSavedComposerDraft()
                offerPipelineErrorRetryIfNeeded()
            }
        }
    }

    private func beginSendAttempt() {
        preSendLastMessageId = messages.last { !$0.id.hasPrefix("kb-optimistic-") }?.id
        userMessageAckedForCurrentSend = false
    }

    private func markUserMessageAcked(
        serverMessageId: String,
        optimisticId: String,
        clientMessageId: String?
    ) {
        userMessageAckedForCurrentSend = true
        if let index = messages.firstIndex(where: { $0.id == optimisticId }) {
            let old = messages[index]
            messages[index] = KBMessage(
                id: serverMessageId,
                role: old.role,
                content: old.content,
                createdAt: old.createdAt,
                attachments: old.attachments,
                contentFormat: old.contentFormat,
                transcription: old.transcription,
                relatedChangedFiles: old.relatedChangedFiles,
                relatedChangedFilesSource: old.relatedChangedFilesSource,
                structuredUI: old.structuredUI,
                clientMessageId: clientMessageId ?? old.clientMessageId
            )
        }
        clearSavedComposerDraft()
    }

    private func serverAcceptedCurrentSend() -> Bool {
        if userMessageAckedForCurrentSend { return true }
        let baseline = preSendLastMessageId
        return messages.contains { message in
            guard message.role == .user, !message.id.hasPrefix("kb-optimistic-") else { return false }
            guard let baseline else { return true }
            if let messageId = Int(message.id), let baselineId = Int(baseline) {
                return messageId > baselineId
            }
            return message.id != baseline
        }
    }

    private func resendFailedDraft(_ draft: ChatComposerDraft) async {
        do {
            try await ensureServerSessionIfNeeded(using: draft)
        } catch {
            errorMessage = error.localizedDescription
            return
        }
        let resolved = remappedComposerDraftForCurrentSession(draft)
        let route = ChatComposerSendPlanner.route(for: resolved)
        if case .unsupported(let message) = route {
            errorMessage = message
            return
        }

        isSending = true
        errorMessage = nil
        scrollIntent = .none
        defer { isSending = false }

        removeOptimisticMessages()

        let succeeded: Bool
        switch route {
        case .unsupported:
            return
        case .textOnly(let text):
            succeeded = await sendStreamingText(
                text,
                optimisticContent: text,
                retryDraft: ChatComposerDraft(text: text)
            )
        case .singleAttachment(let attachment):
            succeeded = await sendSingleAttachment(attachment, retryDraft: resolved)
        case .singleVoice(let clip, let text):
            succeeded = await sendSingleVoice(clip: clip, text: text, retryDraft: resolved)
        case .compose(let composed):
            succeeded = await sendComposedMessage(composed)
        }

        if succeeded {
            clearSavedComposerDraft()
            offerPipelineErrorRetryIfNeeded()
        }
    }

    @discardableResult
    private func sendStreamingText(
        _ text: String,
        optimisticContent: String,
        retryDraft: ChatComposerDraft
    ) async -> Bool {
        beginSendAttempt()
        let optimisticUser = KBMessage(
            id: "kb-optimistic-\(UUID().uuidString)",
            role: .user,
            content: optimisticContent,
            createdAt: Date()
        )
        do {
            messages.append(optimisticUser)
            assistantReplyPhase = .waiting
            cursorActivityLabel = nil
            scrollIntent = .scrollToBottom
            beginInFlightReply()

            let stream = try await client.streamTextMessage(
                sessionId: session.id,
                text: text,
                useKnowledgeBase: useKnowledgeBase
            )
            try await AssistantReplyStreamConsumer.consume(stream) { update in
                applyStreamUpdate(update)
            }
            await waitForStreamRevealAnimation()
            await reloadLatestWindow()
            clearInFlightReply()
            assistantReplyPhase = .idle
            cursorActivityLabel = nil
            return true
        } catch {
            let partial = assistantReplyPhase.displayText
            if await handleResumableStreamInterruption(error, partialText: partial) {
                // Keep disk draft until we know the server accepted the user turn.
                return userMessageAckedForCurrentSend || serverAcceptedCurrentSend()
            }
            return await finishHardSendFailure(
                error: error,
                retryDraft: retryDraft,
                optimisticMessageId: optimisticUser.id,
                errorText: error.localizedDescription
            )
        }
    }

    @discardableResult
    private func sendSingleAttachment(
        _ attachment: PendingAttachment,
        retryDraft: ChatComposerDraft
    ) async -> Bool {
        let scoped = attachment.localURL.startAccessingSecurityScopedResource()
        defer {
            if scoped {
                attachment.localURL.stopAccessingSecurityScopedResource()
            }
        }
        do {
            _ = try await client.sendAttachment(
                sessionId: session.id,
                fileURL: attachment.localURL,
                filename: attachment.filename,
                mimeType: attachment.mimeType,
                useKnowledgeBase: useKnowledgeBase
            )
            try? FileManager.default.removeItem(at: attachment.localURL)
            await reloadLatestWindow()
            return true
        } catch {
            return await finishHardSendFailure(
                error: error,
                retryDraft: retryDraft,
                optimisticMessageId: messages.last { $0.role == .user }?.id,
                errorText: error.localizedDescription
            )
        }
    }

    @discardableResult
    private func sendSingleVoice(clip: PendingVoiceClip, text: String, retryDraft: ChatComposerDraft) async -> Bool {
        beginSendAttempt()
        let optimisticUser = KBMessage(
            id: "kb-optimistic-\(UUID().uuidString)",
            role: .user,
            content: text,
            createdAt: Date()
        )
        do {
            messages.append(optimisticUser)
            assistantReplyPhase = .waiting
            cursorActivityLabel = nil
            scrollIntent = .scrollToBottom
            beginInFlightReply()

            let stream = try await client.streamVoiceMessage(
                sessionId: session.id,
                audioFileURL: clip.audioURL,
                text: text,
                useKnowledgeBase: useKnowledgeBase
            )
            try await AssistantReplyStreamConsumer.consume(stream) { update in
                applyStreamUpdate(update)
            }
            await waitForStreamRevealAnimation()
            await reloadLatestWindow()
            clearInFlightReply()
            assistantReplyPhase = .idle
            cursorActivityLabel = nil
            PendingVoiceStore.deleteRecording(at: clip.audioURL)
            return true
        } catch {
            let partial = assistantReplyPhase.displayText
            if await handleResumableStreamInterruption(error, partialText: partial) {
                return userMessageAckedForCurrentSend || serverAcceptedCurrentSend()
            }
            return await finishHardSendFailure(
                error: error,
                retryDraft: retryDraft,
                optimisticMessageId: optimisticUser.id,
                errorText: VoicePipelineErrorMessage.forSend(error)
            )
        }
    }

    @discardableResult
    private func sendComposedMessage(_ draft: ChatComposerDraft) async -> Bool {
        var scopedURLs: [URL] = []
        defer {
            for url in scopedURLs {
                url.stopAccessingSecurityScopedResource()
            }
        }

        for attachment in draft.attachments where attachment.localURL.startAccessingSecurityScopedResource() {
            scopedURLs.append(attachment.localURL)
        }

        beginSendAttempt()
        var draftForSend = draft
        let clientMessageId = draft.clientMessageId ?? UUID().uuidString
        draftForSend.clientMessageId = clientMessageId
        let optimisticUser = buildOptimisticMessage(from: draftForSend)
        do {
            messages.append(optimisticUser)
            assistantReplyPhase = .waiting
            cursorActivityLabel = nil
            scrollIntent = .scrollToBottom
            beginInFlightReply()

            let stream = try await client.streamComposedMessage(
                sessionId: session.id,
                draft: draftForSend,
                useKnowledgeBase: useKnowledgeBase
            )
            try await AssistantReplyStreamConsumer.consume(
                stream,
                onUserMessageAcked: { messageId, ackedClientId in
                    self.markUserMessageAcked(
                        serverMessageId: messageId,
                        optimisticId: optimisticUser.id,
                        clientMessageId: ackedClientId ?? clientMessageId
                    )
                },
                onUpdate: { update in
                    applyStreamUpdate(update)
                }
            )
            await waitForStreamRevealAnimation()
            await reloadLatestWindow()
            clearInFlightReply()
            assistantReplyPhase = .idle
            cursorActivityLabel = nil
            for attachment in draft.attachments {
                try? FileManager.default.removeItem(at: attachment.localURL)
            }
            for clip in draft.voiceClips {
                PendingVoiceStore.deleteRecording(at: clip.audioURL)
            }
            ShareConversationIntentDonator.donate(sessionId: session.id, title: session.title)
            return true
        } catch {
            let partial = assistantReplyPhase.displayText
            if await handleResumableStreamInterruption(error, partialText: partial) {
                return userMessageAckedForCurrentSend || serverAcceptedCurrentSend()
            }
            return await finishHardSendFailure(
                error: error,
                retryDraft: draftForSend,
                optimisticMessageId: optimisticUser.id,
                errorText: VoicePipelineErrorMessage.forSend(error)
            )
        }
    }

    /// Hard failure: keep composer empty, offer Retry on bubble; drop optimistic only if server already has a turn.
    @discardableResult
    private func finishHardSendFailure(
        error: Error,
        retryDraft: ChatComposerDraft,
        optimisticMessageId: String?,
        errorText: String
    ) async -> Bool {
        clearInFlightReply()
        assistantReplyPhase = .idle
        cursorActivityLabel = nil

        await reloadLatestWindow()

        if serverAcceptedCurrentSend(), messages.last?.role == .assistant {
            // User turn was accepted and a reply (including pipeline error) already exists.
            removeOptimisticMessages()
            clearSavedComposerDraft()
            if messages.last?.isPipelineErrorMessage == true {
                offerPipelineErrorRetryIfNeeded(errorText: errorText)
            } else {
                pendingSendRetry = nil
            }
            // Composer stays empty — no draft restore.
            return false
        }

        let anchorId = messages.last { $0.id.hasPrefix("kb-optimistic-") }?.id
            ?? optimisticMessageId
            ?? messages.last { $0.role == .user }?.id
        if let anchorId {
            pendingSendRetry = FailedSendRetry(
                kind: .draft(retryDraft),
                anchorMessageId: anchorId,
                errorDescription: errorText
            )
        } else {
            // Nothing visible to attach Retry to — last-resort restore so the user does not lose content.
            composerDraft = retryDraft
            scheduleComposerDraftSave()
            errorMessage = errorText
        }
        return false
    }

    private func offerPipelineErrorRetryIfNeeded(errorText: String? = nil) {
        guard let assistant = messages.last, assistant.isPipelineErrorMessage else {
            return
        }
        guard let user = messages.last(where: { $0.role == .user }) else { return }
        let text = user.content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        pendingSendRetry = FailedSendRetry(
            kind: .text(text),
            anchorMessageId: assistant.id,
            errorDescription: errorText ?? assistant.content
        )
    }

    private func composedOptimisticPlaceholder(for draft: ChatComposerDraft) -> String {
        var parts: [String] = []
        if !draft.attachments.isEmpty {
            parts.append("📎 \(draft.attachments.count)")
        }
        if !draft.voiceClips.isEmpty {
            parts.append("🎤 \(draft.voiceClips.count)")
        }
        return parts.joined(separator: " ")
    }

    private func buildOptimisticMessage(from draft: ChatComposerDraft) -> KBMessage {
        var attachments: [KBAttachment] = []
        for item in draft.attachments {
            attachments.append(
                KBAttachment(
                    id: "optimistic-\(item.id)",
                    fileType: {
                        switch item.kind {
                        case .image: return "photo"
                        case .video: return "video"
                        case .file: return "document"
                        }
                    }(),
                    fileName: item.filename,
                    fileSize: item.fileSize.map(Int.init),
                    mimeType: item.mimeType,
                    downloadURL: item.localURL.absoluteString,
                    transcription: nil
                )
            )
        }
        for clip in draft.voiceClips {
            attachments.append(
                KBAttachment(
                    id: "optimistic-\(clip.id)",
                    fileType: "voice",
                    fileName: clip.audioURL.lastPathComponent,
                    fileSize: nil,
                    mimeType: "audio/mp4",
                    downloadURL: clip.audioURL.absoluteString,
                    transcription: clip.transcriptionSegment
                )
            )
        }
        let content = draft.trimmedText.isEmpty
            ? composedOptimisticPlaceholder(for: draft)
            : draft.text
        return KBMessage(
            id: "kb-optimistic-\(UUID().uuidString)",
            role: .user,
            content: content,
            createdAt: Date(),
            attachments: attachments.isEmpty ? nil : attachments,
            clientMessageId: draft.clientMessageId
        )
    }

    /// Clears in-memory composer UI when a send starts. On-disk draft files stay until send succeeds.
    private func detachComposerForSend() {
        composerDraftSaveTask?.cancel()
        composerDraft.clear()
        pendingVoiceCaptures = []
        syncTranscribingVoiceFlag()
    }

    private func removeOptimisticMessages() {
        messages.removeAll { $0.id.hasPrefix("kb-optimistic-") }
    }

    func clearSavedComposerDraft() {
        composerDraftSaveTask?.cancel()
        for clip in composerDraft.voiceClips {
            PendingVoiceStore.deleteRecording(at: clip.audioURL)
        }
        for capture in pendingVoiceCaptures {
            PendingVoiceStore.deleteRecording(at: capture.audioURL)
        }
        composerDraft.clear()
        pendingVoiceCaptures = []
        syncTranscribingVoiceFlag()
        for deferredId in deferredComposerDraftCleanupIds {
            composerDraftStore.clear(sessionId: deferredId)
        }
        deferredComposerDraftCleanupIds.removeAll()
        composerDraftStore.clear(sessionId: session.id)
    }

    func sendAttachment(fileURL: URL, filename: String, mimeType: String) async {
        isSending = true
        errorMessage = nil
        scrollIntent = .none
        defer { isSending = false }
        let scoped = fileURL.startAccessingSecurityScopedResource()
        defer {
            if scoped {
                fileURL.stopAccessingSecurityScopedResource()
            }
        }
        do {
            _ = try await client.sendAttachment(
                sessionId: session.id,
                fileURL: fileURL,
                filename: filename,
                mimeType: mimeType,
                useKnowledgeBase: useKnowledgeBase
            )
            await reloadLatestWindow()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
