import Foundation

public final class BundleResources: Sendable {
    public let bundleURL: URL

    // Bundle.module.bundleURL
    public init(bundleURL: URL) {
        self.bundleURL = bundleURL
    }

    #if os(macOS)
        public var resourcesDirectory: URL {
            bundleURL
                .appendingPathComponent("Contents")
                .appendingPathComponent("Resources")
        }

    #elseif os(iOS)
        public var resourcesDirectory: URL {
            bundleURL
        }
    #endif

    /// Look in the bundle for the file name requested
    public func resource(named name: String) -> URL {
        resourcesDirectory.appendingPathComponent(name)
    }
}
