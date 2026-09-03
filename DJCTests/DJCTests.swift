import Foundation
import Testing
@testable import DJC

struct JamOptimizerTests {
    private let optimizer = JamOptimizer()

    @Test func calculatesTwelveAsFourGroupsOfThree() {
        #expect(optimizer.calculateGroupSizes(dancerCount: 12) == [3, 3, 3, 3])
    }

    @Test func calculatesThirteenAsThreeThreeThreeFour() {
        #expect(optimizer.calculateGroupSizes(dancerCount: 13) == [3, 3, 3, 4])
    }

    @Test func calculatesFourteenAsThreeThreeFourFour() {
        #expect(optimizer.calculateGroupSizes(dancerCount: 14) == [3, 3, 4, 4])
    }

    @Test func calculatesTenAsThreeThreeFour() {
        #expect(optimizer.calculateGroupSizes(dancerCount: 10) == [3, 3, 4])
    }

    @Test func calculatesTypicalClassGroupSizes() {
        #expect(optimizer.calculateGroupSizes(dancerCount: 15) == [3, 3, 3, 3, 3])
        #expect(optimizer.calculateGroupSizes(dancerCount: 16) == [3, 3, 3, 3, 4])
        #expect(optimizer.calculateGroupSizes(dancerCount: 17) == [3, 3, 3, 4, 4])
        #expect(optimizer.calculateGroupSizes(dancerCount: 18) == [3, 3, 3, 3, 3, 3])
        #expect(optimizer.calculateGroupSizes(dancerCount: 19) == [3, 3, 3, 3, 3, 4])
        #expect(optimizer.calculateGroupSizes(dancerCount: 20) == [3, 3, 3, 3, 4, 4])
    }

    @Test func calculatesSmallValidGroups() {
        #expect(optimizer.calculateGroupSizes(dancerCount: 3) == [3])
        #expect(optimizer.calculateGroupSizes(dancerCount: 4) == [4])
        #expect(optimizer.calculateGroupSizes(dancerCount: 5) == [5])
    }

    @Test func calculatesElevenAsThreeFourFour() {
        #expect(optimizer.calculateGroupSizes(dancerCount: 11) == [3, 4, 4])
    }

    @Test func returnsNoGroupSizesForTooFewDancers() {
        #expect(optimizer.calculateGroupSizes(dancerCount: 0) == [])
        #expect(optimizer.calculateGroupSizes(dancerCount: 1) == [])
        #expect(optimizer.calculateGroupSizes(dancerCount: 2) == [])
    }

