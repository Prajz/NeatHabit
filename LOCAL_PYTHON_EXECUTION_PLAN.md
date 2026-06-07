# Local Python Execution Plan

Status: ready for implementation planning, not yet implemented.

## Feasibility

Running Python locally on the phone is feasible, but the old sketch in `AGENTS.md` had two important gaps.

- Do not rely on `subprocess.Popen` on iOS for v1. iOS app extensions and apps should not assume they can spawn and manage child processes, and CPython's iOS support should be treated as an in-process embedding story unless a dedicated feasibility spike proves otherwise.
- Do not store user code inside the App Group progress JSON. The widget reads that JSON, so source code and run history would make widget timeline loading heavier and would expose data the widget does not need.

## Options

| Option | How it works | Pros | Cons | Use |
|---|---|---|---|---|
| In-process CPython | Embed CPython, run a restricted harness inside the app process | Most realistic iOS path, offline, direct Swift bridge possible | Not a true sandbox, runaway code must be managed conservatively | Recommended v1 |
| Child-process CPython | Spawn Python as a subprocess and kill on timeout | Stronger timeout story if allowed | Not reliable on iOS, App Store and sandbox risk, old plan assumed too much | Do not use unless spike proves it |
| WebAssembly Python | Run Python in a WASM runtime | Better isolation model | Adds a heavy third-party runtime, more complexity, slower | Not v1 |
| Server runner | Send code to backend | Easy sandboxing | Violates offline goal and privacy posture | Out of scope |

## Recommendation

Build v1 as an in-process CPython runner with a restricted harness, bundled problem metadata, app-only solution storage, and explicit UX around timeouts. Treat it as an offline personal practice tool, not as a hostile-code sandbox.

## Corrected Architecture

```text
ProblemCatalog.json in app bundle
        |
        v
SolveView -> SolutionStore(app-only) -> PythonRuntimeActor -> CPython harness
        |                                      |
        v                                      v
StudyProgressStore status update       RunResult JSON
        |
        v
App Group StoredProgress for widget-visible habit/status only
```

## Phase 0 - Feasibility Spike

Goal: prove the runtime before changing the UX.

1. Confirm the exact CPython iOS artifact path.
2. Prefer an official or upstream-built `Python.xcframework` for Python 3.13+.
3. If no stable SPM artifact exists, build a local `Python.xcframework` from upstream CPython and document the build command.
4. Add the framework to a throwaway branch and run `print(1 + 1)` from Swift on simulator and device.
5. Measure cold-start time, warm-run time, framework size, and bundled stdlib size.
6. Confirm the app still archives with the widget extension.
7. Confirm no network or downloaded code is involved.

Exit criteria: Swift can initialize Python lazily, execute a tiny script, return JSON, and shut down or reuse the runtime without crashing.

## Phase 1 - Problem Data Model

Goal: add rich LeetCode metadata without breaking the current schedule and widget model.

1. Keep `ProblemSection.problems: [String]` for the schedule and widget contract.
2. Add an app-only `ProblemCatalog` loader keyed by problem title.
3. Bundle `ProblemCatalog.json` in the app target only, not the widget target.
4. Define `LeetProblem` with `title`, `slug`, `difficulty`, `prompt`, `functionName`, `signature`, `starterCode`, `sampleTests`, `hiddenTests`, `constraints`, `hints`, and `referenceSolution`.
5. Define `TestCase` as JSON-serializable values, not Swift closures.
6. Keep each problem's display title identical to the current NeetCode title so existing progress keys remain valid.
7. Add a catalog validation script or temporary command that checks all 150 current titles have metadata before shipping the feature.

Exit criteria: every scheduled problem can resolve to metadata, and missing metadata fails loudly in debug builds.

## Phase 2 - App-Only Solution Storage

Goal: persist user code without bloating App Group progress.

1. Create `SolutionStore` in the app target.
2. Store code under Application Support, not `StoredProgress`.
3. Key files by stable problem slug or title hash.
4. Store `source`, `updatedAt`, `lastRunResult`, and optional `selectedLanguage = python`.
5. Keep widget-visible status changes in `StudyProgressStore` only.
6. Do not add code fields to `DailyProgress` unless there is a later widget reason.

Exit criteria: user code survives app restarts, the widget progress JSON stays small, and deleting progress can optionally leave or clear solutions based on a user-facing setting.

## Phase 3 - Solve UI Without Python

Goal: build and test the data flow before embedding the runtime.

1. Add `SolveView` pushed from problem rows.
2. Show prompt, examples, constraints, hints, and starter code.
3. Use `TextEditor` for v1 unless a native iOS 26 syntax editor is confirmed stable.
4. Add buttons for Run Samples, Run All, Mark Green, Mark Yellow, and Mark Red.
5. Persist code through `SolutionStore` with a debounce.
6. Make Run buttons return a fake result until Phase 4.

