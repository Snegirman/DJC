import Foundation
import SwiftData
import Testing
@testable import DJC

struct JamStarterTests {
    private let optimizer = JamOptimizer()
    private let dancers = (1...9).map { index in
        DancerSnapshot(
            id: UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, UInt8(index))),
            name: "Dancer \(index)"
        )
    }

    @Test func choosesFewestStartsWithinEachGroup() throws {
        let counts = [3, 1, 2, 5, 2, 3, 6, 4, 5]
        let countsByID = Dictionary(uniqueKeysWithValues: zip(dancers.map(\.id), counts))
        let history = dancers.flatMap { dancer in
            (0..<countsByID[dancer.id, default: 0]).map { _ in
                jam(starters: [dancer.id])
            }
        }
        let result = try optimizer.generateGroups(for: input(history: history))

        #expect(result.groups.count == 3)
        for group in result.groups {
            #expect(group.dancers.contains { $0.id == group.startingDancerID })
            let minimum = group.dancers.map { countsByID[$0.id, default: 0] }.min()
            #expect(countsByID[group.startingDancerID] == minimum)
        }
    }

    @Test func prefersDancerWhoHasNeverStarted() throws {
        let history = [jam(starters: [dancers[0].id]), jam(starters: [dancers[1].id])]
        let result = try optimizer.generateGroups(for: input(history: history, count: 3))

        #expect(result.groups.first?.startingDancerID == dancers[2].id)
    }

    @Test(arguments: DanceStyle.allCases)
    func countsOnlyStartsInSelectedStyle(style: DanceStyle) throws {
        let history = DanceStyle.allCases.map { historyStyle in
            jam(starters: [dancers[historyStyle == style ? 0 : 1].id], style: historyStyle)
        }
        let result = try optimizer.generateGroups(for: input(history: history, count: 3, style: style))

        #expect(result.groups.first?.startingDancerID == dancers[1].id)
    }

    @Test func unknownStartersDoNotCountAndTiesStayStableAfterRenaming() throws {
        let history = [jam(starters: []), jam(starters: [])]
        let first = try optimizer.generateGroups(for: input(history: history, count: 3))
        let renamed = dancers.prefix(3).reversed().map { dancer in
            DancerSnapshot(id: dancer.id, name: "Renamed \(dancer.id)")
        }
        let second = try optimizer.generateGroups(for: JamOptimizerInput(
            style: .popping, presentDancers: renamed, previousJams: history
        ))

        #expect(first.groups.first?.startingDancerID == dancers[0].id)
        #expect(second.groups.first?.startingDancerID == first.groups.first?.startingDancerID)
    }

    @Test func savingRotatesStartersButRegenerationDoesNotCountAsAStart() throws {
        var history: [JamSnapshot] = []
        var starters: [UUID] = []
        for _ in 0..<3 {
            let input = input(history: history, count: 3)
            let result = try optimizer.generateGroups(for: input)
            #expect(try optimizer.generateGroups(for: input) == result)
            let starter = try #require(result.groups.first?.startingDancerID)
            starters.append(starter)
            history.append(jam(starters: [starter]))
        }

        #expect(Set(starters) == Set(dancers.prefix(3).map(\.id)))
    }

    private func input(history: [JamSnapshot], count: Int = 9, style: DanceStyle = .popping) -> JamOptimizerInput {
        JamOptimizerInput(style: style, presentDancers: Array(dancers.prefix(count)), previousJams: history)
    }

    private func jam(starters: [UUID], style: DanceStyle = .popping) -> JamSnapshot {
        JamSnapshot(id: UUID(), style: style, date: Date(), groups: [dancers.map(\.id)], startingDancerIDs: starters)
    }
}

@MainActor
struct JamStarterPersistenceTests {
    @Test func manualOverrideSurvivesSavingAndAffectsNextGeneration() throws {
        let container = try ModelContainer(
            for: Dancer.self, Jam.self, JamGroup.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)
        let dancers = (1...3).map { Dancer(name: "Dancer \($0)") }
        let snapshots = dancers.map { DancerSnapshot(id: $0.id, name: $0.visibleName) }
        let optimizer = JamOptimizer()
        let input = JamOptimizerInput(style: .popping, presentDancers: snapshots, previousJams: [])
        var group = try #require(optimizer.generateGroups(for: input).groups.first)
        let suggestedID = group.startingDancerID
        let chosen = try #require(dancers.first { $0.id != suggestedID })
        group.startingDancerID = chosen.id
        context.insert(Jam(style: .popping, groups: [
            JamGroup(index: 1, dancers: dancers, startingDancerID: group.startingDancerID)
        ]))
        try context.save()

        let reader = ModelContext(container)
        let saved = try #require(reader.fetch(FetchDescriptor<Jam>()).first)
        #expect(saved.groups.first?.startingDancerID == chosen.id)
        let savedStarter = try #require(saved.groups.first?.dancers.first { $0.id == chosen.id })
        savedStarter.displayName = "Renamed starter"
        try reader.save()
        let history = JamSnapshot(
            id: saved.id, style: saved.style, date: saved.date,
            groups: saved.groups.map { $0.dancers.map(\.id) },
            startingDancerIDs: saved.groups.compactMap(\.startingDancerID)
        )
        let next = try optimizer.generateGroups(for: JamOptimizerInput(
            style: .popping, presentDancers: snapshots, previousJams: [history]
        ))
        #expect(next.groups.first?.startingDancerID == suggestedID)

        let imported = try JamCSVImporter().importJams(from: JamCSVExporter().export(jams: [saved]))
        #expect(imported.first?.groups.first?.startingDancerID == chosen.id)

        reader.delete(saved)
        try reader.save()
        #expect(try reader.fetch(FetchDescriptor<Jam>()).isEmpty)
        #expect(try optimizer.generateGroups(for: input).groups.first?.startingDancerID == suggestedID)
    }

