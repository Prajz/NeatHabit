import SwiftUI

struct StudyScreen<Content: View>: View {
    let title: String
    let content: Content
    @Binding var tourStep: Int?
    @Binding var tourFrames: [TourAnchorID: CGRect]
    @State private var lastScrolledStep: Int? = -999

    init(title: String, tourStep: Binding<Int?>, tourFrames: Binding<[TourAnchorID: CGRect]>, @ViewBuilder content: () -> Content) {
        self.title = title
        self._tourStep = tourStep
        self._tourFrames = tourFrames
        self.content = content()
    }

    var body: some View {
        ZStack {
            AppBackground()

            ScrollViewReader { proxy in
                ScrollView(showsIndicators: false) {
                    content
                        .padding(.horizontal, ScreenScale.scale(18))
                        .padding(.top, ScreenScale.scale(12))
                        .padding(.bottom, ScreenScale.scale(34))
                }
                .coordinateSpace(name: TourCoordinateSpace.name)
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: tourStep) { _, newStep in
                    guard let step = newStep, step != lastScrolledStep else { return }
                    lastScrolledStep = step
                    let anchor = TourAnchorID.anchor(for: step)
                    guard let anchor else { return }
                    withAnimation(.smooth(duration: 0.45)) {
                        proxy.scrollTo(anchor.rawValue, anchor: .top)
                    }
                }
                .onPreferenceChange(TourElementFrameKey.self) { newFrames in
                    tourFrames = newFrames
                }
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.large)
    }
}
