import SwiftUI

struct JamHistoryRow: View {
    let jam: Jam

    private var dancerCount: Int {
        Set(jam.groups.flatMap { group in
            group.dancers.map(\.id)
        }).count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(jam.style.title)
                    .font(.headline)

                Spacer()

                Text(jam.date, format: .dateTime.day().month().year())
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Text("\(jam.groups.count) groups · \(dancerCount) dancers")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

struct JamHistoryDetailView: View {
    let jam: Jam

    private var sortedGroups: [JamGroup] {
        jam.groups.sorted { $0.index < $1.index }
    }

    var body: some View {
        List {
            Section("Jam") {
                LabeledContent("Style", value: jam.style.title)
                LabeledContent("Date") {
                    Text(jam.date, format: .dateTime.day().month().year().hour().minute())
                }
                LabeledContent("Groups", value: "\(jam.groups.count)")
            }

            Section("Groups") {
                ForEach(sortedGroups) { group in
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Group \(group.index)")
                            .font(.headline)

                        ForEach(sortedDancers(group.dancers)) { dancer in
                            HStack {
                                Text(dancer.visibleName)
                                    .foregroundStyle(.secondary)
                                if dancer.id == group.startingDancerID {
                                    Spacer()
                                    Label("Starts first", systemImage: "play.fill")
                                        .font(.caption)
                                        .foregroundStyle(.tint)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle("Jam History")
    }

    private func sortedDancers(_ dancers: [Dancer]) -> [Dancer] {
        dancers.sorted { first, second in
            first.visibleName.localizedCaseInsensitiveCompare(second.visibleName) == .orderedAscending
        }
    }
}

#Preview {
    let dancers = [
        Dancer(name: "alex", displayName: "Alex", nickname: "alex"),
        Dancer(name: "masha", displayName: "Masha", nickname: "masha"),
        Dancer(name: "ivan", displayName: "Ivan", nickname: "ivan")
    ]
    let group = JamGroup(index: 1, dancers: dancers)
    let jam = Jam(style: .popping, groups: [group])

    NavigationStack {
        JamHistoryDetailView(jam: jam)
    }
}
