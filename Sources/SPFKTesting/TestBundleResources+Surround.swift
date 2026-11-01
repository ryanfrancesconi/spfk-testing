// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-testing

import Foundation

// MARK: - Surround

/// Two seconds of 5.1 at 48 kHz, one tone per channel, so a test can tell which channel landed
/// where. Each codec stores its channels in its own order, so assert by tone, never by index.
///
/// Built from one six-channel float WAV, then encoded per codec:
///
///     ffmpeg -f lavfi -i sine=f=440:d=2:r=48000 … -f lavfi -i sine=f=2100:d=2:r=48000 \
///       -filter_complex '[0][1][2][3][4][5]join=inputs=6:channel_layout=5.1(side):map=0.0-FL|1.0-FR|2.0-FC|3.0-LFE|4.0-SL|5.0-SR' \
///       -c:a pcm_f32le source51.wav
///
/// Every fixture was checked by decoding it with ffmpeg: each channel carries its tone at 0.125
/// (-18 dBFS), with no other tone above 0.001.
extension TestBundleResources {
    /// The tone on each channel, in L R C LFE Ls Rs order.
    public static let surroundTones: [Double] = [440, 660, 1000, 80, 1500, 2100]

    /// `-c:a eac3 -b:a 384k`. `A_EAC3`, no `CodecPrivate`; ffmpeg decodes 94976 frames.
    public var surround_eac3_mka: URL { internalResources.resource(named: "surround_eac3.mka") }

    /// `-c:a ac3 -b:a 384k`. `A_AC3`, no `CodecPrivate`; ffmpeg decodes 94976 frames.
    public var surround_ac3_mka: URL { internalResources.resource(named: "surround_ac3.mka") }

    /// `-c:a aac -b:a 384k`. `A_AAC`, with a 25-byte `CodecPrivate`.
    public var surround_aac_mka: URL { internalResources.resource(named: "surround_aac.mka") }

    /// `-c:a flac -sample_fmt s16`. Lossless, so its samples are the reference the lossy ones are
    /// held to.
    public var surround_flac_mka: URL { internalResources.resource(named: "surround_flac.mka") }

    /// `-c:a libopus -mapping_family 1 -b:a 256k`, after remapping the side surrounds to back.
    /// libopus refuses `5.1(side)`.
    public var surround_opus_mka: URL { internalResources.resource(named: "surround_opus.mka") }

    /// Encoded as ``surround_opus_mka`` is, but in Ogg. Read by libsndfile.
    public var surround_opus_opus: URL { internalResources.resource(named: "surround_opus.opus") }

    /// `-c:a libvorbis -q:a 4`. Read by libsndfile. The LFE decodes at 0.153 rather than 0.125.
    public var surround_vorbis_ogg: URL { internalResources.resource(named: "surround_vorbis.ogg") }

    /// Stereo E-AC-3 (`-b:a 192k`), 440 Hz left and 660 Hz right; ffmpeg decodes 96000 frames.
    public var stereo_eac3_mka: URL { internalResources.resource(named: "stereo_eac3.mka") }

    /// Every 5.1 fixture above.
    public var surroundFixtures: [URL] { [
        surround_eac3_mka, surround_ac3_mka, surround_aac_mka, surround_flac_mka,
        surround_opus_mka, surround_opus_opus, surround_vorbis_ogg,
    ] }
}
