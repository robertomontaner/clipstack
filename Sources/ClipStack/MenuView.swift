import AppKit
import Carbon.HIToolbox
import ServiceManagement
import SwiftUI
import UniformTypeIdentifiers

/// Vista del menú superior: lista completa con buscador y ajustes.
@MainActor
struct MenuView: View {
    @ObservedObject var store: ClipboardStore
    @ObservedObject var updates = UpdateChecker.shared
    let onClose: () -> Void

    @State private var query = ""
    @State private var showSettings = false
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var accessibilityOK = Paster.ensureAccessibility(prompt: false)

    private var filtered: [ClipItem] {
        let all = store.displayItems
        guard !query.isEmpty else { return all }
        return all.filter {
            $0.title.localizedCaseInsensitiveContains(query)
                || ($0.text ?? "").localizedCaseInsensitiveContains(query)
                || ($0.filePaths ?? []).contains { $0.localizedCaseInsensitiveContains(query) }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            if let r = updates.available {
                HStack {
                    Image(systemName: "arrow.down.circle.fill").foregroundColor(.accentColor)
                    Text("Nueva versión v\(r.version) disponible").font(.system(size: 12, weight: .medium))
                    Spacer()
                    Button("Novedades") { updates.openReleasePage(); onClose() }
                        .buttonStyle(.link)
                    Button(updates.installing ? "Instalando…" : "Actualizar ahora") { updates.installUpdate() }
                        .disabled(updates.installing)
                }
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(Color.accentColor.opacity(0.12))
            }
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Buscar en el historial", text: $query)
                    .textFieldStyle(.plain)
                Button { showSettings.toggle() } label: {
                    Image(systemName: showSettings ? "xmark.circle.fill" : "gearshape")
                }
                .buttonStyle(.plain)
                .help("Ajustes")
            }
            .padding(12)
            Divider()

            if showSettings { settings } else { list }
        }
        .frame(width: 380, height: 520)
    }

    // MARK: Lista

    private var list: some View {
        Group {
            if filtered.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "doc.on.clipboard").font(.system(size: 30)).foregroundStyle(.secondary)
                    Text(store.items.isEmpty ? "Todavía no has copiado nada" : "Sin resultados")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 0) {
                    ScrollView {
                        LazyVStack(spacing: 2) {
                            ForEach(filtered) { item in
                                ClipRow(item: item, store: store) { plain in
                                    store.copyToPasteboard(item, plain: plain)
                                    onClose()
                                }
                            }
                        }
                        .padding(6)
                    }
                    Divider()
                    Text("Clic copia · ⇧clic sin formato · mantén pulsado para vista previa")
                        .font(.caption2).foregroundStyle(.secondary)
                        .padding(6)
                }
            }
        }
    }

    // MARK: Ajustes

    private var settings: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Guardar los últimos").font(.headline)
                    Picker("", selection: $store.limit) {
                        ForEach(ClipboardStore.limits, id: \.self) { Text("\($0)").tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    Text("Los elementos fijados no cuentan para el límite.")
                        .font(.caption).foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Atajo del selector rápido").font(.headline)
                    ShortcutRecorderView(store: store)
                    Text("En el selector: escribe para buscar, 1-9 o ↩ pegan, ⇧ pega sin formato, espacio muestra la vista previa y ⌘P fija.")
                        .font(.caption).foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("No guardar lo copiado en").font(.headline)
                    ExcludedAppsView(store: store)
                }

                Toggle("Pausar la captura", isOn: $store.paused)

                Toggle("Abrir al iniciar sesión", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { on in
                        do {
                            if on { try SMAppService.mainApp.register() }
                            else { try SMAppService.mainApp.unregister() }
                        } catch {
                            launchAtLogin = SMAppService.mainApp.status == .enabled
                        }
                    }

                HStack {
                    Image(systemName: accessibilityOK ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundColor(accessibilityOK ? .green : .orange)
                    Text(accessibilityOK ? "Atajo y pegado automático activos" : "Falta permiso de Accesibilidad (atajo y pegado)")
                        .font(.caption)
                    Spacer()
                    Button(accessibilityOK ? "Asistente" : "Configurar") {
                        onClose()
                        PermissionGuide.shared.show()
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Versión \(updates.currentVersion)").font(.headline)
                    HStack {
                        Button(updates.checking ? "Buscando…" : "Buscar actualizaciones") {
                            updates.check(manual: true)
                        }
                        .disabled(updates.checking)
                        if updates.available != nil {
                            Button(updates.installing ? "Instalando…" : "Actualizar ahora") { updates.installUpdate() }
                                .disabled(updates.installing)
                        }
                    }
                    if !updates.status.isEmpty {
                        Text(updates.status).font(.caption).foregroundStyle(.secondary)
                    }
                }

                Divider()

                HStack {
                    Button("Borrar historial", role: .destructive) { store.clear() }
                        .help("Los fijados se conservan")
                    Spacer()
                    Button("Salir") { NSApp.terminate(nil) }
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }
}

@MainActor
struct ClipRow: View {
    let item: ClipItem
    let store: ClipboardStore
    let onTap: (Bool) -> Void
    @State private var hover = false
    @State private var preview = false

    var body: some View {
        HStack(spacing: 10) {
            ItemThumb(item: item, store: store)
                .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .lineLimit(2)
                    .font(.system(size: 12, design: isColor ? .monospaced : .default))
                HStack(spacing: 4) {
                    if item.pinned { Image(systemName: "pin.fill").foregroundStyle(.orange) }
                    Text(item.subtitle + " · " + Self.relative.localizedString(for: item.date, relativeTo: Date()))
                }
                .font(.caption2).foregroundStyle(.secondary)
            }
            Spacer()
            if hover {
                HStack(spacing: 10) {
                    Button { preview = true } label: { Image(systemName: "eye") }
                        .help("Vista previa")
                    Button { store.togglePin(item) } label: {
                        Image(systemName: item.pinned ? "pin.slash" : "pin")
                    }
                    .help(item.pinned ? "Desfijar" : "Fijar")
                    Button { store.remove(item) } label: { Image(systemName: "trash") }
                        .help("Eliminar")
                }
                .buttonStyle(.plain)
            }
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 8)
            .fill(hover ? Color.accentColor.opacity(0.15) : Color.clear))
        .contentShape(Rectangle())
        .onHover { hover = $0 }
        .onTapGesture { onTap(NSEvent.modifierFlags.contains(.shift)) }
        .onLongPressGesture(minimumDuration: 0.4) { preview = true }
        .popover(isPresented: $preview, arrowEdge: .leading) {
            ItemPreview(item: item, store: store)
        }
    }

    private var isColor: Bool {
        if case .color = item.flavor { return true }
        return false
    }

    private static let relative: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .short
        return f
    }()
}

