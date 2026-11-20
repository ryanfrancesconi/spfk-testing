// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-testing

import Foundation

/// Photos too many to bundle, in the folder `SPFK_CAPTURE_SAMPLES` names.
///
/// `xcodebuild` passes the variable to the test process only as `TEST_RUNNER_SPFK_CAPTURE_SAMPLES`.
public enum CaptureSamples {
    /// The folder, when the variable names one that exists.
    public static let folder: URL? = {
        guard let path = ProcessInfo.processInfo.environment["SPFK_CAPTURE_SAMPLES"], !path.isEmpty else { return nil }

        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory), isDirectory.boolValue else { return nil }

        return URL(fileURLWithPath: path, isDirectory: true)
    }()
}
