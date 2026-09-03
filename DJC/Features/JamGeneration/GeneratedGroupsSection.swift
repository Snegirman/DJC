import SwiftUI

struct GeneratedGroupsSection: View {
    let groups: [[DancerSnapshot]]

    var body: some View {
        Section("Generated Groups") {
            if groups.isEmpty {
                Text("Select at least 3 dancers and generate groups.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(groups.enumerated()), id: \.offset) { index, group in
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Group \(index + 1)")
                            .font(.headline)
                        Text(group.map(\.name).joined(separator: ", "))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}
