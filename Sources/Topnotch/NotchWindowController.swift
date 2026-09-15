import AppKit
import SwiftUI
import Combine

/// Owns the notch overlay panel. The panel itself is created once at its maximum
/// (expanded) footprint and never resized — only the SwiftUI content inside animates
/// its visible size with a real spring, which is what gives open/close its bounce and
/// avoids ever clipping content against a mid-resize window frame. We watch for the
/// two-finger swipe down/up trackpad gesture to reveal/dismiss the panel.
final class NotchWindowController: NSObject {
    let viewModel = NotchViewModel()

    private var panel: NotchPanel!
    private var hostingView: NotchHostingView!
    private var hoverTimer: Timer?
    private var collapseWorkItem: DispatchWorkItem?

    private var globalScrollMonitor: Any?
    private var localScrollMonitor: Any?
    private var scrollAccumulatorX: CGFloat = 0
    private var scrollAccumulatorY: CGFloat = 0
    private var lastScrollEventTime: Date = .distantPast
    private var gestureConsumed = false

    /// Identity of the screen the current panel was built for, so repeated screen-parameter
    /// notifications don't rebuild a panel that is already correct.
    private var installedScreenID: CGDirectDisplayID?
    private var installedNotchSize: CGSize?

    private var targetScreen: NSScreen? {
        NSScreen.screens.first(where: { $0.hasNotch }) ?? NSScreen.main
    }

    /// Used only on screens with no real cutout (an external display, or a Mac with no
    /// notch at all). The height tracks that screen's own menu bar rather than assuming
    /// the built-in's taller one.
    private func fallbackNotchSize(for screen: NSScreen) -> CGSize {
        CGSize(width: 200, height: max(screen.menuBarHeight, 24))
    }

    func show() {
        guard let screen = targetScreen else { return }

        let notch = screen.notchSize ?? fallbackNotchSize(for: screen)

        // didChangeScreenParameters also fires for things that don't concern us at all —
        // a colour-profile change, another display waking, brightness on some setups.
        // Rebuilding the panel for those would needlessly tear down the hosting view.
        if panel != nil, installedScreenID == screen.displayID, installedNotchSize == notch {
            NSLog("Topnotch: screen params changed, geometry unchanged — repositioning only")
            reposition(on: screen)
            return
        }

        // Everything installed by a previous show() has to go first. Leaving the old
        // scroll monitors and hover timer running would mean each display change adds
        // another copy, and a single swipe would then be counted once per copy.
        teardown()

        viewModel.configure(notchSize: notch)
        let maxSize = viewModel.expandedSize

        let panel = NotchPanel(
            contentRect: NSRect(origin: .zero, size: maxSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false,
            screen: screen
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        // Above the menu bar / status items so the expanded panel is never drawn behind
        // the real menu bar content.
        panel.level = .popUpMenu
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = false
        panel.isReleasedWhenClosed = false
        panel.becomesKeyOnlyIfNeeded = true

        let root = NotchRootView(viewModel: viewModel)
        let hosting = NotchHostingView(rootView: root)
        hosting.viewModel = viewModel
        hosting.frame = NSRect(origin: .zero, size: maxSize)
        panel.contentView = hosting

        self.panel = panel
        self.hostingView = hosting

        installedScreenID = screen.displayID
        installedNotchSize = notch
        NSLog("Topnotch: panel built for display %u — notch %.0fx%.0f, panel %.0fx%.0f, screen %.0fx%.0f",
              screen.displayID ?? 0, notch.width, notch.height,
              maxSize.width, maxSize.height, screen.frame.width, screen.frame.height)

        positionPanel(on: screen, size: maxSize)
        panel.orderFrontRegardless()

        startAutoCollapseWatcher()
        installGestureMonitors()
    }

    private func positionPanel(on screen: NSScreen, size: CGSize) {
        guard let panel else { return }
        let x = screen.frame.midX - size.width / 2
        let y = screen.frame.maxY - size.height
        panel.setFrame(NSRect(x: x, y: y, width: size.width, height: size.height), display: true)
    }

    /// Same screen and same cutout, but its frame may have moved — e.g. another display
    /// was added to the left, shifting this one's origin in the global coordinate space.
    private func reposition(on screen: NSScreen) {
        positionPanel(on: screen, size: viewModel.expandedSize)
        panel?.orderFrontRegardless()
    }

    private func teardown() {
        hoverTimer?.invalidate()
        hoverTimer = nil
        collapseWorkItem?.cancel()
        collapseWorkItem = nil
        if let monitor = globalScrollMonitor { NSEvent.removeMonitor(monitor) }
        if let monitor = localScrollMonitor { NSEvent.removeMonitor(monitor) }
        globalScrollMonitor = nil
        localScrollMonitor = nil
        resetGesture()
        viewModel.setHovering(false)
        panel?.orderOut(nil)
        panel = nil
        hostingView = nil
    }

    /// The screen-space rect of whatever is *currently visible* (collapsed pill or
    /// expanded panel) — the panel's own `frame` is always the fixed maximum footprint,
    /// so callers that care about "am I over the notch" need this instead.
    private func currentVisibleFrame() -> NSRect {
        guard let panel else { return .zero }
        let size = viewModel.isExpanded ? viewModel.expandedSize : viewModel.collapsedSize
        let x = panel.frame.midX - size.width / 2
        let y = panel.frame.maxY - size.height
        return NSRect(x: x, y: y, width: size.width, height: size.height)
    }

    // MARK: - Auto-collapse on mouse leave

    /// We don't expand on hover, but once expanded (via the swipe gesture or a click),
    /// moving the mouse away should still tidy the panel back up.
    private func startAutoCollapseWatcher() {
        hoverTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            self?.pollCursorForAutoCollapse()
        }
    }

    private func pollCursorForAutoCollapse() {
        let mouse = NSEvent.mouseLocation
        let hitFrame = currentVisibleFrame().insetBy(dx: -6, dy: -6)
        guard viewModel.isExpanded else {
            // Hit testing deliberately uses the un-swollen frame (see collapsedDrawnSize),
            // so the pill growing under the cursor can't feed back into this test.
            let hovering = hitFrame.contains(mouse)
            viewModel.setHovering(hovering)
            if viewModel.settings.openOnHover, hovering {
                viewModel.expand()
            }
            return
        }
        viewModel.setHovering(false)
        if hitFrame.contains(mouse) {
            collapseWorkItem?.cancel()
            collapseWorkItem = nil
        } else {
            guard collapseWorkItem == nil else { return }
            let item = DispatchWorkItem { [weak self] in
                self?.collapseWorkItem = nil
                self?.viewModel.collapse()
            }
            collapseWorkItem = item
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: item)
        }
    }

