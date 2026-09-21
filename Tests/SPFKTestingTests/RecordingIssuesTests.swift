// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-testing

import Foundation
import SPFKTesting
import Testing

@Suite struct RecordingIssuesTests {
    struct CleanupFailure: Error {}

    @Test func aThrownErrorIsRecordedNotPropagated() async {
        await withKnownIssue {
            await recordingIssues { throw CleanupFailure() }
        } matching: { issue in
            issue.error is CleanupFailure
        }
    }

    @Test func aFailedStepDoesNotSkipTheNextOne() async {
        var laterStepRan = false

        await withKnownIssue {
            await recordingIssues { throw CleanupFailure() }
            await recordingIssues { laterStepRan = true }
        }

        #expect(laterStepRan)
    }
}
