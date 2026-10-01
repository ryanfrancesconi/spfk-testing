// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-testing

import Foundation
@testable import SPFKBench
import Testing

@Suite struct BenchSamplesTests {
    @Test func medianIsTheMiddleValueRegardlessOfOrder() {
        let samples = BenchSamples([9, 1, 5, 3, 7])
        #expect(samples.median == 5)
        #expect(samples.min == 1)
        #expect(samples.max == 9)
        #expect(samples.values == [9, 1, 5, 3, 7])
    }

    @Test func evenCountTakesTheUpperMedian() {
        #expect(BenchSamples([4, 1, 3, 2]).median == 3)
    }

    @Test func spreadIsTheRangeOverTheMedian() {
        #expect(BenchSamples([90, 100, 110]).spreadPercent == 20)
        #expect(BenchSamples([0, 0]).spreadPercent == 0)
    }

    /// A fake clock that each call to `body` advances by the next duration, in milliseconds.
    private final class FakeClock: @unchecked Sendable {
        var now: UInt64 = 0
        var durations: [UInt64]

        init(durations: [UInt64]) { self.durations = durations }

        func advance() { now += durations.removeFirst() * 1_000_000 }
    }

    @Test func warmupIterationsAreDiscarded() async {
        let clock = FakeClock(durations: [500, 10, 12, 11])
        var prepared = 0

        let samples = await sample(
            iterations: 3, warmup: 1, clock: { clock.now },
            prepare: { prepared += 1 },
            { _ in clock.advance() }
        )

        #expect(samples.values == [10, 12, 11])
        #expect(prepared == 4)
    }

    @Test func aFailedCaseIsRecordedAndTheRunContinues() async throws {
        struct Failure: Error {}
        var run = RegressionRun(bench: "test")

        await run.measure("a.fails", iterations: 1, warmup: 0) { throw Failure() }
        await run.measure("b.counts", iterations: 2, warmup: 0) { 42 }
        run.skip("c.absent", note: "no corpus")

        #expect(run.cases.map(\.status) == [.failed, .ok, .skipped])
        #expect(run.cases[1].count == 42)
        #expect(run.cases[1].n == 2)

        let json = try #require(String(data: try run.jsonData(), encoding: .utf8))
        #expect(json.contains("\"median_ms\""))
    }
}
