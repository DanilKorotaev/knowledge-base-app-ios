import AVFoundation
import Foundation

enum VoiceAudioMerger {
    /// Concatenates AAC segments into one `.m4a` file. Returns the sole input URL unchanged when count is 1.
    static func mergeSegments(_ urls: [URL]) async throws -> URL {
        guard let first = urls.first else {
            throw VoiceRecordingError.notRecording
        }
        guard urls.count > 1 else {
            return first
        }

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("kb-voice-merged-\(UUID().uuidString).m4a")

        let composition = AVMutableComposition()
        guard let track = composition.addMutableTrack(
            withMediaType: .audio,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            throw VoiceRecordingError.recorderFailed("Cannot create audio track")
        }

        var cursor = CMTime.zero
        for url in urls {
            let asset = AVURLAsset(url: url)
            let sourceTracks = try await asset.loadTracks(withMediaType: .audio)
            guard let sourceTrack = sourceTracks.first else { continue }
            let duration = try await asset.load(.duration)
            try track.insertTimeRange(
                CMTimeRange(start: .zero, duration: duration),
                of: sourceTrack,
                at: cursor
            )
            cursor = CMTimeAdd(cursor, duration)
        }

        guard let export = AVAssetExportSession(
            asset: composition,
            presetName: AVAssetExportPresetAppleM4A
        ) else {
            throw VoiceRecordingError.recorderFailed("Cannot create export session")
        }

        export.outputURL = outputURL
        export.outputFileType = .m4a

        if #available(iOS 18.0, *) {
            try await export.export(to: outputURL, as: .m4a)
        } else {
            await export.export()
            guard export.status == .completed else {
                let message = export.error?.localizedDescription ?? "Export failed"
                throw VoiceRecordingError.recorderFailed(message)
            }
        }

        return outputURL
    }
}
