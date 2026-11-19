// mHUB — état central : catalogue, applis installées, versions disponibles, installations et mises à jour.
import AppKit
import ServiceManagement

enum AppStatus: Equatable {
    case notInstalled, unavailable, upToDate, update(String), noRepo
}

enum TaskState: Equatable {
    case preparing, downloading(Double), verifying, installing, waitQuit
    case failed(String), done(String)
}

struct InstalledApp { let url: URL; let version: String }

enum Prefs {
    static let d = UserDefaults.standard
    static var autoInstall: Bool {
        get { d.object(forKey: "autoInstall") as? Bool ?? !(Bundle.main.bundleIdentifier?.hasSuffix(".dev") ?? false) }
        set { d.set(newValue, forKey: "autoInstall") }
    }
    static var dailyCheck: Bool {
        get { d.object(forKey: "dailyCheck") as? Bool ?? true }
        set { d.set(newValue, forKey: "dailyCheck") }
    }
    static var lastCheck: Date? {
        get { d.object(forKey: "lastCheck") as? Date }
        set { d.set(newValue, forKey: "lastCheck") }
    }
    static var installDir: URL {
        get {
            if let p = d.string(forKey: "installDir") { return URL(fileURLWithPath: p) }
            return FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications/Applications Personnelles")
        }
        set { d.set(newValue.path, forKey: "installDir") }
    }
}

@MainActor
final class Store: ObservableObject {
    static let shared = Store()

    let catalog = Catalog.load()
    @Published private(set) var installed: [String: InstalledApp] = [:]
    @Published private(set) var releases: [String: Release] = [:]
    @Published private(set) var tasks: [String: TaskState] = [:]
    @Published private(set) var checking = false
    @Published private(set) var lastCheck: Date? = Prefs.lastCheck
    @Published private(set) var running: Set<String> = []

    private struct Pending { let app: URL; let work: URL; let notarized: Bool }
    private var pending: [String: Pending] = [:]
    private var timer: Timer?

    var apps: [CatalogApp] { catalog.apps }

    // MARK: Démarrage

