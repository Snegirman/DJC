import SwiftData

struct ManualJamRecorder {
    func save(_ draft: ManualJamDraft, dancers: [Dancer], in context: ModelContext) throws {
        if let error = draft.validationError(availableDancerIDs: Set(dancers.map(\.id))) {
            throw error
        }

        let groups = draft.groups.enumerated().map { index, group in
            JamGroup(index: index + 1, dancers: dancers.filter { group.dancerIDs.contains($0.id) })
        }
        let jam = Jam(style: draft.style, date: draft.date, groups: groups)
        context.insert(jam)

        do {
            try context.save()
        } catch {
            // Remove only this failed insertion, preserving unrelated pending edits.
            for group in groups { context.delete(group) }
            context.delete(jam)
            throw error
        }
    }
}
