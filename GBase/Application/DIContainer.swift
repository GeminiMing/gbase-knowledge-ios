import Foundation
import SwiftUI

public struct DIContainer {
    public let appState: AppState
    public let apiConfiguration: APIConfiguration

    public let loginUseCase: LoginUseCase
    public let refreshTokenUseCase: RefreshTokenUseCase
    public let fetchCurrentUserUseCase: FetchCurrentUserUseCase
    public let fetchProjectsUseCase: FetchProjectsUseCase
    public let fetchEditableProjectsUseCase: FetchEditableProjectsUseCase
    public let createMeetingUseCase: CreateMeetingUseCase
    public let fetchMyMeetingsUseCase: FetchMyMeetingsUseCase
    public let fetchProjectMeetingsUseCase: FetchProjectMeetingsUseCase
    public let fetchMeetingDetailUseCase: FetchMeetingDetailUseCase
    public let applyRecordingUploadUseCase: ApplyRecordingUploadUseCase
    public let finishRecordingUploadUseCase: FinishRecordingUploadUseCase

    // Draft-related use cases
    public let fetchDraftsUseCase: FetchDraftsUseCase
    public let bindDraftToProjectUseCase: BindDraftToProjectUseCase
    public let updateDraftNameUseCase: UpdateDraftNameUseCase
    public let deleteDraftUseCase: DeleteDraftUseCase

    public let audioRecorderService: AudioRecorderService
    public let audioPlayerService: AudioPlayerService
    public let fileStorageService: FileStorageService
    public let recordingUploadService: RecordingUploadServiceType
    public let recordingLocalStore: RecordingLocalStore
    public let tokenStore: TokenStore
    public let credentialsStore: UserCredentialsStoreType
    public let watchConnectivityService: WatchConnectivityService
    public let networkMonitor: NetworkMonitor
    public let companyManager: CompanyManager

    public init(appState: AppState,
                apiConfiguration: APIConfiguration,
                loginUseCase: LoginUseCase,
                refreshTokenUseCase: RefreshTokenUseCase,
                fetchCurrentUserUseCase: FetchCurrentUserUseCase,
                fetchProjectsUseCase: FetchProjectsUseCase,
                fetchEditableProjectsUseCase: FetchEditableProjectsUseCase,
                createMeetingUseCase: CreateMeetingUseCase,
                fetchMyMeetingsUseCase: FetchMyMeetingsUseCase,
                fetchProjectMeetingsUseCase: FetchProjectMeetingsUseCase,
                fetchMeetingDetailUseCase: FetchMeetingDetailUseCase,
                applyRecordingUploadUseCase: ApplyRecordingUploadUseCase,
                finishRecordingUploadUseCase: FinishRecordingUploadUseCase,
                fetchDraftsUseCase: FetchDraftsUseCase,
                bindDraftToProjectUseCase: BindDraftToProjectUseCase,
                updateDraftNameUseCase: UpdateDraftNameUseCase,
                deleteDraftUseCase: DeleteDraftUseCase,
                audioRecorderService: AudioRecorderService,
                audioPlayerService: AudioPlayerService,
                fileStorageService: FileStorageService,
                recordingUploadService: RecordingUploadServiceType,
                recordingLocalStore: RecordingLocalStore,
                tokenStore: TokenStore,
                credentialsStore: UserCredentialsStoreType,
                watchConnectivityService: WatchConnectivityService,
                networkMonitor: NetworkMonitor,
                companyManager: CompanyManager) {
        self.appState = appState
        self.apiConfiguration = apiConfiguration
        self.loginUseCase = loginUseCase
        self.refreshTokenUseCase = refreshTokenUseCase
        self.fetchCurrentUserUseCase = fetchCurrentUserUseCase
        self.fetchProjectsUseCase = fetchProjectsUseCase
        self.fetchEditableProjectsUseCase = fetchEditableProjectsUseCase
        self.createMeetingUseCase = createMeetingUseCase
        self.fetchMyMeetingsUseCase = fetchMyMeetingsUseCase
        self.fetchProjectMeetingsUseCase = fetchProjectMeetingsUseCase
        self.fetchMeetingDetailUseCase = fetchMeetingDetailUseCase
        self.applyRecordingUploadUseCase = applyRecordingUploadUseCase
        self.finishRecordingUploadUseCase = finishRecordingUploadUseCase
        self.fetchDraftsUseCase = fetchDraftsUseCase
        self.bindDraftToProjectUseCase = bindDraftToProjectUseCase
        self.updateDraftNameUseCase = updateDraftNameUseCase
        self.deleteDraftUseCase = deleteDraftUseCase
        self.audioRecorderService = audioRecorderService
        self.audioPlayerService = audioPlayerService
        self.fileStorageService = fileStorageService
        self.recordingUploadService = recordingUploadService
        self.recordingLocalStore = recordingLocalStore
        self.tokenStore = tokenStore
        self.credentialsStore = credentialsStore
        self.watchConnectivityService = watchConnectivityService
        self.networkMonitor = networkMonitor
        self.companyManager = companyManager
    }

