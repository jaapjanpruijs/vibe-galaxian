import Cocoa
import SpriteKit

class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!

    func applicationDidFinishLaunching(_ notification: Notification) {
        let sceneSize = CGSize(width: 480, height: 640)

        let skView = SKView(frame: NSRect(origin: .zero, size: sceneSize))
        skView.showsFPS = false
        skView.showsNodeCount = false
        skView.ignoresSiblingOrder = true

        window = NSWindow(
            contentRect: NSRect(origin: .zero, size: sceneSize),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "GALAXIAN"
        window.contentView = skView
        window.contentMinSize = sceneSize
        window.contentAspectRatio = sceneSize
        window.collectionBehavior = [.fullScreenPrimary]
        window.center()
        window.makeKeyAndOrderFront(nil)

        let scene = GameScene(size: sceneSize)
        scene.scaleMode = .aspectFit
        skView.presentScene(scene)

        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}
