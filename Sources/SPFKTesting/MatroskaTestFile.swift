// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-testing

import Foundation

/// A minimal Matroska file built in memory, for inputs no installed muxer writes: missing or
/// duplicate track UIDs, content encodings, cut files and out-of-range values.
///
/// Every element size is written as an 8-byte vint, so each element's length is known before its
/// payload and offsets resolve in one pass.
public struct MatroskaTestFile: Sendable {
    public struct ContentEncoding: Sendable {
        public enum Kind: Sendable {
            /// `ContentCompAlgo` 3, with the stripped bytes as `ContentCompSettings`.
            case headerStripping(Data)

            /// `ContentCompAlgo` 0.
            case zlib

            /// `ContentEncAlgo` 5 (AES) with no key.
            case encrypted
        }

        public var kind: Kind

        /// `ContentEncodingScope`: bit 1 is the frames, bit 2 the `CodecPrivate`.
        public var scope: UInt64

        public init(kind: Kind, scope: UInt64 = 1) {
            self.kind = kind
            self.scope = scope
        }

        public static func headerStripping(_ prefix: Data, scope: UInt64 = 1) -> Self {
            Self(kind: .headerStripping(prefix), scope: scope)
        }

        public static func zlib(scope: UInt64 = 1) -> Self {
            Self(kind: .zlib, scope: scope)
        }

        public static func encrypted(scope: UInt64 = 1) -> Self {
            Self(kind: .encrypted, scope: scope)
        }
    }

    public struct Track: Sendable {
        public var number: UInt64

        /// `nil` omits the `TrackUID` element.
        public var uid: UInt64?

        /// `TrackType`: 1 video, 2 audio.
        public var type: UInt64
        public var codecID: String
        public var codecPrivate: Data?
        public var defaultDuration: UInt64?
        public var pixelWidth: UInt64?
        public var pixelHeight: UInt64?
        public var samplingFrequency: Double?
        public var channels: UInt64?
        public var bitDepth: UInt64?
        public var contentEncoding: ContentEncoding?

        public init(
            number: UInt64,
            uid: UInt64? = nil,
            type: UInt64,
            codecID: String,
            codecPrivate: Data? = nil,
            defaultDuration: UInt64? = nil,
            pixelWidth: UInt64? = nil,
            pixelHeight: UInt64? = nil,
            samplingFrequency: Double? = nil,
            channels: UInt64? = nil,
            bitDepth: UInt64? = nil,
            contentEncoding: ContentEncoding? = nil
        ) {
            self.number = number
            self.uid = uid
            self.type = type
            self.codecID = codecID
            self.codecPrivate = codecPrivate
            self.defaultDuration = defaultDuration
            self.pixelWidth = pixelWidth
            self.pixelHeight = pixelHeight
            self.samplingFrequency = samplingFrequency
            self.channels = channels
            self.bitDepth = bitDepth
            self.contentEncoding = contentEncoding
        }

        public static func video(number: UInt64, uid: UInt64? = nil, codecID: String, width: UInt64 = 64, height: UInt64 = 48) -> Self {
            Self(number: number, uid: uid, type: 1, codecID: codecID, pixelWidth: width, pixelHeight: height)
        }

        /// A 16-bit little-endian PCM track.
        public static func pcm(number: UInt64, uid: UInt64? = nil, sampleRate: Double = 48000, channels: UInt64 = 2) -> Self {
            Self(
                number: number,
                uid: uid,
                type: 2,
                codecID: "A_PCM/INT/LIT",
                samplingFrequency: sampleRate,
                channels: channels,
                bitDepth: 16
            )
        }
    }

    public struct Block: Sendable {
        public var track: UInt64
        public var relativeTimecode: Int16
        public var keyframe: Bool

        /// More than one writes fixed-size lacing, so every frame must have the same length.
        public var frames: [Data]

        public init(track: UInt64, relativeTimecode: Int16 = 0, keyframe: Bool = true, frames: [Data]) {
            self.track = track
            self.relativeTimecode = relativeTimecode
            self.keyframe = keyframe
            self.frames = frames
        }
    }

    public struct Cluster: Sendable {
        public var timecode: UInt64
        public var blocks: [Block]

        /// Writes the cluster's size as the unknown-size sentinel.
        public var sizeIsUnknown: Bool

