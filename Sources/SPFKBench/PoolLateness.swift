// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-testing

import Foundation

/// How late a small task posted to the cooperative pool runs while other work is in flight.
///
/// Posts one task every `interval` between ``start()`` and ``stop()``, and records how long after
/// its post each one began. A batch that blocks every pool thread shows here as lateness in the
/// hundreds of milliseconds; an app would show it as a stall.
public final class PoolLateness: @unchecked Sendable {
    private let interval: TimeInterval
    private let lock = NSLock()
    private var lateness: [Double] = []
    private var running = false

    public init(interval: TimeInterval = 0.02) {
        self.interval = interval
    }

    public func start() {
        lock.withLock {
            lateness = []
            running = true
        }

        Thread.detachNewThread { [self] in
            while lock.withLock({ running }) {
                let posted = DispatchTime.now().uptimeNanoseconds

                Task.detached { [self] in
                    let late = Double(DispatchTime.now().uptimeNanoseconds - posted) / 1_000_000
                    lock.withLock { lateness.append(late) }
                }

                Thread.sleep(forTimeInterval: interval)
            }
        }
    }

    /// Stops posting and returns the 99th percentile and the maximum lateness, in ms.
    @discardableResult
    public func stop() -> (p99: Double, max: Double) {
        let sorted = lock.withLock {
            running = false
            return lateness.sorted()
        }

        guard let max = sorted.last else { return (0, 0) }
        return (sorted[min(sorted.count - 1, sorted.count * 99 / 100)], max)
    }
}