/// Lista de apps excluidas con botón para añadir (elige una .app) y quitar.
@MainActor
struct ExcludedAppsView: View {
    @ObservedObject var store: ClipboardStore

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(store.excludedApps, id: \.self) { id in
                HStack(spacing: 8) {
                    if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) {
                        Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                            .resizable().frame(width: 18, height: 18)
                        Text(FileManager.default.displayName(atPath: url.path)
                                .replacingOccurrences(of: ".app", with: ""))
                            .font(.system(size: 12))
                    } else {
                        Image(systemName: "app.dashed").frame(width: 18, height: 18)
                        Text(id).font(.system(size: 11)).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button { store.excludedApps.removeAll { $0 == id } } label: {
                        Image(systemName: "minus.circle")
                    }
                    .buttonStyle(.plain)
                    .help("Quitar")
                }
            }
            HStack {
                Button("Añadir app…", action: addApp)
                Button("Restablecer") { store.excludedApps = ClipboardStore.defaultExcluded }
            }
            .padding(.top, 2)
            Text("Las apps sin instalar de la lista se ignoran.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private func addApp() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowsMultipleSelection = true
        panel.prompt = "Excluir"
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK else { return }
        for url in panel.urls {
            if let id = Bundle(url: url)?.bundleIdentifier, !store.excludedApps.contains(id) {
                store.excludedApps.append(id)
            }
        }
    }
}

/// Botón que graba un atajo: haz clic y pulsa la combinación (con ⌘, ⌃ o ⌥).
@MainActor
struct ShortcutRecorderView: View {
    @ObservedObject var store: ClipboardStore
    @State private var recording = false
    @State private var monitor: Any?

    var body: some View {
        HStack {
            Button(action: toggle) {
                Text(recording ? "Pulsa las teclas…" : store.shortcut.display)
                    .frame(minWidth: 130)
            }
            if recording {
                Button("Cancelar") { stop() }
            } else {
                Button("Restablecer") { store.shortcut = Shortcut.default }
            }
        }
        .onDisappear { stop() }
    }

    private func toggle() {
        if recording { stop() } else { start() }
    }

    private func start() {
        recording = true
        store.isRecordingShortcut = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if Int(event.keyCode) == kVK_Escape { stop(); return nil }
            let mods = event.modifierFlags.intersection([.command, .control, .option, .shift])
            guard mods.contains(.command) || mods.contains(.control) || mods.contains(.option) else {
                NSSound.beep()   // hace falta al menos ⌘, ⌃ o ⌥
                return nil
            }
            store.shortcut = Shortcut(keyCode: UInt32(event.keyCode),
                                      modifiers: mods.rawValue,
                                      label: Shortcut.label(for: event))
            stop()
            return nil
        }
    }

    private func stop() {
        if let m = monitor { NSEvent.removeMonitor(m); monitor = nil }
        recording = false
        store.isRecordingShortcut = false
    }
}
