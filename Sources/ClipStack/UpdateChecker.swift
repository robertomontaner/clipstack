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

    func download() {
        guard let r = available else { return }
        NSWorkspace.shared.open(r.dmg ?? r.page)
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
