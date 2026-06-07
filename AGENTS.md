# NeatHabit — Agent Guide

> **Read this before touching the codebase.** NeatHabit is a SwiftUI iOS 26 app for tracking the NeetCode 150 study plan plus a daily system design habit. It has a widget extension. Persistence lives in an App Group container. This file is the source of truth for architecture, conventions, and known landmines.

---

## 1. What this app is

A tracker for a 30-day, 60-day, or custom-length interview prep plan:

- **Today tab.** Day strip, problem list with Green/Yellow/Red status, system design rep, study notes, redo queue.
- **Roadmap tab.** Full NeetCode 150 bank grouped by category. Tap to mark ahead — future days rebalance.
- **Progress tab.** Month-level stats. Target bars: ≥80 green, ~40 yellow, <30 red.
- **Guide tab.** Rules, settings, and a "redo onboarding" button.
- **Widget extension.** Small/medium home + circular/rectangular/inline lock-screen widgets. Reads App Group storage. One AppIntent: `ToggleHabitIntent`.

It does **not** run code, fetch problems, or talk to a network. All 150 problems, ~30 system design topics, and the entire plan generator are bundled. This is intentional. Keep it that way unless the user asks.

---

## 2. Repository layout

```
NeatHabit/
├── NeatHabit/                      # Main app target
│   ├── NeatHabitApp.swift              # @main entry
│   ├── ContentView.swift               # 2,450 lines. Tab roots, cards, tour overlay. Needs splitting (see §7).
│   ├── OnboardingView.swift            # 7-page onboarding flow
│   ├── StudyProgressStore.swift        # @MainActor store + notifications
│   ├── SystemDesignDetailView.swift    # System design topic detail page
│   ├── SystemDesignTopic.swift         # ~30 system design topics as Swift data
│   ├── DesignSystem.swift              # Theme, AppFont, LiquidGlassCard, buttons, haptics
│   ├── Info.plist
│   ├── NeatHabit.entitlements          # App Group: group.uk.co.praj.NeatHabit
│   └── Assets.xcassets
├── Shared/                          # Compiled into BOTH app and widget
│   ├── StudyPlan.swift                 # Model + StudyPlanner + 150 questions + system design rotation
│   └── StudyProgress.swift             # StoredProgress, DailyProgress, App Group persistence
├── NeatHabitWidget/                # Widget extension
│   ├── NeatHabitWidget.swift           # Provider, entry, all widget variants, WidgetTheme
│   ├── WidgetActions.swift             # ToggleHabitIntent
│   ├── Info.plist
│   └── NeatHabitWidget.entitlements
├── NeatHabit.xcodeproj/
└── README.md
```

`Shared/*.swift` are listed in **both** targets' `Sources` build phases. That works in Xcode 15+ but every edit touches two phases. If you refactor, move these into a local SPM package or a framework target.

---

## 3. Build, run, sign

- **Xcode:** 16+ (project is `objectVersion = 60`, `LastUpgradeCheck = 2650`).
- **Deployment target:** iOS 26.0. Do not lower.
- **Swift:** 6.0. Strict concurrency is on. `@MainActor` is the default for the store; do not put UI work on background actors.
- **Team:** `TYVJV99Z56` (set in `project.pbxproj`). The user is `praj`. If you sign on a different machine, override the team in the target editor.
- **Bundle IDs:** `uk.co.praj.NeatHabit` (app) and `uk.co.praj.NeatHabit.widget` (extension).
- **App Group:** `group.uk.co.praj.NeatHabit` in both entitlements. The persistence key `neatHabit.progress.v2` lives in the App Group's `UserDefaults` so the widget can read it.

To run on a device: set your team in both targets and make sure the App Group capability is enabled on your Apple ID. Simulator runs without signing.

---

## 4. Architecture in one diagram

