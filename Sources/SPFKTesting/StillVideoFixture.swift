// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-testing

import AVFoundation
import CoreGraphics
import Foundation
import ImageIO

/// A generated H.264 MP4 with no audio track that shows each of a sequence of still images in turn.
///
/// Real photos rather than solid colors, so each segment classifies as something distinct.
public enum StillVideoFixture {
    public enum Error: Swift.Error {
        case unreadableImage(URL)
    }

    /// Writes the video to a new temporary file; the caller removes it.
    ///
    /// - Parameter size: output frame size, both dimensions even for H.264. Each image is
    ///   stretched to fill it.
    public static func make(
        showing images: [URL],
        segmentDuration: TimeInterval,
        size: CGSize = CGSize(width: 640, height: 360)
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
