// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-testing

import Foundation

/// A canonical XML element tree built with `XMLParser`, for comparing documents that a writer may
/// re-serialize: element names, attributes (sorted by name), text exactly, comments and CDATA
/// each as their own node. Text that is only whitespace between elements is ignored, as are the
/// XML declaration and the document's formatting.
public struct XMLTree: Equatable, Sendable, CustomStringConvertible {
    public enum ReadError: Error, Equatable {
        case unparseable(String)
    }

    /// One line per node in document order, indented two spaces per level:
    /// `<NAME a="1">`, `text "…"`, `comment "…"`, `cdata "…"`.
    public let lines: [String]

    /// Trailing NULs, which RIFF writers use as padding, are not part of the document.
    public init(_ data: Data) throws {
        let builder = Builder()
        let end = data.lastIndex { $0 != 0 }.map { data.index(after: $0) } ?? data.startIndex
        let parser = XMLParser(data: Data(data[data.startIndex ..< end]))
        parser.delegate = builder

        guard parser.parse() else {
            throw ReadError.unparseable(parser.parserError.map { "\($0)" } ?? "unknown error")
        }

        lines = builder.lines
    }

    public init(_ string: String) throws {
        try self.init(Data(string.utf8))
    }

    public var description: String {
        lines.joined(separator: "\n")
    }
}

private final class Builder: NSObject, XMLParserDelegate {
    var lines: [String] = []
    private var depth = 0
    private var text = ""

    private func indent() -> String {
        String(repeating: "  ", count: depth)
    }

    /// Text is gathered across `foundCharacters` calls and emitted at the next node boundary.
    private func flushText() {
        defer { text = "" }
        guard !text.allSatisfy(\.isWhitespace) else { return }
        lines.append("\(indent())text \(quoted(text))")
    }

    private func quoted(_ string: String) -> String {
        "\"" + string.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"") + "\""
    }

    func parser(
        _ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?,
        qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]
    ) {
        flushText()
        let attributes = attributeDict.sorted { $0.key < $1.key }.map { " \($0.key)=\(quoted($0.value))" }.joined()
        lines.append("\(indent())<\(elementName)\(attributes)>")
        depth += 1
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        flushText()
        depth -= 1
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        text += string
    }

    func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
        flushText()
        lines.append("\(indent())cdata \(quoted(String(decoding: CDATABlock, as: UTF8.self)))")
    }

    func parser(_ parser: XMLParser, foundComment comment: String) {
        flushText()
        lines.append("\(indent())comment \(quoted(comment))")
    }
}
