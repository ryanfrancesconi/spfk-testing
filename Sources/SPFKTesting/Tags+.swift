// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-testing

import Testing

extension Tag {
    // MARK: - Cost - the only axis a test plan selects a tier on

    /// Excluded from the `spfk-fast` plan; still runs in the landing gate.
    ///
    /// The only cost tag, and it has to stay that way: a plan ANDs the tags in `skippedTags`, so
    /// two of them would skip nothing. Apply it for measured expense - deliberately large input,
    /// or a dependency on a machine-local library - never for inconvenience.
    @Tag public static var slow: Self

    /// A tag to indicate this is a development test rather than functionality that should be unit tested
    @Tag public static var development: Self

    // MARK: - Requirement - what a test needs. Descriptive; selects no tier.

    @Tag public static var file: Self
    @Tag public static var realtime: Self
    @Tag public static var engine: Self
    @Tag public static var audioUnit: Self
    @Tag public static var hardware: Self

    /// Waits on an async notification. The most timing-sensitive class, and the first suspect when
    /// a run flakes.
    @Tag public static var notification: Self

    // MARK: - Subject - what a test is about. Assembles a cross-package plan via `selectedTags`.

    /// Undo behavior in either product: the action enum, the handlers, and the harness that reaches
    /// them. Unlike the requirement tags - which say what a test *needs* - this says what it is
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
    /// has to wait for or re-run after that fill-in - the store's shell read and hydration, the
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

    /// Field criteria in search: the query language, its parser and resolvers, evaluation over
    /// each product's field registry, and the shared store search that runs it.
    @Tag public static var advancedSearch: Self

    /// Related-word search: the expander's tiers and vocabulary, the fallback's match bands, and
    /// each product's vocabulary source.
    @Tag public static var synonyms: Self

    /// Keyword tools in both products: the shared organize options, the tool-run sequence that
    /// presents a tool's dialog and resolves its targets, and Detect and Organize Keywords.
    @Tag public static var keywordTools: Self

    /// CSV export in both products: the shared pipeline's column resolution and ordering, each
    /// product's column vocabulary, and the persisted options.
    @Tag public static var csvExport: Self

    /// Spreadsheet import in both products: the readers, the engine's matching, values and
    /// deferred writes, each product's vocabulary and profiles, the export round trip, the shared
    /// apply, and the remembered settings.
    @Tag public static var spreadsheetImport: Self

    /// ShadowTag's artwork column filling in after the table paints: what a playlist read no
    /// longer carries, the cache-first fill's order and write-back, carrying thumbnails across a
    /// refresh, and the image store's concurrent thumbnail reads.
    @Tag public static var thumbnailFill: Self

    /// The metadata safety net: every metadata save, checked against readers that share no code
    /// with the writers - what it wrote, the components it left alone, and other apps' data in
    /// the file - plus those readers' own tests.
    @Tag public static var metadataSafetyNet: Self

    /// Musical key in ShadowTag: parsing and writing each notation, the spelling rule, how a key
    /// tag is stored, organizing a batch into one notation, and searching across spellings.
    @Tag public static var musicalKey: Self

    @Tag public static var automation: Self

    /// Reverse as a pending audio edit: the model and its mirrors, the render, the reversed cache
    /// and its store, the transport's identity, and ShadowTag's reversed editor view.
    @Tag public static var reverse: Self

    /// Video transport in both products: bounded playback, loop and the end event, the
    /// user-selection check, the next playable row, trim from the playhead, time display, and
    /// frame stepping.
    @Tag public static var transport: Self

    /// The Help menu in both products: the shared help host, its Help, Feedback and Welcome
    /// windows, the menu rows, and the launch check that decides when Welcome appears.
    @Tag public static var help: Self

    /// Paste Attributes in both products: the shared host, options and dialog, and each product's
    /// source and apply.
    @Tag public static var pasteAttributes: Self

    /// Convert Files in both products: the batch converter, the shared host's passes and step order,
    /// the per-file converters, the failure report, and adding the outputs to an album.
    @Tag public static var conversion: Self

    /// The XMP tab in both products: the shared view, each product's read, edit and undo, and the
    /// packet save.
    @Tag public static var xmp: Self

    /// The cache location setting in both products: the location and its resolution, the swap of a
    /// data object's cache stores, and the hardlink-preserving move between roots.
    @Tag public static var cacheLocation: Self

    /// Spot and FCPXML in both products: the media-neutral spot item, the FCPXML writer, the shared
    /// Spot host and its step order, each product's planner and menu rows, and the transport's
    /// menu-row button.
    @Tag public static var spot: Self

    /// A table's in-place filter in both products: the scorer, the base's filter task and its
    /// re-derive after a mutation, each product's job and mutation sites, and the search field's
    /// count.
    @Tag public static var tableFilter: Self

    /// The folder scan behind a drop or folder import in both products: the stoppable walk, the
    /// shared candidate list (exclude, order, cap), each product's parser, the scan's progress,
    /// and the library planner.
    @Tag public static var importScan: Self
}
