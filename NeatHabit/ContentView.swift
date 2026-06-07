import SwiftUI
import UIKit

enum AppTab: Hashable {
    case today
    case roadmap
    case progress
    case guide
}

struct ContentView: View {
    @EnvironmentObject private var store: StudyProgressStore
    @State private var selectedTab: AppTab = .today
    @State private var selectedDay = 1
    @State private var selectedInitialDay = false
    @State private var tourStep: Int? = nil
    @State private var tourFrames: [TourAnchorID: CGRect] = [:]

    var body: some View {
        GeometryReader { geo in
            content
                .onAppear {
                    ScreenScale.update(width: geo.size.width)
                }
                .onChange(of: geo.size.width) { _, width in
                    ScreenScale.update(width: width)
                }
        }
    }

    private var content: some View {
        ZStack {
            Group {
                if store.hasCompletedOnboarding {
                    mainTabs
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
                } else {
                    OnboardingView()
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
            .animation(.smooth(duration: 0.45), value: store.hasCompletedOnboarding)
            .font(AppFont.body())

            if store.hasCompletedOnboarding && !store.hasSeenWelcomeTour && selectedTab == .today {
                WelcomeTourView(tourStep: $tourStep, tourFrames: tourFrames)
                    .transition(.opacity)
                    .zIndex(10)
            }
        }
    }

    private var mainTabs: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                TodayTab(selectedDay: $selectedDay, tourStep: $tourStep, tourFrames: $tourFrames)
            }
            .tabItem { Label("Today", systemImage: "target") }
            .tag(AppTab.today)

            NavigationStack {
                RoadmapTab(selectedDay: $selectedDay, selectedTab: $selectedTab)
            }
            .tabItem { Label("Roadmap", systemImage: "map.fill") }
            .tag(AppTab.roadmap)

            NavigationStack {
                ProgressTab(selectedDay: $selectedDay, selectedTab: $selectedTab)
            }
            .tabItem { Label("Progress", systemImage: "chart.bar.xaxis") }
            .tag(AppTab.progress)

            NavigationStack {
                GuideTab(selectedTab: $selectedTab)
            }
            .tabItem { Label("Guide", systemImage: "questionmark.circle.fill") }
            .tag(AppTab.guide)
        }
        .tint(Theme.accent)
        .onAppear {
            guard !selectedInitialDay else { return }
            selectedDay = store.progress.currentDayNumber(in: store.schedule)
            selectedInitialDay = true
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(StudyProgressStore())
}
