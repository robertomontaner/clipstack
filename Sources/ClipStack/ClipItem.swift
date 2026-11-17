import AppKit
import Foundation

enum ClipKind: String, Codable {
    case text
    case image
    case file
}

/// Subtipo detectado a partir del texto (solo para mostrarlo mejor).
enum TextFlavor {
    case plain
    case link(URL)
    case color(NSColor, String)
}

struct ClipItem: Identifiable, Codable, Equatable {
    var id = UUID()
    let kind: ClipKind
    var text: String?
    var rtf: Data?           // formato original (para pegar con estilos)
    var imageFile: String?   // PNG dentro de Application Support/ClipStack/images
    var filePaths: [String]? // archivos copiados desde Finder
    var hash: String         // para evitar duplicados
    var date: Date
    var pinned = false

    init(kind: ClipKind, text: String? = nil, rtf: Data? = nil, imageFile: String? = nil,
         filePaths: [String]? = nil, hash: String, date: Date) {
        self.kind = kind
        self.text = text
        self.rtf = rtf
        self.imageFile = imageFile
        self.filePaths = filePaths
        self.hash = hash
        self.date = date
    }

    // Decodificación tolerante: el historial de la v1 no tiene rtf, filePaths ni pinned.
    enum CodingKeys: String, CodingKey {
        case id, kind, text, rtf, imageFile, filePaths, hash, date, pinned
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        kind = try c.decode(ClipKind.self, forKey: .kind)
        text = try c.decodeIfPresent(String.self, forKey: .text)
        rtf = try c.decodeIfPresent(Data.self, forKey: .rtf)
        imageFile = try c.decodeIfPresent(String.self, forKey: .imageFile)
        filePaths = try c.decodeIfPresent([String].self, forKey: .filePaths)
        hash = try c.decode(String.self, forKey: .hash)
        date = try c.decode(Date.self, forKey: .date)
        pinned = try c.decodeIfPresent(Bool.self, forKey: .pinned) ?? false
    }

    // MARK: Presentación

    var flavor: TextFlavor {
        guard kind == .text, let raw = text?.trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty, raw.count < 2048, !raw.contains(where: \.isWhitespace) else { return .plain }
        if let color = Self.parseColor(raw) { return .color(color, raw) }
        if let url = URL(string: raw), let scheme = url.scheme?.lowercased(),
           ["http", "https"].contains(scheme), url.host != nil {
            return .link(url)
        }
        return .plain
    }

    /// Texto corto para listas y tarjetas.
    var title: String {
        switch kind {
        case .image: return "Imagen"
        case .file:
            let names = (filePaths ?? []).map { ($0 as NSString).lastPathComponent }
            if names.count <= 1 { return names.first ?? "Archivo" }
            return "\(names[0]) y \(names.count - 1) más"
        case .text:
            return (text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    var subtitle: String {
        switch kind {
        case .image: return "Imagen"
        case .file:
            let n = filePaths?.count ?? 0
            return n == 1 ? "Archivo" : "\(n) archivos"
        case .text:
            switch flavor {
            case .link(let u): return u.host ?? "Enlace"
            case .color: return "Color"
            case .plain: return "\((text ?? "").count) car." + (rtf != nil ? " · con formato" : "")
            }
        }
    }

    var symbol: String {
        switch kind {
        case .image: return "photo"
        case .file: return "doc"
        case .text:
            switch flavor {
            case .link: return "link"
            case .color: return "paintpalette"
            case .plain: return "text.alignleft"
            }
        }
    }

    /// Acepta #rgb, #rrggbb, #rrggbbaa (con o sin #) y rgb()/rgba().
    static func parseColor(_ s: String) -> NSColor? {
        let lower = s.lowercased()
        if lower.hasPrefix("rgb") {
            let nums = lower.drop(while: { $0 != "(" }).dropFirst().prefix(while: { $0 != ")" })
                .split(separator: ",").compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
            guard nums.count == 3 || nums.count == 4, nums.prefix(3).allSatisfy({ $0 >= 0 && $0 <= 255 }) else { return nil }
            return NSColor(srgbRed: nums[0] / 255, green: nums[1] / 255, blue: nums[2] / 255,
                           alpha: nums.count == 4 ? min(max(nums[3], 0), 1) : 1)
        }
        let hasHash = lower.hasPrefix("#")
        let hex = hasHash ? String(lower.dropFirst()) : lower
        // Sin "#" solo aceptamos 6 dígitos con alguna letra, para no confundir números.
        guard hex.allSatisfy(\.isHexDigit), [3, 6, 8].contains(hex.count) else { return nil }
        if !hasHash && (hex.count != 6 || hex.allSatisfy(\.isNumber)) { return nil }
        let full = hex.count == 3 ? hex.map { "\($0)\($0)" }.joined() : hex
        guard let v = UInt64(full, radix: 16) else { return nil }
        let hasAlpha = full.count == 8
        let r = Double((v >> (hasAlpha ? 24 : 16)) & 0xFF) / 255
        let g = Double((v >> (hasAlpha ? 16 : 8)) & 0xFF) / 255
        let b = Double((v >> (hasAlpha ? 8 : 0)) & 0xFF) / 255
        let a = hasAlpha ? Double(v & 0xFF) / 255 : 1
        return NSColor(srgbRed: r, green: g, blue: b, alpha: a)
    }
}