    @Test func rejectsLessThanThreeDancers() throws {
        let input = JamOptimizerInput(
            style: .popping,
            presentDancers: [DancerSnapshot(id: id(1), name: "Solo")],
            previousJams: []
        )

        #expect(throws: JamOptimizerError.notEnoughDancers) {
            try optimizer.generateGroups(for: input)
        }
    }

    @Test func generatedGroupsContainEveryDancerExactlyOnce() throws {
        let dancers = makeDancers(count: 20)
        let input = JamOptimizerInput(
            style: .popping,
            presentDancers: dancers,
            previousJams: []
        )

        let result = try optimizer.generateGroups(for: input)
        let generatedIDs = result.groups.flatMap { $0.map(\.id) }

        #expect(Set(generatedIDs) == Set(dancers.map(\.id)))
        #expect(generatedIDs.count == dancers.count)
    }

    @Test func generatedGroupsAlwaysRespectMinimumSize() throws {
        for dancerCount in 3...24 {
            let input = JamOptimizerInput(
                style: .popping,
                presentDancers: makeDancers(count: dancerCount),
                previousJams: []
            )

            let result = try optimizer.generateGroups(for: input)

            #expect(result.groups.allSatisfy { $0.count >= 3 })
            #expect(result.groups.flatMap { $0 }.count == dancerCount)
        }
    }

    @Test func seededCandidatesAreDeterministic() throws {
        let dancers = makeDancers(count: 18)
        let input = JamOptimizerInput(
            style: .popping,
            presentDancers: dancers,
            previousJams: makeAlternatingHistory(dancers: dancers)
        )
        let config = JamOptimizer.Configuration(seededShuffleCandidateCount: 32, seededShuffleBaseSeed: 42)
        let firstOptimizer = JamOptimizer(configuration: config)
        let secondOptimizer = JamOptimizer(configuration: config)

        let firstResult = try firstOptimizer.generateGroups(for: input)
        let secondResult = try secondOptimizer.generateGroups(for: input)

        #expect(firstResult == secondResult)
    }

    @Test func seededCandidatesDoNotWorsenBaselineScore() throws {
        let dancers = makeDancers(count: 18)
        let input = JamOptimizerInput(
            style: .popping,
            presentDancers: dancers,
            previousJams: makeAlternatingHistory(dancers: dancers)
        )
        let baselineOptimizer = JamOptimizer(configuration: JamOptimizer.Configuration(seededShuffleCandidateCount: 0))
        let strongerOptimizer = JamOptimizer(configuration: JamOptimizer.Configuration(seededShuffleCandidateCount: 64, seededShuffleBaseSeed: 42))

        let baselineResult = try baselineOptimizer.generateGroups(for: input)
        let strongerResult = try strongerOptimizer.generateGroups(for: input)

        #expect(strongerOptimizer.score(groups: strongerResult.groups, for: input) <= baselineOptimizer.score(groups: baselineResult.groups, for: input))
    }

    @Test func avoidsRepeatedPairsWhenHistoryAllowsIt() throws {
        let dancers = makeDancers(names: ["A", "B", "C", "D", "E", "F", "G", "H", "I"])
        let previousJam = JamSnapshot(
            id: id(100),
            style: .popping,
            date: Date(timeIntervalSince1970: 100),
            groups: [
                dancers[0...2].map(\.id),
                dancers[3...5].map(\.id),
                dancers[6...8].map(\.id)
            ]
        )
        let input = JamOptimizerInput(
            style: .popping,
            presentDancers: dancers,
            previousJams: [previousJam]
        )

        let result = try optimizer.generateGroups(for: input)

        #expect(optimizer.score(groups: result.groups, for: input) == 0)
    }

    @Test func generateGroupsIgnoresHistoryFromOtherDanceStyles() throws {
        let dancers = makeDancers(names: ["A", "B", "C", "D", "E", "F", "G", "H", "I"])
        let baselineInput = JamOptimizerInput(
            style: .popping,
            presentDancers: dancers,
            previousJams: []
        )
        let animationHistoryInput = JamOptimizerInput(
            style: .popping,
            presentDancers: dancers,
            previousJams: [
                JamSnapshot(
                    id: id(90),
                    style: .animation,
                    date: Date(timeIntervalSince1970: 100),
                    groups: [[dancers[0].id, dancers[1].id, dancers[2].id]]
                )
            ]
        )

        let baselineResult = try optimizer.generateGroups(for: baselineInput)
        let resultWithOtherStyleHistory = try optimizer.generateGroups(for: animationHistoryInput)

        #expect(optimizer.score(groups: resultWithOtherStyleHistory.groups, for: animationHistoryInput) == 0)
        #expect(resultWithOtherStyleHistory.groups.map(\.count) == baselineResult.groups.map(\.count))
    }

    @Test func ignoresHistoryFromOtherDanceStyles() {
        let dancers = makeDancers(names: ["A", "B", "C", "D", "E", "F", "G", "H", "I"])
        let groups = [
            [dancers[0], dancers[3], dancers[6]],
            [dancers[1], dancers[4], dancers[7]],
            [dancers[2], dancers[5], dancers[8]]
        ]
        let animationJam = JamSnapshot(
            id: id(101),
            style: .animation,
            date: Date(timeIntervalSince1970: 100),
            groups: groups.map { $0.map(\.id) }
        )
        let input = JamOptimizerInput(
            style: .popping,
            presentDancers: dancers,
            previousJams: [animationJam]
        )

        #expect(optimizer.score(groups: groups, for: input) == 0)
    }

    @Test func penalizesRepeatedGroupsWithinSameDanceStyle() {
        let dancers = makeDancers(names: ["A", "B", "C"])
        let groups = [dancers]
        let poppingJam = JamSnapshot(
            id: id(102),
            style: .popping,
            date: Date(timeIntervalSince1970: 100),
            groups: groups.map { $0.map(\.id) }
        )
        let input = JamOptimizerInput(
            style: .popping,
            presentDancers: dancers,
            previousJams: [poppingJam]
        )

        #expect(optimizer.score(groups: groups, for: input) > 0)
    }

    @Test func scoringUsesConfigurationWeights() {
        let dancers = makeDancers(names: ["A", "B", "C"])
        let groups = [dancers]
        let config = JamOptimizer.Configuration(
            minimumGroupSize: 3,
            repeatedPairWeight: 1,
            attendanceFrequencyWeight: 2,
            recencyWeight: 3,
            repeatedWholeGroupWeight: 4
        )
        let optimizer = JamOptimizer(configuration: config)
        let previousJam = JamSnapshot(
            id: id(103),
            style: .popping,
            date: Date(timeIntervalSince1970: 100),
            groups: groups.map { $0.map(\.id) }
        )
        let input = JamOptimizerInput(
            style: .popping,
            presentDancers: dancers,
            previousJams: [previousJam]
        )

        #expect(optimizer.score(groups: groups, for: input) == 22)
    }

    @Test func frequentPairsArePenalizedMoreThanRarePairsWithSameAbsoluteCount() {
        let dancers = makeDancers(names: ["A", "B", "C", "D", "E", "F"])
        let rarePairInput = JamOptimizerInput(
            style: .popping,
            presentDancers: dancers,
            previousJams: [
                JamSnapshot(id: id(110), style: .popping, date: Date(timeIntervalSince1970: 300), groups: [[dancers[0].id, dancers[1].id, dancers[2].id]]),
                JamSnapshot(id: id(111), style: .popping, date: Date(timeIntervalSince1970: 200), groups: [[dancers[0].id, dancers[3].id, dancers[4].id], [dancers[1].id, dancers[2].id, dancers[5].id]]),
                JamSnapshot(id: id(112), style: .popping, date: Date(timeIntervalSince1970: 100), groups: [[dancers[0].id, dancers[4].id, dancers[5].id], [dancers[1].id, dancers[2].id, dancers[3].id]])
            ]
        )
        let frequentPairInput = JamOptimizerInput(
            style: .popping,
            presentDancers: dancers,
            previousJams: [
                JamSnapshot(id: id(113), style: .popping, date: Date(timeIntervalSince1970: 300), groups: [[dancers[0].id, dancers[1].id, dancers[2].id]])
            ]
        )
        let candidate = [[dancers[0], dancers[1], dancers[2]]]

        #expect(optimizer.score(groups: candidate, for: frequentPairInput) > optimizer.score(groups: candidate, for: rarePairInput))
    }

    @Test func recentPairsArePenalizedMoreThanOlderPairs() {
        let dancers = makeDancers(names: ["A", "B", "C"])
        let candidate = [dancers]
        let oldPairInput = JamOptimizerInput(
            style: .popping,
            presentDancers: dancers,
            previousJams: [
                JamSnapshot(id: id(120), style: .popping, date: Date(timeIntervalSince1970: 200), groups: [[id(10), id(11), id(12)]]),
                JamSnapshot(id: id(121), style: .popping, date: Date(timeIntervalSince1970: 100), groups: candidate.map { $0.map(\.id) })
            ]
        )
        let recentPairInput = JamOptimizerInput(
            style: .popping,
            presentDancers: dancers,
            previousJams: [
                JamSnapshot(id: id(122), style: .popping, date: Date(timeIntervalSince1970: 200), groups: candidate.map { $0.map(\.id) }),
                JamSnapshot(id: id(123), style: .popping, date: Date(timeIntervalSince1970: 100), groups: [[id(10), id(11), id(12)]])
            ]
        )

        #expect(optimizer.score(groups: candidate, for: recentPairInput) > optimizer.score(groups: candidate, for: oldPairInput))
    }

    private func makeDancers(names: [String]) -> [DancerSnapshot] {
        names.enumerated().map { index, name in
            DancerSnapshot(id: id(UInt8(index + 1)), name: name)
        }
    }

    private func makeDancers(count: Int) -> [DancerSnapshot] {
        (1...count).map { index in
            DancerSnapshot(id: id(UInt8(index)), name: "Dancer \(index)")
        }
    }

    private func makeAlternatingHistory(dancers: [DancerSnapshot]) -> [JamSnapshot] {
        let groupPatterns = [
            [[0, 1, 2], [3, 4, 5], [6, 7, 8], [9, 10, 11], [12, 13, 14], [15, 16, 17]],
            [[0, 3, 6], [1, 4, 7], [2, 5, 8], [9, 12, 15], [10, 13, 16], [11, 14, 17]],
            [[0, 4, 8], [1, 5, 6], [2, 3, 7], [9, 13, 17], [10, 14, 15], [11, 12, 16]],
            [[0, 9, 10], [1, 11, 12], [2, 13, 14], [3, 15, 16], [4, 5, 17], [6, 7, 8]]
        ]

        return groupPatterns.enumerated().map { index, groups in
            JamSnapshot(
                id: id(UInt8(130 + index)),
                style: .popping,
                date: Date(timeIntervalSince1970: Double(100 + index)),
                groups: groups.map { group in group.map { dancers[$0].id } }
            )
        }
    }

    private func id(_ value: UInt8) -> UUID {
        UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, value))
    }
}

