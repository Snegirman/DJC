import SwiftUI

struct ManualJamView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft: ManualJamDraft
    @State private var errorMessage: String?

    let dancers: [Dancer]
    let save: (ManualJamDraft) throws -> Void

    init(style: DanceStyle, dancers: [Dancer], save: @escaping (ManualJamDraft) throws -> Void) {
        _draft = State(initialValue: ManualJamDraft(style: style))
        self.dancers = dancers
        self.save = save
    }

    private var validationError: ManualJamValidationError? {
        draft.validationError(availableDancerIDs: Set(dancers.map(\.id)))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Style", selection: $draft.style) {
                        ForEach(DanceStyle.allCases) { style in
                            Text(style.title).tag(style)
                        }
                    }
                    DatePicker("Date and time", selection: $draft.date, in: ...Date())
                } header: {
                    Text("Jam")
                } footer: {
                    Text("Record the groups that actually danced together. This jam will affect future group generation for \(draft.style.title).")
                }

                Section {
                    ForEach($draft.groups) { $group in
                        NavigationLink {
                            ManualJamDancerPicker(
                                selectedIDs: $group.dancerIDs,
                                dancers: dancers,
                                unavailableIDs: Set(draft.groups.filter { $0.id != group.id }.flatMap(\.dancerIDs)),
                                title: groupTitle(group)
                            )
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(groupTitle(group)) · \(group.dancerIDs.count) dancers")
                                Text(memberNames(group))
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .onDelete { offsets in
                        draft.groups.remove(atOffsets: offsets)
                    }

                    Button("Add Group", systemImage: "plus") {
                        draft.groups.append(ManualJamDraft.Group())
                    }
                } header: {
                    Text("Groups")
                } footer: {
                    Text("Select at least 3 dancers per group. Swipe left to remove a group. Add missing dancers on the main screen before recording the jam.")
                }

                if let validationError {
                    Section {
                        Text(validationError.localizedDescription)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Add Past Jam")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveJam() }
                        .disabled(validationError != nil)
                }
            }
            .alert("Could Not Save Jam", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "Unknown error")
            }
        }
    }

    private func groupTitle(_ group: ManualJamDraft.Group) -> String {
        "Group \((draft.groups.firstIndex { $0.id == group.id } ?? 0) + 1)"
    }

    private func memberNames(_ group: ManualJamDraft.Group) -> String {
        let names = dancers.filter { group.dancerIDs.contains($0.id) }.map(\.visibleName)
        return names.isEmpty ? "Select dancers" : names.joined(separator: ", ")
    }

    private func saveJam() {
        do {
            try save(draft)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct ManualJamDancerPicker: View {
    @Binding var selectedIDs: Set<UUID>
    let dancers: [Dancer]
    let unavailableIDs: Set<UUID>
    let title: String

    var body: some View {
        List {
            Section {
                Text("Selected: \(selectedIDs.count) · minimum 3")
                    .foregroundStyle(.secondary)
            }
            Section("Dancers") {
                ForEach(dancers.filter { !$0.isArchived }) { dancer in
                    dancerToggle(dancer)
                }
            }
            if dancers.contains(where: \.isArchived) {
                Section {
                    ForEach(dancers.filter(\.isArchived)) { dancer in
                        dancerToggle(dancer)
                    }
                } header: {
                    Text("Archived Dancers")
                } footer: {
                    Text("Selecting an archived dancer keeps them archived.")
                }
            }
        }
        .navigationTitle(title)
    }

    private func dancerToggle(_ dancer: Dancer) -> some View {
        Toggle(isOn: Binding(
            get: { selectedIDs.contains(dancer.id) },
            set: { isSelected in
                if isSelected {
                    selectedIDs.insert(dancer.id)
                } else {
                    selectedIDs.remove(dancer.id)
                }
            }
        )) {
            VStack(alignment: .leading, spacing: 4) {
                Text(dancer.visibleName)
                if unavailableIDs.contains(dancer.id) {
                    Text("Already in another group")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .disabled(unavailableIDs.contains(dancer.id))
    }
}
