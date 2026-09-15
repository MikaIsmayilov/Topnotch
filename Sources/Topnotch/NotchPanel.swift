import AppKit

/// A borderless, non-activating panel so it can appear above the menu bar and accept
/// clicks/typing (for the Notes widget) without stealing focus from the frontmost app
/// or showing up in the Dock/Cmd-Tab switcher.
final class NotchPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
