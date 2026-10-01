// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-testing

import Foundation

/// A file's extended attributes, read and written with the POSIX calls and no other library.
/// Symbolic links are not followed.
public enum FileXattrs {
    /// Where Finder stores a file's tags: a binary property list of strings.
    public static let userTagsName = "com.apple.metadata:_kMDItemUserTags"

    /// Every attribute name on the file, in the order the file system lists them.
    public static func names(of url: URL) throws -> [String] {
        let path = url.path
        let size = listxattr(path, nil, 0, XATTR_NOFOLLOW)
        guard size >= 0 else { throw lastError() }
        guard size > 0 else { return [] }

        var buffer = [UInt8](repeating: 0, count: size)
        let read = buffer.withUnsafeMutableBytes {
            listxattr(path, $0.baseAddress?.assumingMemoryBound(to: CChar.self), size, XATTR_NOFOLLOW)
        }
        guard read >= 0 else { throw lastError() }

        return buffer[0 ..< read].split(separator: 0).map { String(decoding: $0, as: UTF8.self) }
    }

    /// The attribute's bytes, or `nil` when the file has no attribute of that name.
    public static func value(_ name: String, of url: URL) throws -> Data? {
        let path = url.path
        let size = getxattr(path, name, nil, 0, 0, XATTR_NOFOLLOW)

        guard size >= 0 else {
            if errno == ENOATTR { return nil }
            throw lastError()
        }

        var data = Data(count: size)
        let read = data.withUnsafeMutableBytes {
            getxattr(path, name, $0.baseAddress, size, 0, XATTR_NOFOLLOW)
        }
        guard read >= 0 else { throw lastError() }

        return data.prefix(read)
    }

    /// Every attribute on the file, keyed by name.
    public static func all(of url: URL) throws -> [String: Data] {
        var result: [String: Data] = [:]

        for name in try names(of: url) {
            result[name] = try value(name, of: url)
        }

        return result
    }

    /// Creates or replaces one attribute.
    public static func set(_ name: String, value: Data, on url: URL) throws {
        let result = value.withUnsafeBytes {
            setxattr(url.path, name, $0.baseAddress, value.count, 0, XATTR_NOFOLLOW)
        }
        guard result == 0 else { throw lastError() }
    }

    /// Finder's tags in stored order, exactly as stored: Finder writes a tag as its name, a
    /// newline and a color index (`"Red\n6"`); other writers may omit the suffix. `nil` when the
    /// file has no tag attribute.
    public static func userTags(of url: URL) throws -> [String]? {
        guard let data = try value(userTagsName, of: url) else { return nil }
        return try decodeUserTags(data)
    }

    /// Decodes the property list of ``userTagsName``. Throws unless it is an array of strings.
    public static func decodeUserTags(_ data: Data) throws -> [String] {
        let plist = try PropertyListSerialization.propertyList(from: data, format: nil)

        guard let tags = plist as? [String] else {
            throw CocoaError(.propertyListReadCorrupt)
        }

        return tags
    }

    private static func lastError() -> POSIXError {
        POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
    }
}
