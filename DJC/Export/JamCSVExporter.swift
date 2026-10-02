import Foundation

struct JamCSVExporter {
    func export(jams: [Jam]) -> String {
        var rows = ["jam_id,date,style,group_index,dancer_id,dancer_display_name,dancer_nickname,dancer_first_name,dancer_last_name,starts_first"]
        let formatter = ISO8601DateFormatter()

        for jam in jams.sorted(by: { $0.date < $1.date }) {
            for group in jam.groups.sorted(by: { $0.index < $1.index }) {
                for dancer in group.dancers.sorted(by: { $0.visibleName.localizedCaseInsensitiveCompare($1.visibleName) == .orderedAscending }) {
                    rows.append([
                        jam.id.uuidString,
                        formatter.string(from: jam.date),
                        jam.style.rawValue,
                        String(group.index),
                        dancer.id.uuidString,
                        escape(dancer.visibleName),
                        escape(dancer.nickname),
                        escape(dancer.firstName),
                        escape(dancer.lastName),
                        String(group.startingDancerID == dancer.id)
                    ].joined(separator: ","))
                }
            }
        }

        return rows.joined(separator: "\n")
    }

    private func escape(_ value: String) -> String {
        let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
        if escaped.contains(",") || escaped.contains("\n") || escaped.contains("\"") {
            return "\"\(escaped)\""
        }
        return escaped
    }
}
