// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-testing

import Foundation

public final class TestBundleResources: Sendable {
    let internalResources: BundleResources

    public var bundleURL: URL { internalResources.bundleURL }
    public var resourcesDirectory: URL { internalResources.resourcesDirectory }

    public static let shared = TestBundleResources(bundleURL: Bundle.module.bundleURL)

    public init(bundleURL: URL) {
        internalResources = BundleResources(bundleURL: bundleURL)
    }
}

// MARK: - Audio

extension TestBundleResources {
    public var audioCases: [URL] { [
        mp3_id3, wav_bext_v1, wav_bext_v2, tabla_mp4, tabla_wav, tabla_6_channel, cowbell_wav, pink_noise,
    ] }

    public var formats: [URL] {
        var result = [tabla_aac, tabla_aif, tabla_caf, tabla_flac, tabla_m4a, tabla_mp3, tabla_mp4, tabla_wav]
        #if os(macOS)
            result.append(tabla_ogg)
        #endif
        return result
    }

    /// format files which support either RIFF or Chapter markers and other metadata
    public var markerFormats: [URL] {
        var result = [tabla_aif,
                      tabla_flac,
                      tabla_m4a,
                      tabla_mp3,
                      tabla_mp4,
                      tabla_wav]
        #if os(macOS)
            result.append(tabla_ogg)
        #endif
        return result
    }

    public var ituns_mpb_m4a: URL {
        internalResources.resource(named: "ITUNSMPB.m4a")
    }

    public var mp3_no_metadata: URL {
        internalResources.resource(named: "no metadata.mp3")
    }

    public var mp3_xmp: URL {
        internalResources.resource(named: "xmp.mp3")
    }

    public var mp3_id3: URL {
        internalResources.resource(named: "and-oh-how-they-danced.mp3")
    }

    public var wav_bext_v1: URL {
        internalResources.resource(named: "123456789_60BPM_48k.wav")
    }

    public var counting_123456789bpm60_48k: URL {
        wav_bext_v1
    }

    public var wav_bext_v2: URL {
        internalResources.resource(named: "and-oh-how-they-danced.wav")
    }

    public var wav_bext_v2b: URL {
        internalResources.resource(named: "and-oh-how-they-danced_2.wav")
    }

    public var tabla_aac: URL {
        internalResources.resource(named: "tabla.aac")
    }

    public var tabla_mp4: URL {
        internalResources.resource(named: "tabla.mp4")
    }

    public var tabla_wav: URL {
        internalResources.resource(named: "tabla.wav")
    }

    public var tabla_flac: URL {
        internalResources.resource(named: "tabla.flac")
    }

    /// FLAC with BEXT and iXML APPLICATION blocks authored by metaflac (not our bridge).
    /// Used to verify that externally-produced APPLICATION blocks are read correctly.
    public var flac_bext_ixml_external: URL {
        internalResources.resource(named: "bext_ixml_external.flac")
    }

    public var tabla_ogg: URL {
        internalResources.resource(named: "tabla.ogg")
    }

    public var tabla_aif: URL {
        internalResources.resource(named: "tabla.aif")
    }

    public var tabla_caf: URL {
        internalResources.resource(named: "tabla.caf")
    }

    public var tabla_mp3: URL {
        internalResources.resource(named: "tabla.mp3")
    }

    public var tabla_m4a: URL {
        internalResources.resource(named: "tabla.m4a")
    }

    /// ``tabla_m4a``'s AAC remuxed into Matroska, bit-identical:
    ///
    ///     ffmpeg -i tabla.m4a -c:a copy \
    ///       -metadata title="SPFK Tabla Matroska" -metadata artist="Spongefork" tabla.mka
    ///
    /// The audio fixture for Matroska work, because **`sample.mkv`'s audio track is digital
    /// silence** (-91 dB, verified with `ffmpeg -af volumedetect`) — it exists to make track counts
    /// testable, not signal. A decoder tested only against that passes while producing nothing but
    /// zeros. This carries real signal (-0.1 dB peak) and has an exact reference in ``tabla_m4a``,
    /// which AVFoundation opens normally, so decoded output can be compared rather than merely
    /// counted.
    public var tabla_mka: URL {
        internalResources.resource(named: "tabla.mka")
    }

