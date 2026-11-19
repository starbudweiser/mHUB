// mHUB — fenêtre principale : bibliothèque, catalogue, fiche, activité.
import SwiftUI
import AppKit

enum Filter: Hashable {
    case all, installed, updates, notInstalled, activity
    case category(String)
}

struct RootView: View {
    @EnvironmentObject private var store: Store
    @State private var filter: Filter = .all
    @State private var search = ""
    @State private var sortByStatus = false
    @State private var selectedID: String?

    var body: some View {
        VStack(spacing: 0) {
            TopBar()
            HStack(spacing: 0) {
                Sidebar(filter: $filter)
                if filter == .activity {
                    ActivityView().padding(16)
                } else {
                    HStack(alignment: .top, spacing: 14) {
                        VStack(spacing: 12) {
                            HStack(spacing: 8) {
                                HStack {
                                    Image(systemName: "magnifyingglass").foregroundStyle(T.text2)
                                    TextField(L.t("search"), text: $search).textFieldStyle(.plain)
                                }
                                .padding(.horizontal, 12).padding(.vertical, 8)
                                .background(T.ctl, in: RoundedRectangle(cornerRadius: T.rCtl))
                                Button(sortByStatus ? L.t("sort.status") : L.t("sort.name")) { sortByStatus.toggle() }
                                    .buttonStyle(HubButtonStyle())
                            }
                            ScrollView {
                                LazyVGrid(columns: [GridItem(.adaptive(minimum: 230), spacing: 10)], spacing: 10) {
                                    ForEach(list) { a in
                                        AppCard(app: a, selected: selectedID == a.id).onTapGesture { selectedID = a.id }
                                    }
                                }.padding(.bottom, 6)
                            }
                        }
                        DetailView(app: selectedApp).frame(width: 320)
                    }
                    .padding(.horizontal, 16).padding(.bottom, 16)
                }
            }
        }
        .background(T.bg)
        .foregroundStyle(T.text)
        .onAppear { if selectedID == nil { selectedID = list.first?.id } }
    }

    private var selectedApp: CatalogApp? { store.apps.first { $0.id == selectedID } }

    private var list: [CatalogApp] {
        let q = search.trimmingCharacters(in: .whitespaces).lowercased()
        return store.apps.filter { a in
            switch filter {
            case .all, .activity: break
            case .installed: if store.installed[a.bundleId] == nil { return false }
            case .updates: if case .update = store.status(a) {} else { return false }
            case .notInstalled: if store.installed[a.bundleId] != nil { return false }
            case .category(let c): if a.category != c { return false }
            }
            return q.isEmpty || a.name.lowercased().contains(q) || a.text.lowercased().contains(q)
        }
        .sorted { x, y in
            if sortByStatus {
                let rx = rank(x), ry = rank(y)
                if rx != ry { return rx < ry }
            }
            return sortKey(x) < sortKey(y)
        }
    }

    /// Clé de tri par nom ; les applis liées (iCONIQ et MiCONE) restent côte à côte.
    private func sortKey(_ a: CatalogApp) -> String {
        a.id == "MiCONE" ? "iconiq~" : a.name.lowercased()
    }

    private func rank(_ a: CatalogApp) -> Int {
        switch store.status(a) {
        case .update: return 0
        case .upToDate, .noRepo: return 1
        case .notInstalled: return 2
        case .unavailable: return 3
        }
    }
}

// MARK: Barre du haut

struct TopBar: View {
    @EnvironmentObject private var store: Store

    var body: some View {
        HStack(spacing: 10) {
            brandName(size: 16)
            Text("DESKTOP MAC TOOLKIT").font(.system(size: 11, weight: .medium)).foregroundStyle(T.text2)
            Spacer()
            Text(L.t("checked", store.lastCheck.map { L.ago($0) } ?? L.t("never"))).font(.system(size: 12)).foregroundStyle(T.text2)
            Button(store.checking ? L.t("btn.checking") : L.t("btn.check")) { Task { await store.checkAll() } }
                .buttonStyle(HubButtonStyle()).disabled(store.checking)
            Button { Windows.showSettings() } label: { Image(systemName: "gearshape") }.buttonStyle(HubButtonStyle())
        }
        .padding(.leading, 84).padding(.trailing, 16).padding(.top, 10).padding(.bottom, 12)
    }
}

