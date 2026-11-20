// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-testing

import Foundation

/// RAW files too large to bundle, in the folder `SPFK_RAW_SAMPLES` names.
///
/// `xcodebuild` passes the variable to the test process only as `TEST_RUNNER_SPFK_RAW_SAMPLES`. A suite
/// that needs a sample is enabled on ``folder`` and requires its own file through ``url(_:)``.
public enum RAWSamples {
    /// The folder, when the variable names one that exists.
    public static let folder: URL? = {
        guard let path = ProcessInfo.processInfo.environment["SPFK_RAW_SAMPLES"], !path.isEmpty else { return nil }

        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory), isDirectory.boolValue else { return nil }

        return URL(fileURLWithPath: path, isDirectory: true)
    }()

    /// The named file in ``folder``, or nil when the folder or the file is missing.
    public static func url(_ name: String) -> URL? {
        guard let url = folder?.appendingPathComponent(name, isDirectory: false),
              FileManager.default.fileExists(atPath: url.path)
        else { return nil }

        return url
    }
}