```
   NeatHabitApp
        │
        ▼
   ContentView (root)
        │
        ├── OnboardingView  (if !hasCompletedOnboarding)
        └── TabView
              ├── TodayTab        → StudyScreen → Cards (Day, Redo, Problems, SystemDesign, Notes)
              ├── RoadmapTab      → QuestionBankRoadmapCard
              ├── ProgressTab     → Hero / Targets / HabitStats / StatusLegend / Upcoming
              └── GuideTab        → GuideHeader / Setup / Topics / ExtraPractice / Rules
                       │
                       ▼
            StudyProgressStore (@MainActor, ObservableObject)
                       │
                       ├── ProgressPersistence  →  App Group UserDefaults
                       │     (Shared/StudyProgress.swift)
                       └── UNUserNotificationCenter
                              (daily reminder + per-red morning reminders)

   NeatHabitWidgetExtension
        │
        ▼
   NeatHabitProvider → ProgressPersistence.load() → WidgetCenter.reload
        │
        └── AppIntent: ToggleHabitIntent (toggles one habit in App Group store)
```

The widget **never** calls the store. It reads `ProgressPersistence.load()` directly. If you mutate state from a widget intent, call `WidgetCenter.shared.reloadAllTimelines()` after saving.

---

## 5. Data model (the parts you must not break)

`Shared/StudyPlan.swift` and `Shared/StudyProgress.swift` are the contract between app and widget.

### StudySettings
```swift
struct StudySettings: Codable, Equatable {
    var dailyMinutes: Int              // legacy, kept for back-compat
    var targetFinishDate: Date
    var extraProblems: [CustomProblem] // user-added practice problems
    var reminderHour: Int              // 0-23
    var reminderMinute: Int            // 0-59
    var notificationsEnabled: Bool
    var systemDesignMinutes: Int       // 15-40
    var problemBlockMinutes: Int       // derived but stored
}
```

### StudySchedule
Generated from `StudyPlanner.plan(for: progress)`. **Past and current days are locked**, future days are rebalanced to fill remaining problems. `currentDayNumber` uses `Date()` and clamps to the schedule length.

### DailyProgress
```swift
struct DailyProgress: Codable, Equatable {
    var completedHabits: Set<StudyHabit>      // { .systemDesign, .review, .pattern, .problems }
    var systemDesignChecks: Set<String>       // 5 fixed IDs in ContentView.swift
    var problemStatuses: [String: ProblemStatus]
    var redoDates: [String: Date]
    var note: String
}
```

`CodingKeys` includes a legacy `redoLaterProblems` key that is read for migration but never written. See `StudyProgress.swift:53-90`. **Do not remove the read path** until you are confident no user's JSON still contains it.

### StoredProgress
```swift
struct StoredProgress: Codable, Equatable {
    var startDate: Date
    var settings: StudySettings
    var dayProgress: [Int: DailyProgress]     // sparse, key is the day number (1-based)
}
```

Persisted at `UserDefaults(suiteName: appGroupIdentifier).data(forKey: "neatHabit.progress.v2")`. When bumping the schema, write a `v3` migration that loads v2, transforms, and writes v3 atomically.

### ProblemStatus
`untouched → green → yellow → red → untouched`. `red` triggers a redo date suggestion and schedules a 9 AM morning reminder.

### RedoCandidate
Returned by `StoredProgress.redoCandidates(for:in:)`. Sorted by due date. Used to populate the "Review + redo" card on Today and Upcoming card on Progress.

---

## 6. Conventions (do not deviate)

