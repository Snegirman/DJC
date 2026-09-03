import SwiftUI

struct ArchivedDancersSection: View {
    @Binding var isExpanded: Bool

    let dancers: [Dancer]
    let restoreDancer: (Dancer) -> Void

    var body: some View {
        if !dancers.isEmpty {
            Section {
                DisclosureGroup("Archived Dancers (\(dancers.count))", isExpanded: $isExpanded) {
                    ForEach(dancers) { dancer in
                        HStack {
                            Text(dancer.visibleName)

                            Spacer()

                            Button("Restore") {
                                restoreDancer(dancer)
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                }
            }
        }
    }
}