        public init(timecode: UInt64, blocks: [Block], sizeIsUnknown: Bool = false) {
            self.timecode = timecode
            self.blocks = blocks
            self.sizeIsUnknown = sizeIsUnknown
        }
    }

    public struct CuePoint: Sendable {
        public var time: UInt64
        public var track: UInt64

        /// Index into ``MatroskaTestFile/clusters``.
        public var clusterIndex: Int

        public init(time: UInt64, track: UInt64, clusterIndex: Int) {
            self.time = time
            self.track = track
            self.clusterIndex = clusterIndex
        }
    }

    public var timecodeScale: UInt64
    public var tracks: [Track]
    public var clusters: [Cluster]
    public var cues: [CuePoint]
    public var segmentSizeIsUnknown: Bool

    public init(
        timecodeScale: UInt64 = 1_000_000,
        tracks: [Track],
        clusters: [Cluster],
        cues: [CuePoint] = [],
        segmentSizeIsUnknown: Bool = false
    ) {
        self.timecodeScale = timecodeScale
        self.tracks = tracks
        self.clusters = clusters
        self.cues = cues
        self.segmentSizeIsUnknown = segmentSizeIsUnknown
    }

    /// The absolute byte offset of each cluster's ID in ``data()``.
    public var clusterOffsets: [Int] {
        layout().clusterOffsets
    }

    public func data() -> Data {
        layout().data
    }

    public func write(to url: URL) throws {
        try data().write(to: url)
    }
}

// MARK: - Layout

extension MatroskaTestFile {
    private func layout() -> (data: Data, clusterOffsets: [Int]) {
        let info = EBML.element(0x1549_A966, EBML.uint(0x2A_D7B1, timecodeScale))
        let trackElements = EBML.element(0x1654_AE6B, tracks.map(\.element).concatenated())
        let clusterElements = clusters.map(\.element)

        let seekTargets: [UInt64] = cues.isEmpty ? [0x1549_A966, 0x1654_AE6B] : [0x1549_A966, 0x1654_AE6B, 0x1C53_BB6B]
        let seekHeadLength = EBML.seekHead(seekTargets.map { ($0, 0) }).count

        // Offsets are relative to the segment payload, as SeekPosition and CueClusterPosition are.
        let infoOffset = UInt64(seekHeadLength)
        let tracksOffset = infoOffset + UInt64(info.count)
        var clusterPositions: [UInt64] = []
        var position = tracksOffset + UInt64(trackElements.count)

        for cluster in clusterElements {
            clusterPositions.append(position)
            position += UInt64(cluster.count)
        }

        let cuesOffset = position
        let seekHead = EBML.seekHead(zip(seekTargets, [infoOffset, tracksOffset, cuesOffset]).map { ($0, $1) })

        var payload = seekHead + info + trackElements
        for cluster in clusterElements { payload += cluster }

        if !cues.isEmpty {
            let points = cues.map { cue in
                EBML.element(0xBB, EBML.uint(0xB3, cue.time) + EBML.element(
                    0xB7,
                    EBML.uint(0xF7, cue.track) + EBML.uint(0xF1, clusterPositions[cue.clusterIndex])
                ))
            }
            payload += EBML.element(0x1C53_BB6B, points.concatenated())
        }

        let header = EBML.element(0x1A45_DFA3, [
            EBML.uint(0x4286, 1), EBML.uint(0x42F7, 1), EBML.uint(0x42F2, 4), EBML.uint(0x42F3, 8),
            EBML.element(0x4282, Data("matroska".utf8)), EBML.uint(0x4287, 4), EBML.uint(0x4285, 2),
        ].concatenated())

        let segment = segmentSizeIsUnknown
            ? EBML.id(0x1853_8067) + EBML.unknownSize + payload
            : EBML.element(0x1853_8067, payload)

        let payloadStart = header.count + segment.count - payload.count
        return (header + segment, clusterPositions.map { payloadStart + Int($0) })
    }
}

