# Handoff.md

**Last Updated (UTC):** 2026-04-13 20:43:07 UTC
**Status:** In Progress
**Current Focus:** Move from shell stabilization into truthful dashboard and shared persistence repairs without regressing the now-working macOS app shell.

## 1) Request & Context
- **User’s request (quoted or paraphrased):** Read the macOS app codebase recursively, understand every Swift file, map how the app fits together, then drive the app from its current broken and incomplete state toward a complete, polished, shippable macOS release with improved UI, fixed bugs, additional calculations, updated README, and a pushed GitHub state.
- **Operational constraints / environment:** The project root is `/Users/rogerlin/Downloads/FinancialCalculatorKit-Advanced-main`. The repository is inside a Git worktree rooted at `/Users/rogerlin`, but `HEAD` is currently invalid and normal Git history commands are unsafe. The app targets macOS and uses SwiftUI, SwiftData, Swift Charts, and Swift Package dependencies. The current machine can build, run, sign, and UI-test the app locally.
- **Guidelines / preferences to honor:** Use native macOS patterns, keep changes coherent and reversible, maintain `handoff.md`, `feature_list.json`, and `agent-progress.txt`, prefer one fully-verified feature slice at a time, and do not mark work complete without scenario evidence.
- **Scope boundaries (explicit non-goals):** Do not rewrite the feature spec to reduce scope. Do not claim the app is ready to ship until build, tests, persistence, documentation, and Git state all align. Do not push or commit while repository refs remain broken.
- **Changes since start (dated deltas):**
  - 2026-04-13 UTC: Initial investigation confirmed the codebase compiled with `swift build` and `xcodebuild ... build`, but the app had architectural debt, unfinished flows, misleading UI copy, duplicate Xcode project membership, no meaningful tests, and no continuity harness.
  - 2026-04-13 UTC: Harness files and deterministic run scripts were added.
  - 2026-04-13 UTC: The corrupted Xcode project source phases were cleaned up, the app shell was refactored to use single-sheet routing, and shell-focused unit/UI tests were added and passed.

## 2) Requirements → Acceptance Checks (traceable)
| Requirement | Acceptance Check (scenario steps) | Expected Outcome | Evidence to Capture |
|---|---|---|---|
| R1: Establish continuity and execution harness | Confirm `handoff.md`, `feature_list.json`, `agent-progress.txt`, `init.sh`, and `script/build_and_run.sh` exist; run `init.sh` smoke check | A future session can rediscover status and run a deterministic health check | File contents plus terminal output from `init.sh` |
| R2: Restore trustworthy desktop app shell | Build app, launch app, navigate between dashboard/sidebar/detail, open preferences/help/new calculation flows | Main window launches cleanly, selection is stable, and primary chrome works without dead ends | `./script/build_and_run.sh --verify`, `xcodebuild ... test`, UI smoke logs |
| R3: Make shared persistence flows real | Create, favorite, edit, delete, and redisplay calculations across supported models | Recent activity, favorites, and saved calculations reflect actual stored data instead of placeholders | Scenario notes, query results, screenshots if needed |
| R4: Correct calculator logic and validation | Run representative scenarios for TVM, loan, bond, investment, options, depreciation, currency, unit conversion, and math expressions | Outputs are numerically reasonable, validation is actionable, and unsupported placeholder content is removed or replaced | Added tests, sample inputs/outputs, build/test logs |
| R5: Improve UI/UX to macOS quality bar | Inspect primary screens after refactor for desktop layout, keyboard discoverability, visual consistency, and honest labels | App uses native split-view patterns, meaningful cards/tables/charts, and avoids misleading “live” claims without data | Manual walkthrough notes, design diffs |
| R6: Add useful new capabilities | Introduce at least one substantive new planning/analysis workflow that improves product value and is fully wired into navigation, persistence, and docs | New feature is discoverable, validated, documented, and tested end to end | Feature-specific test evidence and README updates |
| R7: Provide reviewer-ready documentation | Update README and related docs so setup, features, and verification steps match reality | Documentation matches implemented functionality and how to run the app | Diff plus successful command transcript |

> Notes: Each requirement stays tied to observable scenario checks, not only compile success.

## 3) Plan & Decomposition (with rationale)
- **Critical path narrative:** The lowest-regret path remains: stabilize the shared shell and project graph first, then repair truthfulness and shared persistence, then audit calculator math, then add new product value. The shell is now stable enough that future slices can be tested from a trustworthy launch path.
- **Step 1:** Create the missing harness and project run scripts. Risks were low; evidence is file creation plus a smoke-check run. Status: complete.
- **Step 2:** Clean the Xcode project source graph and stabilize shell routing, keyboard paths, and calculator selection. Risks were temporary navigation regressions and UI automation brittleness. Evidence is passing build, launch, unit tests, and UI smoke. Status: complete.
- **Step 3:** Repair shared data workflows: creation, selection, recents aggregation, favorites, deletion, and persistence of preferences. Risks include SwiftData model mismatches across heterogeneous calculation types. Status: next on critical path.
- **Step 4:** Audit each calculator for placeholder UI, incorrect formulas, and incomplete workflows. Replace or remove fake capabilities, then add a new high-value calculator only after the existing foundation is trustworthy.
- **Step 5:** Add docs, ship checklist material, and prepare Git for a clean commit/push once repository refs are healthy.
- **Decision log reference(s):** See Sections 5 and 6 for findings that shaped the order.

