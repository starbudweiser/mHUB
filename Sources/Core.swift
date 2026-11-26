// mHUB — briques communes : catalogue, comparaison de versions, commandes système, réseau GitHub.
import Foundation

struct CatalogApp: Codable, Identifiable, Hashable {
    struct Launch: Codable, Hashable { var url: String?; var args: [String]? }
    let id: String
    let name: String
    let bundleId: String
    let category: String
    var cats: [String]?   // catégories (plusieurs possibles) ; `category` reste pour les mHUB plus anciens
    var repo: String?
    let desc: [String: String]
    var settings: Launch?
    var presence: Bool?

    var allCats: [String] { cats ?? [category] }
    var text: String { desc[L.lang] ?? desc["en"] ?? "" }
}

struct Catalog: Codable {
    let version: Int
    let teamID: String
    let owner: String
    let apps: [CatalogApp]

    static let categories = ["system", "files", "creative", "video", "games", "comms", "ai", "virt"]

    static let remoteURL = URL(string: "https://raw.githubusercontent.com/starbudweiser/mHUB/main/Resources/catalogue.json")!
    private static let cacheKey = "catalogCache"

    private static func decode(_ data: Data) -> Catalog? {
        guard let c = try? JSONDecoder().decode(Catalog.self, from: data), !c.apps.isEmpty else { return nil }
        return c
    }

    /// Catalogue embarqué dans l'appli (secours hors ligne).
    static func embedded() -> Catalog {
        if let url = Bundle.main.url(forResource: "catalogue", withExtension: "json"),
           let data = try? Data(contentsOf: url), let c = decode(data) { return c }
        return Catalog(version: 0, teamID: "35KLMK53PN", owner: "starbudweiser", apps: [])
    }

    /// Le plus récent des deux : copie téléchargée la dernière fois, ou catalogue embarqué.
    static func load() -> Catalog {
        let emb = embedded()
        if let data = UserDefaults.standard.data(forKey: cacheKey), let c = decode(data), c.version > emb.version {
            return Catalog(version: c.version, teamID: emb.teamID, owner: emb.owner, apps: c.apps)
        }
        return emb
    }

    /// Télécharge le catalogue publié sur GitHub ; renvoie nil s'il n'est pas plus récent que `current`.
    /// L'équipe de signature et le propriétaire restent ceux de l'appli : le catalogue distant ne peut pas les changer.
    static func fetchNewer(than current: Catalog) async -> Catalog? {
        var req = URLRequest(url: remoteURL)
        req.setValue("mHUB", forHTTPHeaderField: "User-Agent")
        req.cachePolicy = .reloadIgnoringLocalCacheData
        req.timeoutInterval = 20
        guard let (data, resp) = try? await URLSession.shared.data(for: req),
              (resp as? HTTPURLResponse)?.statusCode == 200,
              let c = decode(data), c.version > current.version else { return nil }
        UserDefaults.standard.set(data, forKey: cacheKey)
        return Catalog(version: c.version, teamID: current.teamID, owner: current.owner, apps: c.apps)
    }
}

enum VersionCompare {
    /// « v1.10.0 » est plus récent que « 1.9.2 » : comparaison numérique champ par champ.
    static func isNewer(_ a: String, than b: String) -> Bool {
        let pa = parts(a), pb = parts(b)
        for i in 0..<max(pa.count, pb.count) {
            let x = i < pa.count ? pa[i] : 0, y = i < pb.count ? pb[i] : 0
            if x != y { return x > y }
        }
        return false
    }
    static func clean(_ v: String) -> String { v.trimmingCharacters(in: CharacterSet(charactersIn: "vV ")) }
    private static func parts(_ v: String) -> [Int] {
        clean(v).split(whereSeparator: { !$0.isNumber }).compactMap { Int($0) }
    }
}

enum HubError: LocalizedError {
    case release, download, signature, bundle, noApp, write, network
    var errorDescription: String? {
        switch self {
        case .release: return L.t("err.release")
        case .download: return L.t("err.download")
        case .signature: return L.t("err.signature")
        case .bundle: return L.t("err.bundle")
        case .noApp: return L.t("err.noApp")
        case .write: return L.t("err.write")
        case .network: return L.t("err.network")
        }
    }
}

struct Release: Equatable, Codable {
    let tag: String
    let version: String
    let asset: URL
    let size: Int64
    let date: Date?

    /// Dernière release publique d'un dépôt GitHub.
    static func fetch(owner: String, repo: String) async throws -> Release {
        guard let r = try await fetchConditional(owner: owner, repo: repo, etag: nil).release else { throw HubError.release }
        return r
    }

