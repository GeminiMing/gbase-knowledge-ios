import Foundation
import RealmSwift

public enum RealmConfigurator {
    public static func configure() {
        var config = Realm.Configuration()
        config.schemaVersion = 1
        config.migrationBlock = { _, _ in }
        Realm.Configuration.defaultConfiguration = config
    }

    public static func realm() throws -> Realm {
        try Realm()
    }
}

