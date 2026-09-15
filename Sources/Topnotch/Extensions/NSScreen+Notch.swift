import AppKit

extension NSScreen {
    /// The physical notch cutout size, if this screen has one.
    var notchSize: CGSize? {
        guard let left = auxiliaryTopLeftArea, let right = auxiliaryTopRightArea else { return nil }
        let height = safeAreaInsets.top
        guard height > 0 else { return nil }
        let width = frame.width - left.width - right.width
        guard width > 0 else { return nil }
        return CGSize(width: width, height: height)
    }

    var hasNotch: Bool {
        notchSize != nil
    }

    /// Stable identity for this display, so we can tell "the same screen came back" from
    /// "we're now on a different screen" across a dock/undock.
    var displayID: CGDirectDisplayID? {
        deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
    }

    /// Height of the menu bar on this screen. External displays use a shorter bar than a
    /// notched built-in, so assuming the built-in's height leaves the pill floating.
    var menuBarHeight: CGFloat {
        max(frame.maxY - visibleFrame.maxY, 0)
    }

    /// The screen that currently contains the mouse cursor, falling back to `.main`.
    static var withCursor: NSScreen? {
        let mouseLocation = NSEvent.mouseLocation
        return NSScreen.screens.first { NSMouseInRect(mouseLocation, $0.frame, false) } ?? NSScreen.main
    }
}
