import Testing

extension Tag {
    /// A tag to indicate this is a development test rather than functionality that should be unit tested
    @Tag public static var development: Self
    @Tag public static var file: Self
    @Tag public static var automation: Self
    @Tag public static var realtime: Self
    @Tag public static var engine: Self
}
