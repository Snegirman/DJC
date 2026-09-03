import Foundation

enum JamOptimizerError: Error, Equatable {
    case notEnoughDancers
}

struct JamOptimizer {
    struct Configuration: Equatable {
        var minimumGroupSize = 3
        var repeatedPairWeight = 10.0
        var attendanceFrequencyWeight = 20.0
        var recencyWeight = 6.0
        var repeatedWholeGroupWeight = 50.0
        var seededShuffleCandidateCount = 64
        var seededShuffleBaseSeed: UInt64 = 0xD1C0FFEE
    }

    private let configuration: Configuration

    init(configuration: Configuration = Configuration()) {
        self.configuration = configuration
    }

    func generateGroups(for input: JamOptimizerInput) throws -> JamOptimizerResult {
        guard input.presentDancers.count >= configuration.minimumGroupSize else {
            throw JamOptimizerError.notEnoughDancers
        }

        let groupSizes = calculateGroupSizes(dancerCount: input.presentDancers.count)
        let candidates = makeCandidates(from: input.presentDancers, groupSizes: groupSizes)
        let bestGroups = candidates.min { first, second in
            score(groups: first, for: input) < score(groups: second, for: input)
        } ?? []

        return JamOptimizerResult(groups: bestGroups)
    }

    func calculateGroupSizes(dancerCount: Int) -> [Int] {
        guard dancerCount >= configuration.minimumGroupSize else { return [] }

        var groupCount = dancerCount / configuration.minimumGroupSize
        while groupCount > 1 && dancerCount / groupCount < configuration.minimumGroupSize {
            groupCount -= 1
        }

        let baseSize = dancerCount / groupCount
        let remainder = dancerCount % groupCount

        return (0..<groupCount).map { index in
            index >= groupCount - remainder ? baseSize + 1 : baseSize
        }
    }

    func score(groups: [[DancerSnapshot]], for input: JamOptimizerInput) -> Double {
        let history = HistorySummary(jams: input.previousJams, style: input.style)
        var total = 0.0

        for group in groups {
            let currentGroupIDs = Set(group.map(\.id))
            if history.wholeGroups.contains(currentGroupIDs) {
                total += configuration.repeatedWholeGroupWeight
            }

            for pair in pairs(from: group.map(\.id)) {
                guard let pairHistory = history.pairs[pair] else { continue }

                let lowerAttendance = min(
                    history.attendanceCounts[pair.first, default: 0],
                    history.attendanceCounts[pair.second, default: 0]
                )
                let frequency = lowerAttendance > 0 ? Double(pairHistory.count) / Double(lowerAttendance) : 0

                total += Double(pairHistory.count) * configuration.repeatedPairWeight
                total += frequency * configuration.attendanceFrequencyWeight
                total += pairHistory.recencyScore * configuration.recencyWeight
            }
        }

        return total
    }

    private func makeCandidates(from dancers: [DancerSnapshot], groupSizes: [Int]) -> [[[DancerSnapshot]]] {
        let sortedDancers = dancers.sorted { first, second in
            if first.name != second.name {
                return first.name.localizedCaseInsensitiveCompare(second.name) == .orderedAscending
            }
            return first.id.uuidString < second.id.uuidString
        }

        var candidates: [[[DancerSnapshot]]] = []
        var seen = Set<String>()

        func appendCandidate(_ groups: [[DancerSnapshot]]) {
            let key = groups
                .map { group in group.map(\.id.uuidString).joined(separator: "-") }
                .joined(separator: "|")
            if seen.insert(key).inserted {
                candidates.append(groups)
            }
        }

        for offset in sortedDancers.indices {
            let rotated = Array(sortedDancers[offset...]) + Array(sortedDancers[..<offset])
            appendCandidate(partitionSequentially(rotated, groupSizes: groupSizes))
            appendCandidate(partitionRoundRobin(rotated, groupSizes: groupSizes))
        }

        appendCandidate(partitionSequentially(Array(sortedDancers.reversed()), groupSizes: groupSizes))
        appendCandidate(partitionRoundRobin(Array(sortedDancers.reversed()), groupSizes: groupSizes))

        for seedOffset in 0..<configuration.seededShuffleCandidateCount {
            let shuffled = deterministicallyShuffled(
                sortedDancers,
                seed: configuration.seededShuffleBaseSeed &+ UInt64(seedOffset)
            )
            appendCandidate(partitionSequentially(shuffled, groupSizes: groupSizes))
            appendCandidate(partitionRoundRobin(shuffled, groupSizes: groupSizes))
        }

        return candidates
    }

