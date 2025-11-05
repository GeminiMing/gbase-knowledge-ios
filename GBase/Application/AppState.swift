import Foundation
import Combine

@MainActor
public final class AppState: ObservableObject {
    public enum MainTab: Hashable {
        case projects
        case profile
    }

    public enum AuthState: Equatable {
        case loading
        case unauthenticated
        case authenticated(User)
    }

    @Published public private(set) var authState: AuthState = .loading
    @Published public private(set) var authContext: AuthContext?
    @Published public var selectedTab: MainTab = .projects
    @Published public var selectedProject: Project?

    private var cancellables = Set<AnyCancellable>()

    public init() {}

    public func update(authContext: AuthContext) {
        self.authContext = authContext
        authState = .authenticated(authContext.user)
    }

    public func markUnauthenticated() {
        authContext = nil
        authState = .unauthenticated
        selectedProject = nil
        selectedTab = .projects
    }

    public func markLoading() {
        authState = .loading
    }
}

