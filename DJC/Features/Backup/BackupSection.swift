import SwiftUI

struct BackupSection: View {
    let hasLocalData: Bool
    let canExportBackup: Bool
    let lastBackupDate: Date?
    let exportBackup: () -> Void
    let importBackup: () -> Void

    var body: some View {
        Section("Backup") {
            VStack(alignment: .leading, spacing: 6) {
                Text(backupStatusText)
                    .font(.subheadline)
                    .foregroundStyle(hasBackupReminder ? .orange : .secondary)

                if hasBackupReminder {
                    Text(reminderText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Button {
                exportBackup()
            } label: {
                Label("Export Backup CSV", systemImage: "square.and.arrow.up")
            }
            .disabled(!canExportBackup)

            Button {
                importBackup()
            } label: {
                Label("Restore from CSV", systemImage: "square.and.arrow.down")
            }

            DisclosureGroup("What is in the CSV?") {
                Text("History is stored on this device. CSV exports saved jams from all styles and their participants, not a full copy of the app.")
                Text("Each row is one dancer in one group of one jam. Jam IDs repeat across participants; dancer IDs identify the same person across jams. Dates are in UTC.")
                Text("Open as a UTF-8 table with comma separators. Keep the ID columns for import. Existing jam IDs are skipped, not replaced.")
                Text("Dancers without saved jams, archive status, attendance selections, and app settings are not included.")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    private var backupStatusText: String {
        guard hasLocalData else {
            return "No local data yet."
        }

        guard canExportBackup else {
            return "Save a jam before exporting a CSV backup."
        }

        guard let lastBackupDate else {
            return "No backup yet."
        }

        return "Last backup: \(lastBackupDate.formatted(date: .abbreviated, time: .shortened))"
    }

    private var hasBackupReminder: Bool {
        guard hasLocalData else { return false }
        guard let lastBackupDate else { return true }

        return Date().timeIntervalSince(lastBackupDate) > 7 * 24 * 60 * 60
    }

    private var reminderText: String {
        if canExportBackup {
            return "Export a CSV before reinstalling the app or moving to another phone."
        }

        return "CSV backups include saved jam history and dancers from those jams."
    }
}