// MARK: Barre latérale

struct Sidebar: View {
    @EnvironmentObject private var store: Store
    @Binding var filter: Filter

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            header(L.t("nav.library"))
            item(L.t("nav.all"), .all, store.apps.count)
            item(L.t("nav.installed"), .installed, store.installedApps.count)
            item(L.t("nav.updates"), .updates, store.updatable.count)
            item(L.t("nav.notInstalled"), .notInstalled, store.apps.count - store.installedApps.count)
            if !store.activeTasks.isEmpty { item(L.t("nav.activity"), .activity, store.activeTasks.count) }
            header(L.t("nav.categories"))
            ForEach(Catalog.categories, id: \.self) { c in
                item(L.t("cat." + c), .category(c), store.apps.filter { $0.category == c }.count)
            }
            Spacer()
            VStack(alignment: .center, spacing: 6) {
                Text(store.updatable.isEmpty ? L.t("upd.none") : L.t("upd.count", store.updatable.count)).font(.system(size: 13, weight: .semibold))
                if !store.updatable.isEmpty {
                    Text(store.updatable.map(\.name).joined(separator: " · ")).font(.system(size: 12)).foregroundStyle(T.text2).lineLimit(2)
                    Button(L.t("btn.updateAll")) { store.updateAll() }.buttonStyle(HubButtonStyle(kind: .primary, small: true))
                }
            }
            .multilineTextAlignment(.center).frame(maxWidth: .infinity, alignment: .center).padding(12)
            .background(T.card, in: RoundedRectangle(cornerRadius: T.rBox))
        }
        .padding(14).frame(width: 224)
    }

    private func header(_ s: String) -> some View {
        Text(s.uppercased()).font(.system(size: 11, weight: .semibold)).foregroundStyle(T.text2).padding(.top, 10).padding(.bottom, 4).padding(.leading, 4)
    }

    private func item(_ title: String, _ f: Filter, _ count: Int) -> some View {
        Button { filter = f } label: {
            HStack {
                Text(title).lineLimit(1)
                Spacer()
                Text("\(count)").font(.system(size: 12)).opacity(0.7)
            }
            .padding(.horizontal, 10).padding(.vertical, 7)
            .foregroundStyle(filter == f ? Color.white : T.text)
            .background(filter == f ? T.acc : Color.clear, in: RoundedRectangle(cornerRadius: T.rCtl))
            .contentShape(Rectangle())
        }.buttonStyle(.plain)
    }
}

// MARK: Cartes

struct StatusTag: View {
    @EnvironmentObject private var store: Store
    let app: CatalogApp
    var body: some View {
        switch store.status(app) {
        case .upToDate: Pill(text: "✓ " + L.t("status.upToDate"), tone: .ok)
        case .update(let v): Pill(text: L.t("status.update", v), tone: .warn)
        case .notInstalled: Pill(text: L.t("status.notInstalled"))
        case .unavailable: Pill(text: L.t("status.unavailable"))
        case .noRepo: Pill(text: L.t("status.noRepo"), tone: .ok)
        }
    }
}

struct AppCard: View {
    @EnvironmentObject private var store: Store
    let app: CatalogApp
    let selected: Bool

    var body: some View {
        Card(selected: selected) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    AppIcon(app: app, size: 40)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(app.name).font(.system(size: 14, weight: .semibold))
                        StatusTag(app: app)
                    }
                }
                Text(app.text).font(.system(size: 12)).foregroundStyle(T.text2).lineLimit(5, reservesSpace: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Spacer(minLength: 0)
                Actions(app: app, compact: true)
            }
            .frame(maxWidth: .infinity, minHeight: 190, alignment: .leading)
        }
    }
}

/// Boutons d'une appli, ou avancement de son installation.
struct Actions: View {
    @EnvironmentObject private var store: Store
    let app: CatalogApp
    var compact = false

