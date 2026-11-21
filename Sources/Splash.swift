// mHUB — splash animé (≈ 3 s) à l'ouverture de la fenêtre : le cœur jaune, six satellites qui se mettent en orbite, puis le nom.
import SwiftUI

@MainActor
final class SplashTrigger: ObservableObject {
    static let shared = SplashTrigger()
    @Published var token = 0
    func fire() { token += 1 }
}

struct SplashView: View {
    var onDone: () -> Void
    @State private var start = Date()
    private let total = 3.0
    private let cols: [UInt32] = [0x7c6cff, 0xff7a59, 0x2fb36a, 0x19a7ce, 0xe0558a, 0x0a84ff]

    private func col(_ h: UInt32) -> Color {
        Color(red: Double((h >> 16) & 0xff) / 255, green: Double((h >> 8) & 0xff) / 255, blue: Double(h & 0xff) / 255)
    }
    private func ease(_ x: Double) -> Double { let c = min(max(x, 0), 1); return 1 - pow(1 - c, 3) }
    private func back(_ x: Double) -> Double { let c = min(max(x, 0), 1), s = 1.70158; return 1 + (s + 1) * pow(c - 1, 3) + s * pow(c - 1, 2) }

    var body: some View {
        ZStack {
            T.bg
            TimelineView(.animation) { ctx in
                let t = ctx.date.timeIntervalSince(start)
                VStack(spacing: 26) {
                    Canvas { g, size in
                        let c = CGPoint(x: size.width / 2, y: size.height / 2)
                        let heart = 36 * back(t / 0.6)
                        g.fill(Path(ellipseIn: CGRect(x: c.x - heart, y: c.y - heart, width: heart * 2, height: heart * 2)), with: .color(col(0xf5b800)))
                        for i in 0..<6 {
                            let p = ease((t - 0.35 - Double(i) * 0.15) / 0.9)
                            let spin = Double.pi / 6 + Double(i) * Double.pi / 3 + (1 - p) * 2.4 + max(0, t - 1.2) * 0.35
                            let r = 87 * p
                            let rad = 19 * back((t - 0.35 - Double(i) * 0.15) / 0.5)
                            let pt = CGPoint(x: c.x + r * cos(spin), y: c.y - r * sin(spin))
                            g.fill(Path(ellipseIn: CGRect(x: pt.x - rad, y: pt.y - rad, width: rad * 2, height: rad * 2)), with: .color(col(cols[i])))
                        }
                    }
                    .frame(width: 240, height: 240)
                    brandName(size: 34)
                        .opacity(ease((t - 1.5) / 0.6))
                        .offset(y: 8 * (1 - ease((t - 1.5) / 0.6)))
                    Text("DESKTOP MAC TOOLKIT").font(.system(size: 12, weight: .medium)).tracking(1.5).foregroundStyle(T.text2)
                        .opacity(ease((t - 1.9) / 0.6))
                        .padding(.top, -14)
                }
                .scaleEffect(1 + 0.04 * ease((t - 2.4) / 0.6))
                .opacity(1 - ease((t - 2.6) / 0.4))
                .onChange(of: t >= total) { _, done in if done { onDone() } }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { onDone() }
        .onAppear { start = Date() }
    }
}
