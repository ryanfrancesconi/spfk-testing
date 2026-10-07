// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-testing

import Foundation

/// A Matroska or WebM file's EBML elements, read without any metadata library: the header's
/// DocType, the Segment's top-level elements with their offsets, `Tags` with their targets and
/// nested SimpleTags, `Attachments`, and the SeekHead's entries.
public struct MatroskaElements: Equatable, Sendable {
    public enum ReadError: Error, Equatable {
        case notEBML
        case malformed(String)
    }

    /// One element: its ID (marker bits kept, as the specification writes them), where it starts,
    /// its header length, its payload and, for a master element this reader descends into, its
    /// children.
    public struct Element: Equatable, Sendable {
        public let id: UInt32
        public let offset: Int
        public let headerSize: Int
        public let payload: Data
        public let children: [Element]

        public var size: Int {
            headerSize + payload.count
        }

        public func child(_ id: UInt32) -> Element? {
            children.first { $0.id == id }
        }

        public func children(_ id: UInt32) -> [Element] {
            children.filter { $0.id == id }
        }

        /// An unsigned integer element's value.
        public var unsignedValue: UInt64 {
            payload.reduce(0) { $0 << 8 | UInt64($1) }
        }

        /// A string element's value, up to any NUL.
        public var stringValue: String {
            let end = payload.firstIndex(of: 0) ?? payload.endIndex
            return String(decoding: payload[payload.startIndex ..< end], as: UTF8.self)
        }
    }

    public enum ID {
        public static let ebml: UInt32 = 0x1A45_DFA3
        public static let docType: UInt32 = 0x4282
        public static let segment: UInt32 = 0x1853_8067
        public static let seekHead: UInt32 = 0x114D_9B74
        public static let seek: UInt32 = 0x4DBB
        public static let seekID: UInt32 = 0x53AB
        public static let seekPosition: UInt32 = 0x53AC
        public static let info: UInt32 = 0x1549_A966
        public static let title: UInt32 = 0x7BA9
        public static let tracks: UInt32 = 0x1654_AE6B
        public static let cluster: UInt32 = 0x1F43_B675
        public static let cues: UInt32 = 0x1C53_BB6B
        public static let chapters: UInt32 = 0x1043_A770
        public static let tags: UInt32 = 0x1254_C367
        public static let tag: UInt32 = 0x7373
        public static let targets: UInt32 = 0x63C0
        public static let targetTypeValue: UInt32 = 0x68CA
        public static let targetType: UInt32 = 0x63CA
        public static let tagTrackUID: UInt32 = 0x63C5
        public static let tagEditionUID: UInt32 = 0x63C9
        public static let tagChapterUID: UInt32 = 0x63C4
        public static let tagAttachmentUID: UInt32 = 0x63C6
        public static let simpleTag: UInt32 = 0x67C8
        public static let tagName: UInt32 = 0x45A3
        public static let tagLanguage: UInt32 = 0x447A
        public static let tagString: UInt32 = 0x4487
        public static let tagBinary: UInt32 = 0x4485
        public static let attachments: UInt32 = 0x1941_A469
        public static let attachedFile: UInt32 = 0x61A7
        public static let fileDescription: UInt32 = 0x467E
        public static let fileName: UInt32 = 0x466E
        public static let fileMediaType: UInt32 = 0x4660
        public static let fileData: UInt32 = 0x465C
        public static let fileUID: UInt32 = 0x46AE
        public static let void: UInt32 = 0xEC
    }

    /// The master elements this reader descends into. Clusters are left whole.
    private static let masters: Set<UInt32> = [
        ID.ebml, ID.segment, ID.seekHead, ID.seek, ID.info, ID.tracks, ID.tags, ID.tag, ID.targets, ID.simpleTag,
        ID.attachments, ID.attachedFile,
    ]

    public let header: Element
    public let segment: Element

    public init(_ data: Data) throws {
        let bytes = Data(data)
        guard bytes.starts(with: [0x1A, 0x45, 0xDF, 0xA3]) else { throw ReadError.notEBML }

        let top = try Self.elements(in: bytes, from: 0, to: bytes.count)

        guard let header = top.first, header.id == ID.ebml else { throw ReadError.notEBML }
        guard let segment = top.first(where: { $0.id == ID.segment }) else { throw ReadError.malformed("no Segment") }

        self.header = header
        self.segment = segment
    }

    public init(contentsOf url: URL) throws {
        try self.init(Data(contentsOf: url))
    }

    public var docType: String? {
        header.child(ID.docType)?.stringValue
    }

    /// Where the Segment's payload starts, which SeekHead and Cues positions count from.
    public var segmentDataOffset: Int {
        segment.offset + segment.headerSize
    }

    /// Every top-level element in the Segment with this ID.
    public func elements(_ id: UInt32) -> [Element] {
        segment.children(id)
    }

    /// `Info/Title`.
    public var title: String? {
        segment.child(ID.info)?.child(ID.title)?.stringValue
    }

