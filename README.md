# NeatHabit

NeatHabit is a SwiftUI iOS 26 tracker for the NeetCode 150 plan plus a daily system design habit.

## Included

- Dynamic plan generated from the official 150-question NeetCode bank.
- First-run onboarding for target date, study budget, and optional pattern study.
- Daily habit checks for system design, optional pattern study, and review/redo only when redo is scheduled.
- Green/yellow/red problem tracking using the target definitions from the plan.
- Redo dates for red problems, with an automatic suggestion and manual date picker.
- Study notes per day.
- Four tabs: Today, Roadmap, Progress, and Guide.
- Blue-accent SwiftUI design that reserves green/yellow/red for problem status.
- Small and medium Home Screen widgets.
- Circular, rectangular, and inline Lock Screen widgets powered by shared App Group storage.

## How to Use

1. Use onboarding to set the target finish date, daily time, and optional pattern study.
2. Follow the daily flow: solve the problem rows, complete system design, and add optional pattern study if enabled.
3. Tap a problem row to cycle `Todo -> Green -> Yellow -> Red`.
4. Use Red honestly. Red problems get an automatic redo date, or you can pick the date yourself.
5. Use Roadmap to jump around the generated calendar.
6. Use Progress to track the monthly goals: 80+ green, 40+ yellow, under 30 red.
7. Add a Home Screen widget for daily status and a Lock Screen widget for quick habit pressure.

## Run

Open `NeatHabit.xcodeproj` in Xcode and run the `NeatHabit` scheme on an iPhone running iOS 26.0 or newer.

For a physical device, set your Apple development team in the app and widget targets and make sure both targets use the App Group `group.uk.co.praj.NeatHabit`.
