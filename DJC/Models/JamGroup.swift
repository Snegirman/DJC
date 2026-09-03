import Foundation
import SwiftData

@Model
final class JamGroup {
    var id: UUID
    var index: Int
    var dancers: [Dancer]
    var jam: Jam?

    init(
        id: UUID = UUID(),
        index: Int,
        dancers: [Dancer] = [],
        jam: Jam? = nil
    ) {
        self.id = id
        self.index = index
        self.dancers = dancers
        self.jam = jam
    }
}