    /// The SeekHead's entries as (element ID, position from ``segmentDataOffset``).
    public var seekEntries: [(id: UInt32, position: UInt64)] {
        (segment.child(ID.seekHead)?.children(ID.seek) ?? []).compactMap { seek in
            guard let id = seek.child(ID.seekID), let position = seek.child(ID.seekPosition) else { return nil }
            return (UInt32(truncatingIfNeeded: id.unsignedValue), position.unsignedValue)
        }
    }

    // MARK: - Tags

    public struct SimpleTag: Equatable, Sendable {
        public let name: String
        public let language: String?
        public let string: String?
        public let binary: Data?
        public let children: [SimpleTag]

        init(_ element: Element) {
            name = element.child(ID.tagName)?.stringValue ?? ""
            language = element.child(ID.tagLanguage)?.stringValue
            string = element.child(ID.tagString)?.stringValue
            binary = element.child(ID.tagBinary)?.payload
            children = element.children(ID.simpleTag).map(SimpleTag.init)
        }
    }

    public struct Tag: Equatable, Sendable {
        /// Nil when `Targets` stores none, which the specification reads as 50.
        public let targetTypeValue: UInt64?
        public let targetType: String?
        public let trackUIDs: [UInt64]
        /// Edition, chapter and attachment UIDs together.
        public let otherUIDs: [UInt64]
        public let simpleTags: [SimpleTag]

        init(_ element: Element) {
            let targets = element.child(ID.targets)
            targetTypeValue = targets?.child(ID.targetTypeValue)?.unsignedValue
            targetType = targets?.child(ID.targetType)?.stringValue
            trackUIDs = targets?.children(ID.tagTrackUID).map(\.unsignedValue) ?? []
            otherUIDs = [ID.tagEditionUID, ID.tagChapterUID, ID.tagAttachmentUID].flatMap { targets?.children($0).map(\.unsignedValue) ?? [] }
            simpleTags = element.children(ID.simpleTag).map(SimpleTag.init)
        }
    }

    /// Every `Tag` in every `Tags` element, in file order.
    public var tags: [Tag] {
        elements(ID.tags).flatMap { $0.children(ID.tag) }.map(Tag.init)
    }

    // MARK: - Attachments

    public struct AttachedFile: Equatable, Sendable {
        public let name: String
        public let mediaType: String
        public let description: String?
        public let uid: UInt64?
        public let data: Data

        init(_ element: Element) {
            name = element.child(ID.fileName)?.stringValue ?? ""
            mediaType = element.child(ID.fileMediaType)?.stringValue ?? ""
            description = element.child(ID.fileDescription)?.stringValue
            uid = element.child(ID.fileUID)?.unsignedValue
            data = element.child(ID.fileData)?.payload ?? Data()
        }
    }

    /// Every attached file in every `Attachments` element, in file order.
    public var attachedFiles: [AttachedFile] {
        elements(ID.attachments).flatMap { $0.children(ID.attachedFile) }.map(AttachedFile.init)
    }

    // MARK: - Helpers

    private static func elements(in data: Data, from start: Int, to end: Int) throws -> [Element] {
        var elements: [Element] = []
        var offset = start

        while offset < end {
            let (id, idLength) = try readID(data, at: offset)
            let (size, sizeLength) = try readSize(data, at: offset + idLength)
            let body = offset + idLength + sizeLength
            let bodyEnd = size.map { body + $0 } ?? end

            guard bodyEnd <= end else { throw ReadError.malformed("element 0x\(String(id, radix: 16)) at \(offset) overruns \(end)") }

            let children = masters.contains(id) ? try Self.elements(in: data, from: body, to: bodyEnd) : []
            elements.append(Element(id: id, offset: offset, headerSize: body - offset, payload: data.subdata(in: body ..< bodyEnd), children: children))
            offset = bodyEnd
        }

        return elements
    }

    private static func readID(_ data: Data, at offset: Int) throws -> (UInt32, Int) {
        guard offset < data.count else { throw ReadError.malformed("ID past the end at \(offset)") }
        let length = vintLength(data[offset])
        guard length <= 4, offset + length <= data.count else { throw ReadError.malformed("ID of \(length) bytes at \(offset)") }
        return (data[offset ..< offset + length].reduce(0) { $0 << 8 | UInt32($1) }, length)
    }

    /// Nil for the unknown size, all value bits set.
    private static func readSize(_ data: Data, at offset: Int) throws -> (Int?, Int) {
        guard offset < data.count else { throw ReadError.malformed("size past the end at \(offset)") }
        let length = vintLength(data[offset])
        guard length <= 8, offset + length <= data.count else { throw ReadError.malformed("size of \(length) bytes at \(offset)") }

        let raw = data[offset ..< offset + length].reduce(UInt64(0)) { $0 << 8 | UInt64($1) }
        let mask = (UInt64(1) << (7 * UInt64(length))) - 1
        let value = raw & mask
        return (value == mask ? nil : Int(value), length)
    }

    private static func vintLength(_ first: UInt8) -> Int {
        first == 0 ? 9 : first.leadingZeroBitCount + 1
    }
}
