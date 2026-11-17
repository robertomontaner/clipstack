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
    @Published var all: [ClipItem] = []
    @Published var query = ""
    @Published var selected = 0
    @Published var previewing = false

    var items: [ClipItem] {
        guard !query.isEmpty else { return all }
        return all.filter { item in
            item.title.localizedCaseInsensitiveContains(query)
                || (item.text ?? "").localizedCaseInsensitiveContains(query)
                || (item.filePaths ?? []).contains { $0.localizedCaseInsensitiveContains(query) }
        }
    }
}

/// Selector rápido:
/// - Atajo: abre el panel (preselecciona el anterior al último copiado). Atajo otra vez: avanza.
/// - ← → navegan · 1-9 o Intro pegan · ⇧ + (1-9 / Intro) pegan sin formato.
/// - Escribir letras filtra · Espacio muestra la vista previa · ⌘P fija/desfija.
/// - Se queda abierto hasta pegar o cerrar (Esc o la X).
@MainActor
final class SwitcherController {
    private let store = ClipboardStore.shared
    private let model = SwitcherModel()
    private var panel: SwitcherPanel?
    private var keyMonitor: Any?

    var requiredFlags: NSEvent.ModifierFlags = [.shift, .option]

    private var isVisible: Bool { panel?.isVisible == true }

    private static let digitKeyCodes: [UInt16] = [18, 19, 20, 21, 23, 22, 26, 28, 25]
    private static let height: CGFloat = 250

    func trigger() {
        if isVisible { advance(1) } else { show() }
    }

    private func show() {
        guard !store.items.isEmpty else { NSSound.beep(); return }
        model.all = store.displayItems
        model.query = ""
        model.previewing = false
        // Preseleccionar el anterior al último copiado (el 2.º por fecha), esté fijado o no.
        if store.items.count > 1, let i = model.all.firstIndex(where: { $0.id == store.items[1].id }) {
            model.selected = i
        } else {
            model.selected = 0
        }

        let screen = NSScreen.screens.first { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) }
            ?? NSScreen.main ?? NSScreen.screens[0]
        let vf = screen.visibleFrame
        let w = min(vf.width - 80, max(520, CGFloat(model.all.count) * 132 + 40))
        let rect = NSRect(x: vf.midX - w / 2, y: vf.midY - Self.height / 2, width: w, height: Self.height)

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
                         onPick: { [weak self] i, plain in self?.commit(index: i, plain: plain) },
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
        let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let shift = mods.contains(.shift)

        switch Int(event.keyCode) {
        case kVK_Escape:
            if model.previewing { model.previewing = false }
            else if !model.query.isEmpty { setQuery("") }
            else { close() }
            return true
        case kVK_Return, kVK_ANSI_KeypadEnter:
            commit(index: model.selected, plain: shift); return true
        case kVK_LeftArrow, kVK_UpArrow:
            advance(-1); return true
        case kVK_RightArrow, kVK_DownArrow, kVK_Tab:
            advance(shift && Int(event.keyCode) == kVK_Tab ? -1 : 1); return true
        case kVK_Space:
            model.previewing.toggle(); return true
        case kVK_Delete:
            if !model.query.isEmpty { setQuery(String(model.query.dropLast())) }
            return true
        default:
            break
        }

        if mods.contains(.command) {
            if event.charactersIgnoringModifiers?.lowercased() == "p" { togglePinSelected() }
            return true
        }
        if let n = Self.digitKeyCodes.firstIndex(of: event.keyCode), !mods.contains(.option) {
            commit(index: n, plain: shift); return true
        }
        // Cualquier otro carácter imprimible filtra.
        if !mods.contains(.control), let chars = event.characters, !chars.isEmpty,
           chars.unicodeScalars.allSatisfy({ !CharacterSet.controlCharacters.contains($0) }) {
            setQuery(model.query + chars)
            return true
        }
        return true
    }

    private func setQuery(_ q: String) {
        model.query = q
        model.selected = 0
        model.previewing = false
    }

    private func advance(_ delta: Int) {
        let n = model.items.count
        guard n > 0 else { return }
        model.selected = (model.selected + delta + n) % n
    }

    private func togglePinSelected() {
        let items = model.items
        guard items.indices.contains(model.selected) else { return }
        let id = items[model.selected].id
        store.togglePin(items[model.selected])
        model.all = store.displayItems
        model.selected = model.items.firstIndex { $0.id == id } ?? 0
    }

    private func commit(index: Int, plain: Bool) {
        let items = model.items
        guard items.indices.contains(index) else { NSSound.beep(); return }
        close()
        store.copyToPasteboard(items[index], plain: plain)
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
    let onPick: (Int, Bool) -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                Text(model.query.isEmpty ? "Escribe para buscar" : model.query)
                    .font(.system(size: 12, weight: model.query.isEmpty ? .regular : .semibold))
                    .foregroundStyle(model.query.isEmpty ? .secondary : .primary)
                Spacer()
                Text("1-9/↩ pegar · ⇧ sin formato · espacio vista previa · ⌘P fijar")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Cerrar (Esc)")
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)

            if model.items.isEmpty {
                Text("Sin resultados").foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                cards
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .overlay {
            if model.previewing, model.items.indices.contains(model.selected) {
                ItemPreview(item: model.items[model.selected], store: store)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 22))
            }
        }
    }

    private var cards: some View {
        let items = model.items
        return ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { i, item in
                        ClipCard(item: item, index: i, selected: i == model.selected, store: store)
                            .id(item.id)
                            .onTapGesture { onPick(i, NSEvent.modifierFlags.contains(.shift)) }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 18)
            }
            .onChange(of: model.selected) { new in
                guard items.indices.contains(new) else { return }
                withAnimation(.easeOut(duration: 0.12)) { proxy.scrollTo(items[new].id, anchor: .center) }
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
                switch item.kind {
                case .image, .file:
                    ItemThumb(item: item, store: store)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    if item.kind == .file {
                        Text(item.title).font(.system(size: 10)).lineLimit(2)
                    }
                case .text:
                    switch item.flavor {
                    case .color:
                        ItemThumb(item: item, store: store)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        Text(item.title).font(.system(size: 11, design: .monospaced)).lineLimit(1)
                    case .link(let url):
                        Image(systemName: "link").foregroundStyle(.secondary)
                        Text(url.host ?? "").font(.system(size: 12, weight: .semibold)).lineLimit(2)
                        Text(url.absoluteString).font(.system(size: 9)).foregroundStyle(.secondary)
                            .lineLimit(4)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    case .plain:
                        Text(item.text ?? "")
                            .font(.system(size: 11))
                            .lineLimit(7)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    }
                }
                Text(item.subtitle)
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .padding(10)
            .padding(.top, 8)

            HStack {
                if item.pinned {
                    Image(systemName: "pin.fill").font(.system(size: 9)).foregroundStyle(.orange)
                }
                Spacer()
                if index < 9 {
                    Text("\(index + 1)")
                        .font(.system(size: 10, weight: .bold))
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Capsule().fill(Color.accentColor.opacity(selected ? 1 : 0.35)))
                        .foregroundColor(.white)
                }
            }
            .padding(6)
        }
        .frame(width: 120, height: 160)
        .overlay(RoundedRectangle(cornerRadius: 14)
            .stroke(Color.accentColor, lineWidth: selected ? 3 : 0))
        .scaleEffect(selected ? 1.05 : 1)
        .animation(.easeOut(duration: 0.1), value: selected)
    }
}
