// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-testing

import Foundation

/// This process's physical footprint right now, in MB, as Activity Monitor's Memory column reports it.
public func footprintMB() -> Double {
    var info = task_vm_info_data_t()
    var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<natural_t>.size)

    let result = withUnsafeMutablePointer(to: &info) {
        $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
            task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
        }
    }

    guard result == KERN_SUCCESS else { return 0 }
    return Double(info.phys_footprint) / 1_048_576
}

/// The highest footprint seen between ``start()`` and ``stop()``, sampled on its own thread.
///
/// A thread rather than a task, so work saturating the cooperative pool cannot starve the samples.
public final class PeakFootprint: @unchecked Sendable {
    private let interval: TimeInterval
    private let lock = NSLock()
    private var peak: Double = 0
    private var running = false

    public init(interval: TimeInterval = 0.05) {
        self.interval = interval
    }

    public func start() {
        lock.withLock {
            peak = footprintMB()
            running = true
        }

        Thread.detachNewThread { [self] in
            while lock.withLock({ running }) {
                let current = footprintMB()
                lock.withLock { peak = max(peak, current) }
                Thread.sleep(forTimeInterval: interval)
            }
        }
    }

    /// Stops sampling and returns the peak in MB.
    @discardableResult
    public func stop() -> Double {
        let current = footprintMB()

        return lock.withLock {
            running = false
            peak = max(peak, current)
            return peak
        }
    }
}
