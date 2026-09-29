// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-testing

import Foundation

// MARK: - One file per container

/// Quarter-second 440 Hz mono tones, 44.1 kHz except Opus (48 kHz), for the containers the other
/// fixtures don't cover. Generated with `ffmpeg -f lavfi -i sine=frequency=440:sample_rate=44100:duration=0.25 -ac 1`
/// and a per-container codec; `sine.aifc` with `afconvert -f AIFC -d BEI16`, since ffmpeg's muxer
/// writes 16-bit big-endian PCM as plain `AIFF`.
extension TestBundleResources {
    public var sine_aifc: URL { internalResources.resource(named: "sine.aifc") }
    public var sine_au: URL { internalResources.resource(named: "sine.au") }
    public var sine_snd: URL { internalResources.resource(named: "sine.snd") }
    public var sine_m4b: URL { internalResources.resource(named: "sine.m4b") }
    public var sine_opus: URL { internalResources.resource(named: "sine.opus") }
    /// Real Wave64: lowercase `riff` plus a GUID, not a renamed WAV.
    public var sine_w64: URL { internalResources.resource(named: "sine.w64") }
    /// H.264 64x64 plus AAC.
    public var sine_m4v: URL { internalResources.resource(named: "sine.m4v") }
    /// MPEG transport stream, H.264 64x64 plus AAC.
    public var sine_ts: URL { internalResources.resource(named: "sine.ts") }
    /// WavPack (`-c:a wavpack`). Not an `AudioFileType`, so not in ``oneFilePerContainer``.
    public var sine_wv: URL { internalResources.resource(named: "sine.wv") }
    /// ASF with WMA v2 (`-c:a wmav2`). Not an `AudioFileType`, so not in ``oneFilePerContainer``.
    public var sine_wma: URL { internalResources.resource(named: "sine.wma") }

    /// One fixture for every container extension, for tests that pin a per-format capability
    /// against the code that implements it.
    public var oneFilePerContainer: [URL] {
        [
            tabla_aac, tabla_aif, sine_aifc, sine_au, tabla_caf, tabla_flac, tabla_m4a, sine_m4b,
            sine_m4v, tabla_mka, sample_mkv, sample_mov, tabla_mp3, tabla_mp4, sample_mxf, tabla_ogg,
            sine_opus, sine_snd, sine_ts, tabla_wav, sine_w64, sample_webm,
        ]
    }
}
