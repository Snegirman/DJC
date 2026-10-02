import SwiftUI

struct GeneratedGroupsSection: View {
    @Binding var groups: [GeneratedJamGroup]

    var body: some View {
        Section {
            if groups.isEmpty {
                Text("Select at least 3 dancers and generate groups.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(groups.indices, id: \.self) { index in
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Group \(index + 1)")
                            .font(.headline)
                        Text(groups[index].dancers.map(\.name).joined(separator: ", "))
                            .foregroundStyle(.secondary)
                        Picker("Starts first", selection: $groups[index].startingDancerID) {
                            ForEach(groups[index].dancers) { dancer in
                                Text(dancer.name).tag(dancer.id)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                }
            }
        } header: {
            Text("Generated Groups")
        } footer: {
            if !groups.isEmpty {
                Text("The suggested starter has the fewest recorded starts in this style among their group. Tap their name to choose someone else before saving.")
            }
        }
    }
}
