import Foundation
import SwiftData

// Original on-disk schema. Keep unchanged so existing stores can be migrated.
enum JamSchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] { [Dancer.self, Jam.self, JamGroup.self] }

    @Model
    final class Dancer {
        var id: UUID
        var name: String
        var displayName: String
        var nickname: String
        var firstName: String
        var lastName: String
        var isArchived: Bool
        var createdAt: Date

        var visibleName: String {
            let trimmedDisplayName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedDisplayName.isEmpty {
                return trimmedDisplayName
            }

            let trimmedNickname = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedNickname.isEmpty {
                return trimmedNickname
            }

            return name
        }

        init(
            id: UUID = UUID(),
            name: String,
            displayName: String = "",
            nickname: String? = nil,
            firstName: String = "",
            lastName: String = "",
            isArchived: Bool = false,
            createdAt: Date = Date()
        ) {
            let resolvedNickname = nickname ?? name

            self.id = id
            self.name = name
            self.displayName = displayName
            self.nickname = resolvedNickname
            self.firstName = firstName
            self.lastName = lastName
            self.isArchived = isArchived
            self.createdAt = createdAt
        }
    }

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
}
