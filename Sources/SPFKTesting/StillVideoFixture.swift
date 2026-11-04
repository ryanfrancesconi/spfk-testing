// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-testing

import AVFoundation
import CoreGraphics
import Foundation
import ImageIO

/// A generated H.264 video that shows each of a sequence of still images in turn, silent unless
/// given a soundtrack.
///
/// Real photos rather than solid colors, so each segment classifies as something distinct.
public enum StillVideoFixture {
    public enum Error: Swift.Error {
        case unreadableImage(URL)
        case missingTrack
        case exportFailed((any Swift.Error)?)
    }

    /// Writes the video to a new temporary file; the caller removes it.
    ///
    /// - Parameter soundtrack: an audio file to carry as the video's audio track, cut to the
    ///   picture's length. The result is then a `.mov`, its audio copied rather than re-encoded.
    /// - Parameter size: output frame size, both dimensions even for H.264. Each image is
    ///   stretched to fill it.
    public static func make(
        showing images: [URL],
        segmentDuration: TimeInterval,
        soundtrack: URL? = nil,
        size: CGSize = CGSize(width: 640, height: 360)
    ) async throws -> URL {
        let picture = try await makePicture(showing: images, segmentDuration: segmentDuration, size: size)

        guard let soundtrack else { return picture }
        defer { try? FileManager.default.removeItem(at: picture) }

        return try await combine(picture: picture, soundtrack: soundtrack)
    }

    private static func combine(picture: URL, soundtrack: URL) async throws -> URL {
        let pictureAsset = AVURLAsset(url: picture)
        let soundAsset = AVURLAsset(url: soundtrack)

        guard let videoTrack = try await pictureAsset.loadTracks(withMediaType: .video).first,
              let audioTrack = try await soundAsset.loadTracks(withMediaType: .audio).first
        else {
            throw Error.missingTrack
        }

        let duration = try await pictureAsset.load(.duration)
        let range = CMTimeRange(start: .zero, duration: min(duration, try await soundAsset.load(.duration)))

        let composition = AVMutableComposition()
        try composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)?
            .insertTimeRange(CMTimeRange(start: .zero, duration: duration), of: videoTrack, at: .zero)
        try composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)?
            .insertTimeRange(range, of: audioTrack, at: .zero)

        guard let session = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetPassthrough) else {
            throw Error.exportFailed(nil)
        }

        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".mov")
        session.outputURL = url
        session.outputFileType = .mov

        nonisolated(unsafe) let exporting = session
        await withCheckedContinuation { continuation in
            exporting.exportAsynchronously { continuation.resume() }
        }

        guard session.status == .completed else {
            throw Error.exportFailed(session.error)
        }

        return url
    }

    private static func makePicture(
        showing images: [URL],
        segmentDuration: TimeInterval,
        size: CGSize
    ) async throws -> URL {
        let segments = try images.map(loadImage)

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".mp4")

        let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)

        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: Int(size.width),
            AVVideoHeightKey: Int(size.height),
        ]
        let writerInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        writerInput.expectsMediaDataInRealTime = false

        let pixelBufferAttrs: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
            kCVPixelBufferWidthKey as String: Int(size.width),
            kCVPixelBufferHeightKey as String: Int(size.height),
        ]
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: writerInput,
            sourcePixelBufferAttributes: pixelBufferAttrs
        )

        writer.add(writerInput)
        writer.startWriting()
        writer.startSession(atSourceTime: .zero)

        let frameRate = 10
        let timescale: CMTimeScale = 600
        let framesPerSegment = Int(segmentDuration) * frameRate

        var frameIndex = 0

        for image in segments {
            for _ in 0 ..< framesPerSegment {
                while !writerInput.isReadyForMoreMediaData {
                    await Task.yield()
                }

                let presentationTime = CMTime(
                    value: CMTimeValue(frameIndex * Int(timescale) / frameRate),
                    timescale: timescale
                )

                guard let pool = adaptor.pixelBufferPool else { break }
                var pixelBuffer: CVPixelBuffer?
                guard CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pool, &pixelBuffer) == kCVReturnSuccess,
                      let pixelBuffer
                else { break }

                fill(pixelBuffer, with: image)
                adaptor.append(pixelBuffer, withPresentationTime: presentationTime)

                frameIndex += 1
            }
        }

        writerInput.markAsFinished()

        await withCheckedContinuation { continuation in
            writer.finishWriting { continuation.resume() }
        }

        if let error = writer.error {
            throw error
        }

        return url
    }

    private static func loadImage(at url: URL) throws -> CGImage {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else {
            throw Error.unreadableImage(url)
        }
        return image
    }

    private static func fill(_ buffer: CVPixelBuffer, with image: CGImage) {
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }

        guard let baseAddress = CVPixelBufferGetBaseAddress(buffer),
              let context = CGContext(
                  data: baseAddress,
                  width: CVPixelBufferGetWidth(buffer),
                  height: CVPixelBufferGetHeight(buffer),
                  bitsPerComponent: 8,
                  bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
                  space: CGColorSpaceCreateDeviceRGB(),
                  bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
              )
        else { return }

        context.draw(image, in: CGRect(x: 0, y: 0, width: context.width, height: context.height))
    }
}
