import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Dancer.nickname) private var dancers: [Dancer]
    @Query(sort: \Jam.date, order: .reverse) private var jams: [Jam]

    @AppStorage("lastSuccessfulCSVBackupTimestamp") private var lastSuccessfulCSVBackupTimestamp = 0.0

    @State private var selectedStyle: DanceStyle = .popping
    @State private var newDancerName = ""
    @State private var presentDancerIDs = Set<UUID>()
    @State private var generatedGroups: [[DancerSnapshot]] = []
    @State private var errorMessage: String?
    @State private var importResultMessage: String?
    @State private var isArchivedDancersExpanded = false
    @State private var isHistoryExpanded = false
    @State private var isExportingCSV = false
    @State private var isImportingCSV = false
    @State private var isConfirmingBackupExport = false
    @State private var isConfirmingBackupImport = false
    @State private var isConfirmingJamSave = false
    @State private var jamPendingDeletion: Jam?
    @State private var csvDocument = JamCSVDocument()
    @State private var editingDancer: Dancer?
    @State private var editedDisplayName = ""
    @State private var editedNickname = ""
    @State private var editedFirstName = ""
    @State private var editedLastName = ""

    private let optimizer = JamOptimizer()

    private var activeDancers: [Dancer] {
        sortedDancers(dancers.filter { !$0.isArchived })
    }

    private var archivedDancers: [Dancer] {
        sortedDancers(dancers.filter { $0.isArchived })
    }

    private var hasLocalData: Bool {
        !dancers.isEmpty || !jams.isEmpty
    }

    private var canExportBackup: Bool {
        !jams.isEmpty
    }

    private var lastBackupDate: Date? {
        guard lastSuccessfulCSVBackupTimestamp > 0 else { return nil }
        return Date(timeIntervalSince1970: lastSuccessfulCSVBackupTimestamp)
    }

    private var csvText: String {
        JamCSVExporter().export(jams: jams)
    }

    private var csvFilename: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return "djc-jams-\(formatter.string(from: Date()))"
    }

    var body: some View {
        NavigationStack {
            List {
                styleSection

                BackupSection(
                    hasLocalData: hasLocalData,
                    canExportBackup: canExportBackup,
                    lastBackupDate: lastBackupDate,
                    exportBackup: { isConfirmingBackupExport = true },
                    importBackup: { isConfirmingBackupImport = true }
                )

                DancerListSection(
                    newDancerName: $newDancerName,
                    presentDancerIDs: $presentDancerIDs,
                    dancers: activeDancers,
                    addDancer: addDancer,
                    editDancer: startEditing,
                    archiveDancers: archiveDancers,
                    clearGeneratedGroups: clearGeneratedGroups
                )

                GeneratedGroupsSection(groups: generatedGroups)

                ArchivedDancersSection(
                    isExpanded: $isArchivedDancersExpanded,
                    dancers: archivedDancers,
                    restoreDancer: restoreDancer
                )

                HistorySection(
                    isExpanded: $isHistoryExpanded,
                    jams: jams,
                    requestDeleteJam: requestDeleteJam
                )
            }
            .navigationTitle("DJC")
            .safeAreaInset(edge: .bottom) {
                jamActionBar
            }
            .alert("Action Failed", isPresented: errorBinding) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "Unknown error")
            }
            .alert("Import Complete", isPresented: importResultBinding) {
                Button("OK", role: .cancel) { importResultMessage = nil }
            } message: {
                Text(importResultMessage ?? "")
            }
            .confirmationDialog(
                "Export backup CSV?",
                isPresented: $isConfirmingBackupExport,
                titleVisibility: .visible
            ) {
                Button("Export Backup") {
                    exportCSV()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Keep this CSV somewhere safe so you can restore DJC data after reinstalling the app or moving to another phone.")
            }
            .confirmationDialog(
                "Restore from CSV?",
                isPresented: $isConfirmingBackupImport,
                titleVisibility: .visible
            ) {
                Button("Import Backup") {
                    isImportingCSV = true
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Import can add jam history, restore dancers by ID, update existing dancer names, and unarchive matching dancers.")
            }
            .confirmationDialog(
                "Save this jam to history?",
                isPresented: $isConfirmingJamSave,
                titleVisibility: .visible
            ) {
                Button("Save Jam") {
                    confirmJam()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Saved jams affect future group generation for \(selectedStyle.title).")
            }
            .confirmationDialog(
                "Delete this saved jam?",
                isPresented: deleteJamConfirmationBinding,
                titleVisibility: .visible
            ) {
                Button("Delete Jam", role: .destructive) {
                    if let jam = jamPendingDeletion {
                        deleteJam(jam)
                    }
                }
                Button("Cancel", role: .cancel) {
                    jamPendingDeletion = nil
                }
            } message: {
                Text("This removes the jam from history and future optimizer calculations.")
            }
            .fileExporter(
                isPresented: $isExportingCSV,
                document: csvDocument,
                contentType: .commaSeparatedText,
                defaultFilename: csvFilename
            ) { result in
                switch result {
                case .success:
                    lastSuccessfulCSVBackupTimestamp = Date().timeIntervalSince1970
                case let .failure(error):
                    errorMessage = error.localizedDescription
                }
            }
            .fileImporter(
                isPresented: $isImportingCSV,
                allowedContentTypes: [.commaSeparatedText]
            ) { result in
                importCSV(from: result)
            }
            .sheet(item: $editingDancer) { dancer in
                DancerEditView(
                    dancer: dancer,
                    stats: DancerStatsCalculator().stats(for: dancer, jams: jams),
                    displayName: $editedDisplayName,
                    nickname: $editedNickname,
                    firstName: $editedFirstName,
                    lastName: $editedLastName,
                    cancel: { editingDancer = nil },
                    save: saveDancer,
                    delete: deleteDancer
                )
            }
        }
    }

    private var styleSection: some View {
        Section("Style") {
            Picker("Dance style", selection: $selectedStyle) {
                ForEach(DanceStyle.allCases) { style in
                    Text(style.title).tag(style)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private var jamActionBar: some View {
        HStack {
            Button(generatedGroups.isEmpty ? "Generate Groups" : "Regenerate", action: generateGroups)
                .buttonStyle(.borderedProminent)
                .disabled(presentDancerIDs.count < 3)

            Spacer()

            Button("Confirm Jam") {
                isConfirmingJamSave = true
            }
            .buttonStyle(.bordered)
            .disabled(generatedGroups.isEmpty)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.bar)
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    errorMessage = nil
                }
            }
        )
    }

    private var deleteJamConfirmationBinding: Binding<Bool> {
        Binding(
            get: { jamPendingDeletion != nil },
            set: { isPresented in
                if !isPresented {
                    jamPendingDeletion = nil
                }
            }
        )
    }

    private var importResultBinding: Binding<Bool> {
        Binding(
            get: { importResultMessage != nil },
            set: { isPresented in
                if !isPresented {
                    importResultMessage = nil
                }
            }
        )
    }

    private func sortedDancers(_ dancers: [Dancer]) -> [Dancer] {
        dancers.sorted { first, second in
            first.visibleName.localizedCaseInsensitiveCompare(second.visibleName) == .orderedAscending
        }
    }

    private func addDancer() {
        let trimmedName = newDancerName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        modelContext.insert(Dancer(name: trimmedName, nickname: trimmedName))
        newDancerName = ""
    }

    private func archiveDancers(offsets: IndexSet) {
        for index in offsets {
            activeDancers[index].isArchived = true
        }
    }

    private func startEditing(_ dancer: Dancer) {
        editedDisplayName = dancer.displayName
        editedNickname = dancer.nickname.isEmpty ? dancer.name : dancer.nickname
        editedFirstName = dancer.firstName
        editedLastName = dancer.lastName
        editingDancer = dancer
    }

    private func saveDancer(_ dancer: Dancer) {
        let trimmedDisplayName = editedDisplayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNickname = editedNickname.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedFirstName = editedFirstName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedLastName = editedLastName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedNickname.isEmpty else { return }

        dancer.displayName = trimmedDisplayName
        dancer.nickname = trimmedNickname
        dancer.firstName = trimmedFirstName
        dancer.lastName = trimmedLastName
        dancer.name = trimmedNickname
        refreshGeneratedGroupName(for: dancer)
        editingDancer = nil
    }

    private func refreshGeneratedGroupName(for dancer: Dancer) {
        generatedGroups = generatedGroups.map { group in
            group.map { snapshot in
                snapshot.id == dancer.id ? DancerSnapshot(id: dancer.id, name: dancer.visibleName) : snapshot
            }
        }
    }

    private func deleteDancer(_ dancer: Dancer) {
        dancer.isArchived = true
        presentDancerIDs.remove(dancer.id)
        clearGeneratedGroups()
        editingDancer = nil
    }

    private func restoreDancer(_ dancer: Dancer) {
        dancer.isArchived = false
    }

    private func clearGeneratedGroups() {
        generatedGroups = []
    }

    private func exportCSV() {
        csvDocument = JamCSVDocument(text: csvText)
        isExportingCSV = true
    }

    private func requestDeleteJam(_ jam: Jam) {
        jamPendingDeletion = jam
    }

    private func deleteJam(_ jam: Jam) {
        modelContext.delete(jam)
        jamPendingDeletion = nil
    }

    private func importCSV(from result: Result<URL, Error>) {
        do {
            let url = try result.get()
            let hasAccess = url.startAccessingSecurityScopedResource()
            defer {
                if hasAccess {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            let csv = try String(contentsOf: url, encoding: .utf8)
            let importedJams = try JamCSVImporter().importJams(from: csv)
            importJams(importedJams)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func importJams(_ importedJams: [ImportedJam]) {
        let existingJamIDs = Set(jams.map(\.id))
        var dancerByID = Dictionary(uniqueKeysWithValues: dancers.map { ($0.id, $0) })
        var importedCount = 0

        for importedJam in importedJams where !existingJamIDs.contains(importedJam.id) {
            let jamGroups = importedJam.groups.map { importedGroup in
                JamGroup(
                    index: importedGroup.index,
                    dancers: importedGroup.dancers.map { importedDancer in
                        dancer(for: importedDancer, dancerByID: &dancerByID)
                    }
                )
            }

            modelContext.insert(Jam(
                id: importedJam.id,
                style: importedJam.style,
                date: importedJam.date,
                groups: jamGroups
            ))
            importedCount += 1
        }

        isHistoryExpanded = true
        importResultMessage = importedCount == 0
            ? "No new jams were imported."
            : "Imported \(importedCount) jams."
    }

    private func dancer(for importedDancer: ImportedDancer, dancerByID: inout [UUID: Dancer]) -> Dancer {
        if let dancer = dancerByID[importedDancer.id] {
            update(dancer, from: importedDancer)
            return dancer
        }

        let nickname = importedDancer.nickname.isEmpty ? importedDancer.displayName : importedDancer.nickname
        let dancer = Dancer(
            id: importedDancer.id,
            name: nickname,
            displayName: importedDancer.displayName,
            nickname: nickname,
            firstName: importedDancer.firstName,
            lastName: importedDancer.lastName,
            isArchived: false
        )
        modelContext.insert(dancer)
        dancerByID[importedDancer.id] = dancer
        return dancer
    }

    private func update(_ dancer: Dancer, from importedDancer: ImportedDancer) {
        let nickname = importedDancer.nickname.isEmpty ? importedDancer.displayName : importedDancer.nickname

        dancer.displayName = importedDancer.displayName
        dancer.nickname = nickname
        dancer.firstName = importedDancer.firstName
        dancer.lastName = importedDancer.lastName
        dancer.name = nickname
        dancer.isArchived = false
    }

    private func generateGroups() {
        let presentDancers = activeDancers
            .filter { presentDancerIDs.contains($0.id) }
            .map { DancerSnapshot(id: $0.id, name: $0.visibleName) }

        let input = JamOptimizerInput(
            style: selectedStyle,
            presentDancers: presentDancers,
            previousJams: jamSnapshots(for: selectedStyle)
        )

        do {
            generatedGroups = try optimizer.generateGroups(for: input).groups
        } catch JamOptimizerError.notEnoughDancers {
            errorMessage = "At least 3 dancers are required."
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func confirmJam() {
        let dancerByID = Dictionary(uniqueKeysWithValues: activeDancers.map { ($0.id, $0) })
        var jamGroups: [JamGroup] = []

        for (index, group) in generatedGroups.enumerated() {
            let dancers = group.compactMap { dancerByID[$0.id] }
            guard dancers.count == group.count else {
                errorMessage = "Generated groups changed because a dancer is no longer active. Please regenerate groups before saving."
                clearGeneratedGroups()
                return
            }

            jamGroups.append(
                JamGroup(
                    index: index + 1,
                    dancers: dancers
                )
            )
        }

        let jam = Jam(style: selectedStyle, groups: jamGroups)

        modelContext.insert(jam)
        presentDancerIDs = []
        clearGeneratedGroups()
        isHistoryExpanded = true
    }

    private func jamSnapshots(for style: DanceStyle) -> [JamSnapshot] {
        jams
            .filter { $0.style == style }
            .map { jam in
                JamSnapshot(
                    id: jam.id,
                    style: jam.style,
                    date: jam.date,
                    groups: jam.groups.map { group in
                        group.dancers.map(\.id)
                    }
                )
            }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Dancer.self, Jam.self, JamGroup.self], inMemory: true)
}
