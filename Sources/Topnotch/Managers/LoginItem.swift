import ServiceManagement

/// Launch-at-login via SMAppService. The system owns this state, so it's always read
/// back from the service rather than mirrored into our own preferences.
enum LoginItem {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    @discardableResult
    static func set(_ enabled: Bool) -> Bool {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            return true
        } catch {
            // Registration can fail for an unsigned/ad-hoc build; reflect reality
            // rather than showing a toggle that lies.
            return false
        }
    }
}
