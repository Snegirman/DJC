import Foundation

struct DancerSnapshot: Identifiable, nonisolated Hashable {
    let id: UUID
    let name: String
}

struct JamSnapshot: Identifiable {
    let id: UUID
    let style: DanceStyle
    let date: Date
    let groups: [[UUID]]
    var startingDancerIDs: [UUID] = []
}

struct JamOptimizerInput {
    let style: DanceStyle
    let presentDancers: [DancerSnapshot]
    let previousJams: [JamSnapshot]
}
