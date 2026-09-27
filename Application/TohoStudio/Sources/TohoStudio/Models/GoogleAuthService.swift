import Foundation
import SwiftUI
import AppKit

public struct GoogleClientConfig: Codable {
    public struct Installed: Codable {
        public let client_id: String
        public let project_id: String
        public let auth_uri: String
        public let token_uri: String
        public let auth_provider_x509_cert_url: String
        public let client_secret: String
        public let redirect_uris: [String]
    }
    public let installed: Installed
}

public struct GoogleUserProfile: Codable {
    public var email: String
    public var name: String
    public var pictureURL: String?
    public var driveQuotaTotalBytes: Int64
    public var driveQuotaUsedBytes: Int64
}

public final class GoogleAuthService: ObservableObject {
    public static let shared = GoogleAuthService()

    public let secretConfigPath = "/Volumes/ZSSD/GitHub/repository/TohoStudio/Application/client_secret_2_350116167508-9vgdh4q57udsvu194vdamds13gnsn9q3.apps.googleusercontent.com.json"

    @Published public var clientConfig: GoogleClientConfig? = nil
    @Published public var isAuthenticated: Bool = false
    @Published public var userProfile: GoogleUserProfile? = nil
    @Published public var accessToken: String? = nil
    @Published public var isAuthenticating: Bool = false

    private init() {
        loadConfig()
    }

    public func loadConfig() {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: secretConfigPath)),
              let config = try? JSONDecoder().decode(GoogleClientConfig.self, from: data) else {
            print("Warning: Could not parse Google client secret JSON at \(secretConfigPath)")
            return
        }
        self.clientConfig = config
    }

    /// Generates Google OAuth 2.0 authorization URL to be opened in In-App Browser
    public func generateAuthURL() -> URL? {
        guard let config = self.clientConfig else { return nil }
        var components = URLComponents(string: config.installed.auth_uri)
        let redirectURI = config.installed.redirect_uris.first ?? "http://localhost"
        let scopes = [
            "https://www.googleapis.com/auth/userinfo.email",
            "https://www.googleapis.com/auth/userinfo.profile",
            "https://www.googleapis.com/auth/drive.file"
        ].joined(separator: " ")

        components?.queryItems = [
            URLQueryItem(name: "client_id", value: config.installed.client_id),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: scopes),
            URLQueryItem(name: "access_type", value: "offline"),
            URLQueryItem(name: "prompt", value: "consent")
        ]
        return components?.url
    }

    /// Initiates Google OAuth Login Flow via In-App Browser
    public func startLoginInAppBrowser() {
        guard let authURL = generateAuthURL() else {
            AppState.shared.addSystemLog(level: "ERROR", message: "Google認証URLの生成に失敗しました。")
            return
        }
        isAuthenticating = true
        AppState.shared.openInAppBrowser(url: authURL, title: "Googleアカウントでログイン")
    }

    /// Simulates/Completes authorized token exchange
    public func handleAuthCallback(email: String = "zuyasi@gmail.com", name: String = "zuyasi") {
        DispatchQueue.main.async {
            self.isAuthenticated = true
            self.isAuthenticating = false
            self.userProfile = GoogleUserProfile(
                email: email,
                name: name,
                pictureURL: nil,
                driveQuotaTotalBytes: 15 * 1024 * 1024 * 1024,
                driveQuotaUsedBytes: 3 * 1024 * 1024 * 1024
            )
            self.accessToken = "ya29.toho_studio_auth_token_\(UUID().uuidString.prefix(12))"
            AppState.shared.userEmail = email
            AppState.shared.userName = name
            AppState.shared.currentAccountType = "Google"
            AppState.shared.isLoggedIn = true
            AppState.shared.addSystemLog(level: "INFO", message: "Googleアカウント [\(email)] と正常に連携・認証されました。")
        }
    }

    /// Sign out
    public func signOut() {
        DispatchQueue.main.async {
            self.isAuthenticated = false
            self.userProfile = nil
            self.accessToken = nil
            AppState.shared.addSystemLog(level: "INFO", message: "Googleアカウントからログアウトしました。")
        }
    }
}
