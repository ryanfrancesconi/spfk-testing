// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-testing

import Foundation
import Testing

@testable import SPFKTesting

struct TemporaryDefaultsTests {
    private let preferences = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Preferences")

    @Test func writesLandInItsDirectoryAndNotInPreferences() throws {
        let before = try Set(FileManager.default.contentsOfDirectory(atPath: preferences.path))

        let defaults = try #require(TemporaryDefaults(label: "TemporaryDefaultsTests"))
        defaults.set("value", forKey: "key")
        defaults.synchronize()

        #expect(defaults.string(forKey: "key") == "value")
        #expect(FileManager.default.fileExists(atPath: defaults.directory.appendingPathComponent("defaults.plist").path))

        let added = try Set(FileManager.default.contentsOfDirectory(atPath: preferences.path)).subtracting(before)
        #expect(added.filter { $0.contains("TemporaryDefaultsTests") }.isEmpty)
    }

    @Test func releasingItDeletesItsDirectory() throws {
        var directory: URL?

        try autoreleasepool {
            let defaults = try #require(TemporaryDefaults(label: "TemporaryDefaultsTests"))
            defaults.set(1, forKey: "key")
            defaults.synchronize()
            directory = defaults.directory
        }

        let released = try #require(directory)
        #expect(!FileManager.default.fileExists(atPath: released.path))
    }

    @Test func eachInstanceStartsEmpty() throws {
        let first = try #require(TemporaryDefaults(label: "TemporaryDefaultsTests"))
        first.set("value", forKey: "key")

        let second = try #require(TemporaryDefaults(label: "TemporaryDefaultsTests"))
        #expect(second.string(forKey: "key") == nil)
    }
}