extension MatroskaTestFile.Track {
    fileprivate var element: Data {
        var body = EBML.uint(0xD7, number)
        if let uid { body += EBML.uint(0x73C5, uid) }
        body += EBML.uint(0x83, type)
        body += EBML.element(0x86, Data(codecID.utf8))
        if let codecPrivate { body += EBML.element(0x63A2, codecPrivate) }
        if let defaultDuration { body += EBML.uint(0x23_E383, defaultDuration) }

        if type == 1 {
            var video = Data()
            if let pixelWidth { video += EBML.uint(0xB0, pixelWidth) }
            if let pixelHeight { video += EBML.uint(0xBA, pixelHeight) }
            body += EBML.element(0xE0, video)
        } else if type == 2 {
            var audio = Data()
            if let samplingFrequency { audio += EBML.float(0xB5, samplingFrequency) }
            if let channels { audio += EBML.uint(0x9F, channels) }
            if let bitDepth { audio += EBML.uint(0x6264, bitDepth) }
            body += EBML.element(0xE1, audio)
        }

        if let contentEncoding {
            body += EBML.element(0x6D80, EBML.element(0x6240, contentEncoding.element))
        }

        return EBML.element(0xAE, body)
    }
}

extension MatroskaTestFile.ContentEncoding {
    fileprivate var element: Data {
        var body = EBML.uint(0x5032, scope)

        switch kind {
        case let .headerStripping(prefix):
            body += EBML.uint(0x5033, 0)
            body += EBML.element(0x5034, EBML.uint(0x4254, 3) + EBML.element(0x4255, prefix))
        case .zlib:
            body += EBML.uint(0x5033, 0)
            body += EBML.element(0x5034, EBML.uint(0x4254, 0))
        case .encrypted:
            body += EBML.uint(0x5033, 1)
            body += EBML.element(0x5035, EBML.uint(0x47E1, 5))
        }

        return body
    }
}

extension MatroskaTestFile.Cluster {
    fileprivate var element: Data {
        var body = EBML.uint(0xE7, timecode)

        for block in blocks {
            body += EBML.element(0xA3, block.payload)
        }

        return sizeIsUnknown
            ? EBML.id(0x1F43_B675) + EBML.unknownSize + body
            : EBML.element(0x1F43_B675, body)
    }
}

extension MatroskaTestFile.Block {
    fileprivate var payload: Data {
        // Track numbers stay below 127, so the track vint is one byte.
        var data = Data([0x80 | UInt8(truncatingIfNeeded: track)])
        let timecode = UInt16(bitPattern: relativeTimecode)
        data += [UInt8(timecode >> 8), UInt8(timecode & 0xFF)]

        var flags: UInt8 = keyframe ? 0x80 : 0
        if frames.count > 1 { flags |= 0x04 }
        data.append(flags)

        if frames.count > 1 {
            data.append(UInt8(frames.count - 1))
        }

        for frame in frames { data += frame }
        return data
    }
}

// MARK: - EBML

private enum EBML {
    static let unknownSize = Data([0x01, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF])

    static func id(_ value: UInt64) -> Data {
        let byteCount = value > 0xFF_FFFF ? 4 : value > 0xFFFF ? 3 : value > 0xFF ? 2 : 1
        return bigEndian(value, byteCount: byteCount)
    }

    /// An element with its size as an 8-byte vint.
    static func element(_ id: UInt64, _ payload: Data) -> Data {
        self.id(id) + Data([0x01]) + bigEndian(UInt64(payload.count), byteCount: 7) + payload
    }

    static func uint(_ id: UInt64, _ value: UInt64) -> Data {
        var byteCount = 1
        while byteCount < 8, value >> (8 * UInt64(byteCount)) != 0 { byteCount += 1 }
        return element(id, bigEndian(value, byteCount: byteCount))
    }

    static func float(_ id: UInt64, _ value: Double) -> Data {
        element(id, bigEndian(value.bitPattern, byteCount: 8))
    }

    /// A SeekHead with 8-byte `SeekPosition` values, so its length does not depend on them.
    static func seekHead(_ entries: [(id: UInt64, position: UInt64)]) -> Data {
        let seeks = entries.map { entry in
            element(0x4DBB, element(0x53AB, id(entry.id)) + element(0x53AC, bigEndian(entry.position, byteCount: 8)))
        }
        return element(0x114D_9B74, seeks.concatenated())
    }

    private static func bigEndian(_ value: UInt64, byteCount: Int) -> Data {
        Data((0 ..< byteCount).reversed().map { UInt8(truncatingIfNeeded: value >> (8 * UInt64($0))) })
    }
}

extension Array where Element == Data {
    fileprivate func concatenated() -> Data {
        reduce(into: Data()) { $0 += $1 }
    }
}