    /// Two audio tracks and no video, in Matroska:
    ///
    ///     ffmpeg -f lavfi -t 2.066 -i "sine=frequency=440:sample_rate=44100" \
    ///       -f lavfi -t 2.066 -i "sine=frequency=880:sample_rate=44100" \
    ///       -map 0:a -map 1:a -filter:a:0 volume=3 -filter:a:1 volume=3 \
    ///       -c:a aac -b:a 32k \
    ///       -metadata:s:a:0 language=eng -metadata:s:a:0 title=English \
    ///       -metadata:s:a:1 language=jpn -metadata:s:a:1 title=Japanese dualaudio.mka
    ///
    /// **The absence of a video track is the point.** A `.mka` is `org.matroska.mka`, which conforms
    /// to `.audio` and not `.movie`, so anything that lists a file's audio tracks behind a video
    /// test skips it — the shape ``dualaudio_m4a`` shares.
    ///
    /// Same tones as ``sample_dualaudio_mkv``: 440 Hz and 880 Hz, mono, 44.1 kHz, AAC, so a test
    /// asserts *which* track it decoded. Measured after the AAC round trip: 442/886 Hz by zero
    /// crossing, peaking 0.53 and 0.69, 92160 frames each.
    public var dualaudio_mka: URL {
        internalResources.resource(named: "dualaudio.mka")
    }

    /// The AVFoundation counterpart to ``dualaudio_mka`` — same two tones, same languages, in an
    /// MP4 audio container that `AVAudioFile(forReading:)` opens and reads the first track of.
    ///
    /// **No track names**, unlike every other fixture in this family: ffmpeg's MP4 muxers write no
    /// `udta/name`, only the QuickTime one does, and a `.mov` renamed `.m4a` would be a fixture
    /// lying about its own container. Language codes alone are also the common real-world case, so
    /// this exercises `AudioTrackDescription.displayName`'s language fallback. Verified against
    /// AVFoundation: two tracks, `trackID` 1 and 2, `languageCode` `eng`/`jpn`, an audible
    /// `AVMediaSelectionGroup` with both options, 91136 frames each.
    public var dualaudio_m4a: URL {
        internalResources.resource(named: "dualaudio.m4a")
    }

    /// ``tabla_wav`` encoded as FLAC in Matroska:
    ///
    ///     ffmpeg -i tabla.wav -c:a flac \
    ///       -metadata title="SPFK Tabla Matroska FLAC" -metadata artist="Spongefork" tabla_flac.mka
    ///
    /// **Sample-exact against ``tabla_wav``** — 210900 frames, no encoder priming — where
    /// ``tabla_mka`` is 2112 frames long and shifted later by AAC's. A decoder can be held to the
    /// samples here rather than to a correlation.
    public var tabla_flac_mka: URL {
        internalResources.resource(named: "tabla_flac.mka")
    }

    /// ``tabla_wav`` stored uncompressed in Matroska, at the source's own 24-bit depth:
    ///
    ///     ffmpeg -i tabla.wav -c:a pcm_s24le \
    ///       -metadata title="SPFK Tabla Matroska PCM" -metadata artist="Spongefork" tabla_pcm.mka
    ///
    /// 24-bit deliberately: it is the width `AVAudioPCMBuffer` has no channel-data accessor for, so
    /// it is the one a PCM path has to widen by hand.
    public var tabla_pcm_mka: URL {
        internalResources.resource(named: "tabla_pcm.mka")
    }

    /// ``tabla_wav`` in Matroska PCM with blocks of 66,666 frames, where ``tabla_pcm_mka``'s are
    /// 4,096 — longer than one decode buffer:
    ///
    ///     ffmpeg -max_size 400000 -i tabla.wav -c:a copy \
    ///       -metadata title="SPFK Tabla Matroska PCM long blocks" -metadata artist="Spongefork" \
    ///       tabla_pcm_long_blocks.mka
    ///
    /// `-max_size` is the WAV demuxer's packet size, so it goes before `-i`.
    public var tabla_pcm_long_blocks_mka: URL {
        internalResources.resource(named: "tabla_pcm_long_blocks.mka")
    }

    public var tabla_6_channel: URL {
        internalResources.resource(named: "tabla_6_channel.wav")
    }

