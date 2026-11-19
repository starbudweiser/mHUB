// mHUB — « Réglages » universel : ouvre la fenêtre de réglages de n'importe quelle appli installée,
// en actionnant son élément de menu « Réglages… » (⌘,) par l'accessibilité. Aucune coopération de l'appli requise.
import AppKit
import ApplicationServices

enum AppSettings {
    private static let titleRegex = try! NSRegularExpression(pattern: "(réglages|préférences|paramètres|settings|preferences|ajustes|impostazioni)", options: [.caseInsensitive])

    static var trusted: Bool { AXIsProcessTrusted() }

    /// Demande l'autorisation « Accessibilité » (une seule fois, dialogue système).
    static func requestTrust() {
        _ = AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
    }

    /// Actionne l'élément de réglages dans le menu de l'appli (pid). Renvoie false s'il n'est pas (encore) trouvé.
    static func press(pid: pid_t) -> Bool {
        let app = AXUIElementCreateApplication(pid)
        var bar: CFTypeRef?
        guard AXUIElementCopyAttributeValue(app, kAXMenuBarAttribute as CFString, &bar) == .success, let bar else { return false }
        var items: [AXUIElement] = []
        collect(bar as! AXUIElement, into: &items, depth: 0)
        let enabled = items.filter { (attr($0, kAXEnabledAttribute) as? Bool) ?? true }
        let byKey = enabled.first { (attr($0, kAXMenuItemCmdCharAttribute) as? String) == "," }
        let byTitle = enabled.first { e in
            guard let t = attr(e, kAXTitleAttribute) as? String else { return false }
            return titleRegex.firstMatch(in: t, range: NSRange(t.startIndex..., in: t)) != nil
        }
        guard let target = byKey ?? byTitle else { return false }
        return AXUIElementPerformAction(target, kAXPressAction as CFString) == .success
    }

    /// Ouvre les réglages : lance l'appli si besoin, attend son menu, puis actionne l'élément.
    static func open(app: NSRunningApplication?, launching url: URL, args: [String]?) async {
        var running = app
        if running == nil {
            let cfg = NSWorkspace.OpenConfiguration(); cfg.activates = true
            if let a = args { cfg.arguments = a }
            running = try? await NSWorkspace.shared.openApplication(at: url, configuration: cfg)
            if args != nil { return }                      // argument de lancement : l'appli ouvre elle-même ses réglages
        } else { running?.activate() }
        guard let pid = running?.processIdentifier else { return }
        guard trusted else { await MainActor.run { requestTrust() }; return }
        for _ in 0..<20 {
            if press(pid: pid) { return }
            try? await Task.sleep(nanoseconds: 500_000_000)
        }
        // Pas de menu « Réglages » (appli de barre des menus sans menu principal) : on la rouvre, elle montre sa fenêtre.
        let cfg = NSWorkspace.OpenConfiguration(); cfg.activates = true
        _ = try? await NSWorkspace.shared.openApplication(at: url, configuration: cfg)
    }

    // MARK: Parcours de l'arbre d'accessibilité (barre des menus → menus → éléments)

    private static func attr(_ e: AXUIElement, _ name: String) -> CFTypeRef? {
        var v: CFTypeRef?
        return AXUIElementCopyAttributeValue(e, name as CFString, &v) == .success ? v : nil
    }

    private static func collect(_ e: AXUIElement, into out: inout [AXUIElement], depth: Int) {
        guard depth < 5, let kids = attr(e, kAXChildrenAttribute) as? [AXUIElement] else { return }
        for k in kids {
            let role = attr(k, kAXRoleAttribute) as? String
            if role == kAXMenuItemRole as String { out.append(k) }
            if depth == 1, role == kAXMenuBarItemRole as String, (attr(k, kAXTitleAttribute) as? String) == "Apple" { continue }
            collect(k, into: &out, depth: depth + 1)
        }
    }
}