    // MARK: - Two-finger swipe gesture

    private func installGestureMonitors() {
        globalScrollMonitor = NSEvent.addGlobalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            self?.handleScroll(event)
        }
        localScrollMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            self?.handleScroll(event)
            return event
        }
    }

    private func handleScroll(_ event: NSEvent) {
        guard event.hasPreciseScrollingDeltas else { return }
        let mouse = NSEvent.mouseLocation
        // Only the notch strip itself reacts to the swipe. Using the whole panel meant
        // scrolling any list inside it (settings, agenda) was read as swipe-to-close.
        let visible = currentVisibleFrame()
        let bandHeight = viewModel.stripHeight
        let reactiveArea = NSRect(
            x: visible.minX,
            y: visible.maxY - bandHeight,
            width: visible.width,
            height: bandHeight
        ).insetBy(dx: -12, dy: -8)
        guard reactiveArea.contains(mouse) else { return }

        // A real trackpad gesture reports .began at finger-down and .ended/.cancelled at
        // finger-up — that's a much more reliable "this is a new physical swipe" signal
        // than a time gap, which can miss two swipes done back-to-back quickly. Plain
        // scroll wheels (no phase at all) fall back to the time-gap heuristic.
        if event.phase == .began {
            resetGesture()
        } else if event.phase.isEmpty && event.momentumPhase.isEmpty {
            let now = Date()
            if now.timeIntervalSince(lastScrollEventTime) > 0.15 {
                resetGesture()
            }
            lastScrollEventTime = now
        }
        guard !gestureConsumed else { return }

        scrollAccumulatorY += event.scrollingDeltaY
        scrollAccumulatorX += event.scrollingDeltaX

        let threshold = viewModel.settings.swipeThreshold

        // Horizontal has to clearly dominate before it counts, otherwise a slightly
        // slanted open/close swipe would skip a track as a side effect.
        if abs(scrollAccumulatorX) > abs(scrollAccumulatorY) * 1.5 {
            guard !viewModel.isExpanded, viewModel.mediaRemote.nowPlaying != nil else { return }
            // Same sign convention as vertical: the delta follows the fingers, so
            // swiping right is positive. Right → next track, left → previous.
            if scrollAccumulatorX >= threshold {
                gestureConsumed = true
                DispatchQueue.main.async { self.viewModel.mediaRemote.next() }
            } else if scrollAccumulatorX <= -threshold {
                gestureConsumed = true
                DispatchQueue.main.async { self.viewModel.mediaRemote.previous() }
            }
            // Still resolving along the horizontal axis — don't let it also open.
            return
        }

        // With natural scrolling (the default), a two-finger swipe DOWN reports a
        // POSITIVE scrollingDeltaY (content is "pulled down" with the fingers) and a
        // swipe UP reports negative. Swipe down opens, swipe up closes.
        if scrollAccumulatorY >= threshold, !viewModel.isExpanded {
            gestureConsumed = true
            DispatchQueue.main.async { self.viewModel.expand() }
        } else if scrollAccumulatorY <= -threshold, viewModel.isExpanded {
            gestureConsumed = true
            collapseWorkItem?.cancel()
            collapseWorkItem = nil
            DispatchQueue.main.async { self.viewModel.collapse() }
        }
    }

    private func resetGesture() {
        scrollAccumulatorX = 0
        scrollAccumulatorY = 0
        gestureConsumed = false
    }
}