    public var toc_many_children: URL {
        internalResources.resource(named: "toc_many_children.mp3")
    }

    public var cowbell_wav: URL {
        internalResources.resource(named: "cowbell.wav")
    }

    public var cowbell_bext_wav: URL {
        internalResources.resource(named: "cowbell_bext.wav")
    }

    public var pink_noise: URL {
        internalResources.resource(named: "pink_noise.wav")
    }

    public var no_data_chunk: URL {
        internalResources.resource(named: "no_data_chunk.wav")
    }

    public var ixml_chunk: URL {
        internalResources.resource(named: "ixml.wav")
    }

    public var addAudio: URL {
        // is m4a internally
        internalResources.resource(named: "boom.addAudio")
    }
}

extension TestBundleResources {
    // MARK: - Pre-rated fixtures (rating=80 embedded by external tooling)

    /// WAV with ID3v2 POPM frame (WMP email, byte=196 = 4 stars = normalized 80).
    public var rated_80_wav: URL {
        internalResources.resource(named: "rated_80.wav")
    }

    /// MP3 with ID3v2 POPM frame (WMP email, byte=196 = 4 stars = normalized 80).
    public var rated_80_mp3: URL {
        internalResources.resource(named: "rated_80.mp3")
    }

    /// FLAC with Xiph RATING=80 and FMPS_RATING=0.800.
    public var rated_80_flac: URL {
        internalResources.resource(named: "rated_80.flac")
    }

    /// M4A with freeform ----:com.apple.iTunes:RATING atom = "80".
    public var rated_80_m4a: URL {
        internalResources.resource(named: "rated_80.m4a")
    }

    /// OGG Vorbis with Xiph RATING=80 and FMPS_RATING=0.800.
    public var rated_80_ogg: URL {
        internalResources.resource(named: "rated_80.ogg")
    }

    /// AIFF with ID3v2 POPM frame (WMP email, byte=196 = 4 stars = normalized 80).
    public var rated_80_aif: URL {
        internalResources.resource(named: "rated_80.aif")
    }
}

// MARK: - Musical Key Audio

extension TestBundleResources {
    public var key_a_major: URL {
        internalResources.resource(named: "a_major.mp3")
    }

    public var key_asharp_major: URL {
        internalResources.resource(named: "asharp_major.mp3")
    }

    public var key_b_major: URL {
        internalResources.resource(named: "b_major.mp3")
    }

    public var key_c_major: URL {
        internalResources.resource(named: "c_major.mp3")
    }

    public var key_csharp_major: URL {
        internalResources.resource(named: "csharp_major.mp3")
    }

    public var key_d_major: URL {
        internalResources.resource(named: "d_major.mp3")
    }

    public var key_dsharp_major: URL {
        internalResources.resource(named: "dsharp_major.mp3")
    }

    public var key_e_major: URL {
        internalResources.resource(named: "e_major.mp3")
    }

    public var key_f_major: URL {
        internalResources.resource(named: "f_major.mp3")
    }

    public var key_fsharp_major: URL {
        internalResources.resource(named: "fsharp_major.mp3")
    }

    public var key_g_major: URL {
        internalResources.resource(named: "g_major.mp3")
    }

    public var key_gsharp_major: URL {
        internalResources.resource(named: "gsharp_major.mp3")
    }

    /// All 12 major key audio files for testing musical key detection.
    public var majorKeyAudioFiles: [(note: String, url: URL)] {
        [
            ("C", key_c_major),
            ("C#", key_csharp_major),
            ("D", key_d_major),
            ("D#", key_dsharp_major),
            ("E", key_e_major),
            ("F", key_f_major),
            ("F#", key_fsharp_major),
            ("G", key_g_major),
            ("G#", key_gsharp_major),
            ("A", key_a_major),
            ("A#", key_asharp_major),
            ("B", key_b_major),
        ]
    }

    /// FLAC with artwork stored in a METADATA_BLOCK_PICTURE Vorbis comment entry
    /// and no native FLAC PICTURE block. Used to test XiphComment read fallback
    /// and migration to native PICTURE blocks.
    public var tabla_legacy_picture_flac: URL {
        internalResources.resource(named: "tabla_legacy_picture.flac")
    }
}

// MARK: - Video

