// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-testing

import Foundation

/// Wall-clock durations of one measured operation, in milliseconds, warm-up excluded.
public struct BenchSamples: Sendable, Equatable {
    /// In the order they were taken. Never empty.
    public let values: [Double]

    private let sorted: [Double]

    public init(_ values: [Double]) {
        precondition(!values.isEmpty, "BenchSamples needs at least one sample")
        self.values = values
        sorted = values.sorted()
    }

    /// The upper median for an even count, so a single sample is its own median.
    public var median: Double { sorted[sorted.count / 2] }

    public var min: Double { sorted[0] }

    public var max: Double { sorted[sorted.count - 1] }

    /// The range as a percentage of the median.
    public var spreadPercent: Double {
        median > 0 ? (max - min) / median * 100 : 0
    }
}

// MARK: - Sampling

/// Runs `body` `warmup + iterations` times and keeps the last `iterations` durations.
///
/// `prepare` runs before every iteration, warm-up included, and is not timed.
public func sample<T>(
    iterations: Int,
    warmup: Int = 0,
    prepare: () async throws -> T,
    _ body: (T) async throws -> Void
) async rethrows -> BenchSamples {
    try await sample(iterations: iterations, warmup: warmup, clock: { DispatchTime.now().uptimeNanoseconds }, prepare: prepare, body)
}

func sample<T>(
    iterations: Int,
    warmup: Int,
    clock: () -> UInt64,
    prepare: () async throws -> T,
    _ body: (T) async throws -> Void
) async rethrows -> BenchSamples {
    precondition(iterations > 0 && warmup >= 0)

    var values: [Double] = []
    values.reserveCapacity(iterations)

    for index in 0 ..< warmup + iterations {
        let input = try await prepare()
        let start = clock()
        try await body(input)
        let elapsed = clock() - start

        if index >= warmup {
            values.append(Double(elapsed) / 1_000_000)
        }
    }

    return BenchSamples(values)
}
