// mHUB — aperçu d'une appli (un coin de sa fenêtre) dans le volet de détail.
// Les images sont choisies une à une et publiées dans le dépôt mHUB (previews/<id>.png) : ajouter ou changer un aperçu ne
// demande aucune nouvelle version. Téléchargées une fois, gardées en cache ; sans image, le volet reste vide.
import SwiftUI
import AppKit

enum PreviewStore {
    private static let dir: URL = {
        let u = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("mHUB/previews")
        try? FileManager.default.createDirectory(at: u, withIntermediateDirectories: true)
        return u
    }()

    static func image(for id: String) async -> NSImage? {
        let file = dir.appendingPathComponent("\(id).png"), none = dir.appendingPathComponent("\(id).none")
        let fm = FileManager.default
        func age(_ u: URL) -> TimeInterval? {
            (try? fm.attributesOfItem(atPath: u.path)[.modificationDate] as? Date).flatMap { $0 }.map { Date().timeIntervalSince($0) }
        }
        if let a = age(file), a < 86_400, let i = NSImage(contentsOf: file) { return i }
        if let a = age(none), a < 3_600 { return NSImage(contentsOf: file) }
        var req = URLRequest(url: URL(string: "https://raw.githubusercontent.com/starbudweiser/mHUB/main/previews/\(id).png")!)
        req.setValue("mHUB", forHTTPHeaderField: "User-Agent")
        req.cachePolicy = .reloadIgnoringLocalCacheData
        req.timeoutInterval = 20
        if let (data, resp) = try? await URLSession.shared.data(for: req), let code = (resp as? HTTPURLResponse)?.statusCode {
            if code == 200, let img = NSImage(data: data) {
                try? data.write(to: file); try? fm.removeItem(at: none); return img
            }
            if code == 404 { try? fm.removeItem(at: file); fm.createFile(atPath: none.path, contents: Data()); return nil }
        }
        return NSImage(contentsOf: file)   // hors ligne : la copie gardée, s'il y en a une
    }
}

struct PreviewImage: View {
    let appID: String
    @State private var img: NSImage?

    var body: some View {
        ZStack {
            if let img {
                GeometryReader { g in
                    Image(nsImage: img).resizable().aspectRatio(contentMode: .fill)
                        .frame(width: g.size.width, height: g.size.height, alignment: .topLeading)
                        .clipped()
                }
                .clipShape(UnevenRoundedRectangle(topLeadingRadius: 14, bottomLeadingRadius: 14, bottomTrailingRadius: 14, topTrailingRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(T.text.opacity(0.1), lineWidth: 1))
                .mask(LinearGradient(stops: [.init(color: .black, location: 0.7), .init(color: .clear, location: 1)], startPoint: .top, endPoint: .bottom))
                .transition(.opacity)
            }
        }
        .task(id: appID) {
            img = nil
            let i = await PreviewStore.image(for: appID)
            withAnimation(.easeOut(duration: 0.25)) { img = i }
        }
    }
}