    var body: some View {
        if let t = store.tasks[app.id] {
            TaskRow(app: app, state: t)
        } else {
            HStack(spacing: 8) {
                switch store.status(app) {
                case .notInstalled:
                    Button(L.t("btn.install")) { store.install(app) }.buttonStyle(HubButtonStyle(kind: .primary, small: compact, fill: compact))
                case .update:
                    Button(L.t("btn.open")) { store.open(app) }.buttonStyle(HubButtonStyle(small: compact, fill: compact))
                    Button(L.t("btn.update")) { store.install(app) }.buttonStyle(HubButtonStyle(kind: .primary, small: compact, fill: compact))
                case .upToDate, .noRepo:
                    Button(L.t("btn.open")) { store.open(app) }.buttonStyle(HubButtonStyle(small: compact, fill: compact))
                    if store.canOpenSettings(app) { Button(L.t("btn.settings")) { store.openSettings(app) }.buttonStyle(HubButtonStyle(small: compact, fill: compact)) }
                case .unavailable:
                    EmptyView()
                }
            }
        }
    }
}

struct TaskRow: View {
    @EnvironmentObject private var store: Store
    let app: CatalogApp
    let state: TaskState

    var body: some View {
        switch state {
        case .preparing: line(L.t("task.preparing"), progress: nil)
        case .downloading(let p): line(L.t("task.downloading", Int(p * 100)), progress: p)
        case .verifying: line(L.t("task.verifying"), progress: nil)
        case .installing: line(L.t("task.installing"), progress: nil)
        case .waitQuit:
            VStack(alignment: .leading, spacing: 6) {
                Text(L.t("task.waitQuit")).font(.system(size: 12)).foregroundStyle(T.text2)
                HStack {
                    Button(L.t("btn.quitUpdate")) { store.quitAndUpdate(app) }.buttonStyle(HubButtonStyle(kind: .primary, small: true))
                    Button(L.t("btn.cancel")) { store.dismiss(app) }.buttonStyle(HubButtonStyle(small: true))
                }
            }
        case .failed(let m):
            VStack(alignment: .leading, spacing: 6) {
                Text(m).font(.system(size: 12)).foregroundStyle(T.bad).lineLimit(2)
                HStack {
                    Button(L.t("btn.retry")) { store.dismiss(app); store.install(app) }.buttonStyle(HubButtonStyle(kind: .primary, small: true))
                    Button(L.t("btn.close")) { store.dismiss(app) }.buttonStyle(HubButtonStyle(small: true))
                }
            }
        case .done(let m):
            Label(m, systemImage: "checkmark.circle.fill").font(.system(size: 12)).foregroundStyle(T.ok).lineLimit(1)
        }
    }

    private func line(_ s: String, progress: Double?) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(s).font(.system(size: 12)).foregroundStyle(T.text2)
            if let p = progress { ProgressView(value: p).tint(T.acc) } else { ProgressView().progressViewStyle(.linear).tint(T.acc) }
        }
    }
}

// MARK: Fiche

struct DetailView: View {
    @EnvironmentObject private var store: Store
    let app: CatalogApp?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let a = app {
                HStack(spacing: 12) {
                    AppIcon(app: a, size: 64)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(a.name).font(.system(size: 18, weight: .bold))
                        StatusTag(app: a)
                    }
                }
                Text(a.text).font(.system(size: 13)).foregroundStyle(T.text2).fixedSize(horizontal: false, vertical: true)
                VStack(spacing: 0) {
                    kv(L.t("detail.category"), L.t("cat." + a.category))
                    kv(L.t("detail.installed"), store.installed[a.bundleId]?.version ?? L.t("detail.none"))
                    kv(L.t("detail.latest"), store.releases[a.id].map { $0.version } ?? L.t("detail.none"))
                    kv(L.t("detail.size"), store.releases[a.id].map { formatSize($0.size) } ?? L.t("detail.none"))
                    kv(L.t("detail.folder"), store.installed[a.bundleId]?.url.deletingLastPathComponent().lastPathComponent ?? L.t("detail.none"))
                }
                Spacer()
                if store.installed[a.bundleId] != nil {
                    HStack(spacing: 8) {
                        if store.isRunning(a) { Button(L.t("btn.quit")) { store.quit(a) }.buttonStyle(HubButtonStyle(small: true)) }
                        Button(L.t("btn.reveal")) { store.reveal(a) }.buttonStyle(HubButtonStyle(kind: .ghost, small: true))
                    }
                }
                Actions(app: a)
            } else {
                Text(L.t("detail.pick")).foregroundStyle(T.text2)
                Spacer()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(16)
        .background(T.card, in: RoundedRectangle(cornerRadius: T.rBox))
    }

    private func kv(_ k: String, _ v: String) -> some View {
        HStack { Text(k).foregroundStyle(T.text2); Spacer(); Text(v).fontWeight(.semibold).lineLimit(1) }
            .font(.system(size: 12.5)).padding(.vertical, 4)
    }
}

