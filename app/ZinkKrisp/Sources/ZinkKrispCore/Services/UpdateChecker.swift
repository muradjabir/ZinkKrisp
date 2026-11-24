import Foundation

public struct AppReleaseUpdate: Identifiable, Equatable {
    public var id: String { tagName }
    public let tagName: String
    public let version: String
    public let title: String
    public let releaseNotes: String
    public let htmlURL: URL
    public let appZipURL: URL?
    public let publishedAt: Date?

    public init(
        tagName: String,
        version: String,
        title: String,
        releaseNotes: String,
        htmlURL: URL,
        appZipURL: URL?,
        publishedAt: Date?
    ) {
        self.tagName = tagName
        self.version = version
        self.title = title
        self.releaseNotes = releaseNotes
        self.htmlURL = htmlURL
        self.appZipURL = appZipURL
        self.publishedAt = publishedAt
    }
}

@MainActor
public final class UpdateChecker: ObservableObject {
    public static let shared = UpdateChecker()

    @Published public var availableUpdate: AppReleaseUpdate? = nil
    @Published public var isChecking: Bool = false
    @Published public var statusAlertMessage: String? = nil

    private static let latestReleaseAPI = URL(string: "https://api.github.com/repos/muradjabir/ZinkKrisp/releases/latest")!
    private static let skippedVersionDefaultsKey = "ZinkKrisp.skippedUpdateVersion"

    private struct GitHubReleaseResponse: Decodable {
        struct Asset: Decodable {
            let name: String
            let browserDownloadURL: String

            enum CodingKeys: String, CodingKey {
                case name
                case browserDownloadURL = "browser_download_url"
            }
        }

        let tagName: String
        let name: String?
        let body: String?
        let htmlURL: String
        let draft: Bool?
        let prerelease: Bool?
        let publishedAt: String?
        let assets: [Asset]

        enum CodingKeys: String, CodingKey {
            case tagName = "tag_name"
            case name
            case body
            case htmlURL = "html_url"
            case draft
            case prerelease
            case publishedAt = "published_at"
            case assets
        }
    }

    public var currentVersion: String {
        if let ver = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
           !ver.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return ver.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return "0.2.0"
    }

    private init() {}

    /// Compares two dot-separated version strings after stripping any leading `v`/`V`
    /// and any `-prerelease` suffix, returning `true` when `remote` > `local`.
    public nonisolated static func isVersion(_ remote: String, newerThan local: String) -> Bool {
        let parse: (String) -> [Int] = { raw in
            var cleaned = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if cleaned.lowercased().hasPrefix("v") {
                cleaned = String(cleaned.dropFirst())
            }
            if let dashIdx = cleaned.firstIndex(of: "-") {
                cleaned = String(cleaned[..<dashIdx])
            }
            if cleaned.isEmpty { return [] }
            return cleaned.split(separator: ".").map { part in
                let digits = part.prefix { $0.isNumber }
                return Int(digits) ?? 0
            }
        }

        let rParts = parse(remote)
        let lParts = parse(local)
        let count = max(rParts.count, lParts.count)
        guard count > 0 else { return false }

        for i in 0..<count {
            let r = i < rParts.count ? rParts[i] : 0
            let l = i < lParts.count ? lParts[i] : 0
            if r != l {
                return r > l
            }
        }
        return false
    }

    /// Fetches the latest published release from GitHub and parses it into `AppReleaseUpdate`.
    public func fetchLatestRelease() async throws -> AppReleaseUpdate? {
        var req = URLRequest(url: Self.latestReleaseAPI)
        req.cachePolicy = .reloadIgnoringLocalCacheData
        req.timeoutInterval = 10
        req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        req.setValue("ZinkKrisp/\(currentVersion)", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: req)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw NSError(
                domain: "UpdateChecker",
                code: http.statusCode,
                userInfo: [NSLocalizedDescriptionKey: "GitHub API returned HTTP \(http.statusCode)"]
            )
        }

        let decoded = try JSONDecoder().decode(GitHubReleaseResponse.self, from: data)
        if decoded.draft == true || decoded.prerelease == true {
            return nil
        }

        let cleanVersion = decoded.tagName.lowercased().hasPrefix("v")
            ? String(decoded.tagName.dropFirst())
            : decoded.tagName

        guard let htmlURL = URL(string: decoded.htmlURL) else { return nil }
        let appZipURL = decoded.assets
            .first { asset in
                let lower = asset.name.lowercased()
                return lower.contains("zinkkrisp") && lower.hasSuffix(".zip")
            }
            .flatMap { URL(string: $0.browserDownloadURL) }

        let publishedDate: Date? = decoded.publishedAt.flatMap {
            ISO8601DateFormatter().date(from: $0)
        }

        let titleText = (decoded.name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let notesText = (decoded.body ?? "").trimmingCharacters(in: .whitespacesAndNewlines)

        return AppReleaseUpdate(
            tagName: decoded.tagName,
            version: cleanVersion,
            title: titleText.isEmpty ? "ZinkKrisp \(decoded.tagName)" : titleText,
            releaseNotes: notesText.isEmpty ? "A new release of ZinkKrisp is available." : notesText,
            htmlURL: htmlURL,
            appZipURL: appZipURL,
            publishedAt: publishedDate
        )
    }

    public func checkForUpdates(manual: Bool = false) async {
        guard !isChecking else { return }
        isChecking = true
        defer { isChecking = false }

        do {
            guard let release = try await fetchLatestRelease() else {
                if manual {
                    statusAlertMessage = "You're up to date! ZinkKrisp v\(currentVersion) is the latest version."
                }
                return
            }

            if Self.isVersion(release.version, newerThan: currentVersion) {
                if !manual,
                   UserDefaults.standard.string(forKey: Self.skippedVersionDefaultsKey) == release.version {
                    return
                }
                availableUpdate = release
            } else if manual {
                statusAlertMessage = "You're up to date! ZinkKrisp v\(currentVersion) is the latest version."
            }
        } catch {
            if manual {
                statusAlertMessage = "Could not check for updates: \(error.localizedDescription)"
            }
        }
    }

    public func skipUpdate(_ update: AppReleaseUpdate) {
        UserDefaults.standard.set(update.version, forKey: Self.skippedVersionDefaultsKey)
        availableUpdate = nil
    }

    public func dismissPrompt() {
        availableUpdate = nil
    }
}
