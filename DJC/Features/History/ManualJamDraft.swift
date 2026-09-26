import Foundation

struct ManualJamDraft {
    struct Group: Identifiable {
        let id = UUID()
        var dancerIDs: Set<UUID> = []
    }

    var style: DanceStyle
    var date = Date()
    var groups = [Group()]

    func validationError(
        availableDancerIDs: Set<UUID>,
        now: Date = Date()
    ) -> ManualJamValidationError? {
        guard date <= now else { return .futureDate }
        guard !groups.isEmpty else { return .noGroups }

        var assignedIDs = Set<UUID>()
        for (index, group) in groups.enumerated() {
            guard group.dancerIDs.count >= 3 else { return .smallGroup(index + 1) }
            guard group.dancerIDs.isSubset(of: availableDancerIDs) else { return .missingDancer }
            guard assignedIDs.isDisjoint(with: group.dancerIDs) else { return .duplicateDancer }
            assignedIDs.formUnion(group.dancerIDs)
        }

        return nil
    }
}

enum ManualJamValidationError: Error, LocalizedError, Equatable {
    case futureDate
    case noGroups
    case smallGroup(Int)
    case missingDancer
    case duplicateDancer

    var errorDescription: String? {
        switch self {
        case .futureDate:
            "Choose a date and time in the past."
        case .noGroups:
            "Add at least one group."
        case let .smallGroup(index):
            "Group \(index) needs at least 3 dancers."
        case .missingDancer:
            "A selected dancer is no longer available. Please select the group members again."
        case .duplicateDancer:
            "Each dancer can belong to only one group in this jam."
        }
    }
}