    public static func bootstrap(environment: APIConfiguration.Environment = .production) -> DIContainer {
        let appState = AppState()
        let tokenStore = KeychainTokenStore()
        let config = APIConfiguration(environment: environment)
        let sessionConfiguration = config.sessionConfiguration
        sessionConfiguration.timeoutIntervalForRequest = 300
        sessionConfiguration.timeoutIntervalForResource = 300

        let urlSession = URLSession(configuration: sessionConfiguration)
        let tokenProvider: () async throws -> AuthSession? = {
            do {
                return try await tokenStore.currentSession()
            } catch {
                return nil
            }
        }

        let requestBuilder = RequestBuilder(config: config, tokenProvider: tokenProvider)
        let unauthorizedRelay = UnauthorizedRelay()

        let apiClient = APIClient(session: urlSession,
                                  builder: requestBuilder,
                                  interceptors: [NetworkLoggerInterceptor()],
                                  unauthorizedHandler: {
            try await unauthorizedRelay.perform()
        })

        let authRepository = RemoteAuthRepository(client: apiClient, authBaseURL: config.environment.authBaseURL)
        let projectRepository = RemoteProjectRepository(client: apiClient)
        let meetingRepository = RemoteMeetingRepository(client: apiClient)
        let recordingRepository = RemoteRecordingRepository(client: apiClient)

        let loginUseCase = DefaultLoginUseCase(repository: authRepository, tokenStore: tokenStore)
        let refreshUseCase = DefaultRefreshTokenUseCase(repository: authRepository, tokenStore: tokenStore)
        let fetchCurrentUserUseCase = DefaultFetchCurrentUserUseCase(repository: authRepository, tokenStore: tokenStore)
        let fetchProjectsUseCase = DefaultFetchProjectsUseCase(repository: projectRepository)
        let fetchEditableProjectsUseCase = DefaultFetchEditableProjectsUseCase(repository: projectRepository)
        let createMeetingUseCase = DefaultCreateMeetingUseCase(repository: meetingRepository)
        let fetchMyMeetingsUseCase = DefaultFetchMyMeetingsUseCase(repository: meetingRepository)
        let fetchProjectMeetingsUseCase = DefaultFetchProjectMeetingsUseCase(repository: meetingRepository)
        let fetchMeetingDetailUseCase = DefaultFetchMeetingDetailUseCase(repository: meetingRepository)
        let applyRecordingUploadUseCase = DefaultApplyRecordingUploadUseCase(repository: recordingRepository)
        let finishRecordingUploadUseCase = DefaultFinishRecordingUploadUseCase(repository: recordingRepository)

        unauthorizedRelay.register {
            guard let session = try? await tokenStore.currentSession() else {
                // No session available, force logout
                await MainActor.run {
                    appState.markUnauthenticated()
                }
                return
            }

            do {
                // Try to refresh token
                _ = try await refreshUseCase.execute(refreshToken: session.refreshToken)
            } catch {
                // Refresh failed (refresh token expired), force logout
                print("🔑 Refresh token failed: \(error.localizedDescription)")
                print("👉 Logging out user...")
                try? await tokenStore.removeSession()
                await MainActor.run {
                    appState.markUnauthenticated()
                }
                throw error
            }
        }

        let fileStorageService = FileStorageService()
        let recordingLocalStore = RealmRecordingLocalStore()

        // Draft-related use cases
        let fetchDraftsUseCase = DefaultFetchDraftsUseCase(localStore: recordingLocalStore)
        let bindDraftToProjectUseCase = DefaultBindDraftToProjectUseCase(localStore: recordingLocalStore)
        let updateDraftNameUseCase = DefaultUpdateDraftNameUseCase(localStore: recordingLocalStore)
        let deleteDraftUseCase = DefaultDeleteDraftUseCase(localStore: recordingLocalStore, fileStorage: fileStorageService)
        let audioRecorderService = AudioRecorderService()
        let audioPlayerService = AudioPlayerService()
        let recordingUploadService = RecordingUploadService(applyUseCase: applyRecordingUploadUseCase,
                                                            finishUseCase: finishRecordingUploadUseCase,
                                                            fileStorageService: fileStorageService,
                                                            config: config,
                                                            tokenProvider: tokenProvider)

        // Create CompanyManager on main actor
        let companyAPIService = CompanyAPIService(baseURL: config.environment.authBaseURL.absoluteString, tokenStore: tokenStore)
        let companyManager = CompanyManager(apiService: companyAPIService, tokenStore: tokenStore)

        // Create UserCredentialsStore
        let credentialsStore = UserCredentialsStore()

        // Create WatchConnectivityService - use shared instance to ensure single instance
        let watchConnectivityService = WatchConnectivityService.shared

        return DIContainer(appState: appState,
                           apiConfiguration: config,
                           loginUseCase: loginUseCase,
                           refreshTokenUseCase: refreshUseCase,
                           fetchCurrentUserUseCase: fetchCurrentUserUseCase,
                           fetchProjectsUseCase: fetchProjectsUseCase,
                           fetchEditableProjectsUseCase: fetchEditableProjectsUseCase,
                           createMeetingUseCase: createMeetingUseCase,
                           fetchMyMeetingsUseCase: fetchMyMeetingsUseCase,
                           fetchProjectMeetingsUseCase: fetchProjectMeetingsUseCase,
                           fetchMeetingDetailUseCase: fetchMeetingDetailUseCase,
                           applyRecordingUploadUseCase: applyRecordingUploadUseCase,
                           finishRecordingUploadUseCase: finishRecordingUploadUseCase,
                           fetchDraftsUseCase: fetchDraftsUseCase,
                           bindDraftToProjectUseCase: bindDraftToProjectUseCase,
                           updateDraftNameUseCase: updateDraftNameUseCase,
                           deleteDraftUseCase: deleteDraftUseCase,
                           audioRecorderService: audioRecorderService,
                           audioPlayerService: audioPlayerService,
                           fileStorageService: fileStorageService,
                           recordingUploadService: recordingUploadService,
                           recordingLocalStore: recordingLocalStore,
                           tokenStore: tokenStore,
                           credentialsStore: credentialsStore,
                           watchConnectivityService: watchConnectivityService,
                           networkMonitor: .shared,
                           companyManager: companyManager)
    }

#if DEBUG
    public static var preview: DIContainer {
        let appState = AppState()
        let tokenStore = InMemoryTokenStore()
        let credentialsStore = UserCredentialsStore()
        let mockUseCase = MockAuthUseCase()
        let config = APIConfiguration(environment: .development)
        let companyAPIService = CompanyAPIService(tokenStore: tokenStore)
        let companyManager = CompanyManager(apiService: companyAPIService, tokenStore: tokenStore)
        let fileStorageService = FileStorageService()
        let recordingLocalStore = MockRecordingLocalStore()
        let watchConnectivityService = WatchConnectivityService(
            recordingLocalStore: recordingLocalStore,
            fileStorageService: fileStorageService
        )

        return DIContainer(appState: appState,
                           apiConfiguration: config,
                           loginUseCase: mockUseCase,
                           refreshTokenUseCase: mockUseCase,
                           fetchCurrentUserUseCase: mockUseCase,
                           fetchProjectsUseCase: MockProjectsUseCase(),
                           fetchEditableProjectsUseCase: MockProjectsUseCase(),
                           createMeetingUseCase: MockMeetingsUseCase(),
                           fetchMyMeetingsUseCase: MockMeetingsUseCase(),
                           fetchProjectMeetingsUseCase: MockMeetingsUseCase(),
                           fetchMeetingDetailUseCase: MockMeetingsUseCase(),
                           applyRecordingUploadUseCase: MockRecordingUseCase(),
                           finishRecordingUploadUseCase: MockRecordingUseCase(),
                           fetchDraftsUseCase: MockDraftUseCases(localStore: recordingLocalStore),
                           bindDraftToProjectUseCase: MockDraftUseCases(localStore: recordingLocalStore),
                           updateDraftNameUseCase: MockDraftUseCases(localStore: recordingLocalStore),
                           deleteDraftUseCase: MockDraftUseCases(localStore: recordingLocalStore, fileStorage: fileStorageService),
                           audioRecorderService: AudioRecorderService(),
                           audioPlayerService: AudioPlayerService(),
                           fileStorageService: fileStorageService,
                           recordingUploadService: MockRecordingUploadService(),
                           recordingLocalStore: recordingLocalStore,
                           tokenStore: tokenStore,
                           credentialsStore: credentialsStore,
                           watchConnectivityService: watchConnectivityService,
                           networkMonitor: .shared,
                           companyManager: companyManager)
    }
#else
    // Release 模式下提供一个fallback（实际上 Preview 不会在 Release 模式下使用）
    public static var preview: DIContainer {
        return .bootstrap()
    }
#endif
}

