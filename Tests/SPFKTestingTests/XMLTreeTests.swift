// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-testing

import Foundation
import SPFKTesting
import Testing

@Suite(.tags(.metadataSafetyNet))
struct XMLTreeTests {
    @Test func nodesInDocumentOrder() throws {
        let tree = try XMLTree("""
        <?xml version="1.0" encoding="UTF-8"?>
        <ROOT b="2" a="1">
            <!-- a comment -->
            <NAME>  Edge  </NAME>
            <EMPTY/>
            <USER><![CDATA[a <b>]]></USER>
            <ESCAPED>x &amp; y</ESCAPED>
        </ROOT>
        """)

        #expect(tree.lines == [
            #"<ROOT a="1" b="2">"#,
            #"  comment " a comment ""#,
            "  <NAME>",
            #"    text "  Edge  ""#,
            "  <EMPTY>",
            "  <USER>",
            #"    cdata "a <b>""#,
            "  <ESCAPED>",
            #"    text "x & y""#,
        ])
    }

    @Test func formattingIsNotCompared() throws {
        let compact = try XMLTree(#"<A><B>1</B><C x="y">2</C></A>"#)
        let indented = try XMLTree("""
        <?xml version="1.0" encoding="utf-8" standalone="no"?>
        <A>
        \t<B>1</B>
        \t<C x='y'>2</C>
        </A>
        """)

        #expect(compact == indented)
        #expect(try XMLTree("<A><B>1 </B></A>") != compact)
        #expect(try XMLTree("<A><!--c--><B>1</B><C x=\"y\">2</C></A>") != compact)
        #expect(try XMLTree("<A><B><![CDATA[1]]></B><C x=\"y\">2</C></A>") != compact)
    }

    @Test func bundledIXMLChunk() throws {
        let riff = try RIFFChunks(contentsOf: TestBundleResources.shared.ixml_chunk)
        let tree = try XMLTree(#require(riff.first("iXML")).payload)

        #expect(tree.lines.filter { $0.trimmingCharacters(in: .whitespaces).hasPrefix("<") }.count == 68)
        #expect(tree.lines.prefix(4) == ["<BWFXML>", "  <IXML_VERSION>", #"    text "1.4""#, "  <PROJECT>"])
        #expect(tree.lines.last == #"    text "SoundMixer=Fred Smith\#nMicrophones=COS11""#)
    }

    @Test func refusesMalformedXML() {
        #expect(throws: XMLTree.ReadError.self) { try XMLTree("<A><B></A>") }
    }
}
