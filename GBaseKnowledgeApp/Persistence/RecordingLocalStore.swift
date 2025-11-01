import Foundation
import RealmSwift

public protocol RecordingLocalStore {
    func upsert(_ recording: Recording) throws
    func fetch(projectId: String?, status: UploadStatus?) throws -> [Recording]
    func update(id: String, status: UploadStatus, progress: Double) throws
    func remove(_ id: String) throws
}

public final class RealmRecordingLocalStore: RecordingLocalStore {
    public init() {}

    public func upsert(_ recording: Recording) throws {
        let realm = try RealmConfigurator.realm()
        try realm.write {
            realm.add(LocalRecordingObject(recording: recording), update: .modified)
        }
    }

    public func fetch(projectId: String?, status: UploadStatus?) throws -> [Recording] {
        let realm = try RealmConfigurator.realm()
        var objects = realm.objects(LocalRecordingObject.self)

        if let projectId {
            objects = objects.where { $0.projectId == projectId }
        }

        if let status {
            objects = objects.where { $0.uploadStatusRaw == status.rawValue }
        }

        return objects.map { $0.toDomain() }
    }

    public func update(id: String, status: UploadStatus, progress: Double) throws {
        let realm = try RealmConfigurator.realm()
        guard let object = realm.object(ofType: LocalRecordingObject.self, forPrimaryKey: id) else { return }
        try realm.write {
            object.uploadStatus = status
            object.uploadProgress = progress
        }
    }

    public func remove(_ id: String) throws {
        let realm = try RealmConfigurator.realm()
        guard let object = realm.object(ofType: LocalRecordingObject.self, forPrimaryKey: id) else { return }
        try realm.write {
            realm.delete(object)
        }
    }
}