Exit criteria: editing, persistence, navigation, and status updates work without the Python runtime.

## Phase 4 - Python Runtime Actor

Goal: isolate all CPython work behind one Swift entry point.

1. Create `PythonRuntimeActor` in the app target.
2. Lazy-initialize CPython on first run, not at app launch.
3. Serialize executions through the actor to avoid interpreter state races.
4. Expose one method: `run(solution:problem:tests:mode:) async -> RunResult`.
5. Return structured `RunResult` with `passed`, `total`, `cases`, `stdout`, `stderr`, `traceback`, `elapsedMs`, and `verdict`.
6. Never call CPython directly from SwiftUI views.

Exit criteria: sample tests can run from Swift and produce deterministic JSON results.

## Phase 5 - Restricted Harness

Goal: reduce risk from accidental bad code while staying honest that v1 is not a hard sandbox.

1. Validate source with Python `ast` before execution.
2. Reject imports by default.
3. Reject `eval`, `exec`, `open`, `input`, `compile`, `globals`, `locals`, `vars`, `dir`, and suspicious dunder access.
4. Provide a narrow builtins map: `abs`, `all`, `any`, `bool`, `dict`, `enumerate`, `float`, `int`, `len`, `list`, `max`, `min`, `range`, `reversed`, `set`, `sorted`, `str`, `sum`, `tuple`, and `zip`.
5. Add an allowlist for safe modules only if a problem needs it, such as `collections`, `heapq`, `bisect`, `math`, `functools`, and `itertools`.
6. Inject test inputs through JSON and call only the expected function name.
7. Capture stdout and cap it to a small byte limit.
8. Cap source length, test count, input size, and output size.

Exit criteria: normal NeetCode solutions run, obvious file/network/import attempts fail before execution, and results are readable.

## Phase 6 - Timeout And Failure Handling

Goal: prevent common infinite loops from ruining the session.

1. Start with cooperative wall-clock timeout using Python tracing or periodic checks in the harness.
2. Set a per-test timeout such as 1,000 to 2,000 ms for samples and a total timeout such as 5,000 ms for all tests.
3. Treat timeout as a verdict, not a crash.
4. If the interpreter becomes wedged, show a recovery message and require app restart for that run session.
5. Do not promise hard CPU or memory limits in v1.
6. Revisit process isolation only if the Phase 0 spike proves iOS child-process control is safe and reviewable.

Exit criteria: simple infinite loops time out in the harness during normal use, and the app UI remains responsive.

## Phase 7 - Results UX

Goal: make solving feel useful, not like a raw console.

1. Show per-case pass/fail rows.
2. Show expected vs actual output for failures.
3. Show collapsed traceback with a copy button.
4. Show runtime in milliseconds as an approximate local measurement.
5. Suggest Green when all tests pass, Yellow when samples pass but all tests fail or hints were opened, and Red when the user chooses to schedule redo.
6. Keep final status user-confirmed, not automatic.
7. Add a reveal action for bundled reference solution after the user has attempted the problem.

Exit criteria: a user can solve a problem end to end and update the same Green/Yellow/Red progress model already used by the app.

## Phase 8 - App Store And Privacy Review

Goal: keep the feature review-safe.

1. Do not download code, tests, prompts, or reference solutions.
2. Do not run code received from the network.
3. Keep all problem data bundled with the app.
4. Keep user code local to the device.
5. Update privacy copy to state that solutions are stored locally and not uploaded.
6. Re-check the privacy manifest if the runtime touches new required-reason APIs.
7. Add a clear user-facing disclaimer that local execution is for practice and may not match LeetCode exactly.

Exit criteria: archive review checklist is clean and the feature remains offline.

## Phase 9 - Hardening And Optional Improvements

1. Add syntax highlighting if a native iOS 26 option is stable.
2. Add problem-specific explanation pages from bundled content.
3. Add export/import of local solutions as JSON.
4. Add on-device Foundation Models help only if available, fully local, and user-approved.
5. Add a test target for catalog validation and runner fixtures if the no-tests convention is lifted.

## Out Of Scope

- No LeetCode account integration.
- No network execution.
- No downloaded prompts, tests, or reference code.
- No third-party Python packages like `numpy` or `pandas`.
- No multi-language support in v1.
- No claim of hostile-code sandboxing in v1.

## Ready-To-Proceed Checklist

- Confirm you want the local Python feature implemented.
- Confirm whether adding a test target is allowed for runner and catalog validation.
- Confirm whether CPython binary artifacts may be checked into the repo if no reliable SPM package exists.
- Confirm whether user solutions should be deleted when the user resets progress.
- Confirm the first metadata batch can start with a smaller subset before all 150 problems are filled.
