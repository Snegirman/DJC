import Foundation

struct ImportedJam {
    let id: UUID
    let date: Date
    let style: DanceStyle
    let groups: [ImportedJamGroup]
}

struct ImportedJamGroup {
    let index: Int
    let dancers: [ImportedDancer]
}

struct ImportedDancer {
    let id: UUID
    let displayName: String
    let nickname: String
    let firstName: String
    let lastName: String
}

enum JamCSVImportError: Error, LocalizedError, Equatable {
    case missingHeader
    case invalidHeader
    case invalidRow(Int)
    case invalidJamID(Int)
    case invalidDate(Int)
    case invalidStyle(Int)
    case inconsistentJamDate(Int)
    case inconsistentJamStyle(Int)
    case invalidGroupIndex(Int)
    case invalidDancerID(Int)

    var errorDescription: String? {
        switch self {
        case .missingHeader:
            "CSV file is empty."
        case .invalidHeader:
            "CSV header does not match the DJC export format."
        case let .invalidRow(line):
            "CSV row \(line) has an invalid number of columns."
        case let .invalidJamID(line):
            "CSV row \(line) has an invalid jam ID."
        case let .invalidDate(line):
            "CSV row \(line) has an invalid date."
        case let .invalidStyle(line):
            "CSV row \(line) has an invalid dance style."
        case let .inconsistentJamDate(line):
            "CSV row \(line) has a date that conflicts with another row for the same jam."
        case let .inconsistentJamStyle(line):
            "CSV row \(line) has a dance style that conflicts with another row for the same jam."
        case let .invalidGroupIndex(line):
            "CSV row \(line) has an invalid group index."
        case let .invalidDancerID(line):
            "CSV row \(line) has an invalid dancer ID."
        }
    }
}

struct JamCSVImporter {
    private let expectedHeader = [
        "jam_id",
        "date",
        "style",
        "group_index",
        "dancer_id",
        "dancer_display_name",
        "dancer_nickname",
        "dancer_first_name",
        "dancer_last_name"
    ]

    func importJams(from csv: String) throws -> [ImportedJam] {
        let records = parseRecords(from: csv)
        guard let header = records.first else {
            throw JamCSVImportError.missingHeader
        }
        guard header == expectedHeader else {
            throw JamCSVImportError.invalidHeader
        }

        var builders: [UUID: JamBuilder] = [:]
        var order: [UUID] = []

        for (recordIndex, columns) in records.dropFirst().enumerated() {
            let line = recordIndex + 2
            guard columns.count == expectedHeader.count else {
                throw JamCSVImportError.invalidRow(line)
            }

            guard let jamID = UUID(uuidString: columns[0]) else {
                throw JamCSVImportError.invalidJamID(line)
            }
            guard let date = ISO8601DateFormatter().date(from: columns[1]) else {
                throw JamCSVImportError.invalidDate(line)
            }
            guard let style = DanceStyle(rawValue: columns[2]) else {
                throw JamCSVImportError.invalidStyle(line)
            }
            guard let groupIndex = Int(columns[3]), groupIndex > 0 else {
                throw JamCSVImportError.invalidGroupIndex(line)
            }
            guard let dancerID = UUID(uuidString: columns[4]) else {
                throw JamCSVImportError.invalidDancerID(line)
            }

            let dancer = ImportedDancer(
                id: dancerID,
                displayName: columns[5],
                nickname: columns[6],
                firstName: columns[7],
                lastName: columns[8]
            )

            if builders[jamID] == nil {
                builders[jamID] = JamBuilder(id: jamID, date: date, style: style)
                order.append(jamID)
            } else if builders[jamID]?.date != date {
                throw JamCSVImportError.inconsistentJamDate(line)
            } else if builders[jamID]?.style != style {
                throw JamCSVImportError.inconsistentJamStyle(line)
            }
            builders[jamID]?.groups[groupIndex, default: []].append(dancer)
        }

        return order.compactMap { builders[$0]?.build() }
    }

    private func parseRecords(from csv: String) -> [[String]] {
        var records: [[String]] = []
        var currentRecord: [String] = []
        var currentField = ""
        var isInsideQuotes = false
        var index = csv.startIndex

        while index < csv.endIndex {
            let character = csv[index]

            if character == "\"" {
                let nextIndex = csv.index(after: index)
                if isInsideQuotes && nextIndex < csv.endIndex && csv[nextIndex] == "\"" {
                    currentField.append("\"")
                    index = nextIndex
                } else {
                    isInsideQuotes.toggle()
                }
            } else if character == "," && !isInsideQuotes {
                currentRecord.append(currentField)
                currentField = ""
            } else if character == "\n" && !isInsideQuotes {
                currentRecord.append(currentField)
                records.append(currentRecord)
                currentRecord = []
                currentField = ""
            } else if character != "\r" {
                currentField.append(character)
            }

            index = csv.index(after: index)
        }

        if !currentField.isEmpty || !currentRecord.isEmpty {
            currentRecord.append(currentField)
            records.append(currentRecord)
        }

        return records
    }
}

private struct JamBuilder {
    let id: UUID
    let date: Date
    let style: DanceStyle
    var groups: [Int: [ImportedDancer]] = [:]

    func build() -> ImportedJam {
        let importedGroups = groups.keys.sorted().map { index in
            ImportedJamGroup(index: index, dancers: groups[index, default: []])
        }
        return ImportedJam(id: id, date: date, style: style, groups: importedGroups)
    }
}
