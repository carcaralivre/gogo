import AppKit
import Carbon
import os

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: LauncherPopover!
    private var hotKey: HotKey?
    private let catalog = AppCatalog()
    private var isReady = false
    /// URLs que chegaram antes do fim da inicialização (ex.: `open gogo://launch` com o app fechado).
    private var pendingURLs: [URL] = []
    private let log = Logger(subsystem: "com.eduardo.GoGo", category: "app")

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = MenuBarIcon.make()
            button.toolTip = "GoGo — clique: abre os apps marcados · botão direito: menu · ⌃⌥⌘G"
            button.target = self
            button.action = #selector(statusItemClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        popover = LauncherPopover(catalog: catalog, statusItem: statusItem) { [weak self] in self?.launchAll() }

        catalog.start()

        hotKey = HotKey(keyCode: kVK_ANSI_G, modifiers: controlKey | optionKey | cmdKey) { [weak self] in
            self?.launchAll()
        }

        let frame = statusItem.button?.window?.frame ?? .zero
        log.notice("GoGo pronto: \(self.catalog.apps.count) apps, item visível=\(self.statusItem.isVisible), frame=\(NSStringFromRect(frame), privacy: .public)")

        isReady = true
        let queued = pendingURLs
        pendingURLs = []
        if !queued.isEmpty { handle(urls: queued) }
    }

    /// URL scheme: `gogo://launch` dispara o mesmo que o clique esquerdo; `gogo://menu` abre/fecha a lista.
    func application(_ application: NSApplication, open urls: [URL]) {
        guard isReady else {
            pendingURLs += urls
            return
        }
        handle(urls: urls)
    }

    private func handle(urls: [URL]) {
        for url in urls where url.scheme?.lowercased() == "gogo" {
            switch url.host?.lowercased() {
            case "launch", "open", "go":
                launchAll()
            case "menu", "list":
                toggleList()
                if wantsOthers(url) { expandOthersSoon() }
                applyQuery(from: url)
            case "snapshot":
                let out = FileManager.default.temporaryDirectory.appendingPathComponent("gogo-snapshot.png")
                if !popover.isShown { toggleList() }
                scrollToBottomIfAsked(url)
                if wantsOthers(url) { expandOthersSoon() }
                applyQuery(from: url)
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
                    self?.popover.snapshot(to: out)
                    self?.log.notice("Snapshot em \(out.path, privacy: .public)")
                }
            default:
                log.error("URL desconhecida: \(url.absoluteString, privacy: .public)")
            }
        }
    }

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent
        let isSecondary = event?.type == .rightMouseUp || event?.modifierFlags.contains(.control) == true
        if isSecondary {
            toggleList()
        } else {
            launchAll()
        }
    }

    private func toggleList() {
        if !popover.isShown { catalog.rescan() }
        popover.toggle()
    }

    private func wantsOthers(_ url: URL) -> Bool {
        URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?.contains { $0.name == "others" && $0.value != "0" } ?? false
    }

    private func expandOthersSoon() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.popover.setOthersExpanded(true)
        }
    }

    private func scrollToBottomIfAsked(_ url: URL) {
        let asked = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?.contains { $0.name == "bottom" && $0.value != "0" } ?? false
        guard asked else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            self?.popover.scrollToBottom()
        }
    }

    private func applyQuery(from url: URL) {
        guard let q = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?.first(where: { $0.name == "q" })?.value, !q.isEmpty else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.popover.setQuery(q)
        }
    }

    private func launchAll() {
        if popover.isShown { popover.close() }
        pulse()
        Launcher.launchChecked(from: catalog)
    }

    /// Feedback visual rápido no ícone ao disparar.
    private func pulse() {
        guard let button = statusItem.button else { return }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.1
            button.animator().alphaValue = 0.2
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.3
                button.animator().alphaValue = 1
            }
        }
    }
}
