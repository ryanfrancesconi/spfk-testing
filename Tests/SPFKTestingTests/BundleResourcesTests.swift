import Foundation
@testable import SPFKTesting
import Testing

@Suite("BundleResources")
struct BundleResourcesTests {
    @Test("init stores bundleURL")
    func initStoresBundleURL() {
        let url = Bundle.module.bundleURL
        let br = BundleResources(bundleURL: url)
        #expect(br.bundleURL == url)
    }

    @Test("resourcesDirectory is derived from bundleURL")
    func resourcesDirectoryDerived() {
        let br = BundleResources(bundleURL: Bundle.module.bundleURL)
        #expect(br.resourcesDirectory.path.hasPrefix(br.bundleURL.path))
    }

    @Test("resourcesDirectory appends Contents/Resources on macOS")
    func resourcesDirectoryPath() {
        let br = BundleResources(bundleURL: Bundle.module.bundleURL)
        let dir = br.resourcesDirectory
        #expect(dir.path.hasSuffix("Contents/Resources"))
    }

    @Test("resource(named:) returns URL under resourcesDirectory")
    func resourceNamedPath() {
        let br = BundleResources(bundleURL: Bundle.module.bundleURL)
        let url = br.resource(named: "test.wav")
        #expect(url.path.hasPrefix(br.resourcesDirectory.path))
        #expect(url.lastPathComponent == "test.wav")
    }

    @Test("resource(named:) preserves file name with spaces")
    func resourceNamedWithSpaces() {
        let br = BundleResources(bundleURL: Bundle.module.bundleURL)
        let url = br.resource(named: "no metadata.mp3")
        #expect(url.lastPathComponent == "no metadata.mp3")
    }

    @Test("resource(named:) preserves file extension")
    func resourceNamedExtension() {
        let br = BundleResources(bundleURL: Bundle.module.bundleURL)
        let url = br.resource(named: "example.flac")
        #expect(url.pathExtension == "flac")
    }

    @Test("two instances with same bundleURL produce same resource URLs")
    func consistentResourceURLs() {
        let url = Bundle.module.bundleURL
        let a = BundleResources(bundleURL: url)
        let b = BundleResources(bundleURL: url)
        #expect(a.resource(named: "foo.wav") == b.resource(named: "foo.wav"))
    }

    @Test("different bundleURLs produce different resource URLs")
    func differentBundleURLs() {
        let a = BundleResources(bundleURL: URL(fileURLWithPath: "/tmp/bundleA.bundle"))
        let b = BundleResources(bundleURL: URL(fileURLWithPath: "/tmp/bundleB.bundle"))
        #expect(a.resource(named: "test.wav") != b.resource(named: "test.wav"))
    }
}
