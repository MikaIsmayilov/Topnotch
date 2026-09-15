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

    private var visibleSize: CGSize {
        viewModel.isExpanded ? viewModel.expandedSize : viewModel.collapsedSize
    }

    private var bottomRadius: CGFloat {
        viewModel.isExpanded ? 22 : 12
    }

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
                        viewModel.isDropTargeted ? Theme.defaultAccent : Color.white.opacity(0.07),
                        lineWidth: viewModel.isDropTargeted ? 1.5 : 1
                    )
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
