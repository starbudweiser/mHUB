import AppKit

extension NSWindow {
    /// Met la fenêtre au premier plan même si l'appli (accessoire, sans Dock) n'est pas encore active : depuis un menu ou un
    /// panneau, l'activation est asynchrone et `makeKeyAndOrderFront` seul laisse la première fenêtre invisible.
    @MainActor func present() {
        // Lancement discret (--quiet, essais et tournages) : la fenêtre s'affiche derrière, sans prendre le focus.
        if CommandLine.arguments.contains("--quiet") { orderBack(nil); return }
        NSApp.activate()
        orderFrontRegardless()
        makeKeyAndOrderFront(nil)
        DispatchQueue.main.async { [weak self] in
            guard let self, self.isVisible, !self.isKeyWindow else { return }
            NSApp.activate()
            self.makeKeyAndOrderFront(nil)
        }
    }
}
