// mHUB — fenêtre « À propos » (modèle Socle : swift/AboutWindow.swift).
import AppKit

@MainActor
enum About {
    private static var window: NSWindow?
    private static let sideMargin: CGFloat = 28
    private static let textWidth: CGFloat = 300

    static func show() {
        if window == nil { window = makeWindow() }
        window?.center()
        window?.present()
    }

    private static func label(_ text: String, size: CGFloat = 12, bold: Bool = false, secondary: Bool = false) -> NSTextField {
        let f = NSTextField(wrappingLabelWithString: text)
        f.font = bold ? NSFont.boldSystemFont(ofSize: size) : NSFont.systemFont(ofSize: size)
        f.textColor = secondary ? T.text2NS : T.textNS
        f.alignment = .center
        f.preferredMaxLayoutWidth = textWidth
        f.isSelectable = false
        f.translatesAutoresizingMaskIntoConstraints = false
        f.widthAnchor.constraint(lessThanOrEqualToConstant: textWidth).isActive = true
        return f
    }

    /// Nom de l'appli avec son « m » dans la couleur du logo.
    private static func nameLabel() -> NSTextField {
        let f = label("mHUB", size: 17, bold: true)
        let s = NSMutableAttributedString(string: "mHUB", attributes: [.font: NSFont.boldSystemFont(ofSize: 17), .foregroundColor: T.textNS])
        s.addAttribute(.foregroundColor, value: T.brandNS, range: NSRange(location: 0, length: 1))
        f.attributedStringValue = s
        f.alignment = .center
        return f
    }

    private final class Opener: NSObject { @objc func go() { NSWorkspace.shared.open(Support.url) } }
    private static let opener = Opener()

    /// Lien discret vers la page de soutien.
    private static func supportButton() -> NSButton {
        let b = NSButton(title: "♥ " + L.t("about.support"), target: opener, action: #selector(Opener.go))
        b.isBordered = false
        b.attributedTitle = NSAttributedString(string: "♥ " + L.t("about.support"), attributes: [.font: NSFont.systemFont(ofSize: 12, weight: .medium), .foregroundColor: T.accNS])
        return b
    }

    private static func makeWindow() -> NSWindow {
        let info = Bundle.main.infoDictionary ?? [:]
        let version = info["CFBundleShortVersionString"] as? String ?? "?"
        let build = info["CFBundleVersion"] as? String ?? "?"
        let icon = NSImageView(image: NSApp.applicationIconImage)
        icon.imageScaling = .scaleProportionallyUpOrDown
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.widthAnchor.constraint(equalToConstant: 84).isActive = true
        icon.heightAnchor.constraint(equalToConstant: 84).isActive = true
        let views: [NSView] = [
            icon, nameLabel(),
            label(L.t("about.version", version, build), secondary: true),
            label(L.t("about.collection"), secondary: true),
            label(L.t("about.tagline")),
            label(L.t("about.authors"), bold: true),
            label(L.t("about.license")),
            label(L.t("about.disclaimer"), secondary: true),
            label(L.t("about.credit"), secondary: true),
            supportButton(),
        ]
        let stack = NSStackView(views: views)
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 12
        stack.setCustomSpacing(6, after: views[1])
        stack.setCustomSpacing(4, after: views[2])
        stack.setCustomSpacing(18, after: views[3])
        stack.edgeInsets = NSEdgeInsets(top: 40, left: sideMargin, bottom: 28, right: sideMargin)
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.widthAnchor.constraint(equalToConstant: textWidth + 2 * sideMargin).isActive = true
        let w = NSWindow(contentRect: .zero, styleMask: [.titled, .closable, .fullSizeContentView], backing: .buffered, defer: false)
        w.title = L.t("about.menu")
        w.isReleasedWhenClosed = false
        w.titlebarAppearsTransparent = true
        w.titleVisibility = .hidden
        w.standardWindowButton(.miniaturizeButton)?.isHidden = true
        w.standardWindowButton(.zoomButton)?.isHidden = true
        w.backgroundColor = T.bgNS
        let content = NSView()
        content.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: content.topAnchor), stack.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor), stack.bottomAnchor.constraint(equalTo: content.bottomAnchor),
        ])
        w.contentView = content
        content.layoutSubtreeIfNeeded()
        w.setContentSize(content.fittingSize)
        return w
    }
}