    /// Avec l'ETag de la dernière réponse, GitHub répond 304 (sans compter dans la limite de 60 requêtes par heure
    /// des appels anonymes) : `release` vaut alors nil et la copie en cache reste valable.
    static func fetchConditional(owner: String, repo: String, etag: String?) async throws -> (release: Release?, etag: String?) {
        var req = URLRequest(url: URL(string: "https://api.github.com/repos/\(owner)/\(repo)/releases/latest")!)
        req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        req.setValue("mHUB", forHTTPHeaderField: "User-Agent")
        req.timeoutInterval = 20
        req.cachePolicy = .reloadIgnoringLocalCacheData
        if let etag { req.setValue(etag, forHTTPHeaderField: "If-None-Match") }
        let (data, resp): (Data, URLResponse)
        do { (data, resp) = try await URLSession.shared.data(for: req) } catch { throw HubError.network }
        if (resp as? HTTPURLResponse)?.statusCode == 304 { return (nil, etag) }
        let newTag = (resp as? HTTPURLResponse)?.value(forHTTPHeaderField: "ETag")
        guard (resp as? HTTPURLResponse)?.statusCode == 200,
              let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tag = json["tag_name"] as? String else { throw HubError.release }
        let assets = (json["assets"] as? [[String: Any]] ?? []).filter { ($0["name"] as? String)?.hasSuffix(".zip") == true }
        let pick = assets.first { ($0["name"] as? String ?? "").contains("arm64") } ?? assets.first
        guard let a = pick, let s = a["browser_download_url"] as? String, let url = URL(string: s) else { throw HubError.release }
        let date = (json["published_at"] as? String).flatMap { ISO8601DateFormatter().date(from: $0) }
        return (Release(tag: tag, version: VersionCompare.clean(tag), asset: url, size: (a["size"] as? NSNumber)?.int64Value ?? 0, date: date), newTag)
    }
}

enum Support {
    /// Page de soutien (GitHub Sponsors) : facultatif, aucune fonction n'en dépend.
    static let url = URL(string: "https://github.com/sponsors/starbudweiser")!
}

enum Sh {
    /// Lance une commande ; renvoie code de sortie et sortie (standard + erreur).
    static func run(_ exe: String, _ args: [String]) async -> (code: Int32, out: String) {
        await withCheckedContinuation { cont in
            DispatchQueue.global().async {
                let p = Process(), pipe = Pipe()
                p.executableURL = URL(fileURLWithPath: exe); p.arguments = args
                p.standardOutput = pipe; p.standardError = pipe
                do { try p.run() } catch { cont.resume(returning: (-1, error.localizedDescription)); return }
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                p.waitUntilExit()
                cont.resume(returning: (p.terminationStatus, String(decoding: data, as: UTF8.self)))
            }
        }
    }
}

enum Net {
    private final class Box: @unchecked Sendable { var obs: NSKeyValueObservation? }

    /// Télécharge un fichier avec progression (0…1) ; renvoie un fichier temporaire stable.
    static func download(_ url: URL, progress: @escaping @Sendable (Double) -> Void) async throws -> URL {
        let box = Box()
        defer { box.obs = nil }
        return try await withCheckedThrowingContinuation { cont in
            var req = URLRequest(url: url)
            req.setValue("mHUB", forHTTPHeaderField: "User-Agent")
            let task = URLSession.shared.downloadTask(with: req) { tmp, resp, err in
                if err != nil { cont.resume(throwing: HubError.network); return }
                guard let tmp, (resp as? HTTPURLResponse)?.statusCode == 200 else { cont.resume(throwing: HubError.download); return }
                let dst = FileManager.default.temporaryDirectory.appendingPathComponent("mhub-\(UUID().uuidString).zip")
                do { try FileManager.default.moveItem(at: tmp, to: dst); cont.resume(returning: dst) }
                catch { cont.resume(throwing: HubError.download) }
            }
            box.obs = task.progress.observe(\.fractionCompleted) { p, _ in progress(p.fractionCompleted) }
            task.resume()
        }
    }
}

enum Verify {
    /// Résultat d'une vérification : appli valide, signée par la bonne équipe ; notarisée ou non.
    static func app(_ app: URL, bundleId: String, teamID: String) async throws -> Bool {
        let v = await Sh.run("/usr/bin/codesign", ["--verify", "--deep", "--strict", app.path])
        guard v.code == 0 else { throw HubError.signature }
        let info = await Sh.run("/usr/bin/codesign", ["-dv", "--verbose=2", app.path])
        guard info.out.contains("TeamIdentifier=\(teamID)") else { throw HubError.signature }
        guard let plist = NSDictionary(contentsOf: app.appendingPathComponent("Contents/Info.plist")),
              plist["CFBundleIdentifier"] as? String == bundleId else { throw HubError.bundle }
        let s = await Sh.run("/usr/sbin/spctl", ["--assess", "--type", "execute", app.path])
        return s.code == 0
    }

    /// Décompresse une archive et renvoie la première appli trouvée (celle du nom attendu en priorité).
    static func extract(zip: URL, into out: URL, preferring name: String) async throws -> URL {
        let r = await Sh.run("/usr/bin/ditto", ["-x", "-k", zip.path, out.path])
        guard r.code == 0 else { throw HubError.download }
        let items = (try? FileManager.default.contentsOfDirectory(at: out, includingPropertiesForKeys: nil)) ?? []
        let apps = items.filter { $0.pathExtension == "app" }
        guard let a = apps.first(where: { $0.deletingPathExtension().lastPathComponent == name }) ?? apps.first else { throw HubError.noApp }
        return a
    }
}

func formatSize(_ bytes: Int64) -> String {
    ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
}
