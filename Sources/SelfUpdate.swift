// mHUB — mise à jour de mHUB lui-même depuis ses releases GitHub (même méthode que les autres applis du kit).
import AppKit

@MainActor
final class SelfUpdate: ObservableObject {
    static let shared = SelfUpdate()

    enum State: Equatable { case idle, checking, upToDate, available(String), downloading, failed(String) }

    static let prodID = "fr.stephan.mhub"
    @Published private(set) var state: State = .idle
    private var release: Release?

    var currentVersion: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0" }
    /// L'édition de développement ne s'écrase jamais avec la version publiée.
    var isDev: Bool { Bundle.main.bundleIdentifier?.hasSuffix(".dev") == true }

    var message: String? {
        switch state {
        case .idle: return nil
        case .checking, .downloading: return L.t("self.checking")
        case .upToDate: return L.t("self.upToDate", currentVersion)
        case .available(let v): return L.t("self.available", v)
        case .failed(let m): return L.t("self.failed", m)
        }
    }

    /// Une recherche par jour ; installation automatique si le réglage est actif et qu'aucune installation d'appli n'est en cours.
    func tick() {
        let last = UserDefaults.standard.object(forKey: "selfLastCheck") as? Date ?? .distantPast
        if Prefs.dailyCheck, Date().timeIntervalSince(last) > 24 * 3600, state != .checking { Task { await check() } }
        if Prefs.autoInstall, !isDev, case .available = state, Store.shared.activeTasks.isEmpty { Task { await install() } }
    }

    func check() async {
        state = .checking
        do {
            let r = try await Release.fetch(owner: "starbudweiser", repo: "mHUB")
            UserDefaults.standard.set(Date(), forKey: "selfLastCheck")
            release = r
            state = VersionCompare.isNewer(r.version, than: currentVersion) ? .available(r.version) : .upToDate
        } catch HubError.release {
            state = .upToDate      // pas encore de release publiée
        } catch {
            state = .failed(error.localizedDescription)
        }
        tick()
    }

    func install() async {
        guard !isDev, case .available = state, let r = release else { return }
        state = .downloading
        do {
            let zip = try await Net.download(r.asset) { _ in }
            defer { try? FileManager.default.removeItem(at: zip) }
            let work = FileManager.default.temporaryDirectory.appendingPathComponent("mhub-self-\(UUID().uuidString)")
            try FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)
            let app = try await Verify.extract(zip: zip, into: work, preferring: "mHUB")
            _ = try await Verify.app(app, bundleId: Self.prodID, teamID: Store.shared.catalog.teamID)
            try Self.swapAndRelaunch(new: app, work: work)
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    /// Un petit script détaché attend la fin de l'appli, remplace le paquet puis relance la nouvelle version.
    private static func swapAndRelaunch(new: URL, work: URL) throws {
        let target = Bundle.main.bundlePath
        let script = work.appendingPathComponent("swap.sh")
        let body = """
        #!/bin/sh
        while kill -0 \(ProcessInfo.processInfo.processIdentifier) 2>/dev/null; do sleep 0.3; done
        rm -rf "\(target)" && /usr/bin/ditto "\(new.path)" "\(target)" && /usr/bin/xattr -dr com.apple.quarantine "\(target)" && /usr/bin/open -g "\(target)"
        rm -rf "\(work.path)"
        """
        try body.write(to: script, atomically: true, encoding: .utf8)
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/sh"); p.arguments = [script.path]
        p.standardOutput = FileHandle.nullDevice; p.standardError = FileHandle.nullDevice
        try p.run()
        NSApp.terminate(nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { exit(0) }
    }
}
