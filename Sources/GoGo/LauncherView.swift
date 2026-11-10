import AppKit
import SwiftUI
import os

/// Conteúdo do popover: busca, marcados, "outros" colapsados e ações.
struct LauncherView: View {
    @ObservedObject var catalog: AppCatalog
    @ObservedObject var ui: PopoverState
    var onLaunch: () -> Void
    var onClose: () -> Void

    @State private var contentHeight: CGFloat = 200
    @State private var loginEnabled = LoginItem.isEnabled
    @FocusState private var searchFocused: Bool

    private var runningIDs: Set<String> {
        Set(NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier))
    }

    private var trimmedQuery: String { ui.query.trimmingCharacters(in: .whitespaces) }

    private func matches(_ app: InstalledApp) -> Bool {
        trimmedQuery.isEmpty || app.name.localizedCaseInsensitiveContains(trimmedQuery)
    }

    private var checked: [InstalledApp] { catalog.apps.filter { catalog.isChecked($0) && matches($0) } }
    private var others: [InstalledApp] { catalog.apps.filter { !catalog.isChecked($0) && matches($0) } }
    private var checkedCount: Int { catalog.checkedApps.count }

    var body: some View {
        let running = runningIDs
        VStack(spacing: 0) {
            searchBar
            Divider()
            ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                Color.clear.frame(height: 0).id("top")
                VStack(alignment: .leading, spacing: 1) {
                    sectionHeader("Marcados", count: checked.count)
                    if checked.isEmpty {
                        emptyHint(trimmedQuery.isEmpty
                                  ? "Nenhum app marcado. Abra \"Não marcados\" e escolha."
                                  : "Nenhum marcado com esse nome.")
                    }
                    ForEach(checked) { app in
                        AppRow(app: app, checked: true, icon: catalog.icon(for: app),
                               running: app.bundleIdentifier.map(running.contains) ?? false) {
                            catalog.setChecked(false, id: app.id)
                        }
                    }

                    othersHeader
                        .id("othersHeader")
                    if ui.showOthers || !trimmedQuery.isEmpty {
                        Group {
                            if others.isEmpty {
                                emptyHint(trimmedQuery.isEmpty
                                          ? "Todos os apps estão marcados."
                                          : "Nenhum não marcado com esse nome.")
                            }
                            ForEach(others) { app in
                                AppRow(app: app, checked: false, icon: catalog.icon(for: app),
                                       running: app.bundleIdentifier.map(running.contains) ?? false) {
                                    catalog.setChecked(true, id: app.id)
                                }
                            }
                        }
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                }
                .onGeometryChange(for: CGFloat.self) { proxy in
                    proxy.size.height
                } action: { height in
                    contentHeight = height
                    Logger(subsystem: "com.eduardo.GoGo", category: "ui").debug("Altura do conteúdo: \(height)")
                }
            }
            .frame(height: min(max(contentHeight, 60), 440))
            .onAppear { proxy.scrollTo("top", anchor: .top) }
            .onChange(of: ui.scrollToTopRequest) { _, _ in
                proxy.scrollTo("top", anchor: .top)
            }
            .onChange(of: ui.scrollToBottomRequest) { _, _ in
                proxy.scrollTo("othersHeader", anchor: .bottom)
            }
            .onChange(of: ui.showOthers) { _, expanded in
                // Expandir: cabeçalho "Não marcados" vai pro topo da área visível, com os itens abaixo.
                // Recolher: o cabeçalho fica visível na base, em vez da lista dar um pulo seco.
                // Dois ciclos de runloop: garante que as linhas novas já tenham layout
                // antes de calcular o destino da rolagem (senão o alvo é cortado na altura antiga).
                DispatchQueue.main.async {
                    DispatchQueue.main.async {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            proxy.scrollTo("othersHeader", anchor: expanded ? .top : .bottom)
                        }
                    }
                }
            }
            }
            Divider()
            footer
        }
        .frame(width: 340)
        .onAppear {
            loginEnabled = LoginItem.isEnabled
            DispatchQueue.main.async { searchFocused = true }
        }
        .onExitCommand { onClose() }
    }

    // MARK: Partes

    private var searchBar: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField("Buscar app…", text: $ui.query)
                .textFieldStyle(.plain)
                .focused($searchFocused)
            if !ui.query.isEmpty {
                Button { ui.query = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
    }

    private func sectionHeader(_ title: String, count: Int) -> some View {
        HStack {
            Text(title).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            Text("\(count)").font(.caption2.weight(.semibold))
                .padding(.horizontal, 5).padding(.vertical, 1)
                .background(Capsule().fill(Color.secondary.opacity(0.15)))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, 6)
        .padding(.top, 6)
        .padding(.bottom, 3)
    }

    private var othersHeader: some View {
        Button {
            ui.setOthersExpanded(!ui.showOthers)
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .rotationEffect(.degrees(ui.showOthers || !trimmedQuery.isEmpty ? 90 : 0))
                    .animation(.easeInOut(duration: 0.2), value: ui.showOthers)
                    .foregroundStyle(.secondary)
                Text("Não marcados").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                Text("\(others.count)").font(.caption2.weight(.semibold))
                    .padding(.horizontal, 5).padding(.vertical, 1)
                    .background(Capsule().fill(Color.secondary.opacity(0.15)))
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 6)
        .padding(.top, 12)
        .padding(.bottom, 3)
    }

    private func emptyHint(_ text: String) -> some View {
        Text(text)
            .font(.callout)
            .foregroundStyle(.tertiary)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
    }

    private var footer: some View {
        HStack(spacing: 8) {
            Button {
                onLaunch()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "forward.fill")
                    Text(checkedCount == 1 ? "Abrir 1 app" : "Abrir \(checkedCount) apps")
                    Text("⌃⌥⌘G").font(.caption2).foregroundStyle(.secondary)
                }
            }
            .keyboardShortcut("g", modifiers: [.control, .option, .command])
            .disabled(checkedCount == 0)

            Spacer()

            Menu {
                Button("Marcar todos") { catalog.setAllChecked(true) }
                Button("Desmarcar todos") { catalog.setAllChecked(false) }
                Divider()
                Toggle("Iniciar com o macOS", isOn: Binding(
                    get: { loginEnabled },
                    set: { newValue in
                        try? LoginItem.setEnabled(newValue)
                        loginEnabled = LoginItem.isEnabled
                    }
                ))
                Divider()
                Button("Sobre o GoGo") { showAbout() }
                Button("Sair do GoGo") { NSApp.terminate(nil) }
            } label: {
                Image(systemName: "gearshape")
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
    }

    private func showAbout() {
        onClose()
        NSApp.activate(ignoringOtherApps: true)
        let credits = NSAttributedString(
            string: "Launcher de menu bar.\nClique: abre os apps marcados\nBotão direito: lista\nAtalho: ⌃⌥⌘G",
            attributes: [.font: NSFont.systemFont(ofSize: 11), .foregroundColor: NSColor.secondaryLabelColor]
        )
        NSApp.orderFrontStandardAboutPanel(options: [.credits: credits])
    }
}

/// Linha de app: clicar em qualquer lugar alterna o check sem fechar o popover.
private struct AppRow: View {
    let app: InstalledApp
    let checked: Bool
    let icon: NSImage
    let running: Bool
    let toggle: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: toggle) {
            HStack(spacing: 8) {
                Image(systemName: checked ? "checkmark.square.fill" : "square")
                    .font(.system(size: 15))
                    .foregroundStyle(checked ? Color.accentColor : Color.secondary)
                    .frame(width: 18)
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 18, height: 18)
                Text(app.name).lineLimit(1)
                Spacer(minLength: 4)
                if running {
                    Text("aberto")
                        .font(.caption2)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Capsule().fill(Color.green.opacity(0.18)))
                        .foregroundStyle(.green)
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(RoundedRectangle(cornerRadius: 6)
                .fill(hovering ? Color.primary.opacity(0.08) : Color.clear))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}
