import AppKit
import SwiftUI

/// Estado de interface do popover compartilhado com a view.
@MainActor
final class PopoverState: ObservableObject {
    @Published var showOthers = false
    @Published var query = ""
    @Published var scrollToBottomRequest = 0
    @Published var scrollToTopRequest = 0

    /// Volta ao estado inicial: busca vazia, "Não marcados" recolhido, lista no topo.
    func resetForNextOpen() {
        showOthers = false
        query = ""
    }

    /// Expandir é instantâneo (a rolagem animada até o cabeçalho é o feedback);
    /// recolher anima a saída das linhas. Animar a inserção quebrava a rolagem,
    /// porque o destino era calculado com o conteúdo ainda na altura antiga.
    func setOthersExpanded(_ expanded: Bool) {
        if expanded {
            showOthers = true
        } else {
            withAnimation(.easeInOut(duration: 0.25)) { showOthers = false }
        }
    }
}

/// Popover ancorado no item da barra. Fecha ao clicar fora ou com Esc.
@MainActor
final class LauncherPopover: NSObject, NSPopoverDelegate {
    private let popover = NSPopover()
    private let state = PopoverState()
    private weak var statusItem: NSStatusItem?
    private var clickMonitor: Any?
    private var previousApp: NSRunningApplication?

    init(catalog: AppCatalog, statusItem: NSStatusItem, onLaunch: @escaping () -> Void) {
        self.statusItem = statusItem
        super.init()
        popover.behavior = .transient
        popover.animates = true
        popover.delegate = self
        let view = LauncherView(catalog: catalog, ui: state, onLaunch: onLaunch, onClose: { [weak self] in self?.close() })
        let hosting = NSHostingController(rootView: view)
        hosting.sizingOptions = [.preferredContentSize]
        popover.contentViewController = hosting
    }

    var isShown: Bool { popover.isShown }

    func toggle() {
        if popover.isShown { close() } else { show() }
    }

    func show() {
        guard let button = statusItem?.button else { return }
        let front = NSWorkspace.shared.frontmostApplication
        previousApp = front?.bundleIdentifier == Bundle.main.bundleIdentifier ? nil : front
        NSApp.activate(ignoringOtherApps: true)
        state.resetForNextOpen()
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        button.highlight(true)
        DispatchQueue.main.async { [state] in state.scrollToTopRequest += 1 }
        // Qualquer clique fora do nosso app fecha o painel (o .transient nem sempre pega).
        clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]) { [weak self] _ in
            DispatchQueue.main.async { self?.close() }
        }
    }

    func close() {
        popover.performClose(nil)
    }

    func setOthersExpanded(_ expanded: Bool) {
        state.setOthersExpanded(expanded)
    }

    /// Diagnóstico: rola até o fim da lista (simula o usuário no fim de "Marcados").
    func scrollToBottom() {
        state.scrollToBottomRequest += 1
    }

    func setQuery(_ query: String) {
        state.query = query
    }

    /// Renderiza o conteúdo atual em PNG (diagnóstico: `gogo://snapshot`).
    func snapshot(to url: URL) {
        guard let view = popover.contentViewController?.view,
              let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
        view.cacheDisplay(in: view.bounds, to: rep)
        try? rep.representation(using: .png, properties: [:])?.write(to: url)
    }

    func popoverDidClose(_ notification: Notification) {
        statusItem?.button?.highlight(false)
        state.resetForNextOpen()
        if let clickMonitor { NSEvent.removeMonitor(clickMonitor) }
        clickMonitor = nil
        // Devolve o foco pro app que estava ativo antes de abrir o painel.
        previousApp?.activate()
        previousApp = nil
    }
}
