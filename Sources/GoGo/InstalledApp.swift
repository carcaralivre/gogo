import Foundation

enum AppSource: String, Codable {
    case local   // /Applications
    case user    // ~/Applications
    case system  // /System/Applications
}

struct InstalledApp: Hashable, Identifiable {
    /// Bundle identifier, ou o caminho quando o bundle não tem um.
    let id: String
    let name: String
    let url: URL
    let bundleIdentifier: String?
    let source: AppSource
}
