import SwiftUI

struct DancerListSection: View {
    @Binding var newDancerName: String
    @Binding var presentDancerIDs: Set<UUID>

    let dancers: [Dancer]
    let addDancer: () -> Void
    let editDancer: (Dancer) -> Void
    let archiveDancers: (IndexSet) -> Void
    let clearGeneratedGroups: () -> Void

    var body: some View {
        Section("Dancers") {
            HStack {
                TextField("New dancer", text: $newDancerName)
                    .textInputAutocapitalization(.words)

                Button(action: addDancer) {
                    Image(systemName: "plus.circle.fill")
                }
                .disabled(newDancerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            ForEach(dancers) { dancer in
                HStack {
                    HStack(spacing: 8) {
                        Text(dancer.visibleName)

                        Button {
                            editDancer(dancer)
                        } label: {
                            Image(systemName: "pencil")
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel("Edit \(dancer.visibleName)")
                    }

                    Spacer()

                    Toggle("Present", isOn: binding(for: dancer.id))
                        .labelsHidden()
                }
            }
            .onDelete(perform: archiveDancers)
        }
    }

    private func binding(for dancerID: UUID) -> Binding<Bool> {
        Binding(
            get: { presentDancerIDs.contains(dancerID) },
            set: { isPresent in
                if isPresent {
                    presentDancerIDs.insert(dancerID)
                } else {
                    presentDancerIDs.remove(dancerID)
                }
                clearGeneratedGroups()
            }
        )
    }
}
