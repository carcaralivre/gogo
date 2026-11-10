import AppKit
import Combine
import os

/// Descobre os apps instalados, guarda quais estão marcados e observa as pastas
/// para detectar apps novos. Só os desmarcados são persistidos, então qualquer app
/// desconhecido entra marcado — exceto na primeira execução, que começa vazia.
@MainActor
final class AppCatalog: ObservableObject {
    private struct State: Codable {
        var known: [String] = []
        var unchecked: [String] = []
    }

    private(set) var apps: [InstalledApp] = []
    private var unchecked: Set<String> = []
    private var known: Set<String> = []
    private var iconCache: [String: NSImage] = [:]
    private var watchers: [DirectoryWatcher] = []
    private var pendingRescan: DispatchWorkItem?
    private let log = Logger(subsystem: "com.eduardo.GoGo", category: "catalog")
    private let fm = FileManager.default

    /// Chamado sempre que a lista ou o estado de marcação muda.
    var onChange: (() -> Void)?

    private var userAppsURL: URL {
        fm.homeDirectoryForCurrentUser.appendingPathComponent("Applications", isDirectory: true)
    }

    private var roots: [(URL, AppSource)] {
        [
            (URL(fileURLWithPath: "/Applications", isDirectory: true), .local),
            (userAppsURL, .user),
            (URL(fileURLWithPath: "/System/Applications", isDirectory: true), .system),
        ]
    }

    private var stateURL: URL {
        fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("GoGo", isDirectory: true)
            .appendingPathComponent("state.json")
    }

    init() {
        loadState()
    }

    func start() {
        if !fm.fileExists(atPath: userAppsURL.path) {
            try? fm.createDirectory(at: userAppsURL, withIntermediateDirectories: true)
        }
        rescan()
        for (url, source) in roots where source != .system {
            if let watcher = DirectoryWatcher(url: url, handler: { [weak self] in self?.scheduleRescan() }) {
                watchers.append(watcher)
            }
        }
    }

    // MARK: Marcação

    var checkedApps: [InstalledApp] { apps.filter { isChecked($0) } }

    func isChecked(_ app: InstalledApp) -> Bool { !unchecked.contains(app.id) }

    func setChecked(_ checked: Bool, id: String) {
        objectWillChange.send()
        if checked { unchecked.remove(id) } else { unchecked.insert(id) }
        saveState()
        onChange?()
    }

    func setAllChecked(_ checked: Bool) {
        objectWillChange.send()
        unchecked = checked ? [] : Set(apps.map(\.id))
        saveState()
        onChange?()
    }

    // MARK: Ícones

    func icon(for app: InstalledApp) -> NSImage {
        if let cached = iconCache[app.id] { return cached }
        let image = NSWorkspace.shared.icon(forFile: app.url.path)
        image.size = NSSize(width: 16, height: 16)
        iconCache[app.id] = image
        return image
    }

    // MARK: Scan

    /// Reescaneia as pastas. Retorna os apps que apareceram desde o último scan.
    @discardableResult
    func rescan() -> [InstalledApp] {
        objectWillChange.send()
        var found: [String: InstalledApp] = [:]
        for (root, source) in roots {
            scan(directory: root, source: source, depth: 0, into: &found)
        }
        found.removeValue(forKey: Bundle.main.bundleIdentifier ?? "com.eduardo.GoGo")

        apps = disambiguated(Array(found.values))
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }

        let ids = Set(found.keys)
        let firstRun = known.isEmpty
        let newApps = ids.subtracting(known).compactMap { found[$0] }
        if firstRun {
            // Primeira execução: nada marcado, pra o primeiro clique não abrir dezenas de apps.
            // Daqui em diante, qualquer app novo detectado entra marcado.
            unchecked = ids
        } else if !newApps.isEmpty {
            let names = newApps.map(\.name).joined(separator: ", ")
            log.notice("Novos apps detectados (já marcados): \(names, privacy: .public)")
        }
        known = ids
        unchecked.formIntersection(ids)
        iconCache = iconCache.filter { ids.contains($0.key) }
        saveState()
        onChange?()
        return newApps
    }

    private func scheduleRescan() {
        pendingRescan?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.rescan() }
        pendingRescan = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: work)
    }

    private func scan(directory: URL, source: AppSource, depth: Int, into found: inout [String: InstalledApp]) {
        guard let items = try? fm.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return }

        for item in items {
            if item.pathExtension == "app" {
                guard let app = makeApp(url: item, source: source) else { continue }
                if found[app.id] == nil { found[app.id] = app }
            } else if depth == 0,
                      (try? item.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true {
                scan(directory: item, source: source, depth: 1, into: &found)
            }
        }
    }

    /// Apps distintos com o mesmo nome localizado (ex.: "Siri.app" e "Siri AI.app" ambos
    /// exibidos como "Siri") passam a usar o nome do arquivo; se ainda colidir, a pasta.
    private func disambiguated(_ list: [InstalledApp]) -> [InstalledApp] {
        let groups = Dictionary(grouping: list, by: \.name)
        return list.map { app in
            guard let group = groups[app.name], group.count > 1 else { return app }
            let fileName = app.url.deletingPathExtension().lastPathComponent
            let fileNames = Set(group.map { $0.url.deletingPathExtension().lastPathComponent })
            let name = fileNames.count == group.count
                ? fileName
                : "\(fileName) (\(app.url.deletingLastPathComponent().lastPathComponent))"
            return InstalledApp(id: app.id, name: name, url: app.url,
                                bundleIdentifier: app.bundleIdentifier, source: app.source)
        }
    }

    private func makeApp(url: URL, source: AppSource) -> InstalledApp? {
        guard let bundle = Bundle(url: url), bundle.executableURL != nil else { return nil }
        let bundleID = bundle.bundleIdentifier
        var name = fm.displayName(atPath: url.path)
        if name.hasSuffix(".app") { name = String(name.dropLast(4)) }
        return InstalledApp(id: bundleID ?? url.path, name: name, url: url,
                            bundleIdentifier: bundleID, source: source)
    }

    // MARK: Persistência

    private func loadState() {
        guard let data = try? Data(contentsOf: stateURL),
              let state = try? JSONDecoder().decode(State.self, from: data) else { return }
        known = Set(state.known)
        unchecked = Set(state.unchecked)
    }

    private func saveState() {
        let state = State(known: known.sorted(), unchecked: unchecked.sorted())
        do {
            try fm.createDirectory(at: stateURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(state).write(to: stateURL, options: .atomic)
        } catch {
            log.error("Falha ao salvar estado: \(error.localizedDescription, privacy: .public)")
        }
    }
}

/// Observa uma pasta via kqueue e chama o handler na main queue a cada mudança.
final class DirectoryWatcher {
    private let source: DispatchSourceFileSystemObject

    init?(url: URL, handler: @escaping () -> Void) {
        let fd = open(url.path, O_EVTONLY)
        guard fd >= 0 else { return nil }
        source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .rename, .delete, .link],
            queue: .main
        )
        source.setEventHandler(handler: handler)
        source.setCancelHandler { close(fd) }
        source.resume()
    }

    deinit { source.cancel() }
}