    @Test func upgradesV2StoreAndPersistsStarterAfterReopening() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("history.store")
        let dancerIDs = [UUID(), UUID(), UUID()]
        let jamIDs = [UUID(), UUID()]

        try autoreleasepool {
            let container = try ModelContainer(
                for: Schema(versionedSchema: JamSchemaV2.self),
                configurations: ModelConfiguration(url: url)
            )
            let context = ModelContext(container)
            let dancers = dancerIDs.map { JamSchemaV2.Dancer(id: $0, name: "Dancer") }
            for jamID in jamIDs {
                context.insert(JamSchemaV2.Jam(id: jamID, style: .waving, groups: [
                    JamSchemaV2.JamGroup(index: 1, dancers: dancers)
                ]))
            }
            try context.save()
        }

        try autoreleasepool {
            let container = try ModelContainer(
                for: Schema(versionedSchema: JamSchemaV3.self),
                migrationPlan: JamMigrationPlan.self,
                configurations: ModelConfiguration(url: url)
            )
            let context = ModelContext(container)
            let jams = try context.fetch(FetchDescriptor<Jam>())
            #expect(Set(jams.map(\.id)) == Set(jamIDs))
            #expect(jams.allSatisfy { $0.style == .waving })
            #expect(jams.allSatisfy { Set($0.groups.flatMap(\.dancers).map(\.id)) == Set(dancerIDs) })
            #expect(jams.flatMap(\.groups).allSatisfy { $0.startingDancerID == nil })
            let firstGroup = try #require(jams.first { $0.id == jamIDs[0] }?.groups.first)
            firstGroup.startingDancerID = dancerIDs[1]
            try context.save()
        }

        try autoreleasepool {
            let container = try ModelContainer(
                for: Schema(versionedSchema: JamSchemaV3.self),
                migrationPlan: JamMigrationPlan.self,
                configurations: ModelConfiguration(url: url)
            )
            let context = ModelContext(container)
            let jams = try context.fetch(FetchDescriptor<Jam>())
            #expect(jams.first { $0.id == jamIDs[0] }?.groups.first?.startingDancerID == dancerIDs[1])
            #expect(jams.first { $0.id == jamIDs[1] }?.groups.first?.startingDancerID == nil)
            #expect(jams.allSatisfy { Set($0.groups.flatMap(\.dancers).map(\.id)) == Set(dancerIDs) })
        }
    }
}

struct JamStarterCSVTests {
    private let header = "jam_id,date,style,group_index,dancer_id,dancer_display_name,dancer_nickname,dancer_first_name,dancer_last_name"
    private let jamID = UUID()
    private let dancers = (1...6).map { Dancer(name: "Dancer \($0)") }

    @Test func roundTripsStartersInMultipleGroupsAndUnknownStarter() throws {
        let firstJam = Jam(style: .animation, groups: [
            JamGroup(index: 1, dancers: Array(dancers.prefix(3)), startingDancerID: dancers[2].id),
            JamGroup(index: 2, dancers: Array(dancers.suffix(3)), startingDancerID: dancers[4].id)
        ])
        let legacyJam = Jam(style: .waving, groups: [JamGroup(index: 1, dancers: dancers)])
        let csv = JamCSVExporter().export(jams: [firstJam, legacyJam])
        let imported = try JamCSVImporter().importJams(from: csv)

        #expect(csv.hasPrefix(header + ",starts_first\n"))
        let groups = try #require(imported.first { $0.id == firstJam.id }?.groups)
        #expect(groups.map(\.startingDancerID) == [dancers[2].id, dancers[4].id])
        #expect(imported.first { $0.id == legacyJam.id }?.groups.first?.startingDancerID == nil)
    }

    @Test func importsOldCSVWithoutInventingStarter() throws {
        let csv = header + "\n" + row(dancerID: dancers[0].id)
        let imported = try JamCSVImporter().importJams(from: csv)

        #expect(imported.first?.groups.first?.startingDancerID == nil)
    }

    @Test func rejectsTwoStartersInOneGroup() {
        let csv = header + ",starts_first\n"
            + row(dancerID: dancers[0].id) + ",true\n"
            + row(dancerID: dancers[1].id) + ",true"

        #expect(throws: JamCSVImportError.multipleStarters(3)) {
            try JamCSVImporter().importJams(from: csv)
        }
    }

    @Test func rejectsInvalidStarterFlag() {
        let csv = header + ",starts_first\n" + row(dancerID: dancers[0].id) + ",yes"

        #expect(throws: JamCSVImportError.invalidStarterFlag(2)) {
            try JamCSVImporter().importJams(from: csv)
        }
    }

    private func row(dancerID: UUID) -> String {
        "\(jamID),1970-01-01T00:00:00Z,popping,1,\(dancerID),Dancer,dancer,,"
    }
}
