import Foundation
import RealmSwift

public enum RealmConfigurator {
    public static func configure() {
        var config = Realm.Configuration()
        config.schemaVersion = 2  // Incremented version for new schema changes
        config.migrationBlock = { migration, oldSchemaVersion in
            if oldSchemaVersion < 2 {
                // Migration for version 2: added optional fields and customName
                migration.enumerateObjects(ofType: "LocalRecordingObject") { oldObject, newObject in
                    // meetingId and projectId are now optional - no action needed
                    // customName is a new field - default value is nil (already handled by Realm)
                }
            }
        }
        Realm.Configuration.defaultConfiguration = config
    }

    public static func realm() throws -> Realm {
        try Realm()
    }
}