private final class UnauthorizedRelay {
    private var action: (() async throws -> Void)?

    func register(_ action: @escaping () async throws -> Void) {
        self.action = action
    }

    func perform() async throws {
        try await action?()
    }
}

private struct DIContainerKey: EnvironmentKey {
#if DEBUG
    static var defaultValue: DIContainer = .preview
#else
    static var defaultValue: DIContainer = .bootstrap()
#endif
}

public extension EnvironmentValues {
    var diContainer: DIContainer {
        get { self[DIContainerKey.self] }
        set { self[DIContainerKey.self] = newValue }
    }
}

#if DEBUG
private final class InMemoryTokenStore: TokenStore {
    private var session: AuthSession?

    func save(session: AuthSession) async throws {
        self.session = session
    }

    func currentSession() async throws -> AuthSession {
        guard let session else { throw KeychainError.itemNotFound }
        return session
    }

    func removeSession() async throws {
        session = nil
    }
}

private final class MockAuthUseCase: LoginUseCase, RefreshTokenUseCase, FetchCurrentUserUseCase {
    func execute(email: String, password: String) async throws -> AuthContext {
        try await execute()
    }

    func execute(refreshToken: String) async throws -> AuthSession {
        AuthSession(accessToken: "", refreshToken: "", expiresAt: Date(), tokenType: "Bearer")
    }