struct DancerStatsCalculatorTests {
    @Test func calculatesAttendanceAndFrequentPartners() {
        let alex = Dancer(id: id(1), name: "alex", displayName: "Alex", nickname: "alex")
        let masha = Dancer(id: id(2), name: "masha", displayName: "Masha", nickname: "masha")
        let ivan = Dancer(id: id(3), name: "ivan", displayName: "Ivan", nickname: "ivan")
        let poppingJam = Jam(
            id: id(101),
            style: .popping,
            groups: [JamGroup(index: 1, dancers: [alex, masha])]
        )
        let wavingJam = Jam(
            id: id(102),
            style: .waving,
            groups: [JamGroup(index: 1, dancers: [alex, masha, ivan])]
        )

        let stats = DancerStatsCalculator().stats(for: alex, jams: [poppingJam, wavingJam])

        #expect(stats.totalJamCount == 2)
        #expect(stats.attendanceByStyle == [
            DancerStats.StyleAttendance(style: .popping, jamCount: 1),
            DancerStats.StyleAttendance(style: .waving, jamCount: 1)
        ])
        #expect(stats.frequentPartners[0] == DancerStats.FrequentPartner(
            dancerID: masha.id,
            name: "Masha",
            sharedJamCount: 2
        ))
        #expect(stats.frequentPartners[1] == DancerStats.FrequentPartner(
            dancerID: ivan.id,
            name: "Ivan",
            sharedJamCount: 1
        ))
    }

    private func id(_ value: UInt8) -> UUID {
        UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, value))
    }
}

