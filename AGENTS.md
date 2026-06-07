# NeatHabit — Agent Guide

> **Read this before touching the codebase.** NeatHabit is a SwiftUI iOS 26 app for tracking the NeetCode 150 study plan plus a daily system design habit. It has a widget extension. Persistence lives in an App Group container. This file is the source of truth for architecture, conventions, and known landmines.

---

## 1. What this app is

A tracker for a 30-day, 60-day, or custom-length interview prep plan:

- **Today tab.** Day strip, problem list with neutral difficulty badges plus Green/Yellow/Red status, system design rep, study notes, redo queue.
- **Roadmap tab.** Full NeetCode 150 bank grouped by category. Tap to mark ahead — future days rebalance.
- **Progress tab.** Month-level stats. Target bars: ≥80 green, ~40 yellow, <30 red.
- **Guide tab.** Rules, settings, "show app tour", "shuffle problems", and "redo onboarding" controls.
- **Widget extension.** Small/medium home + circular/rectangular/inline lock-screen widgets. Reads App Group storage. One AppIntent: `ToggleHabitIntent`.

It does **not** run code, fetch problems, or talk to a network. All 150 problems, ~30 system design topics, and the entire plan generator are bundled. This is intentional. Keep it that way unless the user asks.

---

## 2. Repository layout

