// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-testing

import Foundation

extension TestBundleResources {
    /// ``tabla_mp3``'s audio with an ID3v2.3 tag written by mutagen 1.48.1, the library behind
    /// MusicBrainz Picard, never by this workspace's writer: `TIT2`, `TPE1`, an undescribed Latin-1
    /// `COMM` in `deu` ("Grüße aus Köln") and a `TXXX` described `MusicBrainz Album Id`.
    ///
    ///     ffmpeg -i tabla.mp3 -map 0:a -c copy -map_metadata -1 -id3v2_version 0 foreign_comment_deu.mp3
    ///
    ///     tag = ID3()
    ///     tag.add(TIT2(encoding=0, text="Stonehenge"))
    ///     tag.add(TPE1(encoding=0, text="Spinal Tap"))
    ///     tag.add(COMM(encoding=0, lang="deu", desc="", text="Grüße aus Köln"))
    ///     tag.add(TXXX(encoding=0, desc="MusicBrainz Album Id", text="0b3c7c8e-5a6f-4c3e-9d2a-7f1e2b4c6d8a"))
    ///     tag.save("foreign_comment_deu.mp3", v2_version=3)
    public var foreign_comment_deu_mp3: URL {
        internalResources.resource(named: "foreign_comment_deu.mp3")
    }
}
