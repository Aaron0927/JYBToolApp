import Sparkle
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    private let updaterController: SPUStandardUpdaterController

    override init() {
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Updater 已通过 startingUpdater: true 自动启动
    }
}
