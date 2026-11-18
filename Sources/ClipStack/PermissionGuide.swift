import AppKit
import ApplicationServices
import Combine
import SwiftUI

/// Ventana que guía paso a paso para dar el permiso de Accesibilidad.
/// Se abre sola al arrancar si falta el permiso (también tras actualizar) y se cierra sola al concederlo.
@MainActor
final class PermissionGuide: ObservableObject {
    static let shared = PermissionGuide()

    @Published private(set) var granted = AXIsProcessTrusted()
    @Published var justUpdated = false

    private var window: NSWindow?
    private var timer: Timer?

    func showIfNeeded() {
        if !AXIsProcessTrusted() { show() }
    }

    func show() {
        granted = AXIsProcessTrusted()
        if window == nil {
            let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 460, height: 420),
                             styleMask: [.titled, .closable], backing: .buffered, defer: false)
            w.title = "Configurar ClipStack"
            w.isReleasedWhenClosed = false
            w.contentView = NSHostingView(rootView: PermissionGuideView(guide: self))
            w.center()
            window = w
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
        window?.level = .floating

        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.refresh() }
        }
    }

    func close() {
        timer?.invalidate(); timer = nil
        window?.orderOut(nil)
    }

    private func refresh() {
        let now = AXIsProcessTrusted()
        if now != granted { granted = now }
        if window?.isVisible != true { timer?.invalidate(); timer = nil }
    }

    /// Añade ClipStack a la lista de Accesibilidad y abre ese panel de Ajustes.
    func openSettings() {
        _ = Paster.ensureAccessibility(prompt: true)
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
        window?.level = .normal   // que no tape Ajustes
    }

    func revealApp() {
        NSWorkspace.shared.activateFileViewerSelecting([Bundle.main.bundleURL])
    }
}

@MainActor
struct PermissionGuideView: View {
    @ObservedObject var guide: PermissionGuide
    @ObservedObject var store = ClipboardStore.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(nsImage: NSApp.applicationIconImage).resizable().frame(width: 52, height: 52)
                VStack(alignment: .leading, spacing: 2) {
                    Text(guide.justUpdated ? "ClipStack se ha actualizado" : "Un paso para terminar")
                        .font(.title2.bold())
                    Text("Versión \(UpdateChecker.shared.currentVersion)")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }

            if guide.granted {
                done
            } else {
                steps
            }
        }
        .padding(22)
        .frame(width: 460, height: 420, alignment: .topLeading)
    }

    private var steps: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(LocalizedStringKey(
                "ClipStack necesita el permiso de **Accesibilidad** para el atajo \(store.shortcut.display) y para pegar automáticamente."
                + (guide.justUpdated ? " Cada actualización cambia la firma de la app, así que macOS lo pide otra vez." : "")))
                .fixedSize(horizontal: false, vertical: true)

            step(1, "Pulsa **Abrir Ajustes**.")
            step(2, "En la lista, **activa ClipStack**.")
            step(3, "Si ya aparecía activado, **desactívalo y vuelve a activarlo**. Si no aparece, pulsa **+** y elige ClipStack en Aplicaciones.")

            HStack {
                Button("Abrir Ajustes") { guide.openSettings() }
                    .keyboardShortcut(.defaultAction)
                Button("Mostrar ClipStack en Finder") { guide.revealApp() }
            }

            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text("Esperando el permiso… esta ventana se actualiza sola.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            HStack {
                Spacer()
                Button("Más tarde") { guide.close() }
            }
        }
    }

    private var done: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Permiso concedido", systemImage: "checkmark.circle.fill")
                .font(.headline).foregroundColor(.green)
            Text("Ya está todo listo. Pulsa **\(store.shortcut.display)** en cualquier app para abrir el selector, o usa el icono de la barra de menú.")
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
            HStack {
                Spacer()
                Button("Empezar") { guide.close() }.keyboardShortcut(.defaultAction)
            }
        }
    }

    private func step(_ n: Int, _ text: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(n)")
                .font(.system(size: 12, weight: .bold))
                .frame(width: 22, height: 22)
                .background(Circle().fill(Color.accentColor))
                .foregroundColor(.white)
            Text(text).fixedSize(horizontal: false, vertical: true)
        }
    }
}
