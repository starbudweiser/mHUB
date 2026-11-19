// mHUB — design « Flat Round » (arrondis 20) : mat, arrondi, coloré ; clair ou sombre selon le système.
import SwiftUI
import AppKit

extension NSColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(srgbRed: CGFloat((hex >> 16) & 0xff) / 255, green: CGFloat((hex >> 8) & 0xff) / 255, blue: CGFloat(hex & 0xff) / 255, alpha: alpha)
    }
}

enum T {
    static func dyn(_ dark: UInt32, _ light: UInt32) -> Color {
        Color(nsColor: NSColor(name: nil) { ap in
            NSColor(hex: ap.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light)
        })
    }
    static let bg = dyn(0x131316, 0xf1f1f5)
    static let card = dyn(0x232327, 0xffffff)
    static let ctl = dyn(0x2c2c31, 0xe8e8ef)
    static let text = dyn(0xf5f5f7, 0x1c1c22)
    static let text2 = dyn(0x98989f, 0x6b6b78)
    static let acc = dyn(0x0a84ff, 0x6a5af0)
    static let ok = dyn(0x30d158, 0x2fb36a)
    static let warn = dyn(0xff9f0a, 0xe08a00)
    static let bad = dyn(0xff453a, 0xd93025)
    /// Couleur du logo mHUB : le « m » du nom la prend dans les fenêtres.
    static let brand = Color(nsColor: NSColor(hex: 0xf5b800))
    static let brandNS = NSColor(hex: 0xf5b800)
    static func dynNS(_ dark: UInt32, _ light: UInt32) -> NSColor {
        NSColor(name: nil) { ap in NSColor(hex: ap.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light) }
    }
    static let bgNS = dynNS(0x131316, 0xf1f1f5)
    static let textNS = dynNS(0xf5f5f7, 0x1c1c22)
    static let text2NS = dynNS(0x98989f, 0x6b6b78)

    static let rBox: CGFloat = 20     // arrondi des cartes et panneaux
    static let rCtl: CGFloat = 12     // arrondi des boutons et champs
}

/// « mHUB » avec le « m » dans la couleur du logo.
func brandName(size: CGFloat, bold: Bool = true) -> Text {
    Text("m").foregroundColor(T.brand).font(.system(size: size, weight: bold ? .bold : .regular))
    + Text("HUB").foregroundColor(T.text).font(.system(size: size, weight: bold ? .bold : .regular))
}

struct HubButtonStyle: ButtonStyle {
    enum Kind { case primary, secondary, ghost }
    var kind: Kind = .secondary
    var small = false
    var fill = false
    @Environment(\.isEnabled) private var enabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: small ? 12 : 13, weight: .medium))
            .lineLimit(1).multilineTextAlignment(.center)
            .frame(maxWidth: fill ? .infinity : nil, alignment: .center)
            .padding(.horizontal, small ? 11 : 14).padding(.vertical, small ? 5 : 7)
            .foregroundStyle(kind == .primary ? Color.white : (kind == .ghost ? T.text2 : T.text))
            .background(kind == .primary ? T.acc : (kind == .ghost ? Color.clear : T.ctl), in: RoundedRectangle(cornerRadius: T.rCtl))
            .opacity(enabled ? (configuration.isPressed ? 0.75 : 1) : 0.4)
            .contentShape(RoundedRectangle(cornerRadius: T.rCtl))
    }
}

struct Pill: View {
    enum Tone { case neutral, ok, warn, bad }
    let text: String
    var tone: Tone = .neutral
    var body: some View {
        let c: Color = tone == .ok ? T.ok : tone == .warn ? T.warn : tone == .bad ? T.bad : T.text2
        Text(text).font(.system(size: 10.5, weight: .semibold)).lineLimit(1)
            .padding(.horizontal, 8).padding(.vertical, 2)
            .foregroundStyle(c)
            .background(tone == .neutral ? T.ctl : c.opacity(0.22), in: Capsule())
    }
}

struct Card<Content: View>: View {
    var selected = false
    @ViewBuilder var content: Content
    var body: some View {
        content.padding(12)
            .background(T.card, in: RoundedRectangle(cornerRadius: T.rBox))
            .overlay(RoundedRectangle(cornerRadius: T.rBox).stroke(selected ? T.acc : .clear, lineWidth: 2))
    }
}

/// Icône d'une appli : la vraie icône si elle est installée, sinon une pastille colorée à ses initiales.
struct AppIcon: View {
    let app: CatalogApp
    let size: CGFloat
    @EnvironmentObject private var store: Store

    var body: some View {
        if let i = store.installed[app.bundleId] {
            Image(nsImage: NSWorkspace.shared.icon(forFile: i.url.path)).resizable().interpolation(.high).frame(width: size, height: size)
        } else {
            RoundedRectangle(cornerRadius: size * 0.28)
                .fill(Color(hue: hue, saturation: 0.55, brightness: 0.85))
                .frame(width: size, height: size)
                .overlay(Text(String(app.name.prefix(2))).font(.system(size: size * 0.34, weight: .bold)).foregroundStyle(.white))
        }
    }

    private var hue: Double {
        var h: UInt32 = 5381
        for u in app.name.unicodeScalars { h = h &* 33 &+ u.value }
        return Double(h % 360) / 360
    }
}
