import Foundation

struct JamOptimizerResult: nonisolated Equatable {
    let groups: [GeneratedJamGroup]
}

struct GeneratedJamGroup: nonisolated Equatable {
    let dancers: [DancerSnapshot]
    var startingDancerID: UUID
}
