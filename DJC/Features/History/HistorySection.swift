import SwiftUI

struct HistorySection: View {
    @Binding var isExpanded: Bool

    let jams: [Jam]
    let exportCSV: () -> Void
    let importCSV: () -> Void
    let requestDeleteJam: (Jam) -> Void

    var body: some View {
        Section {
            DisclosureGroup("History (\(jams.count))", isExpanded: $isExpanded) {
                Button {
                    importCSV()
                } label: {
                    Label("Import CSV Backup", systemImage: "square.and.arrow.down")
                }

                if jams.isEmpty {
                    Text("Confirmed jams will appear here.")
                        .foregroundStyle(.secondary)
                } else {
                    Button {
                        exportCSV()
                    } label: {
                        Label("Export CSV File", systemImage: "square.and.arrow.up")
                    }

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