struct JamCSVImporterTests {
    private let header = "jam_id,date,style,group_index,dancer_id,dancer_display_name,dancer_nickname,dancer_first_name,dancer_last_name"

    @Test func importsExportedCSVIntoJamsAndGroups() throws {
        let jamID = UUID(uuidString: "00000000-0000-0000-0000-000000000101")!
        let firstDancerID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let secondDancerID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
        let csv = """
        \(header)
        \(jamID.uuidString),1970-01-01T00:00:00Z,popping,1,\(firstDancerID.uuidString),Alex,alex,Alex,Stone
        \(jamID.uuidString),1970-01-01T00:00:00Z,popping,1,\(secondDancerID.uuidString),Masha,masha,Masha,Ivanova
        """

        let importedJams = try JamCSVImporter().importJams(from: csv)

        #expect(importedJams.count == 1)
        #expect(importedJams[0].id == jamID)
        #expect(importedJams[0].style == .popping)
        #expect(importedJams[0].groups.count == 1)
        #expect(importedJams[0].groups[0].dancers.map(\.id) == [firstDancerID, secondDancerID])
    }

    @Test func importsQuotedCSVValues() throws {
        let jamID = UUID(uuidString: "00000000-0000-0000-0000-000000000102")!
        let dancerID = UUID(uuidString: "00000000-0000-0000-0000-000000000003")!
        let csv = """
        \(header)
        \(jamID.uuidString),1970-01-01T00:00:00Z,waving,1,\(dancerID.uuidString),"Alex, Wave",wavealex,Alex,Stone
        """

        let importedJams = try JamCSVImporter().importJams(from: csv)

        #expect(importedJams[0].groups[0].dancers[0].displayName == "Alex, Wave")
    }

