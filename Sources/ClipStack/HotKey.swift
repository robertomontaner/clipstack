import AppKit
import ApplicationServices
import Carbon.HIToolbox

/// Atajo global con Carbon (no necesita permisos de accesibilidad).
final class HotKey {
    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    private let callback: () -> Void
    private(set) var registered = false

    init(keyCode: UInt32, modifiers: UInt32, callback: @escaping () -> Void) {
        self.callback = callback

        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                 eventKind: UInt32(kEventHotKeyPressed))
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        InstallEventHandler(GetApplicationEventTarget(), { _, _, userData in
            guard let userData else { return noErr }
            let hk = Unmanaged<HotKey>.fromOpaque(userData).takeUnretainedValue()
            DispatchQueue.main.async { hk.callback() }
            return noErr
        }, 1, &spec, selfPtr, &handlerRef)

        let id = EventHotKeyID(signature: OSType(0x434C4950), id: 1) // 'CLIP'
        let status = RegisterEventHotKey(keyCode, modifiers, id, GetApplicationEventTarget(), 0, &hotKeyRef)
        registered = (status == noErr)
    }

    deinit {
        if let r = hotKeyRef { UnregisterEventHotKey(r) }
        if let h = handlerRef { RemoveEventHandler(h) }
    }
}

/// Escucha global del teclado con CGEventTap (usa el permiso de Accesibilidad).
/// A diferencia de Carbon, admite atajos solo con ⌥ o ⇧⌥ (macOS 15+ los bloquea en Carbon)
/// y se "come" la pulsación para que no escriba ningún carácter.
final class EventTapHotKey {
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private let keyCode: Int64
    private let flags: CGEventFlags
    private let callback: () -> Void
    private(set) var active = false

    private static let relevant: CGEventFlags = [.maskCommand, .maskShift, .maskAlternate, .maskControl]

    init(keyCode: UInt32, modifiers: NSEvent.ModifierFlags, callback: @escaping () -> Void) {
        self.keyCode = Int64(keyCode)
        var f: CGEventFlags = []
        if modifiers.contains(.command) { f.insert(.maskCommand) }
        if modifiers.contains(.shift) { f.insert(.maskShift) }
        if modifiers.contains(.option) { f.insert(.maskAlternate) }
        if modifiers.contains(.control) { f.insert(.maskControl) }
        self.flags = f
        self.callback = callback

        let mask = CGEventMask(1 << CGEventType.keyDown.rawValue)
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        guard let t = CGEvent.tapCreate(tap: .cgSessionEventTap,
                                        place: .headInsertEventTap,
                                        options: .defaultTap,
                                        eventsOfInterest: mask,
                                        callback: { _, type, event, userInfo in
            guard let userInfo else { return Unmanaged.passUnretained(event) }
            let me = Unmanaged<EventTapHotKey>.fromOpaque(userInfo).takeUnretainedValue()
            return me.handle(type: type, event: event)
        }, userInfo: selfPtr) else { return }

        tap = t
        source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, t, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: t, enable: true)
        active = true
    }

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)
        }
        guard type == .keyDown,
              event.getIntegerValueField(.keyboardEventKeycode) == keyCode,
              event.flags.intersection(Self.relevant) == flags else {
            return Unmanaged.passUnretained(event)
        }
        if event.getIntegerValueField(.keyboardEventAutorepeat) == 0 {
            DispatchQueue.main.async { [callback] in callback() }
        }
        return nil   // nos comemos la pulsación
    }

    deinit {
        if let tap { CGEvent.tapEnable(tap: tap, enable: false) }
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
    }
}

/// Atajo global libre, grabado por el usuario.
struct Shortcut: Codable, Equatable {
    var keyCode: UInt32
    var modifiers: UInt      // NSEvent.ModifierFlags.rawValue (solo cmd/ctrl/opt/shift)
    var label: String

    static let `default` = Shortcut(
        keyCode: UInt32(kVK_ANSI_V),
        modifiers: NSEvent.ModifierFlags([.shift, .option]).rawValue,
        label: "V")

    var flags: NSEvent.ModifierFlags { NSEvent.ModifierFlags(rawValue: modifiers) }

    var carbonMods: UInt32 {
        var m: UInt32 = 0
        if flags.contains(.command) { m |= UInt32(cmdKey) }
        if flags.contains(.shift) { m |= UInt32(shiftKey) }
        if flags.contains(.option) { m |= UInt32(optionKey) }
        if flags.contains(.control) { m |= UInt32(controlKey) }
        return m
    }

    var display: String {
        var s = ""
        if flags.contains(.control) { s += "⌃" }
        if flags.contains(.option) { s += "⌥" }
        if flags.contains(.shift) { s += "⇧" }
        if flags.contains(.command) { s += "⌘" }
        return s + label
    }

    private static let fKeys: [Int: String] = [
        122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6",
        98: "F7", 100: "F8", 101: "F9", 109: "F10", 103: "F11", 111: "F12"
    ]

    static func label(for event: NSEvent) -> String {
        let code = Int(event.keyCode)
        if let f = fKeys[code] { return f }
        switch code {
        case kVK_Space: return "Espacio"
        case kVK_Return: return "↩"
        case kVK_Tab: return "⇥"
        case kVK_LeftArrow: return "←"
        case kVK_RightArrow: return "→"
        case kVK_UpArrow: return "↑"
        case kVK_DownArrow: return "↓"
        default: return (event.charactersIgnoringModifiers ?? "?").uppercased()
        }
    }
}

/// Pegado automático (simula ⌘V). Necesita permiso de Accesibilidad.
enum Paster {
    @discardableResult
    static func ensureAccessibility(prompt: Bool) -> Bool {
        let opts = ["AXTrustedCheckOptionPrompt": prompt] as CFDictionary
        return AXIsProcessTrustedWithOptions(opts)
    }

    static func pasteIntoFrontApp() {
        guard AXIsProcessTrusted() else { return }
        let src = CGEventSource(stateID: .combinedSessionState)
        let v = CGKeyCode(kVK_ANSI_V)
        let down = CGEvent(keyboardEventSource: src, virtualKey: v, keyDown: true)
        let up = CGEvent(keyboardEventSource: src, virtualKey: v, keyDown: false)
        down?.flags = .maskCommand
        up?.flags = .maskCommand
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }
}
