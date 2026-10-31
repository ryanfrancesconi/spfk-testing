// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-testing

import Foundation

/// A `UserDefaults` whose plist lives in its own temporary directory, deleted when it is released.
///
/// A named suite writes to `~/Library/Preferences`, and `removePersistentDomain` empties it without
/// removing the file — cfprefsd rewrites an empty plist asynchronously even after a delete. A suite
/// named by an absolute path writes there instead, creating the directory on first write, and a
/// deleted directory stays deleted.
public final class TemporaryDefaults: UserDefaults {
    public let directory: URL

    /// - Parameter label: names the directory, so a leftover one says which test made it.
    public init?(label: String) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(label)-\(UUID().uuidString)", isDirectory: true)

        self.directory = directory
        super.init(suiteName: directory.appendingPathComponent("defaults").path)
    }

    deinit {
        try? FileManager.default.removeItem(at: directory)
    }
}