    @Test func rejectsEmptyCSV() {
        #expect(throws: JamCSVImportError.missingHeader) {
            try JamCSVImporter().importJams(from: "")
        }
    }

    @Test func rejectsInvalidHeader() {
        let csv = "wrong,header\n"

        #expect(throws: JamCSVImportError.invalidHeader) {
            try JamCSVImporter().importJams(from: csv)
        }
    }

    @Test func rejectsInvalidRowColumnCount() {
        let csv = """
        \(header)
        too,few,columns
        """

        #expect(throws: JamCSVImportError.invalidRow(2)) {
            try JamCSVImporter().importJams(from: csv)
        }
    }

    @Test func rejectsInvalidJamID() {
        let csv = """
        \(header)
        not-a-uuid,1970-01-01T00:00:00Z,popping,1,00000000-0000-0000-0000-000000000001,Alex,alex,Alex,Stone
        """

        #expect(throws: JamCSVImportError.invalidJamID(2)) {
            try JamCSVImporter().importJams(from: csv)
        }
    }

    @Test func rejectsInvalidDate() {
        let csv = """
        \(header)
        00000000-0000-0000-0000-000000000101,not-a-date,popping,1,00000000-0000-0000-0000-000000000001,Alex,alex,Alex,Stone
        """

        #expect(throws: JamCSVImportError.invalidDate(2)) {
            try JamCSVImporter().importJams(from: csv)
        }
    }

    @Test func rejectsInvalidStyle() {
        let csv = """
        \(header)
        00000000-0000-0000-0000-000000000101,1970-01-01T00:00:00Z,locking,1,00000000-0000-0000-0000-000000000001,Alex,alex,Alex,Stone
        """

        #expect(throws: JamCSVImportError.invalidStyle(2)) {
            try JamCSVImporter().importJams(from: csv)
        }
    }

    @Test func rejectsInconsistentJamDate() {
        let csv = """
        \(header)
        00000000-0000-0000-0000-000000000101,1970-01-01T00:00:00Z,popping,1,00000000-0000-0000-0000-000000000001,Alex,alex,Alex,Stone
        00000000-0000-0000-0000-000000000101,1970-01-02T00:00:00Z,popping,1,00000000-0000-0000-0000-000000000002,Masha,masha,Masha,Ivanova
        """

        #expect(throws: JamCSVImportError.inconsistentJamDate(3)) {
            try JamCSVImporter().importJams(from: csv)
        }
    }

    @Test func rejectsInconsistentJamStyle() {
        let csv = """
        \(header)
        00000000-0000-0000-0000-000000000101,1970-01-01T00:00:00Z,popping,1,00000000-0000-0000-0000-000000000001,Alex,alex,Alex,Stone
        00000000-0000-0000-0000-000000000101,1970-01-01T00:00:00Z,waving,1,00000000-0000-0000-0000-000000000002,Masha,masha,Masha,Ivanova
        """

        #expect(throws: JamCSVImportError.inconsistentJamStyle(3)) {
            try JamCSVImporter().importJams(from: csv)
        }
    }

    @Test func rejectsInvalidGroupIndex() {
        let csv = """
        \(header)
        00000000-0000-0000-0000-000000000101,1970-01-01T00:00:00Z,popping,0,00000000-0000-0000-0000-000000000001,Alex,alex,Alex,Stone
        """

        #expect(throws: JamCSVImportError.invalidGroupIndex(2)) {
            try JamCSVImporter().importJams(from: csv)
        }
    }

    @Test func rejectsInvalidDancerID() {
        let csv = """
        \(header)
        00000000-0000-0000-0000-000000000101,1970-01-01T00:00:00Z,popping,1,not-a-uuid,Alex,alex,Alex,Stone
        """

        #expect(throws: JamCSVImportError.invalidDancerID(2)) {
            try JamCSVImporter().importJams(from: csv)
        }
    }
}

struct JamCSVExporterTests {
    @Test func exportsDancerProfileFieldsAndEscapesCSVValues() {
        let dancer = Dancer(
            name: "legacy",
            displayName: "Alex, Wave",
            nickname: "wavealex",
            firstName: "Alex",
            lastName: "Stone"
        )
        let group = JamGroup(index: 1, dancers: [dancer])
        let jam = Jam(
            style: .waving,
            date: Date(timeIntervalSince1970: 0),
            groups: [group]
        )

        let csv = JamCSVExporter().export(jams: [jam])

        #expect(csv.contains("jam_id,date,style,group_index,dancer_id,dancer_display_name,dancer_nickname,dancer_first_name,dancer_last_name"))
        #expect(csv.contains("waving,1"))
        #expect(csv.contains("\"Alex, Wave\",wavealex,Alex,Stone"))
    }
}
