import SwiftUI

@main
struct NeatHabitApp: App {
    @StateObject private var store = StudyProgressStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
        }
    }
}