- **No comments.** The user has not asked for any. If you think code is unclear, ask first.
- **No emojis in code, README, or commit messages.**
- **No third-party dependencies.** Everything is Foundation/SwiftUI/UIKit/WidgetKit/AppIntents/UserNotifications/Combine. If you need something else, justify it.
- **No new file unless the user asks.** Prefer adding to existing files. If `ContentView.swift` needs to be split, ask first.
- **No tests unless asked.** The project has no test target. Do not silently add one.
- **Color tokens are in `Theme` (app) and `WidgetTheme` (widget).** Both are duplicated. If you add a token, add it in both.
- **`@MainActor` on the store.** All view bodies that touch `StudyProgressStore` inherit the actor. Don't try to await it from a non-isolated context — wrap in `await MainActor.run`.
- **Haptics** go through `Haptics.selection()` / `Haptics.success()`. Do not call `UIImpactFeedbackGenerator` directly.
- **App Group writes** go through `ProgressPersistence.save(_:)`. That is the only sanctioned way.
- **Notifications** are scheduled by `StudyProgressStore`. Do not call `UNUserNotificationCenter` from a view.

---

## 7. Known issues and TODOs (in priority order)

Read this before changing anything. Each item has been verified in the current code.

### High — fix before next release

1. **`PRODUCT_NAME = NeatHabitat` is a typo** (`project.pbxproj:422,451`). The shipped `.app` is `NeatHabitat.app`. Set to `NeatHabit` and confirm the bundle ID is unchanged (`uk.co.praj.NeatHabit` from `PRODUCT_BUNDLE_IDENTIFIER`).
2. **Widget reloads on every keystroke.** `StudyProgressStore.commit` calls `WidgetCenter.shared.reloadAllTimelines()`. Notes in `TextEditor` will fire this per character. Debounce to 2s.
3. **Race in `completeOnboarding`.** `StudyProgressStore.swift:290-297` fires the notification request as a non-awaited `Task`. Show an async indicator or await before dismissing onboarding.
4. **`UIScreen.main.bounds`** in `DesignSystem.swift:8` is deprecated since iOS 16. Switch to a `GeometryReader` at the root or a stored `screenWidth` set on app launch.
5. **Plan rebalance is anchored to "today", not "selected day".** `StudyPlanner.plan(for:)` (`StudyPlan.swift:304-357`) locks days up to `currentDayNumber` (today). The Roadmap tab can show a future day with the **base** plan, not the rebalanced one. Either rebalance against the selected day or rename the function so the contract is explicit.
6. **App icon is a placeholder.** Will fail App Store review.

### Medium — refactor opportunity

7. **Split `ContentView.swift`.** 2,450 lines containing tab roots, ~15 cards, the redo sheet, the tour overlay, and utility functions. Suggest `Views/Today`, `Views/Roadmap`, `Views/Progress`, `Views/Guide`, `Views/Tour`, `Views/Components`.
8. **Move `Shared/` into a local SPM package.** Currently the same files are in two `Sources` build phases. A package gives you one place to edit and a real module boundary.
9. **`WelcomeTourView` hardcodes `tabBarHeight = 49`** (`ContentView.swift:2212`). Wrong on iPad and on iOS 26's custom tab bar shapes. Use safe-area insets or measure the actual `UITabBar`.
10. **`UIColor { traits in ... }` constructed per render** in `Theme.dynamic`. Move to `static let` so SwiftUI sees a stable `Color` value and avoids identity churn.
11. **No `PrivacyInfo.xcprivacy`.** Required for App Store on iOS 17+. Even "we track nothing" needs the file declaring `NSPrivacyAccessedAPITypes: []`.
12. **No localization.** Strings are hardcoded English. If a feature must be localized, switch to a string catalog first.
13. **`setStatus(.red)` reschedules morning reminders** even when the date is unchanged. Compare old and new redo date before re-scheduling.

### Low — nice to have

14. **Add an `XCTest` target.** `StudyPlanner.balancedCounts` and `StoredProgress.redoCandidates` are pure and easy to test. Catches rebalance regressions.
15. **`ProblemSection.problems` could become `LeetProblem`** with `difficulty`, `prompt`, `signature`, `tests`, `hints`. This is a prerequisite for the on-device Python plan below.
16. **Move `SystemDesignTopic.swift` (1,040 lines) to a bundled JSON.** Easier to review, easier to add topics, easier to test.

