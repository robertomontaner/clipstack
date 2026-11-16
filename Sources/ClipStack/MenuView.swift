import AppKit
import Carbon.HIToolbox
import ServiceManagement
import SwiftUI

/// Vista del menú superior: lista completa con buscador y ajustes.
@MainActor
struct MenuView: View {
    @ObservedObject var store: ClipboardStore
    let onClose: () -> Void

    @State private var query = ""
    @State private var showSettings = false
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var accessibilityOK = Paster.ensureAccessibility(prompt: false)

    private var filtered: [ClipItem] {
        guard !query.isEmpty else { return store.items }
        return store.items.filter { ($0.text ?? "").localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        VStack(spacing: 0) {
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
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(filtered) { item in
                            ClipRow(item: item, store: store) {
                                store.copyToPasteboard(item)
                                onClose()
                            }
                        }
                    }
                    .padding(6)
                }
            }
        }
    }

    // MARK: Ajustes

    private var settings: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Guardar los últimos").font(.headline)
                Picker("", selection: $store.limit) {
                    ForEach(ClipboardStore.limits, id: \.self) { Text("\($0)").tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Atajo del selector rápido").font(.headline)
                ShortcutRecorderView(store: store)
                Text("Pulsa el atajo y, sin soltar los modificadores, púlsalo otra vez para avanzar. Al soltar, se pega.")
                    .font(.caption).foregroundStyle(.secondary)
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
                Text(accessibilityOK ? "Pegado automático activo" : "Falta permiso de Accesibilidad para pegar solo")
                    .font(.caption)
                Spacer()
                if !accessibilityOK {
                    Button("Conceder") {
                        Paster.ensureAccessibility(prompt: true)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                            accessibilityOK = Paster.ensureAccessibility(prompt: false)
                        }
                    }
                }
            }

            Spacer()

            HStack {
                Button("Borrar historial", role: .destructive) { store.clear() }
                Spacer()
                Button("Salir") { NSApp.terminate(nil) }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

@MainActor
struct ClipRow: View {
    let item: ClipItem
    let store: ClipboardStore
    let onTap: () -> Void
    @State private var hover = false

    var body: some View {
        HStack(spacing: 10) {
            Group {
                if item.kind == .image, let img = store.thumbnail(for: item) {
                    Image(nsImage: img).resizable().scaledToFit()
                } else {
                    Image(systemName: "text.alignleft").foregroundStyle(.secondary)
                }
            }
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.kind == .image
                     ? "Imagen"
                     : (item.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines))
                    .lineLimit(2)
                    .font(.system(size: 12))
                Text(Self.relative.localizedString(for: item.date, relativeTo: Date()))
                    .font(.caption2).foregroundStyle(.secondary)
            }
            Spacer()
            if hover {
                Button { store.remove(item) } label: { Image(systemName: "trash") }
                    .buttonStyle(.plain)
                    .help("Eliminar")
            }
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 8)
            .fill(hover ? Color.accentColor.opacity(0.15) : Color.clear))
        .contentShape(Rectangle())
        .onHover { hover = $0 }
        .onTapGesture(perform: onTap)
    }

    private static let relative: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .short
        return f
    }()
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