    func execute() async throws -> AuthContext {
        AuthContext(session: AuthSession(accessToken: "", refreshToken: "", expiresAt: Date(), tokenType: "Bearer"),
                    user: User(id: "preview", name: "Preview", email: "preview@example.com", defaultCompanyId: "", language: "zh_hans", enabled: true, authorityCodes: []),
                    profile: UserProfile(id: "", lang: "zh_hans", enabled: true),
                    company: UserCompany(id: "", companyId: "", tenantId: nil, userName: "", enabled: true, activated: true),
                    authorityCodes: [],
                    hasPassword: true)
    }
}

private final class MockProjectsUseCase: FetchProjectsUseCase, FetchEditableProjectsUseCase {
    func execute(page: Int, pageSize: Int, searchType: String, title: String) async throws -> PagedProjects {
        PagedProjects(projects: [], countsBySearchType: [:], totalItems: 0)
    }

    func execute() async throws -> [String: String] {
        [:]
    }
}

private final class MockMeetingsUseCase: CreateMeetingUseCase, FetchMyMeetingsUseCase, FetchProjectMeetingsUseCase, FetchMeetingDetailUseCase {
    func execute(projectId: String, title: String, meetingTime: Date, location: String?, description: String?) async throws -> Meeting {
        Meeting(id: UUID().uuidString,
                projectId: projectId,
                title: title,
                description: description,
                meetingTime: meetingTime,
                location: location,
                duration: nil,
                status: .pending,
                hasRecording: false,
                hasTranscript: false,
                hasSummary: false,
                createdAt: Date(),
                updatedAt: Date())
    }

    func execute(page: Int, pageSize: Int, orderBys: [String], projectId: String?, titleLike: String?) async throws -> PagedMeetings {
        PagedMeetings(meetings: [], currentPage: page, pageSize: pageSize, totalPages: 1, totalItems: 0)
    }

    func execute(projectId: String, page: Int, pageSize: Int) async throws -> PagedMeetings {
        PagedMeetings(meetings: [], currentPage: page, pageSize: pageSize, totalPages: 1, totalItems: 0)
    }

    func execute(meetingId: String) async throws -> MeetingDetail {
        MeetingDetail(meeting: try await execute(projectId: "", title: "", meetingTime: Date(), location: nil, description: nil),
                      recordings: [],
                      participants: [])
    }
}