extension TestBundleResources {
    /// A tiny but complete QuickTime movie.
    ///
    /// Built to serve every kind of video test from one 6 KB file, because the alternatives each
    /// fall short: an audio-only MP4 does not exercise the same format handlers as a `.mov`, and a
    /// single-frame movie has no duration to seek within.
    ///
    /// - 2 seconds, 160x120 (non-square, so aspect-ratio bugs surface), H.264 at 30fps
    /// - a keyframe every 15 frames, so a trim can land mid-GOP
    /// - visibly distinct frames, so a thumbnail-at-timestamp test can assert *which* frame it got
    /// - an AAC audio track, so track counts and audio-through-trim are testable
    /// - QuickTime user data: make, model, software, creation date, and an ISO 6709 location
    ///   (`+45.5152-122.6784+015.000/`, Portland) -- exactly what `QuickTimeUserData` reads
    public var sample_mov: URL {
        internalResources.resource(named: "sample.mov")
    }

    /// The same content as ``sample_mov``, remuxed into a Matroska container:
    ///
    ///     ffmpeg -i sample.mov -c copy \
    ///       -metadata title="SPFK Sample Matroska" -metadata artist="Spongefork" sample.mkv
    ///
    /// `-c copy` rather than a re-encode, so the streams are bit-identical to the `.mov` and any
    /// difference a test observes is the *container*, which is the only thing Matroska changes.
    /// Carries `title` and `artist` so a read can be asserted without writing first.
    ///
    /// **AVFoundation cannot open this file** — Matroska is absent from
    /// `AVURLAsset.audiovisualTypes()`. That is the point of the fixture: it exercises the
    /// TagLib-backed metadata path for a container the AV stack refuses, so anything reaching for
    /// `AVAsset` fails loudly here instead of silently working via a format that happens to be
    /// supported.
    public var sample_mkv: URL {
        internalResources.resource(named: "sample.mkv")
    }

    /// The same content as ``sample_mov`` re-encoded into WebM:
    ///
    ///     ffmpeg -i sample.mov -c:v libvpx-vp9 -crf 40 -b:v 0 -g 15 -c:a libopus -b:a 24k \
    ///       -metadata title="SPFK Sample WebM" -metadata artist="Spongefork" sample.webm
    ///
    /// A re-encode rather than the `-c copy` used for ``sample_mkv``, because WebM admits neither
    /// H.264 nor AAC — so this is VP9 video and Opus audio (resampled to Opus's native 48 kHz),
    /// still 160x120 and 2 seconds with a keyframe every 15 frames.
    ///
    /// Exists to prove the claim that one Matroska parser covers both containers: WebM is a
    /// Matroska profile, and the only thing that should differ is the EBML `DocType`. It is also
    /// the fixture that covers an **absent `CodecPrivate`** — VP9 needs no out-of-band setup data
    /// and carries none, where H.264 carries an `avcC`, so a code path that assumes every video
    /// track has one fails here and only here.
    public var sample_webm: URL {
        internalResources.resource(named: "sample.webm")
    }

    /// ``sample_mov``'s audio track alone, in a Matroska container:
    ///
    ///     ffmpeg -i sample.mov -vn -c:a copy \
    ///       -metadata title="SPFK Sample Matroska Audio" -metadata artist="Spongefork" sample.mka
    ///
    /// `-c copy`, so the AAC is bit-identical to the one in ``sample_mov`` and ``sample_mkv``.
    ///
    /// The audio-only case, which `.mka` is Matroska's own extension for. Worth having separately
    /// because a video-bearing file cannot exercise it: anything reaching for a video track finds
    /// one in ``sample_mkv`` and silently works, where here there is none to find.
    public var sample_mka: URL {
        internalResources.resource(named: "sample.mka")
    }

    /// ``sample_mkv`` with its `SeekHead` rewritten into the two-level form real muxers write: the
    /// one at the head of the file names a *second* `SeekHead` rather than naming `Cues` directly,
    /// and that second one names `Cues`.
    ///
    /// Byte-for-byte identical to ``sample_mkv`` everywhere else — the replacement `SeekHead` is
    /// built inside the existing `Void` padding, so no offset moves and the file is the same
    /// length. ffmpeg writes the flat form, which is why ``sample_mkv`` alone cannot cover this.
    ///
    /// The reason it matters: libwebm keeps only the *first* `SeekHead` and never follows a nested
    /// one, so a reader that stops at what libwebm parsed finds no index here and silently falls
    /// back to the start of the file. Against a film that reads as a black poster frame.
    public var sample_nested_seekhead_mkv: URL {
        internalResources.resource(named: "sample-nested-seekhead.mkv")
    }

