// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi

import Foundation

/// Counts the undo steps a running app would record for one async operation.
///
/// In the app, event grouping gives each run loop event its own step, so an operation whose
/// registrations straddle several events -- any that awaits between them -- leaves one step per
/// registration unless it opens a group of its own. Headless there are no events, so the test
/// wraps the operation in a single group and this reads its structure instead: each registration
/// made directly in the test's group is a step, and so is each group the operation opened inside
/// it. An opened group that registered nothing is an empty step -- a no-op Undo in the Edit menu.
///
/// A registration is seen at the `setActionName(_:)` that follows it, which every
/// `registerUndo(named:withTarget:handler:)` call makes.
public final class StepRecordingUndoManager: UndoManager {
    /// Steps holding at least one registration.
    public private(set) var steps = 0

    /// Groups the operation opened and closed without registering anything.
    public private(set) var emptySteps = 0

    private var openGroupHasRegistration = false

    override public init() {
        super.init()
        groupsByEvent = false
    }

    /// Opens the test's own group, which stands in for the event the operation starts in.
    public func beginOperation() {
        beginUndoGrouping()
    }

    public func endOperation() {
        endUndoGrouping()
    }

    override public func beginUndoGrouping() {
        if groupingLevel == 1 { openGroupHasRegistration = false }
        super.beginUndoGrouping()
    }

    override public func endUndoGrouping() {
        if groupingLevel == 2 {
            if openGroupHasRegistration { steps += 1 } else { emptySteps += 1 }
        }
        super.endUndoGrouping()
    }

    override public func setActionName(_ actionName: String) {
        super.setActionName(actionName)

        guard !isUndoing, !isRedoing else { return }

        if groupingLevel == 1 {
            steps += 1
        } else if groupingLevel > 1 {
            openGroupHasRegistration = true
        }
    }
}
