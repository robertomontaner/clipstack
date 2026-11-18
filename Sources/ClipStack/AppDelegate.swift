import AppKit
import ApplicationServices
import Combine
import SwiftUI

@main
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let popover = NSPopover()
    private var hotKey: HotKey?
    private var tapHotKey: EventTapHotKey?
    private var retryTimer: Timer?
    private let switcher = SwitcherController()
    private var cancellables = Set<AnyCancellable>()

    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)   // sin icono en el Dock
        app.run()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let store = ClipboardStore.shared
        store.start()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            let img = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "ClipStack")
            img?.isTemplate = true
            button.image = img
            button.target = self
            button.action = #selector(togglePopover(_:))
        }

        popover.behavior = .transient
        popover.contentSize = NSSize(width: 380, height: 520)
        popover.contentViewController = NSHostingController(
            rootView: MenuView(store: store) { [weak self] in self?.popover.performClose(nil) })

        // (Re)registra el atajo cuando cambia en ajustes.
        Publishers.CombineLatest(store.$shortcut, store.$isRecordingShortcut)
            .sink { [weak self] shortcut, recording in
                self?.registerHotKey(shortcut, recording: recording)
            }
            .store(in: &cancellables)

        // Aviso de actualización: cambia el icono de la barra de menú.
        UpdateChecker.shared.$available
            .sink { [weak self] release in self?.setStatusIcon(updateAvailable: release != nil) }
            .store(in: &cancellables)
        UpdateChecker.shared.start()

        // Asistente de permisos: tras actualizar, o si falta el permiso de Accesibilidad.
        let updated = CommandLine.arguments.contains("--updated")
        PermissionGuide.shared.justUpdated = updated
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            if updated { PermissionGuide.shared.show() } else { PermissionGuide.shared.showIfNeeded() }
        }
    }

    private func setStatusIcon(updateAvailable: Bool) {
        guard let button = statusItem.button else { return }
        let name = updateAvailable ? "arrow.down.doc" : "doc.on.clipboard"
        let img = NSImage(systemSymbolName: name, accessibilityDescription: "ClipStack")
        img?.isTemplate = true
        button.image = img
        button.toolTip = updateAvailable ? "ClipStack: hay una versión nueva" : "ClipStack"
    }

    /// Intenta primero el event tap (admite ⇧⌥V, ⌥V…). Si aún no hay permiso de
    /// Accesibilidad, usa Carbon de reserva y reintenta cada 2 s hasta tenerlo.
    private func registerHotKey(_ shortcut: Shortcut, recording: Bool) {
        hotKey = nil
        tapHotKey = nil
        retryTimer?.invalidate(); retryTimer = nil
        guard !recording else { return }
        switcher.requiredFlags = shortcut.flags

        let fire: () -> Void = { [weak self] in self?.switcher.trigger() }
        let tap = EventTapHotKey(keyCode: shortcut.keyCode, modifiers: shortcut.flags, callback: fire)
        if tap.active { tapHotKey = tap; return }

        hotKey = HotKey(keyCode: shortcut.keyCode, modifiers: shortcut.carbonMods, callback: fire)
        retryTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, AXIsProcessTrusted() else { return }
                self.registerHotKey(ClipboardStore.shared.shortcut,
                                    recording: ClipboardStore.shared.isRecordingShortcut)
            }
        }
    }

    @objc private func togglePopover(_ sender: Any?) {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(sender)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}