## 4) To-Do & Progress Ledger
- [x] Inventory repository structure and read project docs — **done**; evidence: `rg --files`, `README.md`, `ARCHITECTURE.md`, `CHANGELOG.md`
- [x] Read top-level Swift app shell and core models — **done**; evidence: `FinancialCalculatorKitApp.swift`, `ContentView.swift`, `MainViewModel.swift`, model files
- [x] Run build triage — **done**; evidence: `swift build` succeeded; `xcodebuild ... build` succeeded
- [x] Create continuity harness files — **done**; evidence: `handoff.md`, `feature_list.json`, `agent-progress.txt`, `PLANS.md`, `init.sh`, `script/build_and_run.sh`, `.codex/environments/environment.toml`
- [x] Fix Xcode project duplicate source entries — **done**; evidence: `plutil -lint FinancialCalculatorKit.xcodeproj/project.pbxproj`, `./script/build_and_run.sh --verify` now succeeds
- [x] Refactor app shell into stable macOS scene layout — **done**; evidence: passing `xcodebuild ... test` including shell smoke for New Calculation, Preferences, Help, and calculator navigation
- [ ] Implement real preference persistence and recent/favorite/delete flows — purpose: make the app honest and stateful; planned evidence: create/edit/delete scenario
- [ ] Audit and repair dashboard truthfulness and recent-activity behavior — purpose: remove misleading claims and ensure quick actions reflect real app state; planned evidence: dashboard walkthrough
- [ ] Audit and repair calculator logic and placeholder surfaces — purpose: ensure calculator outputs and charts are reliable; planned evidence: sample-case verification
- [ ] Add at least one meaningful new calculator/planning workflow — purpose: improve usefulness beyond repair work; planned evidence: feature test and docs
- [ ] Refresh README and ship checklist — purpose: make the repo usable by a future maintainer or release reviewer; planned evidence: documentation diff

## 5) Findings, Decisions, Assumptions
- **Finding:** The app is a genuine macOS SwiftUI/SwiftData app, but the central shell was monolithic and mixed toolbar, navigation, sheets, recent activity, and dashboard behavior in one large view.
- **Finding:** `swift build` and direct Xcode builds succeeded even before repair, so the core blocker was not syntax but broken project hygiene, unfinished flows, and misleading UI behaviors.
- **Finding:** The app target’s `PBXSourcesBuildPhase` was polluted with duplicate and unrelated source entries. Emptying the explicit source membership for the app and test targets allowed filesystem-synced root groups to own source membership cleanly, which resolved the deterministic duplicate-output failure in the scripted launch path.
- **Finding:** The app shell had three independent sheet booleans and multiple call sites directly mutating them. This was fragile and made command routing harder to reason about.
- **Finding:** macOS UI automation was more reliable through keyboard shortcuts than through toolbar accessibility lookup, so shell smoke coverage now uses `⌘N`, `⌘,`, and `⌘⇧/` for the modal paths.
- **Finding:** The broader product still has unfinished behavior outside the shell slice: preference persistence remains suspect, recent deletion is still incomplete, dashboard truthfulness still needs attention, and several financial workflows need targeted math validation.
- **Decision:** Treat the first implementation slice as project-graph cleanup plus shell stabilization, because every other feature depends on a reliable build-and-launch path.
- **Decision:** Use a single `presentedSheet` enum in `MainViewModel` instead of multiple independent booleans, because this gives exclusive sheet routing and simpler keyboard-command handling.
- **Assumption:** It is reasonable to mark `feature_app_shell_navigation` as passing because the acceptance scenarios now have direct evidence for launch, sidebar selection, and new-calculation/preferences/help presentation and dismissal.

## 6) Issues, Mistakes, Recoveries
- **Symptom → root cause → fix → guardrail added:** `git status` and `git log` remain unreliable because repository `HEAD` is invalid. Root cause appears to be broken refs in the parent worktree. No fix was attempted in this slice. Guardrail: do not commit, push, or claim repository cleanliness until Git is repaired.
- **Symptom → root cause → fix → guardrail added:** `xcodebuild test` initially failed with a locked build database. Root cause was running build and test concurrently against the same DerivedData path. Fix: serialize `xcodebuild` usage. Guardrail: use one build/test session at a time through the scripted path or separate commands.
- **Symptom → root cause → fix → guardrail added:** `./script/build_and_run.sh --verify` failed with duplicate generated outputs such as `GeneratedAssetSymbols.swiftconstvalues`. Root cause was a corrupted Xcode project source-phase configuration that duplicated and mis-scoped source membership. Fix: remove the polluted explicit `PBXSourcesBuildPhase` entries so filesystem-synced groups define membership. Guardrail: use the scripted build-and-launch path as the canonical readiness check.
- **Symptom → root cause → fix → guardrail added:** Sheet presentation state was spread across multiple booleans, making exclusive routing harder to enforce. Root cause was ad hoc state growth in the shell. Fix: introduce `MainViewModel.PresentedSheet` and route all sheet presentation through it. Guardrail: new modal flows should be added through the enum and shared helper methods.
- **Regression check ID:** `RG-001` — rerun serialized `xcodebuild` commands through scripts instead of ad hoc parallel invocations.
- **Regression check ID:** `RG-002` — keep `./script/build_and_run.sh --verify` green after project-file edits.
- **Regression check ID:** `RG-003` — keep shell smoke tests covering `⌘N`, `⌘,`, `⌘⇧/`, and calculator selection.

