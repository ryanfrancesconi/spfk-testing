// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-testing

import Foundation

extension RIFFChunks {
    /// The `bext` chunk's EBU Tech 3285 fixed layout. Text fields stop at their first NUL; the
    /// UMID, reserved bytes and coding history are kept as stored.
    public struct BroadcastExtension: Equatable, Sendable {
        /// The fixed part's size; the coding history follows it.
        public static let fixedSize = 602

        public let description: String
        public let originator: String
        public let originatorReference: String
        public let originationDate: String
        public let originationTime: String
        public let timeReference: UInt64
        public let version: UInt16
        public let umid: Data
        /// Integrated loudness, loudness range, max true peak, max momentary and max short-term
        /// loudness, each in hundredths as stored.
        public let loudness: [Int16]
        public let reserved: Data
        public let codingHistory: Data

        public init(_ payload: Data) throws {
            guard payload.count >= Self.fixedSize else {
                throw ReadError.malformed("bext of \(payload.count) bytes")
            }

            let bytes = Data(payload)

            func field(_ offset: Int, _ size: Int) -> Data {
                bytes.subdata(in: offset ..< offset + size)
            }

            description = RIFFChunks.text(field(0, 256))
            originator = RIFFChunks.text(field(256, 32))
            originatorReference = RIFFChunks.text(field(288, 32))
            originationDate = RIFFChunks.text(field(320, 10))
            originationTime = RIFFChunks.text(field(330, 8))
            timeReference = UInt64(RIFFChunks.uint32(bytes, at: 342)) << 32 | UInt64(RIFFChunks.uint32(bytes, at: 338))
            version = RIFFChunks.uint16(bytes, at: 346)
            umid = field(348, 64)
            loudness = (0 ..< 5).map { Int16(bitPattern: RIFFChunks.uint16(bytes, at: 412 + $0 * 2)) }
            reserved = field(422, 180)
            codingHistory = bytes.subdata(in: Self.fixedSize ..< bytes.count)
        }
    }

    /// The `bext` chunk, decoded; nil when there is none.
    public func broadcastExtension() throws -> BroadcastExtension? {
        try first("bext").map { try BroadcastExtension($0.payload) }
    }
}
