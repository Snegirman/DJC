import Foundation
import SwiftData

enum JamSchemaV2: VersionedSchema {
    static var versionIdentifier = Schema.Version(2, 0, 0)
    static var models: [any PersistentModel.Type] { [Dancer.self, Jam.self, JamGroup.self] }
}

enum JamMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [JamSchemaV1.self, JamSchemaV2.self] }

    static var stages: [MigrationStage] {
        // Changing relationship cardinality does not preserve links automatically.
        // Carry stable IDs across the schema change, never old model instances.
        var participantsByGroup: [UUID: [UUID]] = [:]
        return [.custom(
            fromVersion: JamSchemaV1.self,
            toVersion: JamSchemaV2.self,
            willMigrate: { context in
                for group in try context.fetch(FetchDescriptor<JamSchemaV1.JamGroup>()) {
                    participantsByGroup[group.id] = group.dancers.map(\.id)
                }
            },
            didMigrate: { context in
                let dancers = try context.fetch(FetchDescriptor<Dancer>())
                let dancerByID = Dictionary(uniqueKeysWithValues: dancers.map { ($0.id, $0) })
                for group in try context.fetch(FetchDescriptor<JamGroup>()) {
                    group.dancers = participantsByGroup[group.id, default: []].compactMap { dancerByID[$0] }
                }
                try context.save()
            }
        )]
    }
}