```
NeatHabit/
├── NeatHabit/                      # Main app target
│   ├── NeatHabitApp.swift              # @main entry
│   ├── ContentView.swift               # 2,534 lines. Tab roots, cards, tour overlay. Needs splitting (see §7).
│   ├── OnboardingView.swift            # 7-page onboarding flow with async completion state
│   ├── StudyProgressStore.swift        # @MainActor store + notifications + problem shuffle
│   ├── SystemDesignDetailView.swift    # System design topic detail page
│   ├── SystemDesignTopic.swift         # ~30 system design topics as Swift data
│   ├── DesignSystem.swift              # Theme, AppFont, LiquidGlassCard, buttons, haptics
│   ├── PrivacyInfo.xcprivacy           # Privacy manifest used by app + widget targets
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
├── BUGFIX_REFACTOR_PLAN.md
├── LOCAL_PYTHON_EXECUTION_PLAN.md
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
- **Product name:** intentionally `NeatHabitat` in Debug/Release. Do not rename it unless the user explicitly asks.
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
Generated from `StudyPlanner.plan(for: progress, lockThroughDay: optionalDay)`. **Past and current days are locked by default**, and the Today tab can lock through the selected future day while peeking ahead. Future days after the lock point are rebalanced to fill remaining problems. `currentDayNumber` uses `Date()` and clamps to the schedule length.

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

### ProblemDifficulty
`easy / medium / hard` is static bundled metadata from `StudyPlanner.difficulty(for:)`. Difficulty must stay visually neutral. Do not use green/yellow/red for difficulty because those colors are reserved for confidence/status.

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
- **Difficulty badges** are neutral metadata. Keep them monochrome/muted and visually separate from Green/Yellow/Red status chips.
- **Shuffle problems** compacts Green/Yellow future work into earlier open day capacity. It intentionally does not move Red redo items.

---

## 7. Known issues and TODOs (in priority order)

Read this before changing anything. Each item has been verified in the current code.

### Completed in the 2026-06-07 pass

1. **Widget reload debounce.** App-side `StudyProgressStore.commit` now delays `WidgetCenter.shared.reloadAllTimelines()` by 2 seconds so notes do not reload widgets on every keystroke.
2. **Onboarding completion race.** `completeOnboarding()` is async and onboarding shows a starting state while reminder scheduling is awaited.
3. **Deprecated screen width lookup.** `ScreenScale` now uses a root `GeometryReader` width update instead of `UIScreen.main.bounds`.
4. **Selected-day-aware rebalance.** `StudyPlanner.plan(for:lockThroughDay:)` supports locking through a selected future day, and Roadmap toggles use the adapted schedule.
5. **Tour tab bar sizing.** `WelcomeTourView` measures the actual `UITabBar` height when available.
6. **Privacy manifest.** `NeatHabit/PrivacyInfo.xcprivacy` is included in both app and widget resources and declares `UserDefaults` required-reason API usage.
7. **Redo reminder churn.** Redo reminders are refreshed only when red status or redo date state changes, including when a red roadmap problem is cleared.

### High — fix before next release

1. **App icon is a placeholder.** This can fail App Store review. Replace the asset catalog icon before submission.

### Medium — refactor opportunity

2. **Split `ContentView.swift`.** 2,534 lines still contain tab roots, cards, the redo sheet, the tour overlay, and utility functions. Suggested folders: `Views/Today`, `Views/Roadmap`, `Views/Progress`, `Views/Guide`, `Views/Tour`, `Views/Components`.
3. **Move `Shared/` into a local SPM package.** Currently the same files are in two `Sources` build phases. A package gives you one place to edit and a real module boundary.
4. **No localization.** Strings are hardcoded English. If a feature must be localized, switch to a string catalog first.

### Low — nice to have

5. **Add an `XCTest` target.** `StudyPlanner.plan(for:lockThroughDay:)`, `StudyPlanner.balancedCounts`, and `StoredProgress.redoCandidates` are pure enough to test. Ask before adding because the repo convention is no tests unless requested.
6. **Move `SystemDesignTopic.swift` (1,040 lines) to a bundled JSON.** Easier to review, easier to add topics, easier to test.
7. **Theme dynamic color stability.** `Theme` currently stores dynamic colors as `static let` values. Keep it that way if adding tokens.

---

## 8. Roadmap: on-device Python execution (planned, not implemented)

Detailed plan: `LOCAL_PYTHON_EXECUTION_PLAN.md`. Implement only when the user explicitly says to proceed.

### Corrected direction

1. **Use in-process CPython for v1.** Do not rely on `subprocess.Popen` or `resource.setrlimit` on iOS unless a dedicated feasibility spike proves child-process control is safe, reviewable, and shippable.
2. **Keep existing schedule strings stable.** Do not immediately replace `ProblemSection.problems: [String]`. Add a bundled app-only `ProblemCatalog.json` keyed by the current titles.
3. **Keep user code out of App Group progress.** The widget reads `StoredProgress`; source code and run history should live in app-only storage unless the widget has a direct need.
4. **Use a `PythonRuntimeActor`.** All CPython initialization and execution should be isolated behind one async API and lazy-loaded on first run.
5. **Be honest about sandboxing.** In-process Python is not a hostile-code sandbox. Use AST validation, restricted builtins, import allowlists, input/output caps, and cooperative timeouts.

### Phases

1. **Feasibility spike.** Prove CPython initializes and runs a tiny script on simulator and device. Measure cold start and binary size.
2. **Problem catalog.** Bundle rich problem metadata in the app target while preserving current progress keys.
3. **Solution storage.** Store user code in app-only Application Support, not in `StoredProgress`.
4. **Solve UI without Python.** Build navigation, prompt, editor, persistence, and fake run results first.
5. **Runtime actor.** Add CPython behind `run(solution:problem:tests:mode:) async -> RunResult`.
6. **Restricted harness.** Validate AST, restrict builtins/imports, run JSON test cases, capture bounded output.
7. **Results UX.** Show per-case failures, diffs, tracebacks, runtime, and a user-confirmed status suggestion.
8. **Review hardening.** No downloaded code, no network execution, no third-party Python packages, and update privacy copy.

### Out of scope

- No real LeetCode integration.
- No server execution.
- No downloaded prompts, tests, or reference solutions.
- No `numpy`, `pandas`, or third-party Python packages.
- No multi-language support in v1.
- No claim of hostile-code sandboxing in v1.

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
- They use the `Agents.md` / `AGENTS.md` convention. Filename on disk: `AGENTS.md` (uppercase). This is the canonical agents-spec name.
- When proposing a plan, structure it as: feasibility → options table → recommendation → phases → out-of-scope.
- For audits, structure as: layout → critical bugs (with file:line) → design smells → things that are good.
- Don't add features they didn't ask for. Don't add tests. Don't add comments. Don't add emoji.

---

## 11. Quick file index

| File | Lines | Owns |
|---|---|---|
| `NeatHabit/NeatHabitApp.swift` | 13 | `@main` entry |
| `NeatHabit/ContentView.swift` | 2,534 | All tabs, all cards, tour overlay, redo sheet, helpers |
| `NeatHabit/OnboardingView.swift` | 866 | 7-page onboarding flow |
| `NeatHabit/StudyProgressStore.swift` | 506 | Store, persistence glue, notification scheduling, shuffle compaction |
| `NeatHabit/SystemDesignDetailView.swift` | 516 | System design topic detail page (hero, diagram, concepts, talking points, tradeoffs) |
| `NeatHabit/SystemDesignTopic.swift` | 1,040 | ~30 system design topics as static data |
| `NeatHabit/DesignSystem.swift` | 396 | `Theme`, `AppFont`, `ScreenScale`, `AppBackground`, `LiquidGlassCard`, button styles, haptics, shimmer |
| `NeatHabit/PrivacyInfo.xcprivacy` | 27 | Privacy manifest for app and widget resources |
| `Shared/StudyPlan.swift` | 643 | `StudySettings`, `StudyDay`, `StudySchedule`, `StudyPlanner`, NeetCode 150 sections, difficulty metadata, system design rotation |
| `Shared/StudyProgress.swift` | 339 | `DailyProgress`, `StoredProgress`, `StatusCounts`, `PlanSummary`, `RedoCandidate`, `ProgressPersistence` |
| `NeatHabitWidget/NeatHabitWidget.swift` | 373 | Provider, entry, all 5 widget families, `WidgetTheme` |
| `NeatHabitWidget/WidgetActions.swift` | 40 | `ToggleHabitIntent` (one AppIntent) |

---

## 12. Glossary

- **App Group.** Shared container between the main app and widget extension. `group.uk.co.praj.NeatHabit`. Required for the widget to read `StoredProgress`.
- **Green / Yellow / Red.** Problem status. Green = got it solo in <35 min. Yellow = needed a hint. Red = did not understand; auto-schedules a redo.
- **Easy / Medium / Hard.** Static problem difficulty metadata. It is shown in neutral badges and should never use the status colors.
- **Redo queue.** Problems marked Red with a due date ≤ the selected day. Shown at the top of Today and on the Upcoming card.
- **Rebalance.** When you mark a problem ahead of schedule (e.g. from Roadmap), future days shrink so you don't double-do work. Past/current days are locked by default, and Today can lock through the selected future day.
- **Shuffle problems.** Guide action that moves Green/Yellow future-day statuses into the earliest earlier open slots. The planner then shifts displaced untouched problems forward. Red redo problems are not moved.
- **Morning reminder.** 9 AM local notification on each day that has one or more red problems due. Scheduled by `StudyProgressStore.scheduleMorningReminderIfNeeded`.
- **Daily reminder.** Repeating notification at the user's chosen time. Scheduled by `StudyProgressStore.scheduleDailyReminderIfNeeded`.
- **Per-question budget.** `problemBlockMinutes / 20` minutes. The onboarding uses this to warn when the plan is too tight.
- **System design focus.** Rotates through 30 system design topics. Each day in the plan has exactly one. The detail view (`SystemDesignDetailView`) explains that topic.
- **Liquid Glass.** The iOS 26 design system. Implemented in this app as `LiquidGlassCard` (gradient overlays, subtle borders, layered shadows).

---

_Last updated after the 2026-06-07 bugfix/refactor pass. Current findings are in §7. The on-device Python plan is in §8 and `LOCAL_PYTHON_EXECUTION_PLAN.md`. Do not implement §8 without an explicit go-ahead._
