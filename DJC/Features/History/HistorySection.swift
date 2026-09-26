import SwiftUI

struct HistorySection: View {
    @Binding var isExpanded: Bool

    let jams: [Jam]
    let addPastJam: () -> Void
    let requestDeleteJam: (Jam) -> Void

    var body: some View {
        Section {
            Button("Add Past Jam", systemImage: "calendar.badge.plus", action: addPastJam)

            DisclosureGroup("History (\(jams.count))", isExpanded: $isExpanded) {
                if jams.isEmpty {
                    Text("Confirmed jams will appear here.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(jams) { jam in
                        NavigationLink {
                            JamHistoryDetailView(jam: jam)
                        } label: {
                            JamHistoryRow(jam: jam)
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                requestDeleteJam(jam)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
    }
}
