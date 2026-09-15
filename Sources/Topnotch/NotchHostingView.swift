import AppKit
import SwiftUI

/// Hosting view that also accepts file drags, so dropping a file anywhere on the notch
/// (even while collapsed) expands it to the Files tab and copies the file into the tray.
final class NotchHostingView: NSHostingView<NotchRootView> {
    var viewModel: NotchViewModel!

    required init(rootView: NotchRootView) {
        super.init(rootView: rootView)
        registerForDraggedTypes([.fileURL])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Nonactivating panels don't automatically become key on click (that's what lets
    /// them appear without stealing focus from the frontmost app). We want the opposite
    /// the moment someone actually clicks inside — e.g. to type in the Notes widget —
    /// so promote it to key window ourselves before normal hit-testing continues.
    override func mouseDown(with event: NSEvent) {
        window?.makeKey()
        super.mouseDown(with: event)
    }

    /// The window is always sized to the maximum (expanded) footprint so SwiftUI alone
    /// can animate the visible shape with a real spring. That means most of the window
    /// is normally empty/invisible, and clicks there must fall through to whatever is
    /// underneath (desktop, other apps) instead of being swallowed by us.
    override func hitTest(_ point: NSPoint) -> NSView? {
        guard let superview else { return super.hitTest(point) }
        let local = superview.convert(point, to: self)
        let size = viewModel.drawnSize
        // Our visible shape is top-anchored; whether "top" is y = 0 or y = bounds.height
        // depends on whether this view is flipped, so check rather than assume.
        let visibleRect = NSRect(
            x: (bounds.width - size.width) / 2,
            y: isFlipped ? 0 : bounds.height - size.height,
            width: size.width,
            height: size.height
        )
        guard visibleRect.contains(local) else { return nil }
        return super.hitTest(point)
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        viewModel.isDropTargeted = true
        viewModel.expand(to: .files)
        return .copy
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        viewModel.isDropTargeted = false
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        viewModel.isDropTargeted = false
        guard let urls = sender.draggingPasteboard.readObjects(
            forClasses: [NSURL.self],
            options: [.urlReadingFileURLsOnly: true]
        ) as? [URL], !urls.isEmpty else { return false }
        viewModel.fileTray.add(urls: urls)
        return true
    }
}