## 7) Scenario-Focused Resolution Tests (problem-centric)
- **Problem:** The project lacked any session continuity artifacts.
  - **Repro steps:** Open repo root and observe missing `handoff.md`, `feature_list.json`, and `agent-progress.txt`.
  - **Change applied:** Added `handoff.md`, `feature_list.json`, `agent-progress.txt`, `PLANS.md`, `init.sh`, `script/build_and_run.sh`, and `.codex/environments/environment.toml`.
  - **Post-change behavior:** Future sessions can recover context, run a deterministic smoke check, and use a Codex app Run button.
  - **Verdict:** Resolved.
- **Problem:** The scripted build-and-launch path failed because the Xcode project produced duplicate generated outputs.
  - **Repro steps:** Run `./script/build_and_run.sh --verify` on the pre-fix project and observe duplicate-output failure from the app target.
  - **Change applied:** Cleaned the explicit `PBXSourcesBuildPhase` membership in `FinancialCalculatorKit.xcodeproj/project.pbxproj`.
  - **Post-change behavior:** `./script/build_and_run.sh --verify` now builds and launches the app successfully.
  - **Verdict:** Resolved.
- **Problem:** The main shell had fragile sheet routing and unverified command paths.
  - **Repro steps:** Inspect `ContentView.swift` and `MainViewModel.swift`; observe separate sheet booleans and direct mutations from multiple UI entry points.
  - **Change applied:** Added `MainViewModel.PresentedSheet`, centralized modal helpers, wired toolbar and dashboard actions through the view model, and added shell-focused unit and UI tests.
  - **Post-change behavior:** New Calculation, Preferences, and Help routes open and dismiss cleanly, and calculator selection updates the detail pane without broken states.
  - **Verdict:** Resolved for the shell slice.

## 8) Verification Summary (evidence over intuition)
- **Fast checks run:** `plutil -lint FinancialCalculatorKit.xcodeproj/project.pbxproj`; `xcodebuild -project FinancialCalculatorKit.xcodeproj -scheme FinancialCalculatorKit -destination 'platform=macOS' -derivedDataPath .derivedData test`; `./script/build_and_run.sh --verify`
- **Acceptance runs:**
  - `xcodebuild ... test` passed with three unit tests and two UI tests.
  - UI smoke verified `⌘N` opens New Calculation, `⌘,` opens Preferences, `⌘⇧/` opens Help, and sidebar selection of Loan Calculator updates the detail pane with the expected description.
  - `./script/build_and_run.sh --verify` passed and launched the app successfully after the project-file cleanup.
- **Evidence artifacts:**
  - Test result bundle: `/Users/rogerlin/Downloads/FinancialCalculatorKit-Advanced-main/.derivedData/Logs/Test/Test-FinancialCalculatorKit-2026.04.14_04-37-55-+0800.xcresult`
  - Scripted launch result: terminal output showing `** BUILD SUCCEEDED **` followed by `FinancialCalculatorKit launched successfully.`
- **Performance/latency snapshots (if relevant):** UI shell smoke completed in about 16.3 seconds for the UI target, which is acceptable for this local acceptance layer.

## 9) Remaining Work & Next Steps
- **Open items & blockers:** Git remains broken and blocks commit/push. The app shell is now stable, but dashboard honesty, preferences persistence, recent/favorite/delete flows, calculator math validation, a new planning tool, and README refresh are still pending.
- **Risks:** The shell is less fragile now, but `ContentView.swift` is still large. Financial formulas may compile while still being mathematically wrong. The dashboard still contains product-positioning risk until mock/live claims are made accurate.
- **Next working interval plan:**
  1. Repair dashboard truthfulness and quick-action honesty so the landing experience matches implemented behavior.
  2. Implement preference persistence and finish recent/favorite/delete data flows.
  3. Add scenario tests for those shared flows before moving into calculator-specific math audits.

## 10) Updates to This File (append-only)
- 2026-04-13 20:09:17 UTC: Created initial handoff with architecture findings, build evidence, major risks, and the first stabilization roadmap.
- 2026-04-13 20:09:17 UTC: Updated handoff after creating the harness, validating `init.sh`, reading the main calculator surfaces, and discovering that `build_and_run.sh --verify` fails because of a polluted Xcode project source graph.
- 2026-04-13 20:43:07 UTC: Updated handoff after cleaning the Xcode project source phases, refactoring shell sheet routing, adding shell-focused unit and UI tests, verifying `xcodebuild ... test`, and confirming `./script/build_and_run.sh --verify` launches the app successfully.
