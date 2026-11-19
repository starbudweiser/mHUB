// mHUB — présence : Dock, barre des menus, ou les deux ; menu de l'icône unique du kit.
// Le menu n'est jamais assigné à statusItem.menu (sur plusieurs écrans macOS l'ouvre loin de l'icône) :
// il est ouvert par mHUB, juste sous l'icône.
import AppKit
import Combine

enum IconMode: String, CaseIterable, Identifiable {
    case dock, menubar, both
    var id: String { rawValue }
    var label: String { L.t("set.presence.\(rawValue)") }
    var showsDock: Bool { self != .menubar }
    var showsMenuBar: Bool { self != .dock }
    static let key = "iconMode"
    static var current: IconMode {
        get { IconMode(rawValue: UserDefaults.standard.string(forKey: key) ?? "") ?? .menubar }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: key) }
    }
}

/// Action d'un élément de menu, portée par un objet retenu par l'élément.
private final class Act: NSObject {
    let f: () -> Void
    init(_ f: @escaping () -> Void) { self.f = f }
    @objc func fire() { f() }
}

@MainActor
final class Presence: NSObject {
    static let shared = Presence()
    private var item: NSStatusItem?
    private var bag = Set<AnyCancellable>()

    func apply() {
        let m = IconMode.current
        let wanted: NSApplication.ActivationPolicy = m.showsDock ? .regular : .accessory
        if NSApp.activationPolicy() != wanted { NSApp.setActivationPolicy(wanted) }
        if m.showsMenuBar { installItem() } else if let it = item { NSStatusBar.system.removeStatusItem(it); item = nil }
        if bag.isEmpty {
            Store.shared.objectWillChange.receive(on: DispatchQueue.main).debounce(for: .milliseconds(200), scheduler: DispatchQueue.main)
                .sink { [weak self] _ in self?.item?.button?.image = Self.glyph(badge: !Store.shared.updatable.isEmpty) }.store(in: &bag)
        }
    }

    private func installItem() {
        if item == nil { item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength) }
        guard let b = item?.button else { return }
        b.image = Self.glyph(badge: !Store.shared.updatable.isEmpty)
        b.imagePosition = .imageOnly
        b.toolTip = "mHUB"
        item?.menu = nil
        b.target = self
        b.action = #selector(clicked)
        b.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    @objc private func clicked() {
        guard let b = item?.button else { return }
        makeMenu().popUp(positioning: nil, at: NSPoint(x: 0, y: b.isFlipped ? b.bounds.maxY + 4 : -4), in: b)
    }

    /// Silhouette en couleur (jaune du logo) : un cœur et six satellites ; pastille rouge s'il y a des mises à jour.
    private static func glyph(badge: Bool) -> NSImage {
        let img = NSImage(size: NSSize(width: 20, height: 20), flipped: false) { _ in
            T.brandNS.setFill()
            NSBezierPath(ovalIn: NSRect(x: 10 - 3.6, y: 10 - 3.6, width: 7.2, height: 7.2)).fill()
            for i in 0..<6 {
                let a = CGFloat(i) * .pi / 3 + .pi / 6
                let c = NSPoint(x: 10 + 6.6 * cos(a), y: 10 + 6.6 * sin(a))
                NSBezierPath(ovalIn: NSRect(x: c.x - 2, y: c.y - 2, width: 4, height: 4)).fill()
            }
            if badge {
                NSColor(hex: 0xff453a).setFill()
                NSBezierPath(ovalIn: NSRect(x: 13.4, y: 13.4, width: 6.2, height: 6.2)).fill()
            }
            return true
        }
        img.isTemplate = false
        return img
    }

    // MARK: Menu

    private func entry(_ title: String, key: String = "", enabled: Bool = true, _ f: @escaping () -> Void) -> NSMenuItem {
        let a = Act(f)
        let it = NSMenuItem(title: title, action: enabled ? #selector(Act.fire) : nil, keyEquivalent: key)
        it.target = a; it.representedObject = a
        return it
    }

    private func makeMenu() -> NSMenu {
        let store = Store.shared
        let menu = NSMenu()
        let installed = store.installedApps
        let head = NSMenuItem(title: "mHUB — " + L.t("menu.summary", installed.count, store.updatable.count), action: nil, keyEquivalent: "")
        head.isEnabled = false
        menu.addItem(head)
        menu.addItem(.separator())

        if installed.isEmpty {
            let none = NSMenuItem(title: L.t("menu.none"), action: nil, keyEquivalent: ""); none.isEnabled = false
            menu.addItem(none)
        }
        let top = installed.prefix(10), rest = installed.dropFirst(10)
        for a in top { menu.addItem(appItem(a)) }
        if !rest.isEmpty {
            let others = NSMenuItem(title: L.t("menu.others", rest.count), action: nil, keyEquivalent: "")
            let sub = NSMenu()
            for a in rest { sub.addItem(appItem(a)) }
            others.submenu = sub
            menu.addItem(others)
        }
        if !store.updatable.isEmpty {
            menu.addItem(.separator())
            menu.addItem(entry(L.t("menu.updateAll")) { store.updateAll() })
        }
        menu.addItem(.separator())
        menu.addItem(entry(L.t("menu.catalogue"), key: "h") { Windows.showMain() })
        menu.addItem(entry(L.t("menu.settings"), key: ",") { Windows.showSettings() })
        menu.addItem(entry(L.t("menu.about")) { About.show() })
        menu.addItem(.separator())
        menu.addItem(entry(L.t("menu.quit"), key: "q") { NSApp.terminate(nil) })
        return menu
    }

    private func appItem(_ a: CatalogApp) -> NSMenuItem {
        let store = Store.shared
        var title = a.name
        var verb = L.t("status.upToDate")
        if case .update(let v) = store.status(a) { title += " ⟳"; verb = L.t("menu.updateAvail") + " " + v }
        let it = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        if let u = store.installed[a.bundleId]?.url {
            let icon = NSWorkspace.shared.icon(forFile: u.path)
            icon.size = NSSize(width: 16, height: 16)
            it.image = icon
        }
        let sub = NSMenu()
        let v = NSMenuItem(title: L.t("menu.version", store.installed[a.bundleId]?.version ?? "?", verb), action: nil, keyEquivalent: "")
        v.isEnabled = false
        sub.addItem(v); sub.addItem(.separator())
        sub.addItem(entry(L.t("menu.open")) { store.open(a) })
        if store.canOpenSettings(a) { sub.addItem(entry(L.t("menu.appSettings")) { store.openSettings(a) }) }
        if a.presence == true {
            let t = entry(L.t("menu.menubarIcon")) { store.setMenuBarIcon(a, !store.menuBarIconOn(a)) }
            t.state = store.menuBarIconOn(a) ? .on : .off
            sub.addItem(t)
        }
        if case .update(let nv) = store.status(a) { sub.addItem(.separator()); sub.addItem(entry(L.t("menu.updateApp", nv)) { store.install(a) }) }
        if store.isRunning(a) { sub.addItem(.separator()); sub.addItem(entry(L.t("menu.quitApp", a.name)) { store.quit(a) }) }
        it.submenu = sub
        return it
    }
}
