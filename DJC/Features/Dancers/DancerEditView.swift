import SwiftUI

struct DancerEditView: View {
    let dancer: Dancer
    let stats: DancerStats

    @Binding var displayName: String
    @Binding var nickname: String
    @Binding var firstName: String
    @Binding var lastName: String

    @State private var isConfirmingDelete = false

    let cancel: () -> Void
    let save: (Dancer) -> Void
    let delete: (Dancer) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Dancer") {
                    TextField("Display name", text: $displayName)
                        .textInputAutocapitalization(.words)
                    TextField("Nickname", text: $nickname)
                        .textInputAutocapitalization(.words)
                    TextField("First name", text: $firstName)
                        .textInputAutocapitalization(.words)
                    TextField("Last name", text: $lastName)
                        .textInputAutocapitalization(.words)
                }

                Section("Stats") {
                    LabeledContent("Total jams", value: "\(stats.totalJamCount)")

                    if stats.attendanceByStyle.isEmpty {
                        Text("No saved jam history yet.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(stats.attendanceByStyle) { attendance in
                            LabeledContent(attendance.style.title, value: "\(attendance.jamCount)")
                        }
                    }
                }

                if !stats.frequentPartners.isEmpty {
                    Section("Frequent Partners") {
                        ForEach(stats.frequentPartners) { partner in
                            LabeledContent(partner.name, value: "\(partner.sharedJamCount)")
                        }
                    }
                }

                Section {
                    Button("Delete Dancer", role: .destructive) {
                        isConfirmingDelete = true
                    }
                }
            }
            .navigationTitle("Edit Dancer")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: cancel)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save(dancer)
                    }
                    .disabled(nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .confirmationDialog(
                "Delete this dancer?",
                isPresented: $isConfirmingDelete,
                titleVisibility: .visible
            ) {
                Button("Delete Dancer", role: .destructive) {
                    delete(dancer)
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("The dancer will be hidden from active classes, but saved jam history will remain available.")
            }
        }
    }
}