    /// ``sample_mkv`` with its `Cues` rewritten so video and audio cue points interleave — each cue
    /// point names one track, and the audio ones sit between the video keyframes.
    ///
    /// The shape a muxer that indexes every track produces. It matters because looking a cue point
    /// up by time and *then* asking it for a track finds the audio point nearest the target and
    /// gives up, which is the case libwebm's own `Cues::Find` documents as wrong in a `TODO`.
    /// Seeking video to 1.5 s here lands on the 1300 ms audio cue point under that algorithm and on
    /// the 1048 ms video keyframe under a correct one.
    public var sample_interleaved_cues_mkv: URL {
        internalResources.resource(named: "sample-interleaved-cues.mkv")
    }

    /// ``sample_mov`` with a timecode track that the **audio** track references:
    ///
    ///     ffmpeg -i sample.mov -timecode 00:00:00:00 -c copy sample-timecode.mov
    ///
    /// then a `tref > tmcd` pointing at the timecode track injected into the audio `trak`, since
    /// ffmpeg writes that reference only on the video track.
    ///
    /// **The audio track's pre-existing `tref` is the entire point.** A `trak` may carry only one
    /// `tref`, and a writer that appends a second rather than merging into it produces a file
    /// AVFoundation discards the whole track from -- silently, while `ffprobe` still reads it. A
    /// camera file (GoPro and similar) has exactly this shape, which is why the failure was
    /// invisible against every fixture whose audio track had no `tref` at all.
    ///
    /// Do not "simplify" this to an audio-only file: the timecode track has to exist for the
    /// reference to resolve.
    public var sample_timecode_mov: URL {
        internalResources.resource(named: "sample-timecode.mov")
    }

    /// ``sample_mov`` re-encoded to 29.97 with a **drop-frame** timecode track starting one frame
    /// past the hour:
    ///
    ///     ffmpeg -i sample.mov -r 30000/1001 -timecode "01:00:00;01" \
    ///       -c:v libx264 -crf 40 -pix_fmt yuv420p -c:a copy sample-timecode-offset.mov
    ///
    /// Two properties make it the start-timecode fixture, and neither ``sample_timecode_mov`` nor
    /// any other bundled file has them. The start is **non-zero**, so a reader that discards the
    /// `tmcd` value and a reader that keeps it disagree. And `01:00:00;01` is **not a whole
    /// multiple of any label interval**, so a ruler that phases its grid from real-time zero
    /// instead of from the start renders every label a frame off.
    ///
    /// The `;` separator is the drop flag, which is why the rate had to change: ffmpeg refuses a
    /// drop-frame timecode at a rate that has no drop twin.
    public var sample_timecode_offset_mov: URL {
        internalResources.resource(named: "sample-timecode-offset.mov")
    }

    /// ``sample_mov``'s video with **two** audio tracks, for audio track selection:
    ///
    ///     ffmpeg -i sample.mov \
    ///       -f lavfi -t 2.066 -i "sine=frequency=440:sample_rate=44100" \
    ///       -f lavfi -t 2.066 -i "sine=frequency=880:sample_rate=44100" \
    ///       -i sub.srt -map 0:v -map 1:a -map 2:a -map 3:s \
    ///       -filter:a:0 volume=3 -filter:a:1 volume=3 \
    ///       -c:v copy -c:a aac -b:a 32k -c:s srt \
    ///       -metadata:s:a:0 language=eng -metadata:s:a:0 title=English \
    ///       -metadata:s:a:1 language=jpn -metadata:s:a:1 title=Japanese \
    ///       -metadata:s:s:0 language=eng sample-dualaudio.mkv
    ///
    /// **The two tracks are 440 Hz and 880 Hz**, so a test asserts *which* track it decoded rather
    /// than only that two differ — measure the dominant frequency or count zero crossings, whose
    /// ratio is exactly 2. Measured after the AAC round trip: 440/879 Hz, peaking 0.53 and 0.69, so
    /// neither clips.
    ///
    /// Identical in every other respect (mono, 44.1 kHz, AAC), which is what isolates the track
    /// choice as the only variable.
    ///
    /// The subtitle track is not decoration: `availableAudioTracks` filters by track kind, and a
    /// file whose non-audio tracks sit *after* the audio ones is what catches a filter that is
    /// really an index.
    public var sample_dualaudio_mkv: URL {
        internalResources.resource(named: "sample-dualaudio.mkv")
    }

