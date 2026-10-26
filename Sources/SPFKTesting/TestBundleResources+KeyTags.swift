// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-testing

import Foundation
import Testing

/// A key tag value as other tools write it, in one file per tag family: ID3v2 `TKEY` (mp3),
/// Xiph `INITIALKEY` (flac) and the MP4 freeform `----:com.apple.iTunes:INITIALKEY` (m4a).
/// Written with ffmpeg, metaflac and AtomicParsley, never by this workspace's own writer.
public struct KeyTagFixture: Sendable, CustomTestStringConvertible {
    /// The key tag's text, or nil when the file has none.
    public let initialKey: String?
    public let comment: String?
    public let mp3: URL
    public let flac: URL
    public let m4a: URL

    public var urls: [URL] { [mp3, flac, m4a] }
    public var testDescription: String { initialKey ?? "comment: \(comment ?? "")" }
}

extension TestBundleResources {
    public var keyTagFixtures: [KeyTagFixture] {
        [
            fixture("camelot", "8A"),
            fixture("standard", "C# Minor"),
            fixture("abmin", "Abmin"),
            fixture("openkey", "1m"),
            fixture("root", "F"),
            fixture("glyph", "B♭maj"),
            fixture("off", "o"),
            fixture("piano", "Piano"),
            fixture("relative", "Am/C"),
            fixture("comment", nil, comment: "8A - Energy 6"),
        ]
    }

    /// A FLAC whose key is in a Vorbis `KEY` comment ("Am"), as MusicBrainz Picard writes it,
    /// rather than `INITIALKEY`.
    public var keyTagVorbisKEY: URL {
        internalResources.resource(named: "key_vorbis_key.flac")
    }

    private func fixture(_ slug: String, _ initialKey: String?, comment: String? = nil) -> KeyTagFixture {
        KeyTagFixture(
            initialKey: initialKey,
            comment: comment,
            mp3: internalResources.resource(named: "key_\(slug).mp3"),
            flac: internalResources.resource(named: "key_\(slug).flac"),
            m4a: internalResources.resource(named: "key_\(slug).m4a")
        )
    }
}
