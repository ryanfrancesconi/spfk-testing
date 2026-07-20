// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-testing

import AVFoundation
import Foundation

/// Helpers for creating synthetic PCM audio files in tests.
public enum AudioTestFile {
    /// Create a temporary WAV file from a sequence of (frameCount, amplitude) segments.
    ///
    /// Each tuple writes `frameCount` frames at the given constant `amplitude` (linear, 0–1).
    /// Pass `0.0` for silence. The file is written to `NSTemporaryDirectory()` and the caller
    /// is responsible for deleting it.
    ///
    /// - Returns: The file URL and total frame count.
    public static func make(
        sampleRate: Double = 44100,
        channelCount: AVAudioChannelCount = 1,
        segments: [(frameCount: Int, amplitude: Float)]
    ) throws -> (url: URL, totalFrames: Int) {
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: channelCount)!
        let totalFrames = segments.reduce(0) { $0 + $1.frameCount }

        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(totalFrames)) else {
            throw NSError(domain: "AudioTestFile", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to allocate PCM buffer"])
        }
        buffer.frameLength = AVAudioFrameCount(totalFrames)

        guard let floatData = buffer.floatChannelData else {
            throw NSError(domain: "AudioTestFile", code: 2, userInfo: [NSLocalizedDescriptionKey: "No float channel data"])
        }

        var offset = 0
        for (count, amplitude) in segments {
            for i in 0 ..< count {
                for ch in 0 ..< Int(channelCount) {
                    floatData[ch][offset + i] = amplitude
                }
            }
            offset += count
        }

        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("audio_test_\(UUID().uuidString).wav")
        let file = try AVAudioFile(forWriting: url, settings: format.settings)
        try file.write(from: buffer)
        return (url, totalFrames)
    }
}
