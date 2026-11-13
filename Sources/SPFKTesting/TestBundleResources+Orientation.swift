// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-testing

import Foundation

// MARK: - Orientation

/// Two seconds of ffmpeg's `testsrc2` at 160×120, 24 fps, with a sine on an AAC track:
///
///     ffmpeg -f lavfi -i testsrc2=size=160x120:rate=24:duration=2 -f lavfi -i sine=duration=2 \
///       -c:v libx264 -pix_fmt yuv420p -c:a aac -shortest orientation-pattern.mov
///
/// The MP4 is the MOV remuxed with `-c copy`. The picture is asymmetric under every rotation and
/// mirror, so an orientation test can tell all 8 apart; ``sample_mov`` is nearly uniform gray and
/// cannot.
extension TestBundleResources {
    public var orientation_pattern_mov: URL {
        internalResources.resource(named: "orientation-pattern.mov")
    }

    public var orientation_pattern_mp4: URL {
        internalResources.resource(named: "orientation-pattern.mp4")
    }
}

/// `songbird` at 400×226, stored unrotated with `irot 1`, which ImageIO reads as orientation 8:
///
///     ffmpeg -i songbird.jpg -vf scale=400:-2 small.png
///     avifenc -q 70 --irot 1 small.png orientation-8.avif
///
/// ImageIO reads an AVIF's orientation but cannot write one, so this is the only way to get a
/// rotated AVIF.
extension TestBundleResources {
    public var orientation_8_avif: URL {
        internalResources.resource(named: "orientation-8.avif")
    }
}
