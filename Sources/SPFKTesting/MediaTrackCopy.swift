// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-testing

import AVFoundation
import Foundation

public enum MediaTrackCopyError: Error {
    case exportUnavailable(URL)
    case exportFailed(URL, underlying: (any Error)?)
}

/// Damaged copies of a fixture, for tests of code that has to notice a file losing a track.
public enum MediaTrackCopy {
    /// A passthrough `.mov` copy of `url` holding every track except those of `mediaType`, written
    /// to `NSTemporaryDirectory()`. The caller removes it.
    public static func copyDroppingTracks(of url: URL, mediaType: AVMediaType) async throws -> URL {
        let asset = AVURLAsset(url: url)
        let composition = AVMutableComposition()

        for track in try await asset.load(.tracks) where track.mediaType != mediaType {
            let timeRange = try await track.load(.timeRange)

            guard let compositionTrack = composition.addMutableTrack(
                withMediaType: track.mediaType,
                preferredTrackID: kCMPersistentTrackID_Invalid
            ) else { continue }

            try compositionTrack.insertTimeRange(timeRange, of: track, at: timeRange.start)
        }

        guard let session = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetPassthrough) else {
            throw MediaTrackCopyError.exportUnavailable(url)
        }

        let outputURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("dropped_\(mediaType.rawValue)_\(UUID().uuidString).mov")

        session.outputURL = outputURL
        session.outputFileType = .mov

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            session.exportAsynchronously { continuation.resume() }
        }

        guard session.status == .completed else {
            try? FileManager.default.removeItem(at: outputURL)
            throw MediaTrackCopyError.exportFailed(url, underlying: session.error)
        }

        return outputURL
    }
}
