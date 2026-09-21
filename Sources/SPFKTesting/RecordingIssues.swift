// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-testing

import Testing

/// Runs `body`, recording anything it throws as an issue on the current test instead of
/// propagating it.
///
/// For async cleanup in a `defer`, whose body cannot throw: `defer { await recordingIssues { try await store.close() } }`.
public func recordingIssues(
    sourceLocation: SourceLocation = #_sourceLocation,
    _ body: () async throws -> Void
) async {
    do {
        try await body()
    } catch {
        Issue.record(error, sourceLocation: sourceLocation)
    }
}
