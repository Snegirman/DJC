import Foundation
import SwiftData

@Model
final class Jam {
    var id: UUID
    var styleRawValue: String
    var date: Date
    @Relationship(deleteRule: .cascade, inverse: \JamGroup.jam)
    var groups: [JamGroup]

    var style: DanceStyle {
        get { DanceStyle(rawValue: styleRawValue) ?? .popping }
        set { styleRawValue = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        style: DanceStyle,
        date: Date = Date(),
        groups: [JamGroup] = []
    ) {
        self.id = id
        self.styleRawValue = style.rawValue
        self.date = date
        self.groups = groups
    }
}
