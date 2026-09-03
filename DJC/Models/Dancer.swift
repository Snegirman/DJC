import Foundation
import SwiftData

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
