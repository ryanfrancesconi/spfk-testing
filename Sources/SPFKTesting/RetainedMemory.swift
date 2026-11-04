// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-testing

import Foundation
import SPFKBench

/// Footprint growth in MB over `measured` items run after `warmUp` items, `width` at a time.
///
/// Caches and pools fill on the warm-up; growth after it is what the work keeps per item. Size the
/// input so that what one item could keep is large against the noise of suites running alongside:
/// a photo-sized image or a song-length file, not a small fixture, which passes whether it leaks or not.
///
/// ```swift
/// let grown = try await retainedMemoryMB(warmUp: 16, measured: 60, width: 8) { index in
///     try convert(input, to: bin.appendingPathComponent("out-\(index).heic"))
/// }
/// #expect(grown < 100, "grew \(Int(grown)) MB over 60 items")
/// ```
public func retainedMemoryMB(
    warmUp: Int,
    measured: Int,
    width: Int,
    _ item: @escaping @Sendable (Int) async throws -> Void
) async throws -> Double {
    try await runWindowed(0 ..< warmUp, width: width, item)
    let settled = footprintMB()
    try await runWindowed(warmUp ..< warmUp + measured, width: width, item)
    return footprintMB() - settled
}

private func runWindowed(
    _ range: Range<Int>,
    width: Int,
    _ item: @escaping @Sendable (Int) async throws -> Void
) async throws {
    try await withThrowingTaskGroup(of: Void.self) { group in
        for index in range {
            if index - range.lowerBound >= max(1, width) { try await group.next() }
            group.addTask { try await item(index) }
        }

        try await group.waitForAll()
    }
}
