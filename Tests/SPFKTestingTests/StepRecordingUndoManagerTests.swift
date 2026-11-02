// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi

import Foundation
import Testing

@testable import SPFKTesting

@Suite
@MainActor
final class StepRecordingUndoManagerTests {
    final class Target {}
    let target = Target()

    private func register(_ manager: UndoManager) {
        manager.registerUndo(withTarget: target) { _ in }
        manager.setActionName("Step")
    }

    @Test func registrationsInTheTestGroupAreEachAStep() {
        let manager = StepRecordingUndoManager()
        manager.beginOperation()
        register(manager)
        register(manager)
        manager.endOperation()

        #expect(manager.steps == 2)
        #expect(manager.emptySteps == 0)
    }

    @Test func aGroupTheOperationOpensIsOneStep() {
        let manager = StepRecordingUndoManager()
        manager.beginOperation()
        manager.beginUndoGrouping()
        register(manager)
        manager.beginUndoGrouping()
        register(manager)
        manager.endUndoGrouping()
        manager.endUndoGrouping()
        manager.endOperation()

        #expect(manager.steps == 1)
        #expect(manager.emptySteps == 0)
    }

    @Test func anOpenedGroupWithNothingInItIsAnEmptyStep() {
        let manager = StepRecordingUndoManager()
        manager.beginOperation()
        manager.beginUndoGrouping()
        manager.endUndoGrouping()
        manager.endOperation()

        #expect(manager.steps == 0)
        #expect(manager.emptySteps == 1)
    }
}
