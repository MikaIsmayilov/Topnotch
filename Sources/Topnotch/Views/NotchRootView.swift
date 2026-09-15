import SwiftUI

/// The window itself is created once at its maximum (expanded) size and never resized —
/// only this visible shape grows/shrinks, driven by a real spring so open/close bounces
/// instead of just easing. `NotchHostingView.hitTest` makes everything outside the
/// currently-visible shape click-through to whatever's beneath.
///
/// Layout is two layers, both top-anchored: the status strip (exactly notch-height,
/// tracks the animating width so its flanks always hug the camera cutout) and the
/// expanded body, which is laid out at its final size and simply *revealed* as the
/// container grows, like a curtain — so nothing inside squishes mid-animation.
struct NotchRootView: View {
    @ObservedObject var viewModel: NotchViewModel

    private var visibleSize: CGSize { viewModel.drawnSize }

    /// Hovering rounds the bottom corners a little further as the pill swells, so it
    /// reads as puffing outward rather than just getting taller.
    private var bottomRadius: CGFloat {
        if viewModel.isExpanded { return 22 }
        return viewModel.isHovering ? 15 : 12
    }

    private var isPopped: Bool { viewModel.isHovering && !viewModel.isExpanded }

    var body: some View {
        ZStack(alignment: .top) {
            ZStack(alignment: .top) {
                Color.black

                StatusStrip(
                    viewModel: viewModel,
                    media: viewModel.mediaRemote,
                    timer: viewModel.pomodoro,
                    settings: viewModel.settings,
                    power: viewModel.power
                )
                .frame(height: viewModel.stripHeight)
            }
            .frame(width: visibleSize.width, height: visibleSize.height)
            // The body is an overlay, not a ZStack child, so its fixed expanded width
            // can't inflate the container and drag the strip's flanks out past the clip
            // while collapsed. Kept mounted and faded rather than inserted/removed, so
            // it dissolves in step with the spring instead of popping out and leaving a
            // bare black slab for the length of the close animation.
            .overlay(alignment: .top) {
                ExpandedView(viewModel: viewModel, settings: viewModel.settings)
                    .frame(width: viewModel.expandedSize.width, height: NotchViewModel.bodyHeight)
                    .padding(.top, viewModel.stripHeight)
                    .opacity(viewModel.isExpanded ? 1 : 0)
                    .allowsHitTesting(viewModel.isExpanded)
            }
            .clipShape(NotchShape(bottomRadius: bottomRadius))
            .overlay(
                NotchShape(bottomRadius: bottomRadius)
                    .stroke(
                        viewModel.isDropTargeted
                            ? Theme.defaultAccent
                            : Color.white.opacity(isPopped ? 0.18 : 0.07),
                        lineWidth: viewModel.isDropTargeted ? 1.5 : 1
                    )
            )
            // The rim brightening alone is easy to miss against the bezel, so the swell
            // also casts a faint glow to separate the pill from the black around it.
            .shadow(
                color: Color.black.opacity(isPopped ? 0.55 : 0),
                radius: isPopped ? 12 : 0,
                y: isPopped ? 4 : 0
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onTapGesture {
            if !viewModel.isExpanded {
                viewModel.expand()
            }
        }
    }
}
