// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-testing

import Testing

extension Tag {
    // MARK: - Cost — the only axis a test plan selects a tier on

    /// Excluded from the `spfk-fast` plan; still runs in the landing gate.
    ///
    /// The only cost tag, and it has to stay that way: a plan ANDs the tags in `skippedTags`, so
    /// two of them would skip nothing. Apply it for measured expense — deliberately large input,
    /// or a dependency on a machine-local library — never for inconvenience.
    @Tag public static var slow: Self

    /// A tag to indicate this is a development test rather than functionality that should be unit tested
    @Tag public static var development: Self

    // MARK: - Requirement — what a test needs. Descriptive; selects no tier.

    @Tag public static var file: Self
    @Tag public static var realtime: Self
    @Tag public static var engine: Self
    @Tag public static var audioUnit: Self
    @Tag public static var hardware: Self

    /// Waits on an async notification. The most timing-sensitive class, and the first suspect when
    /// a run flakes.
    @Tag public static var notification: Self

    // MARK: - Subject — what a test is about. Assembles a cross-package plan via `selectedTags`.

    /// Undo behavior in either product: the action enum, the handlers, and the harness that reaches
    /// them. Unlike the requirement tags — which say what a test *needs* — this says what it is
    /// *about*, so a cross-package run can be assembled without naming each suite.
    @Tag public static var undo: Self

    /// The library's persistence layer in either product: what reaches disk, what is read back,
    /// and everything derived from it -- the shared store, its derived index, smart selection,
    /// migration, bookmarks, and the caches keyed off the set of files the library holds.
    ///
    /// Assembles the run for a change to that layer. The per-package plans each show a fraction of
    /// it, and the landing gate shows it alongside everything else.
    @Tag public static var persistence: Self

    /// Opening a playlist: what a first paint costs, what fills in behind it, and everything that
    /// has to wait for or re-run after that fill-in — the store's shell read and hydration, the
    /// host's step order, and the table's application of a batch.
    ///
    /// Spans the store, the shared host and both products' tables, which is why it is a tag rather
    /// than a suite list.
    @Tag public static var albumLoad: Self

    /// Showing several sidebar playlists in one table: classifying the selection, the store's
    /// bounded read and refusal, the shared host's step order, and each product's gates.
    @Tag public static var combinedSelection: Self

    /// Finding the playlists that hold a file and navigating to one: the store's membership query,
    /// the shared command's step order, its dialog, and each product's arrival selection.
    @Tag public static var showInPlaylists: Self

    /// Search Results as a stored playlist: the store's wholesale replace, the shared host's
    /// write-then-load order, pruning at load, and each product's revisit, relaunch and Clear.
    @Tag public static var searchResults: Self

    /// The metadata safety net: every metadata save, checked against readers that share no code
    /// with the writers — what it wrote, the components it left alone, and other apps' data in
    /// the file — plus those readers' own tests.
    @Tag public static var metadataSafetyNet: Self

    @Tag public static var automation: Self
}
