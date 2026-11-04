// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-testing

import Foundation

/// What a ``retention(_:loops:threshold:_:)`` run kept: the footprint after each loop, and the
/// memory regions that grew between the first loop and the last.
public struct RetentionReport: Sendable {
    public let label: String

    /// Footprint in MB after each loop.
    public let loops: [Double]

    /// Regions whose dirty + swapped size grew by at least 1 MB, largest growth first.
    /// Empty unless the last loop exceeded the first by the threshold.
    public let grownRegions: [RegionGrowth]

    /// Growth from the first loop to the last, as a fraction of the first.
    public var growth: Double {
        guard let first = loops.first, let last = loops.last, first > 0 else { return 0 }
        return (last - first) / first
    }

    /// Mean growth per loop after the first, in MB.
    public var perLoopMB: Double {
        guard let first = loops.first, let last = loops.last, loops.count > 1 else { return 0 }
        return (last - first) / Double(loops.count - 1)
    }

    public var summary: String {
        let values = loops.map { String(format: "%.0f", $0) }.joined(separator: " → ")
        var line = String(format: "  %-42@ %@ MB  (%+.0f MB/loop)", label as NSString, values as NSString, perLoopMB)

        for region in grownRegions.prefix(4) {
            line += String(format: "\n      %-34@ %+8.1f MB", region.name as NSString, region.grownMB)
        }

        return line
    }
}

public struct RegionGrowth: Sendable, Equatable {
    public let name: String
    public let grownMB: Double
}

/// Runs `body` over the same inputs `loops` times, serially, recording the footprint after each.
///
/// When the last loop ends more than `threshold` above the first, the regions that grew are named
/// from `vmmap --summary`, which is the finding: `IOSurface` and `Malloc Large` point to different
/// causes. Growth that never comes back is retention; a high but level footprint is only peak.
public func retention(
    _ label: String,
    loops: Int = 4,
    threshold: Double = 0.2,
    _ body: (Int) async throws -> Void
) async rethrows -> RetentionReport {
    var footprints: [Double] = []
    var firstRegions: [String: Double] = [:]

    for loop in 0 ..< max(2, loops) {
        try await body(loop)
        footprints.append(footprintMB())

        if loop == 0 {
            firstRegions = vmmapRegions()
        }
    }

    var grown: [RegionGrowth] = []

    if let first = footprints.first, let last = footprints.last, last > first * (1 + threshold) {
        let lastRegions = vmmapRegions()

        grown = lastRegions.compactMap { name, size in
            let delta = size - (firstRegions[name] ?? 0)
            return delta >= 1 ? RegionGrowth(name: name, grownMB: delta) : nil
        }
        .sorted { $0.grownMB > $1.grownMB }
    }

    return RetentionReport(label: label, loops: footprints, grownRegions: grown)
}

/// Dirty + swapped size in MB per region type of this process, from `vmmap --summary`.
public func vmmapRegions() -> [String: Double] {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/vmmap")
    process.arguments = ["--summary", "\(ProcessInfo.processInfo.processIdentifier)"]

    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = FileHandle.nullDevice

    do {
        try process.run()
    } catch {
        return [:]
    }

    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()

    return parseVMMapSummary(String(decoding: data, as: UTF8.self))
}

/// Parses the region table of `vmmap --summary`: name, then virtual, resident, dirty and swapped
/// sizes. Only the first table is read; the malloc zone table below it repeats the same memory.
func parseVMMapSummary(_ text: String) -> [String: Double] {
    var regions: [String: Double] = [:]
    var inTable = false

    for line in text.split(separator: "\n", omittingEmptySubsequences: false) {
        if line.hasPrefix("===========") {
            if inTable { break }
            inTable = true
            continue
        }

        guard inTable else { continue }

        let tokens = line.split(separator: " ", omittingEmptySubsequences: true)
        guard let sizeStart = tokens.firstIndex(where: { vmmapBytes($0) != nil }),
              tokens.count >= sizeStart + 4,
              let dirty = vmmapBytes(tokens[sizeStart + 2]),
              let swapped = vmmapBytes(tokens[sizeStart + 3])
        else { continue }

        let name = tokens[..<sizeStart].joined(separator: " ")
        regions[name, default: 0] += (dirty + swapped) / 1_048_576
    }

    return regions
}

/// `16K`, `1.6G`, `848` (bytes) to bytes.
private func vmmapBytes(_ token: Substring) -> Double? {
    let multipliers: [Character: Double] = ["K": 1024, "M": 1_048_576, "G": 1_073_741_824]

    if let last = token.last, let multiplier = multipliers[last] {
        return Double(token.dropLast()).map { $0 * multiplier }
    }

    return token.allSatisfy(\.isNumber) ? Double(token) : nil
}