private final class MockRecordingUseCase: ApplyRecordingUploadUseCase, FinishRecordingUploadUseCase {
    func execute(meetingId: String, fileName: String, extension: String, contentHash: String, length: Int64, fileType: String, fromType: String, actualStartAt: Date, actualEndAt: Date) async throws -> UploadApplication {
        UploadApplication(id: 0, uploadUri: URL(string: "https://example.com")!, uuid: UUID().uuidString, contentType: "audio/mp4")
    }

    func execute(uploadId: Int, contentHash: String) async throws {}
}

private final class MockRecordingUploadService: RecordingUploadServiceType {
    func uploadRecording(meetingId: String, fileURL: URL, actualStartAt: Date, actualEndAt: Date, fileType: String, fromType: String, customName: String?, progressHandler: @escaping (Double) -> Void) async throws -> UploadApplication {
        progressHandler(100)
        return UploadApplication(id: 0, uploadUri: URL(string: "https://example.com")!, uuid: UUID().uuidString, contentType: "audio/mp4")
    }
}

private final class MockRecordingLocalStore: RecordingLocalStore {
    private var storage: [Recording] = []

    func upsert(_ recording: Recording) throws {
        storage.removeAll { $0.id == recording.id }
        storage.append(recording)
    }

    func fetch(projectId: String?, status: UploadStatus?) throws -> [Recording] {
        storage.filter { recording in
            let matchesProject = projectId.map { recording.projectId == $0 } ?? true
            let matchesStatus = status.map { recording.uploadStatus == $0 } ?? true
            return matchesProject && matchesStatus
        }
    }

    func fetchDrafts() throws -> [Recording] {
        storage.filter { $0.projectId == nil || $0.meetingId == nil }
    }

    func update(id: String, status: UploadStatus, progress: Double) throws {
        guard let index = storage.firstIndex(where: { $0.id == id }) else { return }
        let existing = storage[index]
        storage[index] = Recording(id: existing.id,
                                   meetingId: existing.meetingId,
                                   projectId: existing.projectId,
                                   fileName: existing.fileName,
                                   customName: existing.customName,
                                   localFilePath: existing.localFilePath,
                                   fileSize: existing.fileSize,
                                   duration: existing.duration,
                                   contentHash: existing.contentHash,
                                   uploadStatus: status,
                                   uploadProgress: progress,
                                   uploadId: existing.uploadId,
                                   createdAt: existing.createdAt,
                                   actualStartAt: existing.actualStartAt,
                                   actualEndAt: existing.actualEndAt)
    }

    func updateRecording(id: String, projectId: String?, meetingId: String?, customName: String?) throws {
        guard let index = storage.firstIndex(where: { $0.id == id }) else { return }
        let existing = storage[index]
        storage[index] = Recording(id: existing.id,
                                   meetingId: meetingId ?? existing.meetingId,
                                   projectId: projectId ?? existing.projectId,
                                   fileName: existing.fileName,
                                   customName: customName ?? existing.customName,
                                   localFilePath: existing.localFilePath,
                                   fileSize: existing.fileSize,
                                   duration: existing.duration,
                                   contentHash: existing.contentHash,
                                   uploadStatus: existing.uploadStatus,
                                   uploadProgress: existing.uploadProgress,
                                   uploadId: existing.uploadId,
                                   createdAt: existing.createdAt,
                                   actualStartAt: existing.actualStartAt,
                                   actualEndAt: existing.actualEndAt)
    }

    func remove(_ id: String) throws {
        storage.removeAll { $0.id == id }
    }
}

private final class MockDraftUseCases: FetchDraftsUseCase, BindDraftToProjectUseCase, UpdateDraftNameUseCase, DeleteDraftUseCase {
    private let localStore: RecordingLocalStore
    private let fileStorage: FileStorageService?

    init(localStore: RecordingLocalStore, fileStorage: FileStorageService? = nil) {
        self.localStore = localStore
        self.fileStorage = fileStorage
    }

    func execute() throws -> [Recording] {
        try localStore.fetchDrafts()
    }

    func execute(recordingId: String, projectId: String, meetingId: String, customName: String?) throws {
        try localStore.updateRecording(id: recordingId, projectId: projectId, meetingId: meetingId, customName: customName)
    }

    func execute(recordingId: String, customName: String) throws {
        try localStore.updateRecording(id: recordingId, projectId: nil, meetingId: nil, customName: customName)
    }

    func execute(recordingId: String) throws {
        try localStore.remove(recordingId)
    }
}
#endif

