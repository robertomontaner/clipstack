import AppKit
import SwiftUI

/// Miniatura de un elemento: imagen, muestra de color, icono de archivo o símbolo.
@MainActor
struct ItemThumb: View {
    let item: ClipItem
    let store: ClipboardStore

    var body: some View {
        switch item.kind {
        case .image:
            if let img = store.thumbnail(for: item) {
                Image(nsImage: img).resizable().scaledToFit()
            } else {
                Image(systemName: "photo").foregroundStyle(.secondary)
            }
        case .file:
            if let first = item.filePaths?.first {
                Image(nsImage: NSWorkspace.shared.icon(forFile: first)).resizable().scaledToFit()
            } else {
                Image(systemName: "doc").foregroundStyle(.secondary)
            }
        case .text:
            if case .color(let c, _) = item.flavor {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(nsColor: c))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(.secondary.opacity(0.4)))
            } else {
                Image(systemName: item.symbol).foregroundStyle(.secondary)
            }
        }
    }
}

/// Vista previa grande (selector con Espacio, menú con el ojo o pulsación larga).
@MainActor
struct ItemPreview: View {
    let item: ClipItem
    let store: ClipboardStore

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: item.symbol)
                Text(item.subtitle).font(.caption).foregroundStyle(.secondary)
                Spacer()
                if item.pinned { Image(systemName: "pin.fill").foregroundStyle(.orange) }
            }
            content
        }
        .padding(14)
        .frame(width: 460, height: 340)
    }

    @ViewBuilder private var content: some View {
        switch item.kind {
        case .image:
            if let url = store.imageURL(for: item), let img = NSImage(contentsOf: url) {
                Image(nsImage: img).resizable().scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                Text("\(Int(img.size.width)) × \(Int(img.size.height)) px")
                    .font(.caption2).foregroundStyle(.secondary)
            }
        case .file:
            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(item.filePaths ?? [], id: \.self) { path in
                        HStack {
                            Image(nsImage: NSWorkspace.shared.icon(forFile: path))
                                .resizable().frame(width: 28, height: 28)
                            VStack(alignment: .leading) {
                                Text((path as NSString).lastPathComponent).font(.system(size: 12, weight: .medium))
                                Text(path).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        case .text:
            switch item.flavor {
            case .color(let c, let raw):
                RoundedRectangle(cornerRadius: 12).fill(Color(nsColor: c))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                Text(raw).font(.system(size: 14, design: .monospaced)).textSelection(.enabled)
            case .link(let url):
                Text(url.host ?? "").font(.title3.bold())
                Text(url.absoluteString).font(.system(size: 12)).textSelection(.enabled)
                Spacer()
                Button("Abrir en el navegador") { NSWorkspace.shared.open(url) }
            case .plain:
                ScrollView {
                    Text(item.text ?? "")
                        .font(.system(size: 12))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
}
