// mHUB — Hub du Mac Desktop Toolkit : catalogue, installation, mises à jour et lancement des applis, depuis une seule icône.
import SwiftUI
import AppKit

@MainActor
enum Windows {
    private static var main: NSWindow?
    private static var settings: NSWindow?

    static func showMain() {
        if main == nil {
            let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1120, height: 720),
                             styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView], backing: .buffered, defer: false)
            w.titleVisibility = .hidden
            w.titlebarAppearsTransparent = true
            w.isReleasedWhenClosed = false
            w.minSize = NSSize(width: 960, height: 620)
            w.contentView = NSHostingView(rootView: RootView().environmentObject(Store.shared))
            w.center()
            w.setFrameAutosaveName("mHUB.main")
            main = w
        }
        main?.present()
        SplashTrigger.shared.fire()
    }

    static func showSettings() {
        if settings == nil {
            let w = NSWindow(contentRect: .zero, styleMask: [.titled, .closable], backing: .buffered, defer: false)
            w.title = L.t("set.title")
            w.isReleasedWhenClosed = false
            let host = NSHostingView(rootView: SettingsView().environmentObject(Store.shared))
            w.contentView = host
            w.setContentSize(host.fittingSize)
            w.center()
            settings = w
        }
        settings?.present()
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        if CommandLine.arguments.contains("--light") { NSApp.appearance = NSAppearance(named: .aqua) }   // captures d'écran
        buildMainMenu()
        Store.shared.start()
        Presence.shared.apply()
        SelfUpdate.shared.tick()
        // Première ouverture ou --show : la fenêtre. À l'ouverture de session : aucune fenêtre.
        let first = !UserDefaults.standard.bool(forKey: "launchedBefore")
        UserDefaults.standard.set(true, forKey: "launchedBefore")
        if first || CommandLine.arguments.contains("--show") { Windows.showMain() }
        if CommandLine.arguments.contains("--settings") { Windows.showSettings() }
        Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { _ in Task { @MainActor in SelfUpdate.shared.tick() } }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        Windows.showMain()
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    @objc private func showAbout() { About.show() }
    @objc private func showSettings() { Windows.showSettings() }

    /// Menu de l'appli (visible quand mHUB est dans le Dock) : à propos, réglages, édition standard, fenêtre.
    private func buildMainMenu() {
        let main = NSMenu()
        func sub(_ title: String, _ build: (NSMenu) -> Void) {
            let it = NSMenuItem(); let m = NSMenu(title: title); build(m); it.submenu = m; main.addItem(it)
        }
        sub("mHUB") { m in
            m.addItem(withTitle: L.t("menu.about"), action: #selector(showAbout), keyEquivalent: "").target = self
            m.addItem(.separator())
            m.addItem(withTitle: L.t("menu.settings"), action: #selector(showSettings), keyEquivalent: ",").target = self
            m.addItem(.separator())
            m.addItem(withTitle: "Hide mHUB", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
            m.addItem(.separator())
            m.addItem(withTitle: L.t("menu.quit"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        }
        sub("Edit") { m in
            m.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
            m.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
            m.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
            m.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        }
        sub("Window") { m in
            m.addItem(withTitle: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
            m.addItem(withTitle: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        }
        NSApp.mainMenu = main
    }
}

/// Point d'entrée explicite : le délégué est créé et retenu ici (sans fichier nib, @main seul ne le crée pas).
@main
enum Boot {
    @MainActor static let delegate = AppDelegate()
    static func main() {
        MainActor.assumeIsolated {
            let app = NSApplication.shared
            app.delegate = delegate
            app.run()
        }
    }
}
