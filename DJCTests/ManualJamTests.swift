import Foundation
import SwiftData
import Testing
@testable import DJC

@MainActor
struct ManualJamTests {
    private let now = Date(timeIntervalSince1970: 1_000)
    private let dancerIDs = (0..<8).map { _ in UUID() }

    @Test func acceptsUnevenGroupsAndCurrentTime() {
        let draft = ManualJamDraft(style: .popping, date: now, groups: [
            .init(dancerIDs: Set(dancerIDs.prefix(3))),
            .init(dancerIDs: Set(dancerIDs.suffix(5)))
        ])

        #expect(draft.validationError(availableDancerIDs: Set(dancerIDs), now: now) == nil)
    }

    @Test func rejectsFutureDate() {
        let draft = ManualJamDraft(style: .popping, date: now.addingTimeInterval(1), groups: [
            .init(dancerIDs: Set(dancerIDs))
        ])

        #expect(draft.validationError(availableDancerIDs: Set(dancerIDs), now: now) == .futureDate)
    }

    @Test func rejectsNoGroups() {
        let draft = ManualJamDraft(style: .popping, date: now, groups: [])

        #expect(draft.validationError(availableDancerIDs: Set(dancerIDs), now: now) == .noGroups)
    }

    @Test(arguments: [0, 1, 2])
    func rejectsUndersizedGroup(count: Int) {
        let draft = ManualJamDraft(style: .popping, date: now, groups: [
            .init(dancerIDs: Set(dancerIDs.prefix(3))),
            .init(dancerIDs: Set(dancerIDs.suffix(count)))
        ])

        #expect(draft.validationError(availableDancerIDs: Set(dancerIDs), now: now) == .smallGroup(2))
    }

    @Test func rejectsDancerInMultipleGroups() {
        let draft = ManualJamDraft(style: .popping, date: now, groups: [
            .init(dancerIDs: Set(dancerIDs.prefix(3))),
            .init(dancerIDs: Set(dancerIDs[2...4]))
        ])

        #expect(draft.validationError(availableDancerIDs: Set(dancerIDs), now: now) == .duplicateDancer)
    }

    @Test func rejectsMissingDancer() {
        let draft = ManualJamDraft(style: .popping, date: now, groups: [
            .init(dancerIDs: Set(dancerIDs.prefix(3)))
        ])

        #expect(draft.validationError(availableDancerIDs: Set(dancerIDs.dropFirst()), now: now) == .missingDancer)
    }

    @Test func invalidDraftDoesNotInsertJamOrGroups() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let dancers = dancerIDs.map { Dancer(id: $0, name: "Dancer") }
        for dancer in dancers { context.insert(dancer) }
        let draft = ManualJamDraft(style: .waving, date: now, groups: [
            .init(dancerIDs: Set(dancerIDs.prefix(3))),
            .init(dancerIDs: Set(dancerIDs.suffix(2)))
        ])

        #expect(throws: ManualJamValidationError.smallGroup(2)) {
            try ManualJamRecorder().save(draft, dancers: dancers, in: context)
        }
        try context.save()
        let reader = ModelContext(container)
        #expect(try reader.fetchCount(FetchDescriptor<Jam>()) == 0)
        #expect(try reader.fetchCount(FetchDescriptor<JamGroup>()) == 0)
        #expect(try reader.fetchCount(FetchDescriptor<Dancer>()) == dancers.count)
    }

    @Test(arguments: DanceStyle.allCases)
    func savesBackdatedJamWithExactGroupsAndPreservesHistory(style: DanceStyle) throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let dancers = dancerIDs.enumerated().map { index, id in
            Dancer(id: id, name: "Dancer \(index)", isArchived: index == 0)
        }
        for dancer in dancers { context.insert(dancer) }
        let latestJam = Jam(style: style, date: now, groups: [
            JamGroup(index: 1, dancers: Array(dancers[3...5]))
        ])
        context.insert(latestJam)
        try context.save()

        let draft = ManualJamDraft(style: style, date: now.addingTimeInterval(-100), groups: [
            .init(dancerIDs: Set(dancerIDs.prefix(3))),
            .init(dancerIDs: Set(dancerIDs.suffix(5)))
        ])
        try ManualJamRecorder().save(draft, dancers: dancers, in: context)

        let reader = ModelContext(container)
        let jams = try reader.fetch(FetchDescriptor<Jam>(sortBy: [SortDescriptor(\.date, order: .reverse)]))
        #expect(jams.count == 2)
        let savedLatest = try #require(jams.first)
        let saved = try #require(jams.last)
        #expect(savedLatest.id == latestJam.id)
        #expect(Set(savedLatest.groups.flatMap(\.dancers).map(\.id)) == Set(dancerIDs[3...5]))
        #expect(saved.style == style)
        #expect(saved.date == draft.date)
        let groups = saved.groups.sorted { $0.index < $1.index }
        #expect(groups.map(\.index) == [1, 2])
        #expect(groups.map { Set($0.dancers.map(\.id)) } == draft.groups.map(\.dancerIDs))
        #expect(try reader.fetchCount(FetchDescriptor<Dancer>()) == dancers.count)
        let archivedDancer = try #require(reader.fetch(FetchDescriptor<Dancer>()).first { $0.id == dancerIDs[0] })
        #expect(archivedDancer.isArchived)

        let imported = try JamCSVImporter().importJams(from: JamCSVExporter().export(jams: jams))
        let exportedJam = try #require(imported.first { $0.id == saved.id })
        #expect(exportedJam.date == draft.date)
        #expect(exportedJam.style == style)
        #expect(exportedJam.groups.sorted { $0.index < $1.index }.map { Set($0.dancers.map(\.id)) } == draft.groups.map(\.dancerIDs))

        let history = jams.map { jam in
            JamSnapshot(id: jam.id, style: jam.style, date: jam.date, groups: jam.groups.map { $0.dancers.map(\.id) })
        }
        let candidate = dancers.prefix(3).map { DancerSnapshot(id: $0.id, name: $0.visibleName) }
        let optimizer = JamOptimizer(configuration: .init(
            repeatedPairWeight: 0, attendanceFrequencyWeight: 0, recencyWeight: 1, repeatedWholeGroupWeight: 0
        ))
        // Three pairs occurred in the second most recent jam: 3 × 1/2.
        #expect(optimizer.score(groups: [candidate], for: JamOptimizerInput(
            style: style, presentDancers: candidate, previousJams: history
        )) == 1.5)
        for otherStyle in DanceStyle.allCases where otherStyle != style {
            #expect(optimizer.score(groups: [candidate], for: JamOptimizerInput(
                style: otherStyle, presentDancers: candidate, previousJams: history
            )) == 0)
        }
    }

    private func makeContainer() throws -> ModelContainer {
        try ModelContainer(
            for: Dancer.self, Jam.self, JamGroup.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }
}
