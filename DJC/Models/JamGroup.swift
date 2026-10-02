import Foundation
import SwiftData

@Model
final class JamGroup {
    var id: UUID
    var index: Int
    var startingDancerID: UUID?
    // A dancer can belong to groups in many saved jams.
    @Relationship(deleteRule: .nullify, inverse: \Dancer.groups)
    var dancers: [Dancer]
    var jam: Jam?

    init(
        id: UUID = UUID(),
        index: Int,
        dancers: [Dancer] = [],
        startingDancerID: UUID? = nil,
        jam: Jam? = nil
    ) {
        self.id = id
        self.index = index
        self.dancers = dancers
        self.startingDancerID = startingDancerID
        self.jam = jam
    }
}
