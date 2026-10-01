// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-testing

import Foundation

/// Runs `body` `iterations` times and prints the **median** with the observed range.
///
/// Compare medians, and read the range first: identical code re-run can move by 20%, which is
/// wider than most differences worth acting on.
@discardableResult
public func measure(
    _ label: String,
    iterations: Int = 1,
    warmup: Int = 0,
    _ body: () async throws -> Void
) async rethrows -> Double {
    try await measure(label, iterations: iterations, warmup: warmup, prepare: {}, { _ in try await body() })
}

/// As above, with per-iteration setup that is **not** timed — for anything whose second run would
/// measure something other than its first: a store already loaded, a cache already warm.
@discardableResult
public func measure<T>(
    _ label: String,
    iterations: Int = 1,
    warmup: Int = 0,
    prepare: () async throws -> T,
    _ body: (T) async throws -> Void
) async rethrows -> Double {
    let samples = try await sample(iterations: iterations, warmup: warmup, prepare: prepare, body)
    print(formatted(label, samples))
    return samples.median
}

/// One line of the human-readable report.
public func formatted(_ label: String, _ samples: BenchSamples) -> String {
    guard samples.values.count > 1 else {
        return String(format: "  %-42@ %8.1f ms", label as NSString, samples.median)
    }

    return String(
        format: "  %-42@ %8.1f ms   %7.1f-%-8.1f +/-%3.0f%%  n=%d",
        label as NSString, samples.median, samples.min, samples.max, samples.spreadPercent, samples.values.count
    )
}

public func section(_ title: String) {
    print("\n\(title)")
    print(String(repeating: "-", count: 72))
}