// MARK: Activité

struct ActivityView: View {
    @EnvironmentObject private var store: Store
    var body: some View {
        VStack(spacing: 10) {
            if store.activeTasks.isEmpty {
                Text(L.t("task.empty")).foregroundStyle(T.text2).frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ForEach(store.activeTasks) { a in
                    HStack(spacing: 12) {
                        AppIcon(app: a, size: 36)
                        Text(a.name).font(.system(size: 14, weight: .semibold)).frame(width: 130, alignment: .leading)
                        if let t = store.tasks[a.id] { TaskRow(app: a, state: t) }
                        Spacer()
                    }
                    .padding(12).background(T.card, in: RoundedRectangle(cornerRadius: T.rBox))
                }
                Spacer()
            }
        }
    }
}

// MARK: Réglages de mHUB

struct SettingsView: View {
    @EnvironmentObject private var store: Store
    @ObservedObject private var selfUpdate = SelfUpdate.shared
    @State private var mode = IconMode.current
    @State private var auto = Prefs.autoInstall
    @State private var daily = Prefs.dailyCheck

    var body: some View {
        VStack(spacing: 10) {
            row(L.t("set.presence"), L.t("set.presence.help")) {
                Picker("", selection: $mode) {
                    ForEach(IconMode.allCases) { Text($0.label).tag($0) }
                }.pickerStyle(.segmented).labelsHidden().frame(width: 260)
                    .onChange(of: mode) { _, m in IconMode.current = m; Presence.shared.apply() }
            }
            row(L.t("set.auto"), L.t("set.auto.help")) {
                Toggle("", isOn: $auto).toggleStyle(.switch).labelsHidden()
                    .onChange(of: auto) { _, v in Prefs.autoInstall = v }
            }
            row(L.t("set.freq"), nil) {
                Picker("", selection: $daily) {
                    Text(L.t("set.freq.daily")).tag(true); Text(L.t("set.freq.manual")).tag(false)
                }.pickerStyle(.segmented).labelsHidden().frame(width: 200)
                    .onChange(of: daily) { _, v in Prefs.dailyCheck = v }
            }
            row(L.t("set.folder"), Prefs.installDir.path.replacingOccurrences(of: NSHomeDirectory(), with: "~")) {
                Button(L.t("set.folder.change")) { chooseFolder() }.buttonStyle(HubButtonStyle(small: true))
            }
            row(L.t("set.login"), nil) {
                Toggle("", isOn: Binding(get: { store.launchAtLogin }, set: { store.setLaunchAtLogin($0) })).toggleStyle(.switch).labelsHidden()
            }
            row(L.t("set.selfUpdate"), selfUpdate.message) {
                HStack {
                    if case .available(let v) = selfUpdate.state, !selfUpdate.isDev {
                        Button(L.t("self.install", v)) { Task { await selfUpdate.install() } }.buttonStyle(HubButtonStyle(kind: .primary, small: true))
                    }
                    Button(L.t("set.selfUpdate.btn")) { Task { await selfUpdate.check() } }.buttonStyle(HubButtonStyle(small: true))
                }
            }
            row("mHUB \(selfUpdate.currentVersion)", "DESKTOP MAC TOOLKIT") {
                Button(L.t("set.about")) { About.show() }.buttonStyle(HubButtonStyle(small: true))
            }
        }
        .padding(18).frame(width: 600)
        .background(T.bg).foregroundStyle(T.text)
    }

    private func row<C: View>(_ title: String, _ help: String?, @ViewBuilder _ control: () -> C) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 13))
                if let h = help { Text(h).font(.system(size: 12)).foregroundStyle(T.text2).lineLimit(2) }
            }
            Spacer()
            control()
        }
        .padding(.horizontal, 14).padding(.vertical, 11)
        .background(T.card, in: RoundedRectangle(cornerRadius: T.rBox))
    }

    private func chooseFolder() {
        let p = NSOpenPanel()
        p.canChooseDirectories = true; p.canChooseFiles = false; p.canCreateDirectories = true
        p.directoryURL = Prefs.installDir
        if p.runModal() == .OK, let u = p.url { store.setInstallDir(u) }
    }
}
