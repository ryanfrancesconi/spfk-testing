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

    public var formats: [URL] { [
        tabla_aac,
        tabla_aif,
        tabla_caf,
        tabla_flac,
        tabla_m4a,
        tabla_mp3,
        tabla_mp4,
        tabla_ogg,
        tabla_wav,
    ] }

    /// format files which support either RIFF or Chapter markers and other metadata
    public var markerFormats: [URL] { [
        tabla_aif,
        tabla_flac,
        tabla_m4a,
        tabla_mp3,
        tabla_mp4,
        // tabla_ogg, // ogg isn't parsing on iOS
        tabla_wav,
    ] }

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
}

// MARK: - Images

extension TestBundleResources {
    public var sharksandwich: URL {
        internalResources.resource(named: "sharksandwich.jpg")
    }
}
