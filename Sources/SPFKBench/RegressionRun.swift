// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-testing

import Foundation

/// One case of a regression run, as compared against a baseline.
///
/// `id` is the key a baseline is stored under, so renaming a case orphans its history.
public struct RegressionCase: Codable, Sendable, Equatable {
    public enum Status: String, Codable, Sendable {
        case ok
        case skipped
        case failed
    }

    public let id: String
    public let status: Status
    public let medianMs: Double?
    public let minMs: Double?
    public let maxMs: Double?
    public let n: Int?

    /// What the case processed — rows read, results returned. A case that got faster by doing
    /// less work shows up here rather than as an improvement.
    public let count: Int?

    /// Why a case was skipped or failed.
    public let note: String?
}

/// A regression run's cases, written as JSON for a script to compare against a baseline.
public struct RegressionRun: Sendable {
    public let bench: String
    public private(set) var cases: [RegressionCase] = []

    public init(bench: String) {
        self.bench = bench
    }

    /// Times `body`, which returns the count of what it processed, after `warmup` discarded runs.
    /// A throw is recorded as a failed case rather than propagated, so one case cannot hide the rest.
    public mutating func measure<T>(
        _ id: String,
        iterations: Int = 7,
        warmup: Int = 1,
        prepare: () async throws -> T,
        _ body: (T) async throws -> Int
    ) async {
        var count = 0

        do {
            let samples = try await sample(iterations: iterations, warmup: warmup, prepare: prepare) { input in
                count = try await body(input)
            }

            cases.append(RegressionCase(
                id: id, status: .ok, medianMs: samples.median, minMs: samples.min, maxMs: samples.max,
                n: samples.values.count, count: count, note: nil
            ))
            log(formatted(id, samples) + "  count=\(count)")
        } catch {
            fail(id, note: String(describing: error))
        }
    }

    public mutating func measure(
        _ id: String,
        iterations: Int = 7,
        warmup: Int = 1,
        _ body: () async throws -> Int
    ) async {
        await measure(id, iterations: iterations, warmup: warmup, prepare: {}, { _ in try await body() })
    }

    public mutating func skip(_ id: String, note: String) {
        cases.append(RegressionCase(id: id, status: .skipped, medianMs: nil, minMs: nil, maxMs: nil, n: nil, count: nil, note: note))
        log("  \(id): skipped — \(note)")
    }

    public mutating func fail(_ id: String, note: String) {
        cases.append(RegressionCase(id: id, status: .failed, medianMs: nil, minMs: nil, maxMs: nil, n: nil, count: nil, note: note))
        log("  \(id): FAILED — \(note)")
    }

    // MARK: - Output

    public var configuration: String {
        #if DEBUG
            "debug"
        #else
            "release"
        #endif
    }

    public func jsonData() throws -> Data {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(Document(bench: bench, configuration: configuration, cases: cases))
    }

    /// Writes to the path following `--json` in `arguments`, or to standard output when absent.
    public func write(arguments: [String] = CommandLine.arguments) throws {
        let data = try jsonData()

        if let flag = arguments.firstIndex(of: "--json"), arguments.indices.contains(flag + 1) {
            try data.write(to: URL(fileURLWithPath: arguments[flag + 1]), options: .atomic)
        } else {
            FileHandle.standardOutput.write(data)
            FileHandle.standardOutput.write(Data("\n".utf8))
        }
    }

    /// Progress goes to standard error so standard output can carry the JSON alone.
    private func log(_ line: String) {
        FileHandle.standardError.write(Data((line + "\n").utf8))
    }

    private struct Document: Encodable {
        let bench: String
        let configuration: String
        let cases: [RegressionCase]
    }
}