    /// The AVFoundation counterpart to ``sample_dualaudio_mkv`` — same video, same two tone tracks,
    /// same names and languages, in a QuickTime container and without the subtitle track.
    ///
    /// Both containers are needed because audio track selection is not a Matroska feature: MP4 and
    /// MOV carry alternate audio as readily, and the two backends select it by unrelated
    /// mechanisms.
    ///
    /// Verified against AVFoundation rather than assumed: the tracks come back with
    /// `trackID` 2 and 3, `languageCode` `eng`/`jpn`, and the ffmpeg `title` reaching
    /// `commonMetadata` as `.commonKeyTitle` (stored as `udta/name`). An **audible
    /// `AVMediaSelectionGroup` is present** with both options, correctly named and localed — so
    /// this fixture exercises the media-selection route as well as per-track enabling. Whether
    /// every real-world multi-track movie declares such a group is not established here.
    public var sample_dualaudio_mov: URL {
        internalResources.resource(named: "sample-dualaudio.mov")
    }

    /// ``sample_mov``'s video in an MXF container, with a tone in place of its audio:
    ///
    ///     ffmpeg -y -i sample.mov -f lavfi -t 2 -i "sine=frequency=440:sample_rate=48000" \
    ///       -map 0:v -map 1:a -c:v mpeg2video -b:v 300k -c:a pcm_s16le -shortest sample.mxf
    ///
    /// **Nothing opens this without `ProVideoFormats.register()`** — MXF is absent from
    /// `AVURLAsset.audiovisualTypes()` until the process opts into macOS's professional video
    /// workflow plug-ins, and those ship in a separate Apple download. That is what the fixture is
    /// for, so any test using it must be gated on `ProVideoFormats.isAvailable`.
    ///
    /// A re-encode rather than the `-c copy` used for ``sample_mkv``: the MXF muxer takes neither
    /// H.264 nor AAC, so this is MPEG-2 video and uncompressed PCM, and the streams are not
    /// bit-identical to the `.mov`. It stays 160x120 and 2 seconds with ``sample_mov``'s visibly
    /// distinct frames, so a thumbnail-at-timestamp test can still assert *which* frame it got.
    ///
    /// **The audio is a tone rather than ``sample_mov``'s own track**, because that track is
    /// digital silence — the trap ``tabla_mka`` exists for, and a worse one here: a wrong ASBD
    /// decodes silence while reporting success at every step, so against a silent fixture a
    /// decode test cannot tell the two apart. Measured through `AVAssetReader` as deinterleaved
    /// 32-bit float: 96000 frames, 48 kHz mono, peak 0.125, 439.5 Hz by zero crossing.
    ///
    /// MPEG-2 rather than DNxHD deliberately — a DNxHD fixture is 7.5 MB, and the format reader is
    /// the part under test either way. At 285 KB this is still the largest fixture here, almost all
    /// of it the uncompressed PCM.
    public var sample_mxf: URL {
        internalResources.resource(named: "sample.mxf")
    }
}

// MARK: - Images

extension TestBundleResources {
    public var sharksandwich: URL {
        internalResources.resource(named: "sharksandwich.jpg")
    }

    /// HEIC version of sharksandwich, for testing non-JPEG/PNG artwork decode.
    public var sharksandwich_heic: URL {
        internalResources.resource(named: "sharksandwich.heic")
    }

    /// WebP version of sharksandwich, for testing non-JPEG/PNG artwork decode.
    public var sharksandwich_webp: URL {
        internalResources.resource(named: "sharksandwich.webp")
    }

    /// A real photograph (yellow warbler on a branch) with an unambiguous subject,
    /// for testing ML image classification against genuine framework output.
    public var songbird: URL {
        internalResources.resource(named: "songbird.jpg")
    }
}
