import Foundation

struct DancerStats {
    struct StyleAttendance: Identifiable, nonisolated Equatable {
        let style: DanceStyle
        let jamCount: Int

        var id: DanceStyle { style }
    }

    struct FrequentPartner: Identifiable, nonisolated Equatable {
        let dancerID: UUID
        let name: String
        let sharedJamCount: Int

        var id: UUID { dancerID }
    }

    let totalJamCount: Int
    let attendanceByStyle: [StyleAttendance]
    let frequentPartners: [FrequentPartner]

    static let empty = DancerStats(
        totalJamCount: 0,
        attendanceByStyle: [],
        frequentPartners: []
    )
}

struct DancerStatsCalculator {
    func stats(for dancer: Dancer, jams: [Jam]) -> DancerStats {
        var totalJamIDs = Set<UUID>()
        var jamIDsByStyle: [DanceStyle: Set<UUID>] = [:]
        var sharedJamIDsByPartner: [UUID: Set<UUID>] = [:]
        var partnerNameByID: [UUID: String] = [:]

        for jam in jams {
            let groupsWithDancer = jam.groups.filter { group in
                group.dancers.contains { $0.id == dancer.id }
            }

            guard !groupsWithDancer.isEmpty else { continue }

            totalJamIDs.insert(jam.id)
            jamIDsByStyle[jam.style, default: []].insert(jam.id)

            for group in groupsWithDancer {
                for partner in group.dancers where partner.id != dancer.id {
                    sharedJamIDsByPartner[partner.id, default: []].insert(jam.id)
                    partnerNameByID[partner.id] = partner.visibleName
                }
            }
        }

        let attendanceByStyle = DanceStyle.allCases.compactMap { style -> DancerStats.StyleAttendance? in
            let jamCount = jamIDsByStyle[style, default: []].count
            guard jamCount > 0 else { return nil }
            return DancerStats.StyleAttendance(style: style, jamCount: jamCount)
        }

        let frequentPartners = sharedJamIDsByPartner.map { partnerID, jamIDs in
            DancerStats.FrequentPartner(
                dancerID: partnerID,
                name: partnerNameByID[partnerID, default: "Unknown"],
                sharedJamCount: jamIDs.count
            )
        }
        .sorted { first, second in
            if first.sharedJamCount != second.sharedJamCount {
                return first.sharedJamCount > second.sharedJamCount
            }
            return first.name.localizedCaseInsensitiveCompare(second.name) == .orderedAscending
        }

        return DancerStats(
            totalJamCount: totalJamIDs.count,
            attendanceByStyle: attendanceByStyle,
            frequentPartners: Array(frequentPartners.prefix(5))
        )
    }
}
