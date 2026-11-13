// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-testing

import Foundation

public final class BundleResources: Sendable {
    public let bundleURL: URL

    // Bundle.module.bundleURL
    public init(bundleURL: URL) {
        self.bundleURL = bundleURL
    }

    /// Where the bundle's resources are. Never assume a layout: Xcode writes macOS bundles with
    /// `Contents/Resources`, SwiftPM's CLI build writes them flat, and both occur on the same
    /// platform. Falls back to the bundle URL for a URL that names no bundle.
    ///
    /// `absoluteURL` is load-bearing: `Bundle.resourceURL` carries a `baseURL`, and `URL`'s `==`
    /// compares the relative string and base rather than the resolved path - so a relative form
    /// resolves to the right file while comparing unequal to every absolute URL of it.
    public var resourcesDirectory: URL {
        (Bundle(url: bundleURL)?.resourceURL ?? bundleURL).absoluteURL
    }

    /// Look in the bundle for the file name requested
    public func resource(named name: String) -> URL {
        resourcesDirectory.appendingPathComponent(name)
    }
}
