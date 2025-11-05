import Foundation
import SwiftUI

extension String {
    /// 获取本地化字符串
    var localized: String {
        // 首先尝试标准的 NSLocalizedString（这是 iOS 的标准方式）
        let localizedString = NSLocalizedString(self, bundle: .main, comment: "")
        
        // 如果返回的不是键本身，说明找到了翻译
        if localizedString != self {
            return localizedString
        }
        
        // 如果返回的是键本身，尝试手动从 Bundle 中加载
        // 获取当前语言代码
        let preferredLanguage = Locale.preferredLanguages.first ?? "en"
        
        // 确定使用哪个语言文件夹
        var lprojName = "Base"
        if preferredLanguage.contains("zh-Hans") || preferredLanguage.contains("zh_CN") {
            lprojName = "zh-Hans"
        } else if preferredLanguage.contains("ja") {
            lprojName = "ja"
        } else if preferredLanguage.contains("en") {
            lprojName = "en"
        }
        
        // 尝试多种路径加载本地化文件
        let possiblePaths = [
            // 标准路径：直接在 .lproj 文件夹中（iOS 标准位置）
            Bundle.main.path(forResource: "Localizable", ofType: "strings", inDirectory: "\(lprojName).lproj"),
            // 直接使用语言代码（不带 .lproj）
            Bundle.main.path(forResource: "Localizable", ofType: "strings", inDirectory: lprojName),
            // 在 Resources 子文件夹中（备用）
            Bundle.main.path(forResource: "Localizable", ofType: "strings", inDirectory: "Resources/\(lprojName).lproj"),
        ]
        
        // 尝试从对应的语言文件夹加载
        for path in possiblePaths.compactMap({ $0 }) {
            if let dict = NSDictionary(contentsOfFile: path),
               let value = dict[self] as? String,
               !value.isEmpty {
                return value
            }
        }
        
        // 如果还是找不到，尝试 Base.lproj 作为后备
        let basePaths = [
            Bundle.main.path(forResource: "Localizable", ofType: "strings", inDirectory: "Base.lproj"),
            Bundle.main.path(forResource: "Localizable", ofType: "strings", inDirectory: "Base"),
            Bundle.main.path(forResource: "Localizable", ofType: "strings", inDirectory: "Resources/Base.lproj"),
        ]
        
        for path in basePaths.compactMap({ $0 }) {
            if let dict = NSDictionary(contentsOfFile: path),
               let value = dict[self] as? String,
               !value.isEmpty {
                return value
            }
        }
        
        // 如果都找不到，返回键本身（这样至少能看到键名）
        return localizedString
    }
    
    /// 使用格式化的本地化字符串
    func localized(_ arguments: CVarArg...) -> String {
        let format = self.localized
        return String(format: format, arguments: arguments)
    }
}

/// 本地化字符串键
enum LocalizedStringKey {
    // Common
    static let commonOk = "common.ok"
    static let commonCancel = "common.cancel"
    static let commonError = "common.error"
    static let commonSuccess = "common.success"
    static let commonLoading = "common.loading"
    static let commonBack = "common.back"
    
    // Login
    static let loginTitle = "login.title"
    static let loginEmail = "login.email"
    static let loginPassword = "login.password"
    static let loginButton = "login.button"
    static let loginWelcomeBack = "login.welcome_back"
    static let loginEmailPlaceholder = "login.email_placeholder"
    static let loginPasswordPlaceholder = "login.password_placeholder"
    
    // Profile
    static let profileTitle = "profile.title"
    static let profileBasicInfo = "profile.basic_info"
    static let profileName = "profile.name"
    static let profileEmail = "profile.email"
    static let profileDefaultCompany = "profile.default_company"
    static let profileCompanyId = "profile.company_id"
    static let profileCompanyUsername = "profile.company_username"
    static let profileLanguage = "profile.language"
    static let profileNotLoggedIn = "profile.not_logged_in"
    static let profileClearCache = "profile.clear_cache"
    static let profileLogout = "profile.logout"
    static let profileAlertTitle = "profile.alert_title"
    static let profileCacheCleared = "profile.cache_cleared"
    static let profileDependencyNotInjected = "profile.dependency_not_injected"
    
    // Projects
    static let projectsTitle = "projects.title"
    static let projectsItems = "projects.items"
    static let projectsTemporaryMeeting = "projects.temporary_meeting"
    static let projectsSearchPlaceholder = "projects.search_placeholder"
    static let projectsEmptyTitle = "projects.empty_title"
    static let projectsSearchEmptyTitle = "projects.search_empty_title"
    static let projectsSearchEmptyMessage = "projects.search_empty_message"
    static let projectRoleOwner = "project_role.owner"
    static let projectRoleContributor = "project_role.contributor"
    static let projectRoleSharee = "project_role.sharee"
    
    // Recorder
    static let recorderBack = "recorder.back"
    static let recorderMeetingId = "recorder.meeting_id"
    static let recorderNoRecordings = "recorder.no_recordings"
    static let recorderStartRecordingHint = "recorder.start_recording_hint"
    static let recorderPreparing = "recorder.preparing"
    static let recorderRetryUpload = "recorder.retry_upload"
    static let recorderDelete = "recorder.delete"
    static let recorderUploadFailed = "recorder.upload_failed"
    static let recorderUploadProgress = "recorder.upload_progress"
    static let recorderProcessing = "recorder.processing"
    static let recorderUploading = "recorder.uploading"
    static let recorderDependencyNotInjected = "recorder.dependency_not_injected"
    static let recorderMeetingNotPrepared = "recorder.meeting_not_prepared"
    static let recorderMicrophonePermissionDenied = "recorder.microphone_permission_denied"
    static let recorderUnknownError = "recorder.unknown_error"
    
    // Upload Status
    static let uploadStatusPending = "upload_status.pending"
    static let uploadStatusUploading = "upload_status.uploading"
    static let uploadStatusCompleted = "upload_status.completed"
    static let uploadStatusFailed = "upload_status.failed"
    
    // Tab Bar
    static let tabProjects = "tab.projects"
    static let tabProfile = "tab.profile"
    
    // Waveform
    static let waveformAccessibilityLabel = "waveform.accessibility_label"
}