---

## 8. Roadmap: on-device Python execution (planned, not implemented)

The user has asked: can users actually solve problems in the app? Yes, by embedding Python 3.13 in the app via the official `Python.xcframework` (same approach Pythonista and a-Shell have shipped for years). This section is the plan, not a TODO list. Implement only when the user says so.

### Phases

**0. Data model.** Replace `[String]` in `ProblemSection.problems` with `[LeetProblem]` carrying `difficulty`, `prompt`, `functionName`, `signature`, `tests: [TestCase]`, `hints`. Ship a `problems.json` in the bundle. Keep the old title array as a thin compatibility shim.

**1. Code editor.** New `SolveView` pushed from `ProblemRow` when status is `.untouched` or `.yellow`. `TextEditor` for v1; iOS 26 `Syntax` framework for highlighting. Persist in-progress code as `DailyProgress.userCode: [String: String]`. "Run sample" is a no-op for now; it proves the data path.

**2. Embedded Python.** Add `Python.xcframework` via SPM (or a thin local wrapper if upstream lags). New `PythonRunner` with one entry:
```swift
func run(solution: String, signature: String, tests: [TestCase],
         timeLimitMs: Int, memLimitMB: Int) async -> RunResult
```
Run user code via `subprocess.Popen` inside Python with `resource` limits (CPU, memory, wall time). Return `RunResult { passed, total, perCase, error }`. Map to a *suggested* `ProblemStatus`; user always confirms.

**3. Result UX.** Per-case pass/fail with diff, runtime ms, collapsed traceback. "View canonical solution" reveals a stored reference implementation from the bundle.

**4. Offline guarantee.** Confirm App Store review (Pythonista has shipped this since 2014). Add an onboarding toggle: "Practice in app vs mark status only" (default ON for the new flow). Cache last run per problem.

**5. Stretch.** Re-run on save (debounced). Apple Foundation Models (iOS 26) for "explain this error" — fully on device. Export run history as JSON.

### Out of scope (be explicit)

- No real LeetCode integration. Problem bank is curated and bundled.
- No Python packages beyond stdlib. `numpy`/`pandas` are 50–100 MB and unnecessary for these problems.
- No multi-language. Swift is too painful to sandbox; JavaScript would mean embedding JSC (doable, later).

### Pitfalls

- **iOS disallows executable memory.** CPython 3.13 supports iOS via the Tier-2 interpreter (PEP 744). Use the official upstream build, not a JIT build.
- **App Store review.** Embedded interpreters are allowed but must not download code. Test cases and reference solutions must be in the bundle.
- **Sandboxing.** `subprocess.Popen` from inside the embedded Python is fine — it inherits the app's sandbox. Use `resource.setrlimit` for CPU/memory.
- **Cold start.** ~150–400 ms for first import. Acceptable for a "Run" button, not for "open app". Lazy-load Python on first use.

---

## 9. Conventions for adding features

When you are asked to add something new:

1. **Locate first.** `grep` and `glob` before writing. Many helpers already exist: `percent(_:)`, `shortDateText(_:)`, `LiquidGlassCard`, `SWPrimaryGlassButtonStyle`, `Haptics`.
2. **Match the design language.** New cards use `LiquidGlassCard(tint: Theme.accent)`. New buttons use `SWPrimaryGlassButtonStyle` or `SWSecondaryGlassButtonStyle`. New text uses `AppFont` or system with the project's tracking/weight choices.
3. **Use the store.** All persistence flows through `StudyProgressStore`. Do not write `UserDefaults` from a view. Do not call `UNUserNotificationCenter` from a view.
4. **Test the widget.** If the feature changes `StoredProgress` shape, the widget may need updates. Re-run on the device (or simulator) and add widgets to a Home Screen and Lock Screen to confirm.
5. **Document in `CHANGELOG.md` if it exists.** It does not. Ask the user if they want one.
6. **No new third-party packages** without explicit ask. SPM dependencies for the Python plan are the only approved exception so far.

