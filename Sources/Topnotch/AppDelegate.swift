import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var notchController: NotchWindowController?
    private var statusItem: NSStatusItem?
    private var appNapActivity: NSObjectProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // This is a background accessory app with no visible/key window most of the
        // time, which makes it a prime target for App Nap — timers (our media/weather
        // polling) get silently throttled to a crawl until something "wakes" it, like
        // becoming key on click. Since this app's whole job is to stay live in the
        // background, opt out entirely.
        appNapActivity = ProcessInfo.processInfo.beginActivity(
            options: [.userInitiated, .idleSystemSleepDisabled],
            reason: "Topnotch keeps live widgets (media, weather) updating in the background"
        )

        let controller = NotchWindowController()
        notchController = controller
        controller.show()

        controller.viewModel.calendarManager.requestAccessIfNeeded()
        controller.viewModel.weather.start()
        controller.viewModel.power.start()
        controller.viewModel.clipboard.start()

        setUpStatusItem()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    @objc private func screenParametersChanged() {
        notchController?.show()
    }

    private func setUpStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "rectangle.topthird.inset.filled", accessibilityDescription: "Topnotch")
        let menu = NSMenu()
        let quitItem = NSMenuItem(title: "Quit Topnotch", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        item.menu = menu
        statusItem = item
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }
}
