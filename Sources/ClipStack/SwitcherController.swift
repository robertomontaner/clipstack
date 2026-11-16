import AppKit
import Carbon.HIToolbox
import SwiftUI

/// Panel flotante que puede recibir teclado sin activar la app (el foco no se mueve de donde estabas).
final class SwitcherPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

@MainActor
final class SwitcherModel: ObservableObject {
    @Published var items: [ClipItem] = []
    @Published var selected = 0
}

/// Selector rápido tipo ⌘Tab:
/// - Atajo: abre el panel (preselecciona el 2.º elemento, el anterior al actual).
/// - Atajo de nuevo (manteniendo los modificadores): avanza.
/// - ← → ↑ ↓ también navegan, 1-9 elige directo, Esc cancela.
/// - El panel se queda abierto hasta elegir (1-9, Intro o clic) o cerrar (Esc o la X).
@MainActor
final class SwitcherController {
    private let store = ClipboardStore.shared
    private let model = SwitcherModel()
    private var panel: SwitcherPanel?
    private var keyMonitor: Any?

    var requiredFlags: NSEvent.ModifierFlags = [.option]   // ya no se usa para pegar al soltar

    private var isVisible: Bool { panel?.isVisible == true }

    private static let digitKeyCodes: [UInt16] = [18, 19, 20, 21, 23, 22, 26, 28, 25]

    func trigger() {
        if isVisible { advance(1) } else { show() }
    }

    private func show() {
        guard !store.items.isEmpty else { NSSound.beep(); return }
        model.items = store.items
        model.selected = store.items.count > 1 ? 1 : 0

        let screen = NSScreen.screens.first { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) }
            ?? NSScreen.main ?? NSScreen.screens[0]
        let vf = screen.visibleFrame
        let w = min(vf.width - 80, max(380, CGFloat(model.items.count) * 132 + 40))
        let h: CGFloat = 230
        let rect = NSRect(x: vf.midX - w / 2, y: vf.midY - h / 2, width: w, height: h)

        let p = SwitcherPanel(contentRect: rect,
                              styleMask: [.borderless, .nonactivatingPanel],
                              backing: .buffered, defer: false)
        p.isFloatingPanel = true
        p.level = .popUpMenu
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = true
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        p.contentView = NSHostingView(rootView:
            SwitcherView(model: model, store: store,
                         onPick: { [weak self] i in self?.commit(index: i) },
                         onClose: { [weak self] in self?.close() }))
        p.orderFrontRegardless()
        p.makeKey()
        panel = p

        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            return self.handle(event) ? nil : event
        }

    }

    private func handle(_ event: NSEvent) -> Bool {
        switch Int(event.keyCode) {
        case kVK_Escape:
            close(); return true
        case kVK_Return, kVK_ANSI_KeypadEnter:
            commit(index: model.selected); return true
        case kVK_LeftArrow, kVK_UpArrow:
            advance(-1); return true
        case kVK_RightArrow, kVK_DownArrow, kVK_Tab:
            advance(1); return true
        default:
            if let n = Self.digitKeyCodes.firstIndex(of: event.keyCode) {
                commit(index: n); return true
            }
            return false
        }
    }

    private func advance(_ delta: Int) {
        let n = model.items.count
        guard n > 0 else { return }
        model.selected = (model.selected + delta + n) % n
    }

    private func commit(index: Int) {
        let items = model.items
        close()
        guard items.indices.contains(index) else { return }
        store.copyToPasteboard(items[index])
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { Paster.pasteIntoFrontApp() }
    }

    private func close() {
        if let m = keyMonitor { NSEvent.removeMonitor(m); keyMonitor = nil }
        panel?.orderOut(nil)
        panel = nil
    }
}

// MARK: - Vista del selector

@MainActor
struct SwitcherView: View {
    @ObservedObject var model: SwitcherModel
    let store: ClipboardStore
    let onPick: (Int) -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("1-9 o Intro para pegar · ← → para moverte · Esc para cerrar")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Cerrar (Esc)")
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            cards
        }
        .frame(height: 230)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 22))
    }

    private var cards: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(Array(model.items.enumerated()), id: \.element.id) { i, item in
                        ClipCard(item: item, index: i, selected: i == model.selected, store: store)
                            .id(i)
                            .onTapGesture { onPick(i) }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 18)
            }
            .onChange(of: model.selected) { new in
                withAnimation(.easeOut(duration: 0.12)) { proxy.scrollTo(new, anchor: .center) }
            }
        }
    }
}

@MainActor
struct ClipCard: View {
    let item: ClipItem
    let index: Int
    let selected: Bool
    let store: ClipboardStore

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.9))

            VStack(alignment: .leading, spacing: 6) {
                if item.kind == .image, let img = store.thumbnail(for: item) {
                    Image(nsImage: img)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    Text(item.text ?? "")
                        .font(.system(size: 11))
                        .lineLimit(7)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
                Text(item.kind == .image ? "Imagen" : "\((item.text ?? "").count) car.")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }
            .padding(10)

            if index < 9 {
                Text("\(index + 1)")
                    .font(.system(size: 10, weight: .bold))
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Capsule().fill(Color.accentColor.opacity(selected ? 1 : 0.35)))
                    .foregroundColor(.white)
                    .padding(6)
                    .frame(maxWidth: .infinity, alignment: .topTrailing)
            }
        }
        .frame(width: 120, height: 150)
        .overlay(RoundedRectangle(cornerRadius: 14)
            .stroke(Color.accentColor, lineWidth: selected ? 3 : 0))
        .scaleEffect(selected ? 1.05 : 1)
        .animation(.easeOut(duration: 0.1), value: selected)
    }
}
