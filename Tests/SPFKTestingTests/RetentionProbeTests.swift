// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-testing

import Foundation
import SPFKTesting
import Testing

@testable import SPFKBench

@Suite(.serialized)
struct RetentionProbeTests {
    @Test func parsesTheRegionTableOnly() {
        let text = """
                                            VIRTUAL RESIDENT    DIRTY  SWAPPED VOLATILE   NONVOL    EMPTY   REGION
            REGION TYPE                        SIZE     SIZE     SIZE     SIZE     SIZE     SIZE     SIZE    COUNT (non-coalesced)
            ===========                     ======= ========    =====  ======= ========   ======    =====  =======
            IOSurface                        512.0M   400.0M   300.0M   100.0M       0K       0K       0K       12
            Malloc Large                      1.5G     1.0G     1.0G       0K       0K       0K       0K        3         see MALLOC ZONE table below
            __AUTH                              35K      35K      848       0K       0K       0K       0K       15
            ===========                     ======= ========    =====  ======= ========   ======    =====  =======
            TOTAL                              2.0G     1.4G     1.3G     100M       0K       0K       0K       30

                                              VIRTUAL   RESIDENT      DIRTY    SWAPPED ALLOCATION      BYTES DIRTY+SWAP          REGION
            MALLOC ZONE                          SIZE       SIZE       SIZE       SIZE      COUNT  ALLOCATED  FRAG SIZE  % FRAG   COUNT
            ===========                       =======  =========  =========  =========  =========  =========  =========  ======  ======
            DefaultMallocZone_0x100000000       1.5G       1.0G       1.0G         0K        100       1.0G         0K      0%       3
            """

        let regions = parseVMMapSummary(text)

        #expect(regions.count == 3)
        #expect(regions["IOSurface"] == 400)
        #expect(regions["Malloc Large"] == 1024)
        #expect(abs((regions["__AUTH"] ?? 0) - 848 / 1_048_576) < 1e-9)
    }

    @Test func namesTheRegionThatGrows() async {
        var kept: [UnsafeMutableRawPointer] = []

        let report = await retention("leak", loops: 3) { _ in
            let size = 64 * 1_048_576
            guard let block = malloc(size) else { return }
            memset(block, 1, size)
            kept.append(block)
        }

        defer { kept.forEach { free($0) } }

        #expect(report.perLoopMB > 50)
        #expect(report.grownRegions.first?.name.hasPrefix("Malloc") == true, "\(report.grownRegions)")
    }

    @Test func flatWorkReportsNoRegions() async {
        let report = await retention("flat", loops: 3) { _ in
            let size = 64 * 1_048_576
            guard let block = malloc(size) else { return }
            memset(block, 1, size)
            free(block)
        }

        #expect(report.grownRegions.isEmpty)
    }

    @Test func retainedMemorySeesPerItemGrowth() async throws {
        let store = Store()

        let grown = try await retainedMemoryMB(warmUp: 4, measured: 8, width: 4) { _ in
            let size = 16 * 1_048_576
            guard let block = malloc(size) else { return }
            memset(block, 1, size)
            await store.keep(Int(bitPattern: block))
        }

        await store.freeAll()
        #expect(grown > 100, "grew \(Int(grown)) MB")
    }

    private actor Store {
        var blocks: [Int] = []
        func keep(_ block: Int) { blocks.append(block) }
        func freeAll() { blocks.forEach { free(UnsafeMutableRawPointer(bitPattern: $0)) }; blocks = [] }
    }
}