---

## 10. Communication style with the user

- The user wants **concise, direct** answers. No preamble, no postamble. A one-line answer beats a paragraph.
- They explicitly asked for a **plan, not implementation** in this session. Respect that. Don't write code unless asked.
- They use the `Agents.md` / `AGENTS.md` convention. Filename on disk: `AGENTS.md` (uppercase). This is the canonical agents-spec name.
- When proposing a plan, structure it as: feasibility → options table → recommendation → phases → out-of-scope.
- For audits, structure as: layout → critical bugs (with file:line) → design smells → things that are good.
- Don't add features they didn't ask for. Don't add tests. Don't add comments. Don't add emoji.

---

## 11. Quick file index

| File | Lines | Owns |
|---|---|---|
| `NeatHabit/NeatHabitApp.swift` | 13 | `@main` entry |
| `NeatHabit/ContentView.swift` | 2,450 | All tabs, all cards, tour overlay, redo sheet, helpers |
| `NeatHabit/OnboardingView.swift` | 850 | 7-page onboarding flow |
| `NeatHabit/StudyProgressStore.swift` | 414 | Store, persistence glue, notification scheduling |
| `NeatHabit/SystemDesignDetailView.swift` | 516 | System design topic detail page (hero, diagram, concepts, talking points, tradeoffs) |
| `NeatHabit/SystemDesignTopic.swift` | 1,040 | ~30 system design topics as static data |
| `NeatHabit/DesignSystem.swift` | 389 | `Theme`, `AppFont`, `ScreenScale`, `AppBackground`, `LiquidGlassCard`, button styles, haptics, shimmer |
| `Shared/StudyPlan.swift` | 587 | `StudySettings`, `StudyDay`, `StudySchedule`, `StudyPlanner`, NeetCode 150 sections, system design rotation |
| `Shared/StudyProgress.swift` | 339 | `DailyProgress`, `StoredProgress`, `StatusCounts`, `PlanSummary`, `RedoCandidate`, `ProgressPersistence` |
| `NeatHabitWidget/NeatHabitWidget.swift` | 373 | Provider, entry, all 5 widget families, `WidgetTheme` |
| `NeatHabitWidget/WidgetActions.swift` | 40 | `ToggleHabitIntent` (one AppIntent) |

---

## 12. Glossary

- **App Group.** Shared container between the main app and widget extension. `group.uk.co.praj.NeatHabit`. Required for the widget to read `StoredProgress`.
- **Green / Yellow / Red.** Problem status. Green = got it solo in <35 min. Yellow = needed a hint. Red = did not understand; auto-schedules a redo.
- **Redo queue.** Problems marked Red with a due date ≤ the selected day. Shown at the top of Today and on the Upcoming card.
- **Rebalance.** When you mark a problem ahead of schedule (e.g. from Roadmap), future days shrink so you don't double-do work. Past days are locked.
- **Morning reminder.** 9 AM local notification on each day that has one or more red problems due. Scheduled by `StudyProgressStore.scheduleMorningReminderIfNeeded`.
- **Daily reminder.** Repeating notification at the user's chosen time. Scheduled by `StudyProgressStore.scheduleDailyReminderIfNeeded`.
- **Per-question budget.** `problemBlockMinutes / 20` minutes. The onboarding uses this to warn when the plan is too tight.
- **System design focus.** Rotates through 30 system design topics. Each day in the plan has exactly one. The detail view (`SystemDesignDetailView`) explains that topic.
- **Liquid Glass.** The iOS 26 design system. Implemented in this app as `LiquidGlassCard` (gradient overlays, subtle borders, layered shadows).

---

_Last updated alongside the audit that produced this file. The audit's findings are in §7. The on-device Python plan is in §8. Do not implement §8 without an explicit go-ahead._