    func start() {
        scan()
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didLaunchApplicationNotification, object: nil, queue: .main) { _ in Task { @MainActor in Store.shared.refreshRunning() } }
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didTerminateApplicationNotification, object: nil, queue: .main) { _ in Task { @MainActor in Store.shared.refreshRunning() } }
        refreshRunning()
        timer = Timer.scheduledTimer(withTimeInterval: 1800, repeats: true) { _ in Task { @MainActor in Store.shared.tick() } }
        tick()
    }

    /// Une vérification par jour (sauf mode manuel), puis installation automatique des mises à jour.
    func tick() {
        if Prefs.dailyCheck, Date().timeIntervalSince(lastCheck ?? .distantPast) > 24 * 3600 { Task { await checkAll() } }
        installPendingAutomatically()
    }

    // MARK: Applis installées

    private var searchDirs: [URL] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return [Prefs.installDir, home.appendingPathComponent("Applications/Applications Personnelles"),
                home.appendingPathComponent("Applications"), URL(fileURLWithPath: "/Applications")]
    }

    func scan() {
        var found: [String: InstalledApp] = [:]
        let wanted = Set(apps.map(\.bundleId))
        for dir in searchDirs {
            let items = (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? []
            for u in items where u.pathExtension == "app" {
                guard let b = Bundle(url: u), let id = b.bundleIdentifier, wanted.contains(id), found[id] == nil else { continue }
                found[id] = InstalledApp(url: u, version: b.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?")
            }
        }
        installed = found
    }

    func refreshRunning() {
        running = Set(apps.filter { !NSRunningApplication.runningApplications(withBundleIdentifier: $0.bundleId).isEmpty }.map(\.bundleId))
    }

    func isRunning(_ a: CatalogApp) -> Bool { running.contains(a.bundleId) }

    func status(_ a: CatalogApp) -> AppStatus {
        if let i = installed[a.bundleId] {
            if let r = releases[a.id], VersionCompare.isNewer(r.version, than: i.version) { return .update(r.version) }
            return a.repo == nil ? .noRepo : .upToDate
        }
        return a.repo == nil ? .unavailable : .notInstalled
    }

    var installedApps: [CatalogApp] { apps.filter { installed[$0.bundleId] != nil } }
    var updatable: [CatalogApp] { apps.filter { if case .update = status($0) { return true }; return false } }
    var activeTasks: [CatalogApp] { apps.filter { tasks[$0.id] != nil } }

    // MARK: Vérification des versions

    func checkAll() async {
        guard !checking else { return }
        checking = true
        defer { checking = false }
        scan()
        await withTaskGroup(of: (String, Release?).self) { group in
            for a in apps {
                guard let repo = a.repo else { continue }
                let owner = catalog.owner
                group.addTask { (a.id, try? await Release.fetch(owner: owner, repo: repo)) }
            }
            for await (id, r) in group { if let r { releases[id] = r } }
        }
        lastCheck = Date(); Prefs.lastCheck = lastCheck
        installPendingAutomatically()
    }

    private func installPendingAutomatically() {
        guard Prefs.autoInstall else { return }
        for a in updatable where tasks[a.id] == nil && !isRunning(a) { install(a) }
    }

    // MARK: Installation et mise à jour

    func install(_ a: CatalogApp) {
        if let t = tasks[a.id], !isFailed(t) { return }
        Task { await perform(a) }
    }

    func updateAll() { for a in updatable { install(a) } }

    private func isFailed(_ t: TaskState) -> Bool { if case .failed = t { return true }; return false }

    private func perform(_ a: CatalogApp) async {
        guard let repo = a.repo else { return }
        tasks[a.id] = .preparing
        do {
            let rel: Release
            if let r = releases[a.id] { rel = r } else { rel = try await Release.fetch(owner: catalog.owner, repo: repo) }
            releases[a.id] = rel
            tasks[a.id] = .downloading(0)
            let id = a.id
            let zip = try await Net.download(rel.asset) { p in Task { @MainActor in Store.shared.progress(id, p) } }
            defer { try? FileManager.default.removeItem(at: zip) }
            tasks[a.id] = .verifying
            let work = FileManager.default.temporaryDirectory.appendingPathComponent("mhub-\(UUID().uuidString)")
            try FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)
            let app = try await Verify.extract(zip: zip, into: work, preferring: a.name)
            let notarized: Bool
            do { notarized = try await Verify.app(app, bundleId: a.bundleId, teamID: catalog.teamID) }
            catch { try? FileManager.default.removeItem(at: work); throw error }
            pending[a.id] = Pending(app: app, work: work, notarized: notarized)
            if isRunning(a) { tasks[a.id] = .waitQuit; return }
            try await swap(a, relaunch: false)
        } catch {
            tasks[a.id] = .failed(error.localizedDescription)
        }
    }

    private func progress(_ id: String, _ p: Double) {
        if case .downloading = tasks[id] { tasks[id] = .downloading(p) }
    }

    /// Quitte l'appli ouverte, installe la nouvelle version, puis la relance sans prendre le focus.
    func quitAndUpdate(_ a: CatalogApp) {
        Task {
            guard pending[a.id] != nil else { return }
            tasks[a.id] = .installing
            NSRunningApplication.runningApplications(withBundleIdentifier: a.bundleId).forEach { $0.terminate() }
            for _ in 0..<50 where isRunningNow(a) { try? await Task.sleep(nanoseconds: 300_000_000) }
            if isRunningNow(a) { tasks[a.id] = .waitQuit; return }
            do { try await swap(a, relaunch: true) } catch { tasks[a.id] = .failed(error.localizedDescription) }
        }
    }

    private func isRunningNow(_ a: CatalogApp) -> Bool { !NSRunningApplication.runningApplications(withBundleIdentifier: a.bundleId).isEmpty }

    private func swap(_ a: CatalogApp, relaunch: Bool) async throws {
        guard let p = pending[a.id] else { return }
        tasks[a.id] = .installing
        let fm = FileManager.default
        let dest = installed[a.bundleId]?.url ?? Prefs.installDir.appendingPathComponent(p.app.lastPathComponent)
        do {
            try fm.createDirectory(at: dest.deletingLastPathComponent(), withIntermediateDirectories: true)
            if fm.fileExists(atPath: dest.path) { try fm.removeItem(at: dest) }
        } catch { throw HubError.write }
        let c = await Sh.run("/usr/bin/ditto", [p.app.path, dest.path])
        guard c.code == 0 else { throw HubError.write }
        _ = await Sh.run("/usr/bin/xattr", ["-dr", "com.apple.quarantine", dest.path])
        try? fm.removeItem(at: p.work)
        pending[a.id] = nil
        scan()
        tasks[a.id] = .done(L.t(p.notarized ? "task.signedNotarized" : "task.signed"))
        if relaunch {
            let cfg = NSWorkspace.OpenConfiguration(); cfg.activates = false
            NSWorkspace.shared.openApplication(at: dest, configuration: cfg) { _, _ in }
        }
        let id = a.id
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) { Task { @MainActor in
            if case .done = Store.shared.tasks[id] { Store.shared.tasks[id] = nil }
        } }
    }

    func dismiss(_ a: CatalogApp) {
        if let p = pending[a.id] { try? FileManager.default.removeItem(at: p.work); pending[a.id] = nil }
        tasks[a.id] = nil
    }

    // MARK: Lancement

    func open(_ a: CatalogApp) {
        guard let i = installed[a.bundleId] else { return }
        NSWorkspace.shared.openApplication(at: i.url, configuration: NSWorkspace.OpenConfiguration()) { _, _ in }
    }

    func quit(_ a: CatalogApp) {
        NSRunningApplication.runningApplications(withBundleIdentifier: a.bundleId).forEach { $0.terminate() }
    }

    func reveal(_ a: CatalogApp) {
        if let i = installed[a.bundleId] { NSWorkspace.shared.activateFileViewerSelecting([i.url]) }
    }

    func canOpenSettings(_ a: CatalogApp) -> Bool { a.settings != nil && installed[a.bundleId] != nil }

    /// Réglages d'une appli : schéma d'URL ou argument de lancement déclaré dans le catalogue.
    func openSettings(_ a: CatalogApp) {
        guard let s = a.settings, let i = installed[a.bundleId] else { return }
        if let u = s.url, let url = URL(string: u) { NSWorkspace.shared.open(url); return }
        if let args = s.args {
            if let r = NSRunningApplication.runningApplications(withBundleIdentifier: a.bundleId).first { r.activate(); return }
            let cfg = NSWorkspace.OpenConfiguration(); cfg.arguments = args; cfg.activates = true
            NSWorkspace.shared.openApplication(at: i.url, configuration: cfg) { _, _ in }
        }
    }

    // MARK: Présence des applis (icône de la barre des menus)

    func menuBarIconOn(_ a: CatalogApp) -> Bool { Prefs.d.object(forKey: "presence." + a.bundleId) as? Bool ?? true }

    func setMenuBarIcon(_ a: CatalogApp, _ on: Bool) {
        Prefs.d.set(on, forKey: "presence." + a.bundleId)
        DistributedNotificationCenter.default().postNotificationName(Notification.Name("fr.stephan.toolkit.presence"), object: nil,
            userInfo: ["app": a.bundleId, "visible": on], deliverImmediately: true)
        objectWillChange.send()
    }

    // MARK: Ouverture de session

    var launchAtLogin: Bool { SMAppService.mainApp.status == .enabled }
    func setLaunchAtLogin(_ on: Bool) {
        do { if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() } } catch {}
        objectWillChange.send()
    }

    func setInstallDir(_ u: URL) { Prefs.installDir = u; scan(); objectWillChange.send() }
}
