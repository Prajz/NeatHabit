# Bugfix And Refactor Plan

Status: updated after the 2026-06-07 implementation pass.

## Implemented In This Pass

- Kept `PRODUCT_NAME = NeatHabitat` unchanged because that name is intentional for now.
- Debounced app-side widget timeline reloads to 2 seconds in `StudyProgressStore.commit` so notes no longer reload widgets on every keystroke.
- Made onboarding completion await reminder scheduling before dismissing the onboarding flow.
- Added an onboarding CTA in-progress state so the user gets feedback while notification authorization and scheduling run.
- Changed redo reminder scheduling so it only refreshes when red status or redo date state actually changes.
- Made roadmap clearing of a red problem refresh morning reminders so stale redo notifications are removed.
- Made roadmap problem assignment use the currently adapted schedule instead of the base schedule.
- Added `StudyPlanner.plan(for:lockThroughDay:)` and `StudyProgressStore.schedule(lockingThrough:)` so selected future days can anchor rebalancing.
- Changed the Today tab to use selected-day-aware planning when peeking ahead.
- Replaced deprecated `UIScreen.main.bounds` scaling with a root `GeometryReader` width update.
- Changed the welcome tour tab bar highlight to use the measured `UITabBar` height when available.
- Added `NeatHabit/PrivacyInfo.xcprivacy` to the app and widget targets, including the `UserDefaults` required-reason API declaration.

## Remaining Release Fixes

| Priority | Work | Reason | Recommendation |
|---|---|---|---|
| High | Replace placeholder app icon | App Store review risk | Do this before any TestFlight/App Store submission. |
| Medium | Split `ContentView.swift` | It is still 2,484 lines and owns too many tabs/cards/sheets/tour pieces | Split only after a clean build and preferably after adding tests or snapshot checks. |
| Medium | Move `Shared/` into a local package | The app and widget still compile the same files from two target source phases | Do after the Python data-model work is scoped because both affect shared boundaries. |
| Medium | Add localization/string catalog | Strings are still hardcoded English | Defer until the product wording stabilizes. |
| Low | Add XCTest target | Planner and redo logic are pure enough to test well | Ask before adding because the repo convention says no tests unless requested. |
| Low | Move system design topics to JSON | `SystemDesignTopic.swift` is still large static data | Defer until the Python catalog JSON shape is settled. |

## Refactor Sequence

1. Replace the app icon and verify the asset catalog in Xcode.
2. Add focused tests for `StudyPlanner.plan(for:lockThroughDay:)`, redo candidates, and reminder reschedule decisions if tests are approved.
3. Split `ContentView.swift` by feature area: Today, Roadmap, Progress, Guide, Tour, and shared card components.
4. Move `Shared/StudyPlan.swift` and `Shared/StudyProgress.swift` into a local package once the Python catalog plan is finalized.
5. Move bundled problem metadata and system design topics into JSON resources if the local Python feature proceeds.

## Verification Checklist

- Build the app target and widget extension.
- Type rapidly in the notes editor and confirm widget reloads are delayed rather than immediate per keypress.
- Complete onboarding with notifications enabled and confirm the onboarding sheet waits during authorization/scheduling.
- Mark a problem red, set the same red status again, and confirm morning reminders are not repeatedly recreated.
- Clear a red roadmap problem and confirm morning reminder state is refreshed.
- Select a future day, open Roadmap, mark a problem, and confirm the assigned day follows the adapted schedule.
- Add app and lock-screen widgets on simulator/device and confirm they still read App Group progress.