    private func deterministicallyShuffled(_ dancers: [DancerSnapshot], seed: UInt64) -> [DancerSnapshot] {
        guard dancers.count > 1 else { return dancers }

        var shuffled = dancers
        var generator = SeededNumberGenerator(seed: seed)

        for index in stride(from: shuffled.count - 1, through: 1, by: -1) {
            let randomIndex = Int(generator.next(upperBound: UInt64(index + 1)))
            shuffled.swapAt(index, randomIndex)
        }

        return shuffled
    }

    private func partitionSequentially(_ dancers: [DancerSnapshot], groupSizes: [Int]) -> [[DancerSnapshot]] {
        var remainingDancers = dancers

        return groupSizes.map { size in
            let group = Array(remainingDancers.prefix(size))
            remainingDancers.removeFirst(size)
            return group
        }
    }

    private func partitionRoundRobin(_ dancers: [DancerSnapshot], groupSizes: [Int]) -> [[DancerSnapshot]] {
        var groups = groupSizes.map { _ in [DancerSnapshot]() }
        var groupIndex = 0

        for dancer in dancers {
            while groups[groupIndex].count == groupSizes[groupIndex] {
                groupIndex = (groupIndex + 1) % groups.count
            }

            groups[groupIndex].append(dancer)
            groupIndex = (groupIndex + 1) % groups.count
        }

        return groups
    }

    private func pairs(from dancerIDs: [UUID]) -> [DancerPair] {
        guard dancerIDs.count >= 2 else { return [] }

        var result: [DancerPair] = []
        for firstIndex in 0..<(dancerIDs.count - 1) {
            for secondIndex in (firstIndex + 1)..<dancerIDs.count {
                result.append(DancerPair(dancerIDs[firstIndex], dancerIDs[secondIndex]))
            }
        }
        return result
    }
}

private struct HistorySummary {
    var attendanceCounts: [UUID: Int] = [:]
    var pairs: [DancerPair: PairHistory] = [:]
    var wholeGroups = Set<Set<UUID>>()

    init(jams: [JamSnapshot], style: DanceStyle) {
        let matchingJams = jams
            .filter { $0.style == style }
            .sorted { $0.date > $1.date }

        for (jamIndex, jam) in matchingJams.enumerated() {
            let recencyScore = 1.0 / Double(jamIndex + 1)
            let attendingIDs = Set(jam.groups.flatMap { $0 })

            for dancerID in attendingIDs {
                attendanceCounts[dancerID, default: 0] += 1
            }

            for group in jam.groups {
                let groupIDs = Set(group)
                wholeGroups.insert(groupIDs)

                for pair in makePairs(from: group) {
                    var pairHistory = pairs[pair, default: PairHistory()]
                    pairHistory.count += 1
                    pairHistory.recencyScore = max(pairHistory.recencyScore, recencyScore)
                    pairs[pair] = pairHistory
                }
            }
        }
    }

    private func makePairs(from dancerIDs: [UUID]) -> [DancerPair] {
        guard dancerIDs.count >= 2 else { return [] }

        var result: [DancerPair] = []
        for firstIndex in 0..<(dancerIDs.count - 1) {
            for secondIndex in (firstIndex + 1)..<dancerIDs.count {
                result.append(DancerPair(dancerIDs[firstIndex], dancerIDs[secondIndex]))
            }
        }
        return result
    }
}

private struct PairHistory {
    var count = 0
    var recencyScore = 0.0
}

private struct SeededNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed == 0 ? 0x9E3779B97F4A7C15 : seed
    }

    mutating func next(upperBound: UInt64) -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state % upperBound
    }
}

private struct DancerPair: Hashable {
    let first: UUID
    let second: UUID

    init(_ first: UUID, _ second: UUID) {
        if first.uuidString < second.uuidString {
            self.first = first
            self.second = second
        } else {
            self.first = second
            self.second = first
        }
    }
}
