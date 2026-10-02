import SwiftUI
import SwiftData

@main
struct DJCApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema(versionedSchema: JamSchemaV3.self)
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, migrationPlan: JamMigrationPlan.self, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
