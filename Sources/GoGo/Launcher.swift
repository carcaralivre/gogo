import AppKit
import os

@MainActor
enum Launcher {
    nonisolated private static let log = Logger(subsystem: "com.eduardo.GoGo", category: "launcher")

    static func isRunning(_ app: InstalledApp) -> Bool {
        if let bundleID = app.bundleIdentifier {
            return !NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).isEmpty
        }
        return NSWorkspace.shared.runningApplications.contains { $0.bundleURL == app.url }
    }

    /// Abre todos os apps marcados que ainda não estão rodando. Retorna quantos foram disparados.
    @discardableResult
    static func launchChecked(from catalog: AppCatalog) -> Int {
        var launched = 0
        for app in catalog.checkedApps where !isRunning(app) {
            let config = NSWorkspace.OpenConfiguration()
            NSWorkspace.shared.openApplication(at: app.url, configuration: config) { _, error in
                if let error {
                    log.error("Falha ao abrir \(app.name, privacy: .public): \(error.localizedDescription, privacy: .public)")
                }
            }
            launched += 1
        }
        log.notice("Disparados \(launched) apps (via clique, atalho ou URL)")
        return launched
    }
}
