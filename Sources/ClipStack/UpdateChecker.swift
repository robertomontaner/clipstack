import AppKit
import Foundation

/// Comprueba en GitHub Releases si hay una versión más nueva (al arrancar y cada 24 h).
@MainActor
final class UpdateChecker: ObservableObject {
    static let shared = UpdateChecker()
    static let repo = "robertomontaner/clipstack"

    struct Release { let version: String; let page: URL; let dmg: URL? }

    @Published private(set) var available: Release?
    @Published private(set) var status = ""
    @Published private(set) var checking = false

    private var timer: Timer?

    var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    }

    func start() {
        check(manual: false)
        timer = Timer.scheduledTimer(withTimeInterval: 24 * 3600, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.check(manual: false) }
        }
    }

    func check(manual: Bool) {
        guard !checking else { return }
        checking = true
        if manual { status = "Buscando…" }
        var req = URLRequest(url: URL(string: "https://api.github.com/repos/\(Self.repo)/releases/latest")!)
        req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        req.setValue("ClipStack", forHTTPHeaderField: "User-Agent")
        req.timeoutInterval = 15

        URLSession.shared.dataTask(with: req) { data, response, _ in
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            var found: Release?
            if code == 200, let data,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let tag = json["tag_name"] as? String,
               let page = (json["html_url"] as? String).flatMap(URL.init(string:)) {
                let dmg = (json["assets"] as? [[String: Any]])?
                    .first { ($0["name"] as? String)?.hasSuffix(".dmg") == true }
                    .flatMap { ($0["browser_download_url"] as? String).flatMap(URL.init(string:)) }
                found = Release(version: tag.hasPrefix("v") ? String(tag.dropFirst()) : tag, page: page, dmg: dmg)
            }
            let result = found
            Task { @MainActor in self.finish(result, code: code, manual: manual) }
        }.resume()
    }

    private func finish(_ release: Release?, code: Int, manual: Bool) {
        checking = false
        guard let release else {
            available = nil
            status = code == 404 ? "Aún no hay versiones publicadas" : "No se pudo comprobar"
            return
        }
        if Self.isNewer(release.version, than: currentVersion) {
            available = release
            status = "Hay una versión nueva: v\(release.version)"
        } else {
            available = nil
            status = "Tienes la última versión (v\(currentVersion))"
        }
    }

    /// Abre la página de la Release (novedades / descarga manual).
    func openReleasePage() {
        guard let r = available else { return }
        NSWorkspace.shared.open(r.page)
    }

    // MARK: - Instalación automática

    @Published private(set) var installing = false

    /// Descarga el DMG, sustituye la app instalada, quita la cuarentena y la vuelve a abrir.
    /// Si algo no se puede hacer (sin DMG, carpeta sin permisos), abre la descarga para hacerlo a mano.
    func installUpdate() {
        guard let r = available, !installing else { return }
        guard let dmg = r.dmg, Self.isTrustedHost(dmg) else { NSWorkspace.shared.open(r.page); return }

        let dest = Bundle.main.bundleURL
        guard dest.pathExtension == "app",
              FileManager.default.isWritableFile(atPath: dest.deletingLastPathComponent().path) else {
            status = "No tengo permiso para escribir en \(dest.deletingLastPathComponent().path). Descárgala a mano."
            NSWorkspace.shared.open(dmg)
            return
        }

        installing = true
        status = "Descargando v\(r.version)…"
        URLSession.shared.downloadTask(with: dmg) { tmp, response, _ in
            let ok = (response as? HTTPURLResponse)?.statusCode == 200
            var saved: URL?
            if ok, let tmp {
                let dir = FileManager.default.temporaryDirectory
                    .appendingPathComponent("ClipStackUpdate-\(UUID().uuidString)", isDirectory: true)
                try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
                let target = dir.appendingPathComponent("ClipStack.dmg")
                if (try? FileManager.default.moveItem(at: tmp, to: target)) != nil { saved = target }
            }
            let file = saved
            Task { @MainActor in self.runInstaller(dmg: file, dest: dest, version: r.version) }
        }.resume()
    }

    private func runInstaller(dmg: URL?, dest: URL, version: String) {
        guard let dmg else {
            installing = false
            status = "No se pudo descargar la actualización"
            return
        }
        status = "Instalando v\(version)…"

        // Script que espera a que ClipStack se cierre, cambia la app y la reabre.
        let script = """
        #!/bin/bash
        DMG="$1"; DEST="$2"; PID="$3"
        MNT=$(mktemp -d /tmp/clipstack-mnt.XXXXXX)
        if ! hdiutil attach "$DMG" -nobrowse -readonly -mountpoint "$MNT" -quiet; then open "$DMG"; exit 1; fi
        if [ ! -d "$MNT/ClipStack.app" ]; then hdiutil detach "$MNT" -quiet; open "$DMG"; exit 1; fi
        while kill -0 "$PID" 2>/dev/null; do sleep 0.2; done
        rm -rf "$DEST.old"
        mv "$DEST" "$DEST.old"
        if ditto "$MNT/ClipStack.app" "$DEST"; then
          rm -rf "$DEST.old"
          xattr -cr "$DEST" 2>/dev/null
          tccutil reset Accessibility com.roberto.clipstack >/dev/null 2>&1
        else
          rm -rf "$DEST"; mv "$DEST.old" "$DEST"
        fi
        hdiutil detach "$MNT" -quiet
        rm -rf "$(dirname "$DMG")"
        open "$DEST" --args --updated
        """
        let scriptURL = dmg.deletingLastPathComponent().appendingPathComponent("install.sh")
        do {
            try script.write(to: scriptURL, atomically: true, encoding: .utf8)
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/bin/bash")
            p.arguments = [scriptURL.path, dmg.path, dest.path, String(ProcessInfo.processInfo.processIdentifier)]
            try p.run()
        } catch {
            installing = false
            status = "No se pudo instalar; abriendo el DMG"
            NSWorkspace.shared.open(dmg)
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { NSApp.terminate(nil) }
    }

    private static func isTrustedHost(_ url: URL) -> Bool {
        guard url.scheme == "https", let host = url.host?.lowercased() else { return false }
        return host == "github.com" || host.hasSuffix(".githubusercontent.com")
    }

    /// Compara versiones tipo 1.2.10 numéricamente.
    static func isNewer(_ a: String, than b: String) -> Bool {
        let pa = a.split(separator: ".").map { Int($0) ?? 0 }
        let pb = b.split(separator: ".").map { Int($0) ?? 0 }
        for i in 0..<max(pa.count, pb.count) {
            let x = i < pa.count ? pa[i] : 0, y = i < pb.count ? pb[i] : 0
            if x != y { return x > y }
        }
        return false
    }
}
